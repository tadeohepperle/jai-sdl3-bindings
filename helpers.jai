// Hand-written versions of SDL's function-like macros and header-only inline functions,
// which the bindings generator cannot translate.

// SDL_version.h

SDL_VERSIONNUM       :: (major: s32, minor: s32, patch: s32) -> s32 { return major * 1000000 + minor * 1000 + patch; }
SDL_VERSIONNUM_MAJOR :: (version: s32) -> s32 { return version / 1000000; }
SDL_VERSIONNUM_MINOR :: (version: s32) -> s32 { return (version / 1000) % 1000; }
SDL_VERSIONNUM_MICRO :: (version: s32) -> s32 { return version % 1000; }

SDL_VERSION : s32 : SDL_MAJOR_VERSION * 1000000 + SDL_MINOR_VERSION * 1000 + SDL_MICRO_VERSION;

SDL_VERSION_ATLEAST :: (x: s32, y: s32, z: s32) -> bool { return SDL_VERSION >= SDL_VERSIONNUM(x, y, z); }

// SDL_stdinc.h

SDL_FOURCC :: (a: u8, b: u8, c: u8, d: u8) -> Uint32 {
    return (cast(Uint32) a) | ((cast(Uint32) b) << 8) | ((cast(Uint32) c) << 16) | ((cast(Uint32) d) << 24);
}

// SDL_thread.h
// In C these are macros that pass _beginthreadex/_endthreadex on Windows so the C runtime gets initialized
// for the new thread. Jai code does not depend on that, so we pass null and SDL uses CreateThread / pthreads.

SDL_CreateThread :: (fn: SDL_ThreadFunction, name: *u8, data: *void) -> *SDL_Thread {
    return SDL_CreateThreadRuntime(fn, name, data, null, null);
}

SDL_CreateThreadWithProperties :: (props: SDL_PropertiesID) -> *SDL_Thread {
    return SDL_CreateThreadWithPropertiesRuntime(props, null, null);
}

// SDL_video.h

SDL_WINDOWPOS_UNDEFINED_DISPLAY :: (display: SDL_DisplayID) -> s32 { return cast(s32) (SDL_WINDOWPOS_UNDEFINED_MASK | display); }
SDL_WINDOWPOS_CENTERED_DISPLAY  :: (display: SDL_DisplayID) -> s32 { return cast(s32) (SDL_WINDOWPOS_CENTERED_MASK  | display); }

SDL_WINDOWPOS_UNDEFINED : s32 : SDL_WINDOWPOS_UNDEFINED_MASK;
SDL_WINDOWPOS_CENTERED  : s32 : SDL_WINDOWPOS_CENTERED_MASK;

SDL_WINDOWPOS_ISUNDEFINED :: (x: s32) -> bool { return (x & 0xFFFF0000) == SDL_WINDOWPOS_UNDEFINED_MASK; }
SDL_WINDOWPOS_ISCENTERED  :: (x: s32) -> bool { return (x & 0xFFFF0000) == SDL_WINDOWPOS_CENTERED_MASK; }

// SDL_mouse.h

SDL_BUTTON_MASK :: (button: s32) -> SDL_MouseButtonFlags { return cast(SDL_MouseButtonFlags) (1 << (button - 1)); }

SDL_MouseButtonFlags :: enum_flags Uint32 {
    LMASK  :: 1 << (SDL_BUTTON_LEFT   - 1);
    MMASK  :: 1 << (SDL_BUTTON_MIDDLE - 1);
    RMASK  :: 1 << (SDL_BUTTON_RIGHT  - 1);
    X1MASK :: 1 << (SDL_BUTTON_X1     - 1);
    X2MASK :: 1 << (SDL_BUTTON_X2     - 1);
}

SDL_BUTTON_LMASK  :: SDL_MouseButtonFlags.LMASK;
SDL_BUTTON_MMASK  :: SDL_MouseButtonFlags.MMASK;
SDL_BUTTON_RMASK  :: SDL_MouseButtonFlags.RMASK;
SDL_BUTTON_X1MASK :: SDL_MouseButtonFlags.X1MASK;
SDL_BUTTON_X2MASK :: SDL_MouseButtonFlags.X2MASK;

// SDL_keycode.h

SDL_SCANCODE_TO_KEYCODE :: (scancode: SDL_Scancode) -> SDL_Keycode {
    return cast(SDL_Keycode) ((cast(Uint32) scancode) | (cast(Uint32) SDL_Keycode.SCANCODE_MASK));
}

// SDL_audio.h

SDL_AUDIO_BITSIZE        :: (x: SDL_AudioFormat) -> Uint32 { return (cast(Uint32) x) & SDL_AUDIO_MASK_BITSIZE; }
SDL_AUDIO_BYTESIZE       :: (x: SDL_AudioFormat) -> Uint32 { return SDL_AUDIO_BITSIZE(x) / 8; }
SDL_AUDIO_ISFLOAT        :: (x: SDL_AudioFormat) -> bool   { return ((cast(Uint32) x) & SDL_AUDIO_MASK_FLOAT) != 0; }
SDL_AUDIO_ISBIGENDIAN    :: (x: SDL_AudioFormat) -> bool   { return ((cast(Uint32) x) & SDL_AUDIO_MASK_BIG_ENDIAN) != 0; }
SDL_AUDIO_ISLITTLEENDIAN :: (x: SDL_AudioFormat) -> bool   { return !SDL_AUDIO_ISBIGENDIAN(x); }
SDL_AUDIO_ISSIGNED       :: (x: SDL_AudioFormat) -> bool   { return ((cast(Uint32) x) & SDL_AUDIO_MASK_SIGNED) != 0; }
SDL_AUDIO_ISINT          :: (x: SDL_AudioFormat) -> bool   { return !SDL_AUDIO_ISFLOAT(x); }
SDL_AUDIO_ISUNSIGNED     :: (x: SDL_AudioFormat) -> bool   { return !SDL_AUDIO_ISSIGNED(x); }
SDL_AUDIO_FRAMESIZE      :: (spec: SDL_AudioSpec)  -> s32  { return (cast(s32) SDL_AUDIO_BYTESIZE(spec.format)) * spec.channels; }

// SDL_pixels.h

SDL_PIXELFLAG   :: (format: SDL_PixelFormat) -> Uint32 { return ((cast(Uint32) format) >> 28) & 0x0F; }
SDL_PIXELTYPE   :: (format: SDL_PixelFormat) -> Uint32 { return ((cast(Uint32) format) >> 24) & 0x0F; }
SDL_PIXELORDER  :: (format: SDL_PixelFormat) -> Uint32 { return ((cast(Uint32) format) >> 20) & 0x0F; }
SDL_PIXELLAYOUT :: (format: SDL_PixelFormat) -> Uint32 { return ((cast(Uint32) format) >> 16) & 0x0F; }

SDL_ISPIXELFORMAT_FOURCC :: (format: SDL_PixelFormat) -> bool { return format != .UNKNOWN && SDL_PIXELFLAG(format) != 1; }

SDL_BITSPERPIXEL :: (format: SDL_PixelFormat) -> Uint32 {
    if SDL_ISPIXELFORMAT_FOURCC(format) return 0;
    return ((cast(Uint32) format) >> 8) & 0xFF;
}

SDL_BYTESPERPIXEL :: (format: SDL_PixelFormat) -> Uint32 {
    if SDL_ISPIXELFORMAT_FOURCC(format) {
        if format == .YUY2 || format == .UYVY || format == .YVYU || format == .P010 return 2;
        return 1;
    }
    return (cast(Uint32) format) & 0xFF;
}

// SDL_rect.h

SDL_RectToFRect :: (rect: *SDL_Rect, frect: *SDL_FRect) {
    frect.x = cast(float) rect.x;
    frect.y = cast(float) rect.y;
    frect.w = cast(float) rect.w;
    frect.h = cast(float) rect.h;
}

SDL_PointInRect :: (p: *SDL_Point, r: *SDL_Rect) -> bool {
    return p && r && p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h;
}

SDL_RectEmpty :: (r: *SDL_Rect) -> bool {
    return !r || r.w <= 0 || r.h <= 0;
}

SDL_RectsEqual :: (a: *SDL_Rect, b: *SDL_Rect) -> bool {
    return a && b && a.x == b.x && a.y == b.y && a.w == b.w && a.h == b.h;
}

SDL_PointInRectFloat :: (p: *SDL_FPoint, r: *SDL_FRect) -> bool {
    return p && r && p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h;
}

SDL_RectEmptyFloat :: (r: *SDL_FRect) -> bool {
    return !r || r.w < 0 || r.h < 0;
}

SDL_RectsEqualEpsilon :: (a: *SDL_FRect, b: *SDL_FRect, epsilon: float) -> bool {
    if !a || !b return false;
    if a == b return true;
    return SDL_fabsf(a.x - b.x) <= epsilon && SDL_fabsf(a.y - b.y) <= epsilon
        && SDL_fabsf(a.w - b.w) <= epsilon && SDL_fabsf(a.h - b.h) <= epsilon;
}

SDL_RectsEqualFloat :: (a: *SDL_FRect, b: *SDL_FRect) -> bool {
    return SDL_RectsEqualEpsilon(a, b, cast(float) SDL_FLT_EPSILON);
}
