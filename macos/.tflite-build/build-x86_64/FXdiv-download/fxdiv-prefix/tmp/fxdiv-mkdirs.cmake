# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FXdiv-source"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FXdiv"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FXdiv-download/fxdiv-prefix"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FXdiv-download/fxdiv-prefix/tmp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FXdiv-download/fxdiv-prefix/src/fxdiv-stamp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FXdiv-download/fxdiv-prefix/src"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FXdiv-download/fxdiv-prefix/src/fxdiv-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FXdiv-download/fxdiv-prefix/src/fxdiv-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/FXdiv-download/fxdiv-prefix/src/fxdiv-stamp${cfgdir}") # cfgdir has leading slash
endif()
