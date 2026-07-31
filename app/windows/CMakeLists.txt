# [INPUT]: Depends on Flutter Windows tooling and product/build version metadata, the SkillsGo Go CLI workspace, and the shared data/bin bundle layout.
# [OUTPUT]: Builds the Windows desktop runner and packages a native SkillsGo CLI aligned to the App product version, excluding the Flutter build number.
# [POS]: Serves as the Windows desktop build and runnable bundle entry point.
# [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
cmake_minimum_required(VERSION 3.14)
project(skillsgo LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "skillsgo")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Build the CLI for the supported Windows x64 desktop target.
find_program(GO_EXECUTABLE go REQUIRED)
string(REGEX REPLACE "\\+.*$" "" SKILLSGO_APP_VERSION "${FLUTTER_VERSION}")
set(SKILLSGO_CLI_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../cli")
set(SKILLSGO_CLI_BINARY "${CMAKE_BINARY_DIR}/bundled_cli/skillsgo.exe")
file(GLOB_RECURSE SKILLSGO_CLI_SOURCES CONFIGURE_DEPENDS
  "${SKILLSGO_CLI_SOURCE_DIR}/*.go"
  "${SKILLSGO_CLI_SOURCE_DIR}/go.mod"
  "${SKILLSGO_CLI_SOURCE_DIR}/go.sum"
  "${CMAKE_CURRENT_SOURCE_DIR}/../../protocol/*.go"
)
add_custom_command(
  OUTPUT "${SKILLSGO_CLI_BINARY}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/bundled_cli"
  COMMAND ${CMAKE_COMMAND} -E env CGO_ENABLED=0 GOOS=windows GOARCH=amd64
    ${GO_EXECUTABLE} build -trimpath
    "-ldflags=-s -w -X github.com/skillsgo/skillsgo/cli/internal/command.version=${SKILLSGO_APP_VERSION}"
    -o "${SKILLSGO_CLI_BINARY}" ./cmd/skillsgo
  WORKING_DIRECTORY "${SKILLSGO_CLI_SOURCE_DIR}"
  DEPENDS ${SKILLSGO_CLI_SOURCES}
  VERBATIM
)
add_custom_target(skillsgo_cli ALL DEPENDS "${SKILLSGO_CLI_BINARY}")
add_dependencies(${BINARY_NAME} skillsgo_cli)


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(PROGRAMS "${SKILLSGO_CLI_BINARY}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}/bin" COMPONENT Runtime)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
