cmake_minimum_required(VERSION 3.18)
project(whisper_bridge VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ──────────────────────────────────────────────
# Fetch whisper.cpp from GitHub
# ──────────────────────────────────────────────
include(FetchContent)

FetchContent_Declare(
    whisper
    GIT_REPOSITORY https://github.com/ggerganov/whisper.cpp.git
    GIT_TAG        v1.7.4
    GIT_SHALLOW    TRUE
)

# Configure whisper.cpp build options
set(WHISPER_BUILD_TESTS    OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER   OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS      OFF CACHE BOOL "" FORCE)

# Platform-specific acceleration
if(APPLE)
    # Detect simulator vs device: iphonesimulator SDK = no Metal GPU
    string(TOLOWER "${CMAKE_OSX_SYSROOT}" _sysroot_lower)
    if(_sysroot_lower MATCHES "simulator")
        message(STATUS "MeetMind: iOS Simulator — Metal/CoreML disabled (no GPU)")
        set(WHISPER_COREML              OFF CACHE BOOL "" FORCE)
        set(WHISPER_METAL               OFF CACHE BOOL "" FORCE)
        set(GGML_METAL                  OFF CACHE BOOL "" FORCE)
        set(GGML_METAL_EMBED_LIBRARY    OFF CACHE BOOL "" FORCE)
    else()
        message(STATUS "MeetMind: Apple device — CoreML + Metal enabled")
        set(WHISPER_COREML              ON  CACHE BOOL "" FORCE)
        set(WHISPER_METAL               ON  CACHE BOOL "" FORCE)
        set(GGML_METAL                  ON  CACHE BOOL "" FORCE)
        set(GGML_METAL_EMBED_LIBRARY    ON  CACHE BOOL "" FORCE)
    endif()
elseif(ANDROID)
    set(WHISPER_COREML       OFF CACHE BOOL "" FORCE)
    set(WHISPER_METAL        OFF CACHE BOOL "" FORCE)
    # NNAPI available on Android 8.1+
    message(STATUS "MeetMind: Android platform — NDK build")
endif()

FetchContent_MakeAvailable(whisper)

# ──────────────────────────────────────────────
# Build whisper_bridge shared library
# ──────────────────────────────────────────────
add_library(whisper_bridge SHARED
    src/whisper_bridge.cpp
)

target_include_directories(whisper_bridge PRIVATE
    ${whisper_SOURCE_DIR}/include
    ${whisper_SOURCE_DIR}/ggml/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(whisper_bridge PRIVATE
    whisper
)

# Platform-specific frameworks
if(APPLE)
    target_link_libraries(whisper_bridge PRIVATE
        "-framework Foundation"
        "-framework Accelerate"
        "-framework Metal"
        "-framework MetalKit"
        "-framework CoreML"
    )

    # Set install name for macOS/iOS dynamic loading
    set_target_properties(whisper_bridge PROPERTIES
        INSTALL_NAME_DIR "@rpath"
        BUILD_WITH_INSTALL_RPATH TRUE
    )
endif()

# Export C symbols (no C++ mangling)
target_compile_definitions(whisper_bridge PRIVATE
    WHISPER_BRIDGE_EXPORTS
)

# Output library name
set_target_properties(whisper_bridge PROPERTIES
    OUTPUT_NAME "whisper_bridge"
    PREFIX "lib"
)

message(STATUS "MeetMind: whisper_bridge configured successfully")
message(STATUS "  whisper.cpp version: v1.7.4")
message(STATUS "  C++ standard: ${CMAKE_CXX_STANDARD}")
