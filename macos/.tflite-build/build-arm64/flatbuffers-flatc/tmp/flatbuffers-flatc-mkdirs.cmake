# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/flatbuffers"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/flatbuffers-flatc/src/flatbuffers-flatc-build"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/flatbuffers-flatc"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/flatbuffers-flatc/tmp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/flatbuffers-flatc/src/flatbuffers-flatc-stamp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/flatbuffers-flatc/src"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/flatbuffers-flatc/src/flatbuffers-flatc-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/flatbuffers-flatc/src/flatbuffers-flatc-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/flatbuffers-flatc/src/flatbuffers-flatc-stamp${cfgdir}") # cfgdir has leading slash
endif()
