#!/bin/sh

cd "$(dirname "$0")" || exit 1

# some environments have cmake v2 as 'cmake' and v3 as 'cmake3'
# check for cmake3 first then fallback to just cmake
[ -n "$B_CMAKE" ] || B_CMAKE=$(command -v cmake3)
[ -n "$B_CMAKE" ] || B_CMAKE=$(command -v cmake)
if [ -z "$B_CMAKE" ]; then
    echo "ERROR: CMake not in $PATH, cannot build! Please install CMake, or if this persists, file a bug report."
    exit 1
fi

# Allow local customizations to build environment
[ -r ./build_env.sh ] && . ./build_env.sh

B_BUILD_DIR="${B_BUILD_DIR:-build}"
B_BUILD_TYPE="${B_BUILD_TYPE:-Debug}"
B_CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=${B_BUILD_TYPE} ${B_CMAKE_FLAGS:-}"

# Allow setting custom QT root
if ! [ -z "$B_QT_ROOT" ]; then
    echo "Using QT root: ${B_QT_ROOT}"
    B_CMAKE_FLAGS="${B_CMAKE_FLAGS} -DCMAKE_PREFIX_PATH=${B_QT_ROOT}"
fi

if [ "$(uname)" = "Darwin" ]; then
    B_CMAKE_FLAGS="${B_CMAKE_FLAGS} -DCMAKE_OSX_SYSROOT=$(xcrun --sdk macosx --show-sdk-path) -DCMAKE_OSX_DEPLOYMENT_TARGET=${B_OSX_DEPLOYMENT_TARGET:-10.15}"
fi

# Prefer ninja if available
if command -v ninja 2>/dev/null; then
    B_CMAKE_FLAGS="-GNinja ${B_CMAKE_FLAGS}"
fi

set -e

# Initialise Git submodules
git submodule update --init --recursive

rm -rf ${B_BUILD_DIR}
mkdir ${B_BUILD_DIR}
cd ${B_BUILD_DIR}
echo "Starting Input Leap $B_BUILD_TYPE build in '${B_BUILD_DIR}'..."
"$B_CMAKE" $B_CMAKE_FLAGS ..
"$B_CMAKE" --build . --parallel
echo "Build completed successfully"
