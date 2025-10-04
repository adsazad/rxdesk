#!/usr/bin/env bash
# Embed libtensorflowlite_c into the macOS app bundle Resources with the expected name.
#
# Primary usage: Add as an Xcode Run Script phase (after "Embed Frameworks").
#   Copies macos/TensorFlowLite/libtensorflowlite_c.dylib to:
#     <App>.app/Contents/Resources/libtensorflowlite_c-mac.dylib
#
# Manual usage (outside Xcode):
#   embed_tflite_dylib.sh --bundle "/path/to/YourApp.app" [--src "/path/to/libtensorflowlite_c.dylib"] [--codesign "IDENTITY|-"]
#
set -euo pipefail

show_usage() {
  cat <<'USAGE'
Usage:
  Xcode build phase:  bash "${PROJECT_DIR}/scripts/embed_tflite_dylib.sh"
  Manual invocation:  embed_tflite_dylib.sh --bundle "/path/to/YourApp.app" [--src "/path/to/libtensorflowlite_c.dylib"] [--codesign "IDENTITY|-"]

Notes:
  - By default, --src resolves to macos/TensorFlowLite/libtensorflowlite_c.dylib relative to this script.
  - The destination is always: <App>.app/Contents/Resources/libtensorflowlite_c-mac.dylib
  - Provide --codesign if you want to codesign manually when not building in Xcode.
USAGE
}

# Defaults relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR_FALLBACK="$(cd "${SCRIPT_DIR}/.." && pwd)"        # macos/
SRC_DIR_DEFAULT="${PROJECT_DIR_FALLBACK}/TensorFlowLite"
SRC_LIB_DEFAULT="${SRC_DIR_DEFAULT}/libtensorflowlite_c.dylib"

BUNDLE_PATH=""
SRC_LIB_OVERRIDE=""
CODESIGN_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle)
      BUNDLE_PATH="${2:-}"
      shift 2
      ;;
    --src)
      SRC_LIB_OVERRIDE="${2:-}"
      shift 2
      ;;
    --codesign)
      CODESIGN_ID="${2:-}"
      shift 2
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo "[embed_tflite_dylib] Unknown argument: $1"
      show_usage
      exit 1
      ;;
  esac
done

DEST_DIR=""
DEST_LIB=""
SRC_LIB=""

if [[ -n "${PROJECT_DIR:-}" && -n "${BUILT_PRODUCTS_DIR:-}" && -n "${WRAPPER_NAME:-}" ]]; then
  # Xcode mode
  SRC_DIR="${PROJECT_DIR}/TensorFlowLite"
  SRC_LIB="${SRC_LIB_OVERRIDE:-${SRC_DIR}/libtensorflowlite_c.dylib}"
  DEST_DIR="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Contents/Resources"
  DEST_LIB="${DEST_DIR}/libtensorflowlite_c-mac.dylib"
else
  # Manual mode
  if [[ -z "${BUNDLE_PATH}" ]]; then
    echo "[embed_tflite_dylib] Missing Xcode environment. Provide --bundle <path to .app> or run from Xcode build phases."
    show_usage
    exit 1
  fi
  if [[ ! -d "${BUNDLE_PATH}" || "${BUNDLE_PATH##*.}" != "app" ]]; then
    echo "[embed_tflite_dylib] --bundle must point to a valid .app directory: ${BUNDLE_PATH}"
    exit 1
  fi
  SRC_LIB="${SRC_LIB_OVERRIDE:-${SRC_LIB_DEFAULT}}"
  DEST_DIR="${BUNDLE_PATH}/Contents/Resources"
  DEST_LIB="${DEST_DIR}/libtensorflowlite_c-mac.dylib"
fi

if [[ ! -f "${SRC_LIB}" ]]; then
  # Fallback: try the already-embedded copy under Contents/Frameworks in the built app
  if [[ -n "${BUNDLE_PATH}" ]]; then
    # Manual mode fallback
    FALLBACK_SRC="${BUNDLE_PATH}/Contents/Frameworks/libtensorflowlite_c.dylib"
  else
    # Xcode mode fallback
    FALLBACK_SRC="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Contents/Frameworks/libtensorflowlite_c.dylib"
  fi
  if [[ -f "${FALLBACK_SRC}" ]]; then
    echo "[embed_tflite_dylib] Using fallback source from Frameworks: ${FALLBACK_SRC}"
    SRC_LIB="${FALLBACK_SRC}"
  else
    echo "[embed_tflite_dylib] Source dylib not found: ${SRC_LIB}"
    echo "[embed_tflite_dylib] Also not found fallback at: ${FALLBACK_SRC}"
    echo "Place a universal libtensorflowlite_c.dylib under macOS project at: ${SRC_DIR_DEFAULT} or ensure Xcode embeds it to Frameworks."
    exit 2
  fi
fi

mkdir -p "${DEST_DIR}"
cp -f "${SRC_LIB}" "${DEST_LIB}"

# Codesign when applicable
if [[ -n "${CODESIGN_ID}" ]]; then
  echo "[embed_tflite_dylib] Codesigning ${DEST_LIB} with identity ${CODESIGN_ID}"
  codesign --force --sign "${CODESIGN_ID}" --timestamp=none "${DEST_LIB}" || true
elif [[ "${CODE_SIGNING_ALLOWED:-NO}" == "YES" ]]; then
  IDENTITY=${EXPANDED_CODE_SIGN_IDENTITY:-"-"}
  echo "[embed_tflite_dylib] Codesigning ${DEST_LIB} with identity ${IDENTITY}"
  codesign --force --sign "${IDENTITY}" --timestamp=none "${DEST_LIB}" || true
fi

echo "[embed_tflite_dylib] Embedded ${DEST_LIB}"