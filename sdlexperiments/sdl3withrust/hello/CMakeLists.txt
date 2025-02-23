cmake_minimum_required(VERSION 3.25)
project(hello)


find_library(RUSTHELLO myrustlib PATHS ${PROJECT_SOURCE_DIR}/myrustlib/target/debug)
# set the output directory for built objects.
# This makes sure that the dynamic library goes into the build directory automatically.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIGURATION>")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIGURATION>")

# This assumes the SDL source is available in vendored/SDL
add_subdirectory(../../vendored/SDL3-3.2.2/ ./sdl EXCLUDE_FROM_ALL)

# Create your game executable target as usual
add_executable(hello hello.c)

# Link to the actual SDL3 library.
target_link_libraries(hello PRIVATE SDL3::SDL3 ${RUSTHELLO})
