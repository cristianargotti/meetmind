# Android NDK build for whisper_bridge
cmake_minimum_required(VERSION 3.18)

# Import the parent CMake (whisper.cpp + bridge)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/.. ${CMAKE_CURRENT_BINARY_DIR}/native)
