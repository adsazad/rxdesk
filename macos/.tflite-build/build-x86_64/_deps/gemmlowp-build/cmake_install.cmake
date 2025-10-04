# Install script for directory: /Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/contrib

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
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/gemmlowp/eight_bit_int_gemm" TYPE FILE FILES "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/eight_bit_int_gemm/eight_bit_int_gemm.h")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/gemmlowp/meta" TYPE FILE FILES
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/base.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/legacy_multi_thread_common.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/legacy_multi_thread_gemm.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/legacy_multi_thread_gemv.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/legacy_operations_common.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/legacy_single_thread_gemm.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/multi_thread_common.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/multi_thread_gemm.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/multi_thread_transform.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/quantized_mul_kernels.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/quantized_mul_kernels_arm_32.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/quantized_mul_kernels_arm_64.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/single_thread_gemm.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/single_thread_transform.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/streams.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/streams_arm_32.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/streams_arm_64.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/transform_kernels.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/transform_kernels_arm_32.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/meta/transform_kernels_arm_64.h"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/gemmlowp/public" TYPE FILE FILES
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/public/bit_depth.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/public/gemmlowp.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/public/map.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/public/output_stages.h"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/gemmlowp/profiling" TYPE FILE FILES
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/profiling/instrumentation.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/profiling/profiler.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/profiling/pthread_everywhere.h"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/gemmlowp/internal" TYPE FILE FILES
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/allocator.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/block_params.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/common.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/compute.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/detect_platform.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/dispatch_gemm_shape.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/kernel.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/kernel_avx.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/kernel_default.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/kernel_msa.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/kernel_neon.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/kernel_reference.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/kernel_sse.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/multi_thread_gemm.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/output.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/output_avx.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/output_msa.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/output_neon.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/output_sse.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/pack.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/pack_avx.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/pack_msa.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/pack_neon.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/pack_sse.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/platform.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/simd_wrappers.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/simd_wrappers_common_neon_sse.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/simd_wrappers_msa.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/simd_wrappers_neon.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/simd_wrappers_sse.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/single_thread_gemm.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/internal/unpack.h"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/gemmlowp/fixedpoint" TYPE FILE FILES
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/fixedpoint/fixedpoint.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/fixedpoint/fixedpoint_avx.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/fixedpoint/fixedpoint_msa.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/fixedpoint/fixedpoint_neon.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/fixedpoint/fixedpoint_sse.h"
    "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/gemmlowp/fixedpoint/fixedpoint_wasmsimd.h"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/gemmlowp-build/libeight_bit_int_gemm.a")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libeight_bit_int_gemm.a" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libeight_bit_int_gemm.a")
    execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libeight_bit_int_gemm.a")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/gemmlowp/gemmlowp-config.cmake")
    file(DIFFERENT _cmake_export_file_changed FILES
         "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/gemmlowp/gemmlowp-config.cmake"
         "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/gemmlowp-build/CMakeFiles/Export/bdd242ce7a57c2e75f6ccd2dc66d07f4/gemmlowp-config.cmake")
    if(_cmake_export_file_changed)
      file(GLOB _cmake_old_config_files "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/gemmlowp/gemmlowp-config-*.cmake")
      if(_cmake_old_config_files)
        string(REPLACE ";" ", " _cmake_old_config_files_text "${_cmake_old_config_files}")
        message(STATUS "Old export file \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/gemmlowp/gemmlowp-config.cmake\" will be replaced.  Removing files [${_cmake_old_config_files_text}].")
        unset(_cmake_old_config_files_text)
        file(REMOVE ${_cmake_old_config_files})
      endif()
      unset(_cmake_old_config_files)
    endif()
    unset(_cmake_export_file_changed)
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/gemmlowp" TYPE FILE FILES "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/gemmlowp-build/CMakeFiles/Export/bdd242ce7a57c2e75f6ccd2dc66d07f4/gemmlowp-config.cmake")
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/gemmlowp" TYPE FILE FILES "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-x86_64/_deps/gemmlowp-build/CMakeFiles/Export/bdd242ce7a57c2e75f6ccd2dc66d07f4/gemmlowp-config-release.cmake")
  endif()
endif()

