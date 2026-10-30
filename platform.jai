// Declarations that differ between Windows and Linux.
// generated.jai is generated on Linux, so everything in here is excluded there (see OMIT_DECLARATIONS in generate.jai).

#if OS == .WINDOWS {
    SDL_wchar_t :: u16;
    SDL_c_long  :: s32;
    SDL_c_ulong :: u32;

    SDL_PRILL_PREFIX :: "I64";
    SDL_PRIs64       :: "I64d";
    SDL_PRIu64       :: "I64u";
    SDL_PRIx64       :: "I64x";
    SDL_PRIX64       :: "I64X";
    SDL_PRILLd       :: "I64d";
    SDL_PRILLu       :: "I64u";
    SDL_PRILLx       :: "I64x";
    SDL_PRILLX       :: "I64X";
} else {
    SDL_wchar_t :: s32;
    SDL_c_long  :: s64;
    SDL_c_ulong :: u64;

    SDL_PRILL_PREFIX :: "ll";
    SDL_PRIs64       :: "ld";
    SDL_PRIu64       :: "lu";
    SDL_PRIx64       :: "lx";
    SDL_PRIX64       :: "lX";
    SDL_PRILLd       :: "lld";
    SDL_PRILLu       :: "llu";
    SDL_PRILLx       :: "llx";
    SDL_PRILLX       :: "llX";
}

SDL_PRIs32 :: "d";
SDL_PRIu32 :: "u";
SDL_PRIx32 :: "x";
SDL_PRIX32 :: "X";

SDL_BYTEORDER      :: SDL_LIL_ENDIAN; // Jai only targets little-endian CPUs.
SDL_FLOATWORDORDER :: SDL_LIL_ENDIAN;

// Functions that use C "long":
SDL_wcstol  :: (str: *SDL_wchar_t, endp: **SDL_wchar_t, base: s32) -> SDL_c_long #foreign SDL3;
SDL_ltoa    :: (value: SDL_c_long, str: *u8, radix: s32) -> *u8 #foreign SDL3;
SDL_ultoa   :: (value: SDL_c_ulong, str: *u8, radix: s32) -> *u8 #foreign SDL3;
SDL_strtol  :: (str: *u8, endp: **u8, base: s32) -> SDL_c_long #foreign SDL3;
SDL_strtoul :: (str: *u8, endp: **u8, base: s32) -> SDL_c_ulong #foreign SDL3;
SDL_lround  :: (x: float64) -> SDL_c_long #foreign SDL3;
SDL_lroundf :: (x: float) -> SDL_c_long #foreign SDL3;

// Windows-only functions from SDL_system.h and SDL_main.h.
// (The library exports them on all platforms, but they only do something on Windows.)
#if OS == .WINDOWS {
    // msg is a Win32 MSG*. It is declared as *void so you can use the MSG type of whichever Windows bindings you like.
    SDL_WindowsMessageHook :: #type (userdata: *void, msg: *void) -> bool #c_call;

    SDL_SetWindowsMessageHook    :: (callback: SDL_WindowsMessageHook, userdata: *void) -> void #foreign SDL3;
    SDL_GetDirect3D9AdapterIndex :: (displayID: SDL_DisplayID) -> s32 #foreign SDL3;
    SDL_GetDXGIOutputInfo        :: (displayID: SDL_DisplayID, adapterIndex: *s32, outputIndex: *s32) -> bool #foreign SDL3;
    SDL_RegisterApp              :: (name: *u8, style: Uint32, hInst: *void) -> bool #foreign SDL3;
    SDL_UnregisterApp            :: () -> void #foreign SDL3;
}
