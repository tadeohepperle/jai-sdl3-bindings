// SDL3 bindings for Jai.
//
//     #import "SDL3";
//
// All declarations keep their C names (SDL_CreateWindow, SDL_Event, ...).
// Enums and flags can be written either Jai-style (.OPENGL | .RESIZABLE, event.type == .QUIT)
// or with the original C names (SDL_WINDOW_OPENGL, SDL_EVENT_QUIT).

#module_parameters (LINK_STATIC := false);
// LINK_STATIC: Linux only. Link libSDL3.a into the executable instead of loading libSDL3.so at run time.
// (There is no static SDL3 library for Windows in this module. SDL3.dll is copied next to your executable.)

#load "generated.jai";
#load "helpers.jai";
#load "platform.jai";

#scope_export // Export the library so that you can declare bindings for things we have omitted.

#if OS == .WINDOWS {
    SDL3 :: #library "windows/SDL3";
} else #if OS == .LINUX {
    // The static library lives in its own directory because Jai always prefers a .a over a .so in the same place.
    #if LINK_STATIC {
        SDL3 :: #library,no_dll "linux/static/libSDL3";
        // SDL loads X11, Wayland, audio libraries etc. with dlopen() at run time,
        // so these are the only libraries the static library needs at link time.
        #library,system,link_always "libm";
        #library,system,link_always "libc";
    } else {
        SDL3 :: #library "linux/libSDL3";
    }
} else {
    #assert false "The SDL3 module currently only supports Windows and Linux.";
}

// Jai does not copy shared libraries next to the executable, but the executable looks for them there
// (on Linux via rpath $ORIGIN, before falling back to a system-wide SDL3).
// Call this from your build metaprogram after compiling, e.g. SDL3_copy_shared_library(output_path).
// Does nothing when linking statically.
SDL3_copy_shared_library :: (output_directory: string) -> bool {
    #if OS == .WINDOWS {
        return copy_file(tprint("%/windows/SDL3.dll", #filepath), tprint("%/SDL3.dll", output_directory));
    } else #if OS == .LINUX && !LINK_STATIC {
        // The library's soname is libSDL3.so.0, so that's the name the executable asks for.
        return copy_file(tprint("%/linux/libSDL3.so", #filepath), tprint("%/libSDL3.so.0", output_directory));
    } else {
        return true;
    }
}

#scope_file

#import "Basic";
#import "File_Utilities";
