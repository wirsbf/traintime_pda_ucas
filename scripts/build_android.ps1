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

# Clean stale jniLibs to prevent mixing architectures
if (Test-Path $ANDROID_LIBS_OUT) {
    Write-Host "Cleaning old jniLibs..."
    Remove-Item -Recurse -Force $ANDROID_LIBS_OUT
}
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
$OrtZipPath = "$CACHE_DIR/onnxruntime.zip"
$OrtExtractDir = "$CACHE_DIR/onnxruntime_extracted"

# Check if we need to extract (if dir missing OR jni missing)
if (-not (Test-Path "$OrtExtractDir/jni")) {
    Write-Host "Downloading/Extracting ONNX Runtime Android v$ORT_VERSION..."
    
    # Download if missing
    if (-not (Test-Path $OrtZipPath)) {
         Invoke-WebRequest -Uri $ORT_AAR_URL -OutFile $OrtZipPath
    }
    
    # Clean extract dir if exists
    if (Test-Path $OrtExtractDir) {
        Remove-Item -Recurse -Force $OrtExtractDir
    }

    Write-Host "Extracting AAR..."
    Expand-Archive -Path $OrtZipPath -DestinationPath $OrtExtractDir -Force
}

# Build Rust libraries per target
Write-Host "Building Rust libraries for Android..."
Push-Location rust

# Define targets and mapping to Android ABIs
# Format: @{ RustTarget = "target-triple"; AndroidAbi = "jni-lib-name" }
$Targets = @(
    @{ Rust = "aarch64-linux-android"; Abi = "arm64-v8a" }
    # @{ Rust = "armv7-linux-androideabi"; Abi = "armeabi-v7a" },
    # @{ Rust = "x86_64-linux-android"; Abi = "x86_64" }
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
    
    # Copy libonnxruntime.so to the same output directory
    # cargo ndk -o outputs to: $ANDROID_LIBS_OUT/$AndroidAbi/librust_ocr.so
    # So we copy to $ANDROID_LIBS_OUT/$AndroidAbi/
    $DestDir = "$ANDROID_LIBS_OUT/$AndroidAbi"
    if (-not (Test-Path $DestDir)) {
         New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
    }
    Copy-Item -Path "$OrtLibPath/libonnxruntime.so" -Destination "$DestDir/libonnxruntime.so" -Force
    Write-Host "Copied libonnxruntime.so to $DestDir"
    
    # Try to copy libc++_shared.so from NDK (Generic attempt)
    # Common NDK path: toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/lib/<triple>/libc++_shared.so
    
    $NdkRoot = $env:ANDROID_NDK_HOME
    
    # Auto-detect NDK if not set
    if (-not $NdkRoot) {
        $AutoNdk = Get-ChildItem -Path "$env:LOCALAPPDATA/Android/Sdk/ndk" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($AutoNdk) {
            $NdkRoot = $AutoNdk.FullName
            Write-Host "Auto-detected NDK: $NdkRoot"
        }
    }

    if ($NdkRoot) {
        $Triple = $RustTarget
        if ($RustTarget -eq "armv7-linux-androideabi") { $Triple = "arm-linux-androideabi" }
        
        # Search for libc++_shared.so recursively in NDK for this triple
        # Limit depth to avoid long searches, usually in toolchains
        $LibCxx = Get-ChildItem -Path "$NdkRoot/toolchains" -Filter "libc++_shared.so" -Recurse -ErrorAction SilentlyContinue | 
                  Where-Object { $_.FullName -like "*$Triple*" } | 
                  Select-Object -First 1
        
        if ($LibCxx) {
             Copy-Item -Path $LibCxx.FullName -Destination "$DestDir/libc++_shared.so" -Force
             Write-Host "Copied libc++_shared.so to $DestDir"
        } else {
             Write-Warning "Could not find libc++_shared.so for $Triple in NDK. App might crash if STL is missing."
        }
    } else {
        Write-Warning "ANDROID_NDK_HOME not set and auto-detection failed. Skiping libc++_shared.so copy."
    }
}

Pop-Location

# Build Flutter APK
Write-Host "Building Flutter APK..."
flutter build apk --release

Write-Host "Build Complete! APK located at: build/app/outputs/flutter-apk/app-release.apk"
