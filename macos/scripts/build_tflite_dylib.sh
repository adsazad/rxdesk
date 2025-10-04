#!/usr/bin/env bash
set -euo pipefail

# Build TensorFlow Lite C API dynamic libraries for macOS (arm64 and x86_64) and lipo them into a universal dylib.
# Requirements:
# - cmake, ninja, git
# - Xcode command line tools
# - Internet access to fetch TF Lite source (or set TFLITE_SRC to a local checkout)
#
# Usage:
#   ./build_tflite_dylib.sh [TFLITE_TAG]
# Example to build a specific tag: ./build_tflite_dylib.sh v2.14.0

TFLITE_TAG=${1:-v2.14.0}
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
WORK_DIR="${ROOT_DIR}/macos/.tflite-build"
INSTALL_DIR="${ROOT_DIR}/macos/TensorFlowLite"
SRC_DIR="${WORK_DIR}/tensorflow"

mkdir -p "$WORK_DIR" "$INSTALL_DIR"

if [ ! -d "$SRC_DIR" ]; then
  echo "Cloning TensorFlow (this may take a while)..."
  git clone --depth=1 --branch ${TFLITE_TAG} https://github.com/tensorflow/tensorflow.git "$SRC_DIR"
else
  echo "Using existing TensorFlow source at $SRC_DIR"
fi

build_arch() {
  local ARCH="$1"; shift
  local BUILD_DIR="${WORK_DIR}/build-${ARCH}"
  echo "\n=== Building for ${ARCH} ==="
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  pushd "$BUILD_DIR" >/dev/null

  cmake -DTFLITE_ENABLE_RESOURCE=ON \
        -DTFLITE_ENABLE_XNNPACK=ON \
        -DCMAKE_OSX_ARCHITECTURES=${ARCH} \
        -DCMAKE_BUILD_TYPE=Release \
        -DTFLITE_ENABLE_EXTERNAL_DELEGATE=OFF \
        -S "${SRC_DIR}/tensorflow/lite/c" \
        -B .

  cmake --build . --config Release

  # Expect libtensorflowlite_c.dylib in build dir
  if [ ! -f "libtensorflowlite_c.dylib" ]; then
    echo "Error: libtensorflowlite_c.dylib not found for ${ARCH}" >&2
    exit 1
  fi

  cp -f libtensorflowlite_c.dylib "${INSTALL_DIR}/libtensorflowlite_c_${ARCH}.dylib"
  popd >/dev/null
}

build_arch arm64
build_arch x86_64

# Create universal binary
lipo -create \
  "${INSTALL_DIR}/libtensorflowlite_c_arm64.dylib" \
  "${INSTALL_DIR}/libtensorflowlite_c_x86_64.dylib" \
  -output "${INSTALL_DIR}/libtensorflowlite_c.dylib"

# Copy headers (C API headers only)
mkdir -p "${INSTALL_DIR}/include"
cp -R "${SRC_DIR}/tensorflow/lite/c" "${INSTALL_DIR}/include/"

echo "\nBuilt universal TensorFlow Lite C dylib at: ${INSTALL_DIR}/libtensorflowlite_c.dylib"
