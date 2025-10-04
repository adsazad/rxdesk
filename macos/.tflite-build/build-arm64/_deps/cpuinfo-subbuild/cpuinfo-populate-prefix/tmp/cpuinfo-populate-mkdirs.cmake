# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/cpuinfo"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/cpuinfo-build"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/cpuinfo-subbuild/cpuinfo-populate-prefix"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/cpuinfo-subbuild/cpuinfo-populate-prefix/tmp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/cpuinfo-subbuild/cpuinfo-populate-prefix/src/cpuinfo-populate-stamp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/cpuinfo-subbuild/cpuinfo-populate-prefix/src"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/cpuinfo-subbuild/cpuinfo-populate-prefix/src/cpuinfo-populate-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/cpuinfo-subbuild/cpuinfo-populate-prefix/src/cpuinfo-populate-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/cpuinfo-subbuild/cpuinfo-populate-prefix/src/cpuinfo-populate-stamp${cfgdir}") # cfgdir has leading slash
endif()
