# Jai bindings for SDL3 

## (DISCLAIMER: 99% AI given Jai SDL2 bindings and Odin SDL3 bindings as reference!)

Bindings for [SDL 3](https://libsdl.org) (version **3.4.18**) for the Jai programming language,
for **Windows (x64)** and **Linux (x64, X11 and Wayland)**.

The bindings are generated from the official SDL headers with Jai's `Bindings_Generator`, so they cover
the whole SDL3 API (about 1200 functions, 165 structs, 115 enums, all hints and properties), including the
SDL_GPU API, gamepads, audio streams, the main-callbacks API, and so on. Every struct has been checked against
clang's layout of the C headers.

SDL_image, SDL_ttf and SDL_mixer are not included.

## Installation

Jai finds modules by directory name, so this repository has to be available as a directory called `SDL3`
in one of your module directories, for example:

```sh
ln -s /path/to/this/repo ~/jai/modules/SDL3      # or: git clone <url> ~/jai/modules/SDL3
```

or put it into your project's own modules directory and compile with `-import_dir`.

## Quick start

```jai
#import "Basic";
#import "SDL3";

main :: () {
    if !SDL_Init(.VIDEO) {
        print("SDL_Init failed: %\n", to_string(SDL_GetError()));
        return;
    }
    defer SDL_Quit();

    window := SDL_CreateWindow("Hello SDL3", 800, 600, .RESIZABLE | .HIGH_PIXEL_DENSITY);
    defer SDL_DestroyWindow(window);

    running := true;
    while running {
        event: SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == {
                case .QUIT;     running = false;
                case .KEY_DOWN; if event.key.key == .ESCAPE running = false;
            }
        }
        SDL_Delay(16);
    }
}
```

More in [examples/](examples/): [renderer.jai](examples/renderer.jai) (SDL_Renderer, keyboard, mouse) and
[opengl.jai](examples/opengl.jai) (an OpenGL context with Jai's `GL` module; it is `modules/GL/examples/gl_sdl.jai`
ported from SDL2, with comments on what changed). Build them with `jai examples/build.jai`.

## How the bindings look

* **All names are the C names**: `SDL_CreateWindow`, `SDL_Event`, `SDL_GetError`, ... The SDL wiki
  (<https://wiki.libsdl.org/SDL3>) and the header comments (kept in `generated.jai`) apply directly.
* **Enums and flags** can be written Jai-style or with their C names. Both of these work:
  ```jai
  SDL_CreateWindow("x", 800, 600, .OPENGL | .RESIZABLE);
  SDL_CreateWindow("x", 800, 600, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);

  if event.type == .KEY_DOWN && event.key.key == .ESCAPE { ... }
  if event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_ESCAPE { ... }
  ```
  SDL3 declares many flag sets as `#define`s (`SDL_WindowFlags`, `SDL_InitFlags`, `SDL_Keymod`,
  `SDL_MouseButtonFlags`, `SDL_GPUTextureUsageFlags`, ...) and keycodes as `#define SDLK_...`.
  These are proper `enum_flags` / `enum` types here, so they print nicely and work with `.MEMBER` syntax.
  Keycodes and scancodes whose names start with a digit get a leading underscore: `SDL_Keycode._1`
  (or just `SDLK_1`).
* `SDL_Event.type` is typed as `SDL_EventType` (it is a `Uint32` in C), so you can switch on it with
  `if event.type == { case .QUIT; ... }`. User events registered with `SDL_RegisterEvents()` still fit.
* **Functions return `bool`** (true = success), unlike SDL2's 0/-1 return codes.
* **Strings** are `*u8` (C strings). String literals and string constants can be passed directly;
  use `to_string()` on returned strings and `temp_c_string()` / `to_c_string()` for Jai strings you build at run time.
* Arrays returned by SDL (`SDL_GetDisplays`, `SDL_GetFullscreenDisplayModes`, ...) are allocated by SDL;
  release them with `SDL_free()`.
* `SDL_Log` and the other printf-style functions take Jai format strings: `SDL_Log("% frames", count)`.
* Function-like macros and header-only inline functions that the generator can't translate are
  hand-written in [helpers.jai](helpers.jai): `SDL_WINDOWPOS_CENTERED`, `SDL_BUTTON_MASK`, `SDL_VERSION_ATLEAST`,
  `SDL_PointInRect`, `SDL_RectEmpty`, `SDL_AUDIO_BYTESIZE`, `SDL_BYTESPERPIXEL`, `SDL_CreateThread`, etc.

## Linking

| Platform | Default                                                           | Files                                  |
| -------- | ----------------------------------------------------------------- | -------------------------------------- |
| Linux    | links `libSDL3.so` dynamically                                    | `linux/libSDL3.so`                     |
| Linux    | `#import "SDL3"(LINK_STATIC=true);` links SDL into the executable | `linux/static/libSDL3.a`               |
| Windows  | links `SDL3.dll` dynamically (via its import library)             | `windows/SDL3.dll`, `windows/SDL3.lib` |

There is no static library for Windows: the official SDL releases don't ship one for MSVC.
To get one, build SDL with CMake and `-DSDL_STATIC=ON` on Windows.

**Jai does not copy shared libraries next to your executable.** The executable looks for them there first
(on Linux through the `$ORIGIN` rpath that Jai sets, for `libSDL3.so.0`, which is the library's soname).
Call `SDL3_copy_shared_library(output_path)` from your build metaprogram, as [examples/build.jai](examples/build.jai)
does, or copy the file yourself:

* Windows: `windows/SDL3.dll` → next to your `.exe`
* Linux: `linux/libSDL3.so` → next to your executable, renamed to `libSDL3.so.0`

On Linux the executable falls back to a system-wide SDL3 (e.g. the `sdl3` package) if it doesn't find the file next to it.
With `LINK_STATIC=true` there is nothing to copy: the executable only depends on libc and libm.

### X11 and Wayland

A single `libSDL3` supports both X11 and Wayland (with libdecor window decorations), as well as KMSDRM,
PipeWire, PulseAudio, ALSA, OpenGL, OpenGL ES and Vulkan. It loads the system libraries for whatever it uses at
run time with `dlopen`, so none of them are required to build or start your program. SDL picks Wayland if it
is available and falls back to X11. To force a driver, set the environment variable `SDL_VIDEO_DRIVER=x11` or
`SDL_VIDEO_DRIVER=wayland`, or call `SDL_SetHint(SDL_HINT_VIDEO_DRIVER, "x11")` before `SDL_Init`.

The Linux libraries were built on Ubuntu 22.04, so they need glibc 2.34 or newer (Ubuntu 22.04+, Debian 12+,
Fedora 35+, any current Arch).

## Porting from the SDL2 module

The official migration guide is the complete reference: <https://wiki.libsdl.org/SDL3/README-migration>.
The changes you'll run into first:

### General

| SDL2                                             | SDL3                                                                                        |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| `#import "SDL";`                                 | `#import "SDL3";`                                                                           |
| `SDL_Init(...)` returns 0 on success             | returns `true` on success; same for almost every function that used to return an error code |
| `SDL_bool`, `SDL_TRUE`, `SDL_FALSE`              | `bool`, `true`, `false`                                                                     |
| `SDL_INIT_EVERYTHING`, `SDL_INIT_TIMER`          | removed; list the subsystems you need                                                       |
| `SDL_INIT_GAMECONTROLLER`, `SDL_GameController*` | `SDL_INIT_GAMEPAD`, `SDL_Gamepad*`                                                          |
| `SDL_GetTicks()` returns u32                     | returns `Uint64` milliseconds; `SDL_GetTicksNS()` for nanoseconds                           |
| `SDL_FreeSurface`                                | `SDL_DestroySurface`                                                                        |
| `SDL_RenderCopy`, `SDL_RenderCopyEx`             | `SDL_RenderTexture`, `SDL_RenderTextureRotated` (take `SDL_FRect`)                          |

### SDL_video.h

| SDL2                                                                         | SDL3                                                                                                                                         |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `SDL_CreateWindow(title, x, y, w, h, flags)`                                 | `SDL_CreateWindow(title, w, h, flags)`; then `SDL_SetWindowPosition`, or use `SDL_CreateWindowWithProperties`                                |
| `SDL_WINDOW_SHOWN`                                                           | removed: windows are shown by default (use `.HIDDEN` to create them hidden)                                                                  |
| `SDL_WINDOW_ALLOW_HIGHDPI`                                                   | `.HIGH_PIXEL_DENSITY`                                                                                                                        |
| `SDL_WINDOW_FULLSCREEN_DESKTOP`                                              | `.FULLSCREEN` + `SDL_SetWindowFullscreenMode(window, null)` (null = desktop mode)                                                            |
| `SDL_WINDOW_INPUT_GRABBED`                                                   | `.MOUSE_GRABBED`                                                                                                                             |
| `SDL_SetWindowFullscreen(window, flags)`                                     | `SDL_SetWindowFullscreen(window, bool)`                                                                                                      |
| `SDL_SetWindowGrab` / `SDL_GetWindowGrab`                                    | `SDL_SetWindowMouseGrab` / `SDL_GetWindowMouseGrab` (plus `SDL_SetWindowKeyboardGrab`)                                                       |
| `SDL_GL_GetDrawableSize`                                                     | `SDL_GetWindowSizeInPixels`                                                                                                                  |
| `SDL_GL_DeleteContext`                                                       | `SDL_GL_DestroyContext`                                                                                                                      |
| `SDL_GL_GetSwapInterval() -> s32`                                            | `SDL_GL_GetSwapInterval(*interval) -> bool`                                                                                                  |
| `SDL_GL_GetProcAddress` returns `*void`                                      | returns `SDL_FunctionPointer`; cast it (see [examples/opengl.jai](examples/opengl.jai) for `gl_load`)                                        |
| `SDL_GLattr`, `SDL_GLprofile`, `SDL_GLcontextFlag`                           | `SDL_GLAttr`, `SDL_GLProfile`, `SDL_GLContextFlag` (the `SDL_GL_*` constant names are unchanged)                                             |
| display index (`s32`)                                                        | `SDL_DisplayID`; 0 is invalid                                                                                                                |
| `SDL_GetNumVideoDisplays`                                                    | `SDL_GetDisplays(*count)` (free the array with `SDL_free`)                                                                                   |
| `SDL_GetWindowDisplayIndex`                                                  | `SDL_GetDisplayForWindow`                                                                                                                    |
| `SDL_GetDisplayDPI`                                                          | removed; use `SDL_GetWindowDisplayScale` / `SDL_GetDisplayContentScale`                                                                      |
| `SDL_GetNumDisplayModes`, `SDL_GetDisplayMode`                               | `SDL_GetFullscreenDisplayModes(display, *count)`                                                                                             |
| `SDL_GetDesktopDisplayMode(i, *mode)`, `SDL_GetCurrentDisplayMode(i, *mode)` | return `*SDL_DisplayMode` (owned by SDL)                                                                                                     |
| `SDL_GetClosestDisplayMode`                                                  | `SDL_GetClosestFullscreenDisplayMode`                                                                                                        |
| `SDL_SetWindowDisplayMode` / `SDL_GetWindowDisplayMode`                      | `SDL_SetWindowFullscreenMode` / `SDL_GetWindowFullscreenMode`                                                                                |
| `SDL_SetWindowData` / `SDL_GetWindowData`                                    | `SDL_SetPointerProperty` / `SDL_GetPointerProperty` on `SDL_GetWindowProperties(window)`                                                     |
| `SDL_CreateWindowFrom`                                                       | `SDL_CreateWindowWithProperties` with the window-wrapping properties                                                                         |
| `SDL_SetWindowBrightness`, `SDL_SetWindowGammaRamp`                          | removed                                                                                                                                      |
| `SDL_SetWindowInputFocus`                                                    | `SDL_RaiseWindow`                                                                                                                            |
| `SDL_SetWindowModalFor`                                                      | `SDL_SetWindowParent` + `SDL_SetWindowModal`                                                                                                 |
| `SDL_IsScreenSaverEnabled`                                                   | `SDL_ScreenSaverEnabled`                                                                                                                     |
| `SDL_VideoInit` / `SDL_VideoQuit`                                            | `SDL_InitSubSystem(.VIDEO)` / `SDL_QuitSubSystem(.VIDEO)`                                                                                    |
| `SDL_GetWindowWMInfo` (SDL_syswm.h)                                          | window properties, e.g. `SDL_PROP_WINDOW_WIN32_HWND_POINTER`, `SDL_PROP_WINDOW_X11_WINDOW_NUMBER`, `SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER` |

### Events

| SDL2                                                                | SDL3                                                                                              |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `SDL_QUIT`, `SDL_KEYDOWN`, `SDL_MOUSEMOTION`, ...                   | `.QUIT`, `.KEY_DOWN`, `.MOUSE_MOTION`, ... (or `SDL_EVENT_QUIT`, `SDL_EVENT_KEY_DOWN`, ...)       |
| `SDL_WINDOWEVENT` + `event.window.event == SDL_WINDOWEVENT_RESIZED` | top-level events: `.WINDOW_RESIZED`, `.WINDOW_PIXEL_SIZE_CHANGED`, `.WINDOW_CLOSE_REQUESTED`, ... |
| `SDL_WINDOWEVENT_SIZE_CHANGED`                                      | `.WINDOW_PIXEL_SIZE_CHANGED` (size in pixels) or `.WINDOW_RESIZED` (size in screen coordinates)   |
| `event.key.keysym.sym` / `.scancode` / `.mod`                       | `event.key.key` / `event.key.scancode` / `event.key.mod`                                          |
| `event.key.state == SDL_PRESSED`                                    | `event.key.down`                                                                                  |
| `SDLK_a`                                                            | `SDLK_A` / `.A` (the value is still the lower-case character)                                     |
| `KMOD_SHIFT`                                                        | `SDL_KMOD_SHIFT` / `.SHIFT`                                                                       |
| mouse coordinates (`s32`)                                           | `float` (`event.motion.x`, `event.button.x`, `SDL_GetMouseState(*float, *float)`)                 |
| `event.wheel.y` (`s32`)                                             | `float`; `event.wheel.integer_y` for whole steps                                                  |
| text input is on by default                                         | call `SDL_StartTextInput(window)` to get `.TEXT_INPUT` events                                     |
| `SDL_SetRelativeMouseMode(bool)`                                    | `SDL_SetWindowRelativeMouseMode(window, bool)`                                                    |

## What's not included

* Functions taking a `va_list` (`SDL_LogMessageV`, `SDL_vsnprintf`, ...) and `SDL_swprintf`.
  Use the printf-style versions, which accept Jai format strings.
* Some header-only helpers that have Jai equivalents, like `SDL_Swap16`, `SDL_min`, `SDL_zero`,
  and the `SDL_assert` macros.
* The functions for other platforms (Android, iOS, GDK) are there, but they only do something on those
  platforms, which this module doesn't support yet. macOS is not supported yet either: it would need a
  `libSDL3.dylib` in a `macos` directory and a `#library` for it in [module.jai](module.jai).

## Files

| File                                                   |                                                                                                  |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| [module.jai](module.jai)                               | The module: library declarations, `LINK_STATIC` parameter, `SDL3_copy_shared_library`            |
| [generated.jai](generated.jai)                         | The generated bindings (do not edit)                                                             |
| [helpers.jai](helpers.jai)                             | Hand-written function-like macros and inline functions                                           |
| [platform.jai](platform.jai)                           | Declarations that differ between Windows and Linux (`wchar_t`, C `long`, Windows-only functions) |
| [generate.jai](generate.jai)                           | The bindings generator                                                                           |
| [include/SDL3](include/SDL3)                           | The official SDL 3.4.18 headers the bindings were generated from                                 |
| `linux/`, `windows/`                                   | Prebuilt libraries                                                                               |
| [tools/build_linux_libs.sh](tools/build_linux_libs.sh) | Rebuilds the Linux libraries from an official SDL release                                        |

## Updating SDL

1. Replace `include/SDL3` with the headers of the new release (`include/SDL3` in the source tarball, without the `SDL_test*.h` headers).
2. `tools/build_linux_libs.sh <version>` to rebuild the Linux libraries (needs Docker).
3. Copy `lib/x64/SDL3.dll` and `lib/x64/SDL3.lib` from `SDL3-devel-<version>-VC.zip` into `windows/`.
4. Run `jai generate.jai` (on Linux) to regenerate `generated.jai`. It strips any function that is missing
   from `linux/libSDL3.so`, and lists what it stripped.

Windows and Linux builds of SDL3 export the same set of functions, so the bindings generated on Linux also work on Windows.

## Where the binaries come from

* `windows/SDL3.dll`, `windows/SDL3.lib`: unmodified from `SDL3-devel-3.4.18-VC.zip` of the
  [official 3.4.18 release](https://github.com/libsdl-org/SDL/releases/tag/release-3.4.18).
* `linux/libSDL3.so`, `linux/static/libSDL3.a`: built from `SDL3-3.4.18.tar.gz` of the same release with
  [tools/build_linux_libs.sh](tools/build_linux_libs.sh) (Release build, Ubuntu 22.04, GCC).

## License

SDL is distributed under the zlib license, see [LICENSE_SDL3.txt](LICENSE_SDL3.txt).
