cmake_minimum_required(VERSION 3.25)
project(hellolib)


# set the output directory for built objects.
# This makes sure that the dynamic library goes into the build directory automatically.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIGURATION>")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIGURATION>")

add_subdirectory(${PROJECT_SOURCE_DIR}/../printlib printlib)

# Create your game executable target as usual
add_library(hellolib hello.c)
target_link_libraries(hellolib printlib)
target_include_directories(hellolib INTERFACE
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<INSTALL_INTERFACE:include/hellolib>  # <prefix>/include/mylib
)
install(TARGETS hellolib)
