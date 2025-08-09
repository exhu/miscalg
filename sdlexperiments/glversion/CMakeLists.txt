cmake_minimum_required(VERSION 3.21)

# This template attempts to be "fetch_content"-able
# so that it works well with tools like CPM or other
# manual dependency management

# Only set the cxx_standard if it is not set by someone else
if (NOT DEFINED CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 23)
endif()

# strongly encouraged to enable this globally to avoid conflicts between
# -Wpedantic being enabled and -std=c++20 and -std=gnu++20 for example
# when compiling with PCH enabled
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Set the project name and language
project(
  glversion_proj
  VERSION 0.0.1
  DESCRIPTION ""
  LANGUAGES CXX C)

add_subdirectory(../vendored/SDL3-3.2.20/ sdl3)

add_executable(glversion main.c glad/src/glad.c)
target_include_directories(glversion PRIVATE glad/include SDL3::SDL3)
#find_package(SDL3 REQUIRED CONFIG REQUIRED COMPONENTS SDL3-shared PATHS ../vendored/sdlbuild/)
target_link_libraries(glversion PRIVATE SDL3::SDL3)
