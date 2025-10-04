CMAKE_MINIMUM_REQUIRED(VERSION 3.5 FATAL_ERROR)

PROJECT(fxdiv-download NONE)

INCLUDE(ExternalProject)
ExternalProject_Add(fxdiv
	GIT_REPOSITORY https://github.com/Maratyszcza/FXdiv.git
	GIT_TAG master
	SOURCE_DIR "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/FXdiv-source"
	BINARY_DIR "/Users/arashdeep/StudioProjects/holtersync/macos/.tflite-build/build-arm64/FXdiv"
	CONFIGURE_COMMAND ""
	BUILD_COMMAND ""
	INSTALL_COMMAND ""
	TEST_COMMAND ""
)
