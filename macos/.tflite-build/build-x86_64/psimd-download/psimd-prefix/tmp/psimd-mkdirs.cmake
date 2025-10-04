# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/psimd-source"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/psimd"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/psimd-download/psimd-prefix"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/psimd-download/psimd-prefix/tmp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/psimd-download/psimd-prefix/src/psimd-stamp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/psimd-download/psimd-prefix/src"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/psimd-download/psimd-prefix/src/psimd-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/psimd-download/psimd-prefix/src/psimd-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/psimd-download/psimd-prefix/src/psimd-stamp${cfgdir}") # cfgdir has leading slash
endif()
