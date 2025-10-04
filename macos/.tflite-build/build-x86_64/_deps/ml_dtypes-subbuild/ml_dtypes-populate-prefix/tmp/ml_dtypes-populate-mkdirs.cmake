# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/ml_dtypes"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/ml_dtypes-build"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/ml_dtypes-subbuild/ml_dtypes-populate-prefix"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/ml_dtypes-subbuild/ml_dtypes-populate-prefix/tmp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/ml_dtypes-subbuild/ml_dtypes-populate-prefix/src/ml_dtypes-populate-stamp"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/ml_dtypes-subbuild/ml_dtypes-populate-prefix/src"
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/ml_dtypes-subbuild/ml_dtypes-populate-prefix/src/ml_dtypes-populate-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/ml_dtypes-subbuild/ml_dtypes-populate-prefix/src/ml_dtypes-populate-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/ml_dtypes-subbuild/ml_dtypes-populate-prefix/src/ml_dtypes-populate-stamp${cfgdir}") # cfgdir has leading slash
endif()
