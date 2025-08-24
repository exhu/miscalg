cmake_minimum_required(VERSION 3.25)
project(printlib)


# set the output directory for built objects.
# This makes sure that the dynamic library goes into the build directory automatically.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIGURATION>")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIGURATION>")


# Create your game executable target as usual
add_library(printlib myprint.c myprint.h)
target_include_directories(printlib INTERFACE
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<INSTALL_INTERFACE:include/printlib>  # <prefix>/include/mylib
)
install(TARGETS printlib)

