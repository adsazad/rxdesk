# Install script for directory: /Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen

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

if(CMAKE_INSTALL_COMPONENT STREQUAL "Devel" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/eigen3/unsupported/Eigen" TYPE FILE FILES
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/AdolcForward"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/AlignedVector3"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/ArpackSupport"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/AutoDiff"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/BVH"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/EulerAngles"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/FFT"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/IterativeSolvers"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/KroneckerProduct"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/LevenbergMarquardt"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/MatrixFunctions"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/MoreVectorization"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/MPRealSupport"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/NNLS"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/NonLinearOptimization"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/NumericalDiff"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/OpenGLSupport"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/Polynomials"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/Skyline"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/SparseExtra"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/SpecialFunctions"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/Splines"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Devel" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/eigen3/unsupported/Eigen" TYPE DIRECTORY FILES "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/eigen/unsupported/Eigen/src" FILES_MATCHING REGEX "/[^/]*\\.h$")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for each subdirectory.
  include("/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/eigen-build/unsupported/Eigen/CXX11/cmake_install.cmake")

endif()

