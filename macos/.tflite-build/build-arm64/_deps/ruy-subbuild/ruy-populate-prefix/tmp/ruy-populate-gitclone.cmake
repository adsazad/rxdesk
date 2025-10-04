# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

if(EXISTS "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/ruy-subbuild/ruy-populate-prefix/src/ruy-populate-stamp/ruy-populate-gitclone-lastrun.txt" AND EXISTS "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/ruy-subbuild/ruy-populate-prefix/src/ruy-populate-stamp/ruy-populate-gitinfo.txt" AND
  "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/ruy-subbuild/ruy-populate-prefix/src/ruy-populate-stamp/ruy-populate-gitclone-lastrun.txt" IS_NEWER_THAN "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/ruy-subbuild/ruy-populate-prefix/src/ruy-populate-stamp/ruy-populate-gitinfo.txt")
  message(STATUS
    "Avoiding repeated git clone, stamp file is up to date: "
    "'/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/ruy-subbuild/ruy-populate-prefix/src/ruy-populate-stamp/ruy-populate-gitclone-lastrun.txt'"
  )
  return()
endif()

execute_process(
  COMMAND ${CMAKE_COMMAND} -E rm -rf "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/ruy"
  RESULT_VARIABLE error_code
)
if(error_code)
  message(FATAL_ERROR "Failed to remove directory: '/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/ruy'")
endif()

# try the clone 3 times in case there is an odd git clone issue
set(error_code 1)
set(number_of_tries 0)
while(error_code AND number_of_tries LESS 3)
  execute_process(
    COMMAND "/usr/bin/git"
            clone --no-checkout --progress --config "advice.detachedHead=false" "https://github.com/google/ruy" "ruy"
    WORKING_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64"
    RESULT_VARIABLE error_code
  )
  math(EXPR number_of_tries "${number_of_tries} + 1")
endwhile()
if(number_of_tries GREATER 1)
  message(STATUS "Had to git clone more than once: ${number_of_tries} times.")
endif()
if(error_code)
  message(FATAL_ERROR "Failed to clone repository: 'https://github.com/google/ruy'")
endif()

execute_process(
  COMMAND "/usr/bin/git"
          checkout "3286a34cc8de6149ac6844107dfdffac91531e72" --
  WORKING_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/ruy"
  RESULT_VARIABLE error_code
)
if(error_code)
  message(FATAL_ERROR "Failed to checkout tag: '3286a34cc8de6149ac6844107dfdffac91531e72'")
endif()

set(init_submodules TRUE)
if(init_submodules)
  execute_process(
    COMMAND "/usr/bin/git" 
            submodule update --recursive --init 
    WORKING_DIRECTORY "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/ruy"
    RESULT_VARIABLE error_code
  )
endif()
if(error_code)
  message(FATAL_ERROR "Failed to update submodules in: '/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/ruy'")
endif()

# Complete success, update the script-last-run stamp file:
#
execute_process(
  COMMAND ${CMAKE_COMMAND} -E copy "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/ruy-subbuild/ruy-populate-prefix/src/ruy-populate-stamp/ruy-populate-gitinfo.txt" "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/ruy-subbuild/ruy-populate-prefix/src/ruy-populate-stamp/ruy-populate-gitclone-lastrun.txt"
  RESULT_VARIABLE error_code
)
if(error_code)
  message(FATAL_ERROR "Failed to copy script-last-run stamp file: '/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/_deps/ruy-subbuild/ruy-populate-prefix/src/ruy-populate-stamp/ruy-populate-gitclone-lastrun.txt'")
endif()
