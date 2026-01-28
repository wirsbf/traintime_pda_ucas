use std::ffi::CString;
use std::os::raw::c_char;
use std::ptr;
use std::sync::Once;
use std::sync::OnceLock;
use std::panic;

static OCR_INSTANCE: OnceLock<Result<ddddocr::Ddddocr<'static>, String>> = OnceLock::new();
static LAST_ERROR: OnceLock<std::sync::Mutex<String>> = OnceLock::new();
static INIT_LOGGER: Once = Once::new();

fn init_logger() {
    INIT_LOGGER.call_once(|| {
        #[cfg(target_os = "android")]
        {
            android_logger::init_once(
                android_logger::Config::default()
                    .with_max_level(log::LevelFilter::Debug)
                    .with_tag("RustOcr"),
            );
            log::info!("Android Logger initialized");
            
            // Explicitly load libc++_shared.so first (STL dependency)
            unsafe {
                match libloading::os::unix::Library::open(Some("libc++_shared.so"), 0x102) {
                    Ok(lib) => {
                        std::mem::forget(lib);
                        log::info!("Successfully loaded libc++_shared.so with RTLD_GLOBAL");
                    },
                    Err(e) => {
                         // It might be preloaded by Zygote or dependencies, so not always fatal
                        log::warn!("Failed to load libc++_shared.so (might be okay if already loaded): {:?}", e);
                    }
                }
            }

            // Explicitly load libonnxruntime.so with RTLD_GLOBAL (0x100) | RTLD_NOW (0x2)
            // This ensures ddddocr/ort can find the symbols
            unsafe {
                match libloading::os::unix::Library::open(Some("libonnxruntime.so"), 0x102) {
                    Ok(lib) => {
                        // Leak the library to keep it loaded forever
                        std::mem::forget(lib);
                        log::info!("Successfully loaded libonnxruntime.so with RTLD_GLOBAL");
                    },
                    Err(e) => {
                        log::error!("Failed to load libonnxruntime.so: {:?}", e);
                    }
                }
            }
        }
    });
}

fn get_ocr() -> Result<&'static ddddocr::Ddddocr<'static>, String> {
    let result = OCR_INSTANCE.get_or_init(|| {
        log::info!("Initializing ddddocr...");
        match ddddocr::ddddocr_classification_old() {
            Ok(ocr) => {
                log::info!("ddddocr init success");
                Ok(ocr)
            }
            Err(e) => {
                let msg = format!("OCR init failed: {:?}", e);
                log::error!("{}", msg);
                Err(msg)
            }
        }
    });
    
    match result {
        Ok(ocr) => Ok(ocr),
        Err(e) => Err(e.clone()),
    }
}

fn set_error(msg: String) {
    log::error!("Error: {}", msg);
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
    init_logger(); // Ensure logger is ready
    
    // Catch panic to prevent unwinding into C/Dart
    let result = panic::catch_unwind(|| {
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
        log::info!("Running classification on {} bytes", image_len);
        match ocr.classification(image_bytes) {
            Ok(text) => {
                log::info!("Classification result: {}", text);
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
    });

    match result {
        Ok(ptr) => ptr,
        Err(payload) => {
            let msg = if let Some(s) = payload.downcast_ref::<&str>() {
                format!("Rust Panic: {}", s)
            } else if let Some(s) = payload.downcast_ref::<String>() {
                format!("Rust Panic: {}", s)
            } else {
                "Rust Panic: Unknown error".to_string()
            };
            set_error(msg);
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

