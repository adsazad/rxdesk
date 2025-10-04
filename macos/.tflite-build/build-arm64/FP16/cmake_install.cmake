# Install script for directory: /Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/FP16-source

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/objdump")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include" TYPE FILE FILES "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/FP16-source/include/fp16.h")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/fp16" TYPE FILE FILES
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/FP16-source/include/fp16/bitcasts.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/FP16-source/include/fp16/fp16.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/FP16-source/include/fp16/psimd.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/FP16-source/include/fp16/__init__.py"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/FP16-source/include/fp16/avx.py"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/FP16-source/include/fp16/avx2.py"
    )
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for each subdirectory.
  include("/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/psimd/cmake_install.cmake")

endif()

