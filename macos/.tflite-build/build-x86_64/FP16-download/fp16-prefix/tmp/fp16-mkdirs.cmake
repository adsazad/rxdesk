# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FP16-source"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FP16"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FP16-download/fp16-prefix"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FP16-download/fp16-prefix/tmp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FP16-download/fp16-prefix/src/fp16-stamp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FP16-download/fp16-prefix/src"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FP16-download/fp16-prefix/src/fp16-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FP16-download/fp16-prefix/src/fp16-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FP16-download/fp16-prefix/src/fp16-stamp${cfgdir}") # cfgdir has leading slash
endif()
