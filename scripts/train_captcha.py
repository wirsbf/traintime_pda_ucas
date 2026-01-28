
import os
import random
import string
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models, backend as K
from PIL import Image, ImageDraw, ImageFont

# Configuration
CHAR_SET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
CAPTCHA_LENGTH = 4
WIDTH = 120
HEIGHT = 40
BATCH_SIZE = 64
EPOCHS = 50
TRAIN_SAMPLES = 50000
VAL_SAMPLES = 5000
MODEL_PATH = "captcha_model.tflite"

def generate_captcha_text():
    return "".join(random.choices(CHAR_SET, k=CAPTCHA_LENGTH))

def generate_captcha_image(text):
    image = Image.new('RGB', (WIDTH, HEIGHT), (255, 255, 255))
    font = ImageFont.load_default() # In real usage, use a TTF font that looks like the target
    draw = ImageDraw.Draw(image)
    
    # Add noise (lines, dots)
    for _ in range(5):
        x1 = random.randint(0, WIDTH)
        y1 = random.randint(0, HEIGHT)
        x2 = random.randint(0, WIDTH)
        y2 = random.randint(0, HEIGHT)
        draw.line(((x1, y1), (x2, y2)), fill=(0, 0, 0), width=1)
        
    for _ in range(50):
        x = random.randint(0, WIDTH)
        y = random.randint(0, HEIGHT)
        draw.point((x, y), fill=(0, 0, 0))

    # Draw text
    # This is a very basic generator. For better results, match the target site's font and style.
    w_total = 0
    chars_draw = []
    
    # Simple spacing logic
    step = WIDTH // (CAPTCHA_LENGTH + 1)
    for i, char in enumerate(text):
        x = step * (i + 0.5)
        y = random.randint(5, 15)
        draw.text((x, y), char, font=font, fill=(0, 0, 0))

    return image

def preprocess_image(image):
    # Convert to grayscale
    image = image.convert('L')
    # Resize to specific input size if needed (we generated at target size)
    image = image.resize((WIDTH, HEIGHT))
    # Normalize to [0, 1]
    arr = np.array(image).astype(np.float32) / 255.0
    # Transpose to (Width, Height, Channels) for TimeDistributed usage if strictly following CRNN papers,
    # but standard CNN inputs are usually (Height, Width, Channel). 
    # For TFLite optimization, (H, W, 1) or (1, H, W, 1) is standard.
    # However, for CRNN (CNN->RNN), the width is often the time dimension.
    # Let's use (Width, Height, 1) structure for "Time-Major" simulation after permutation
    arr = np.expand_dims(arr, axis=-1)
    return arr

# Data Generator
class CaptchaSequence(tf.keras.utils.Sequence):
    def __init__(self, samples, batch_size):
        self.samples = samples
        self.batch_size = batch_size
        self.char_map = {c: i for i, c in enumerate(CHAR_SET)}
        
    def __len__(self):
        return self.samples // self.batch_size
    
    def __getitem__(self, idx):
        x_batch = []
        y_batch = []
        
        for _ in range(self.batch_size):
            text = generate_captcha_text()
            img = generate_captcha_image(text)
            processed_img = preprocess_image(img)
            # Transpose to (Width, Height, 1) so Width is time axis
            # TF Conv2D usually expects (Batch, Height, Width, Channel)
            # We will permute inside the model.
            x_batch.append(processed_img)
            
            # Label encoding for CTC
            label = [self.char_map[c] for c in text]
            y_batch.append(label)
            
        return np.array(x_batch), np.array(y_batch)

# CTC Layer
class CTCLayer(layers.Layer):
    def __init__(self, name=None):
        super().__init__(name=name)
        self.loss_fn = K.ctc_batch_cost

    def call(self, y_true, y_pred):
        # Compute the training-time loss value and add it
        # to the layer using `self.add_loss()`.
        batch_len = tf.cast(tf.shape(y_true)[0], dtype="int64")
        input_length = tf.cast(tf.shape(y_pred)[1], dtype="int64")
        label_length = tf.cast(tf.shape(y_true)[1], dtype="int64")

        input_length = input_length * tf.ones(shape=(batch_len, 1), dtype="int64")
        label_length = label_length * tf.ones(shape=(batch_len, 1), dtype="int64")

        loss = self.loss_fn(y_true, y_pred, input_length, label_length)
        self.add_loss(loss)

        # At test time, just return the computed predictions
        return y_pred

def build_model():
    # Input: (Height, Width, 1) -> Standard Image format
    input_img = layers.Input(shape=(HEIGHT, WIDTH, 1), name="image", dtype="float32")
    labels = layers.Input(name="label", shape=(None,), dtype="float32")

    # CNN
    x = layers.Conv2D(32, (3, 3), activation="relu", kernel_initializer="he_normal", padding="same")(input_img)
    x = layers.MaxPooling2D((2, 2), name="pool1")(x)
    
    x = layers.Conv2D(64, (3, 3), activation="relu", kernel_initializer="he_normal", padding="same")(x)
    x = layers.MaxPooling2D((2, 2), name="pool2")(x)

    # We have downsampled by 4 locally (pool1 * pool2). 
    # Height 40 -> 10. Width 120 -> 30.
    # Reshape to (Width, Height * Channels) = (30, 10 * 64) = (30, 640)
    # This prepares for RNN (Time, Features)
    new_shape = ((WIDTH // 4), (HEIGHT // 4) * 64)
    x = layers.Reshape(target_shape=new_shape, name="reshape")(x)
    
    x = layers.Dense(64, activation="relu", name="dense1")(x)
    
    # RNNs
    x = layers.Bidirectional(layers.LSTM(128, return_sequences=True, dropout=0.25))(x)
    x = layers.Bidirectional(layers.LSTM(64, return_sequences=True, dropout=0.25))(x)
    
    # Output: (Time, NumChars + 1 for blank)
    x = layers.Dense(len(CHAR_SET) + 1, activation="softmax", name="dense2")(x)
    
    # Add CTC layer for training
    output = CTCLayer(name="ctc_loss")(labels, x)
    
    # Define the model with inputs image and labels
    model = models.Model(inputs=[input_img, labels], outputs=output, name="ocr_model_v1")
    return model

if __name__ == "__main__":
    print("Building model...")
    model = build_model()
    model.compile(optimizer=tf.keras.optimizers.Adam())
    model.summary()
    
    print("Starting training...")
    train_gen = CaptchaSequence(TRAIN_SAMPLES, BATCH_SIZE)
    val_gen = CaptchaSequence(VAL_SAMPLES, BATCH_SIZE)
    
    # Check if we can train simply
    # Note: Keras sequence with custom output signature could be tricky with fit,
    # but since layer has add_loss, we can pass dummy targets.
    
    # Actually, simpler to just pass x and y if generator yields them.
    # But Keras Sequence __getitem__ returns (x, y). 
    # For multi-input model, x should be specific.
    # Let's adjust Generator to return ({'image': img, 'label': label}, dummy_y)
    
    class MultiInputSequence(CaptchaSequence):
        def __getitem__(self, idx):
            x, y = super().__getitem__(idx)
            return {"image": x, "label": y}, y 
            
    train_gen_multi = MultiInputSequence(TRAIN_SAMPLES, BATCH_SIZE)
    val_gen_multi = MultiInputSequence(VAL_SAMPLES, BATCH_SIZE)

    model.fit(
        train_gen_multi,
        validation_data=val_gen_multi,
        epochs=EPOCHS,
        callbacks=[tf.keras.callbacks.EarlyStopping(patience=3)]
    )
    
    print("Training complete. Converting to TFLite...")
    
    # Extraction model (without CTC layer/labels input) for inference
    prediction_model = models.Model(
        model.get_layer(name="image").input, model.get_layer(name="dense2").output
    )
    
    converter = tf.lite.TFLiteConverter.from_keras_model(prediction_model)
    tflite_model = converter.convert()

    with open(MODEL_PATH, 'wb') as f:
        f.write(tflite_model)
        
    print(f"Model saved to {MODEL_PATH}")
    print("Please copy this file to assets/captcha_model.tflite in your Flutter project.")
