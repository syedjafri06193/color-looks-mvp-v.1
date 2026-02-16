cmake_minimum_required(VERSION 3.22)
project(color_looks_mvp_v1 VERSION 1.0 LANGUAGES C CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(COLORLOOKS_BUILD_TESTS "Build test utilities" ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

find_package(OpenColorIO REQUIRED)
find_package(Metal REQUIRED)

add_subdirectory(tools)

if(COLORLOOKS_BUILD_TESTS)
    enable_testing()
endif()
