# TensorFlow Lite for macOS setup (Flutter + tflite_flutter)

This app uses `tflite_flutter` and on macOS you need to provide the TensorFlow Lite C dynamic library manually.

Important: The plugin looks for a file named `libtensorflowlite_c-mac.dylib` inside your app bundle Resources folder:

- `<YourApp>.app/Contents/Resources/libtensorflowlite_c-mac.dylib`

So even if you build or download `libtensorflowlite_c.dylib`, you must ensure a copy exists in Resources with the exact name `libtensorflowlite_c-mac.dylib`.

## 1) Build the TensorFlow Lite C dylib (universal)

We provide a helper script that builds arm64 and x86_64 binaries using CMake and lipo’s them into a universal dylib.

Requirements: Xcode CLT, cmake, git, ninja (optional)

Steps:

- Open a terminal at the project root
- Run:

```
./macos/scripts/build_tflite_dylib.sh v2.14.0
```

This will produce:

- `macos/TensorFlowLite/libtensorflowlite_c.dylib` (universal)
- headers under `macos/TensorFlowLite/include/tensorflow/lite/c/`

If you already have prebuilt dylibs, place the universal `libtensorflowlite_c.dylib` under `macos/TensorFlowLite/`.

## 2) Add the dylib to the Xcode project

Follow the official Flutter guide for adding a dynamic library on macOS (similar to iOS):

1) Open `macos/Runner.xcworkspace` in Xcode
2) In the Runner target:
   - General > Frameworks, Libraries, and Embedded Content: press `+` and add `libtensorflowlite_c.dylib` from `macos/TensorFlowLite/`
   - Set it to “Embed & Sign” (this places it under `Contents/Frameworks`)
3) Build Settings:
   - Library Search Paths: add `$(PROJECT_DIR)/TensorFlowLite`
   - Header Search Paths (if needed for C headers): add `$(PROJECT_DIR)/TensorFlowLite/include`
4) Ensure a copy with the expected name is in Resources (see next section)

### 2a) Ensure the expected file in Resources (preferred: Run Script)

Add a Run Script phase after “Embed Frameworks” to copy and rename the dylib into Resources with the expected name:

Script to run:

```
bash "${PROJECT_DIR}/scripts/embed_tflite_dylib.sh"
```

Notes:
- Make the script executable once: `chmod +x macos/scripts/embed_tflite_dylib.sh`
- The script copies `macos/TensorFlowLite/libtensorflowlite_c.dylib` to `Contents/Resources/libtensorflowlite_c-mac.dylib` and codesigns it when applicable.

Alternative (manual): Add `libtensorflowlite_c.dylib` to a “Copy Files” phase targeting `Resources` and set the destination filename to `libtensorflowlite_c-mac.dylib`.

## 3) Codesigning (if needed)

For distribution or strict environments, codesign the dylib:

```
codesign --force --sign - macos/TensorFlowLite/libtensorflowlite_c.dylib
```

Use a real signing identity instead of `-` if required.

## 4) Verify at runtime

When the app launches the AI model, check logs:

- You should see the interpreter initialized and no dynamic library error.
- If you see an error like “Failed to load dynamic library ... Contents/Resources/libtensorflowlite_c-mac.dylib (no such file)”, then the file is missing. Verify build output contains:
  - `YourApp.app/Contents/Resources/libtensorflowlite_c-mac.dylib`
  - If missing, check the Run Script phase and that `macos/TensorFlowLite/libtensorflowlite_c.dylib` exists.

## 5) Architecture notes

- If you need to build per-arch:
  - arm64: `-DCMAKE_OSX_ARCHITECTURES=arm64`
  - x86_64: `-DCMAKE_OSX_ARCHITECTURES=x86_64`
- Create the universal using lipo:

```
lipo -create arm64/libtensorflowlite_c.dylib x86/libtensorflowlite_c.dylib -output libtensorflowlite_c.dylib
```

## 6) Troubleshooting

- If Xcode can’t find the library, ensure `libtensorflowlite_c.dylib` is inside the app bundle (Embed & Sign) and `@rpath` resolves at runtime.
- If using Rosetta or running on x86_64, make sure the universal has both slices (check with `lipo -info macos/TensorFlowLite/libtensorflowlite_c.dylib`).
- If fromAsset still fails to load the model, the fallback that uses `fromFile` (now added) helps bypass asset lookup issues.
