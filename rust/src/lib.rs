use std::ffi::CString;
use std::os::raw::c_char;
use std::ptr;
use std::sync::OnceLock;

static OCR_INSTANCE: OnceLock<Result<ddddocr::Ddddocr<'static>, String>> = OnceLock::new();
static LAST_ERROR: OnceLock<std::sync::Mutex<String>> = OnceLock::new();

fn get_ocr() -> Result<&'static ddddocr::Ddddocr<'static>, String> {
    let result = OCR_INSTANCE.get_or_init(|| {
        match ddddocr::ddddocr_classification_old() {
            Ok(ocr) => Ok(ocr),
            Err(e) => Err(format!("OCR init failed: {:?}", e)),
        }
    });
    
    match result {
        Ok(ocr) => Ok(ocr),
        Err(e) => Err(e.clone()),
    }
}

fn set_error(msg: String) {
    let mutex = LAST_ERROR.get_or_init(|| std::sync::Mutex::new(String::new()));
    if let Ok(mut guard) = mutex.lock() {
        *guard = msg;
    }
}

/// Get last error message
#[no_mangle]
pub extern "C" fn get_last_error() -> *mut c_char {
    let mutex = LAST_ERROR.get_or_init(|| std::sync::Mutex::new(String::new()));
    if let Ok(guard) = mutex.lock() {
        if let Ok(c_str) = CString::new(guard.clone()) {
            return c_str.into_raw();
        }
    }
    ptr::null_mut()
}

/// Solve captcha from image bytes
#[no_mangle]
pub extern "C" fn solve_captcha(
    image_ptr: *const u8,
    image_len: usize,
) -> *mut c_char {
    if image_ptr.is_null() {
        set_error("image_ptr is null".to_string());
        return ptr::null_mut();
    }
    if image_len == 0 {
        set_error("image_len is 0".to_string());
        return ptr::null_mut();
    }

    let image_bytes = unsafe { std::slice::from_raw_parts(image_ptr, image_len) };

    // Get or init OCR
    let ocr = match get_ocr() {
        Ok(o) => o,
        Err(e) => {
            set_error(e);
            return ptr::null_mut();
        }
    };

    // Run classification
    match ocr.classification(image_bytes) {
        Ok(text) => {
            match CString::new(text) {
                Ok(c_str) => c_str.into_raw(),
                Err(e) => {
                    set_error(format!("CString error: {:?}", e));
                    ptr::null_mut()
                }
            }
        }
        Err(e) => {
            set_error(format!("classification error: {:?}", e));
            ptr::null_mut()
        }
    }
}

/// Free a string returned by solve_captcha or get_last_error
#[no_mangle]
pub extern "C" fn free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}
