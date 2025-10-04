# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/xnnpack"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/xnnpack-build"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/tmp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/src/xnnpack-populate-stamp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/src"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/src/xnnpack-populate-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/src/xnnpack-populate-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/src/xnnpack-populate-stamp${cfgdir}") # cfgdir has leading slash
endif()
