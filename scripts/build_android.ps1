# Check and install cargo-ndk
Write-Host "Checking/Installing cargo-ndk..."
if (-not (Get-Command cargo-ndk -ErrorAction SilentlyContinue)) {
    cargo install cargo-ndk
}

# Configuration
$ORT_VERSION = "1.17.3"
$ORT_AAR_URL = "https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/$ORT_VERSION/onnxruntime-android-$ORT_VERSION.aar"
$CACHE_DIR = "build_cache"
$ANDROID_LIBS_OUT = "../android/app/src/main/jniLibs"

# Ensure output dir exists
if (-not (Test-Path $ANDROID_LIBS_OUT)) {
    New-Item -ItemType Directory -Force -Path $ANDROID_LIBS_OUT | Out-Null
}

# Setup directory for caching ORT
if (-not (Test-Path $CACHE_DIR)) {
    New-Item -ItemType Directory -Force -Path $CACHE_DIR | Out-Null
}

# Download and Extract ORT AAR if needed
$OrtAarPath = "$CACHE_DIR/onnxruntime.aar"
$OrtExtractDir = "$CACHE_DIR/onnxruntime_extracted"

if (-not (Test-Path $OrtExtractDir)) {
    Write-Host "Downloading ONNX Runtime Android v$ORT_VERSION..."
    Invoke-WebRequest -Uri $ORT_AAR_URL -OutFile $OrtAarPath
    
    Write-Host "Extracting AAR..."
    # AAR is just a ZIP
    Expand-Archive -Path $OrtAarPath -DestinationPath $OrtExtractDir -Force
}

# Build Rust libraries per target
Write-Host "Building Rust libraries for Android..."
Push-Location rust

# Define targets and mapping to Android ABIs
# Format: @{ RustTarget = "target-triple"; AndroidAbi = "jni-lib-name" }
$Targets = @(
    @{ Rust = "aarch64-linux-android"; Abi = "arm64-v8a" },
    @{ Rust = "armv7-linux-androideabi"; Abi = "armeabi-v7a" },
    @{ Rust = "x86_64-linux-android"; Abi = "x86_64" }
)

# Ensure targets installed
foreach ($t in $Targets) {
    rustup target add $t.Rust
}

foreach ($t in $Targets) {
    $RustTarget = $t.Rust
    $AndroidAbi = $t.Abi
    Write-Host "--> Building for $RustTarget ($AndroidAbi)..."

    # Locate the extracted .so for this ABI
    # AAR structure: jni/<abi>/libonnxruntime.so
    $OrtLibPath = Resolve-Path "../$OrtExtractDir/jni/$AndroidAbi"
    
    if (-not (Test-Path "$OrtLibPath/libonnxruntime.so")) {
        Write-Error "Could not find libonnxruntime.so for $AndroidAbi in extraction dir!"
        exit 1
    }

    # Set Environment Variables for 'ort' crate to find the library
    $env:ORT_STRATEGY = "system"
    $env:ORT_LIB_LOCATION = $OrtLibPath.Path

    # Run cargo ndk build for SINGLE target
    # We use cargo ndk to handle env vars for cross-compilation (CC, AR, etc)
    cargo ndk -t $RustTarget -o $ANDROID_LIBS_OUT build --release

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed for $RustTarget"
        Pop-Location
        exit 1
    }
}

Pop-Location

# Build Flutter APK
Write-Host "Building Flutter APK..."
flutter build apk --release

Write-Host "Build Complete! APK located at: build/app/outputs/flutter-apk/app-release.apk"
