cmake_minimum_required(VERSION 3.16)
project(ryoku-settings-apply VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# Fixed at package time — never from GUI.
set(RYOKU_REPO_PATH "" CACHE STRING "Absolute path to Ryoku flake repo")
set(RYOKU_FLAKE_HOST "" CACHE STRING "NixOS flake host attribute")
set(RYOKU_NIXOS_REBUILD "" CACHE STRING "Absolute path to nixos-rebuild")
set(RYOKU_NIX_ENV "" CACHE STRING "Absolute path to nix-env")

if(RYOKU_REPO_PATH STREQUAL "")
  message(FATAL_ERROR "RYOKU_REPO_PATH is required")
endif()
if(NOT RYOKU_FLAKE_HOST MATCHES "^[A-Za-z0-9_-]+$")
  message(FATAL_ERROR "RYOKU_FLAKE_HOST must be a flake host attribute ([A-Za-z0-9_-]+)")
endif()
if(RYOKU_NIXOS_REBUILD STREQUAL "")
  message(FATAL_ERROR "RYOKU_NIXOS_REBUILD is required")
endif()
if(RYOKU_NIX_ENV STREQUAL "")
  message(FATAL_ERROR "RYOKU_NIX_ENV is required")
endif()

add_executable(ryoku-settings-apply
  src/main.cpp
  src/ops.c
  src/ops.h
)

target_compile_definitions(ryoku-settings-apply PRIVATE
  "RYOKU_REPO_PATH=\"${RYOKU_REPO_PATH}\""
  "RYOKU_FLAKE_HOST=\"${RYOKU_FLAKE_HOST}\""
  "RYOKU_NIXOS_REBUILD=\"${RYOKU_NIXOS_REBUILD}\""
  "RYOKU_NIX_ENV=\"${RYOKU_NIX_ENV}\""
)

install(TARGETS ryoku-settings-apply RUNTIME DESTINATION bin)
