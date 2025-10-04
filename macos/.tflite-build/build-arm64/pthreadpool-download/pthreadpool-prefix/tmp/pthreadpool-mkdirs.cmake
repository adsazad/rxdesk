# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/pthreadpool-source"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/pthreadpool"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/pthreadpool-download/pthreadpool-prefix"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/pthreadpool-download/pthreadpool-prefix/tmp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/pthreadpool-download/pthreadpool-prefix/src/pthreadpool-stamp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/pthreadpool-download/pthreadpool-prefix/src"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/pthreadpool-download/pthreadpool-prefix/src/pthreadpool-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/pthreadpool-download/pthreadpool-prefix/src/pthreadpool-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/pthreadpool-download/pthreadpool-prefix/src/pthreadpool-stamp${cfgdir}") # cfgdir has leading slash
endif()
