#!/bin/bash
# Rebuilds linux/libSDL3.so and linux/static/libSDL3.a from an official SDL release.
#
#     tools/build_linux_libs.sh [version]        (default: 3.4.18)
#
# The build runs in an Ubuntu 22.04 container so the result only needs glibc 2.34 or newer
# instead of whatever glibc the build machine has. X11, Wayland (with libdecor), PipeWire,
# PulseAudio, ALSA, KMSDRM, OpenGL/GLES and Vulkan support are all enabled; SDL loads those
# system libraries with dlopen() at run time, so libSDL3 itself only links against libc and libm.
#
# Requires docker and curl.
#
# The Windows files (windows/SDL3.dll, windows/SDL3.lib) are copied unchanged from
# lib/x64 of SDL3-devel-<version>-VC.zip on https://github.com/libsdl-org/SDL/releases.
# The headers in include/SDL3 come from the same release (minus the SDL_test*.h headers).

set -euo pipefail

VERSION="${1:-3.4.18}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Downloading SDL $VERSION..."
curl -sSL -o "$WORK_DIR/SDL3.tar.gz" "https://github.com/libsdl-org/SDL/releases/download/release-$VERSION/SDL3-$VERSION.tar.gz"
mkdir -p "$WORK_DIR/src" "$WORK_DIR/out"
tar xzf "$WORK_DIR/SDL3.tar.gz" -C "$WORK_DIR/src" --strip-components=1

cat > "$WORK_DIR/build.sh" <<'EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq build-essential cmake ninja-build pkg-config \
  libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev libxss-dev libxtst-dev libxkbcommon-dev \
  libwayland-dev wayland-protocols libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libdecor-0-dev \
  libasound2-dev libpulse-dev libpipewire-0.3-dev libudev-dev libdbus-1-dev libdrm-dev libgbm-dev libusb-1.0-0-dev > /dev/null
mkdir -p /build && cd /build
cmake -G Ninja /src -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/out \
  -DSDL_SHARED=ON -DSDL_STATIC=ON -DSDL_STATIC_PIC=ON -DSDL_TESTS=OFF -DSDL_TEST_LIBRARY=OFF -DSDL_EXAMPLES=OFF \
  -DSDL_X11=ON -DSDL_WAYLAND=ON -DSDL_WAYLAND_LIBDECOR=ON -DSDL_KMSDRM=ON -DSDL_PIPEWIRE=ON -DSDL_PULSEAUDIO=ON -DSDL_ALSA=ON
ninja install
chown -R "$HOST_UID:$HOST_GID" /out
EOF
chmod +x "$WORK_DIR/build.sh"

echo "Building in ubuntu:22.04..."
docker run --rm -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "$WORK_DIR/src:/src:ro" -v "$WORK_DIR/out:/out" -v "$WORK_DIR/build.sh:/build.sh:ro" \
  ubuntu:22.04 /build.sh

mkdir -p "$REPO_DIR/linux/static"
cp "$WORK_DIR/out/lib/libSDL3.so.0."* "$REPO_DIR/linux/libSDL3.so"
cp "$WORK_DIR/out/lib/libSDL3.a" "$REPO_DIR/linux/static/libSDL3.a"
echo "Done. Updated linux/libSDL3.so and linux/static/libSDL3.a."
