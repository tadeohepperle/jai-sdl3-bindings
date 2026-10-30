// OpenGL with SDL3. This is modules/GL/examples/gl_sdl.jai (SDL2) ported to SDL3;
// the comments point out what changed.
// F11 toggles fullscreen, Escape quits.

main :: () {
    // SDL3 functions return bool (true = success) instead of an int error code.
    if !SDL_Init(SDL_INIT_VIDEO) {
        print("SDL_Init failed: %\n", to_string(SDL_GetError()));
        return;
    }
    defer SDL_Quit();

    // GL attributes have to be set before the window is created.
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);

    // No more x/y arguments (use SDL_SetWindowPosition or SDL_CreateWindowWithProperties),
    // no more SDL_WINDOW_SHOWN (windows are shown by default), and SDL_WINDOW_ALLOW_HIGHDPI is now .HIGH_PIXEL_DENSITY.
    window := SDL_CreateWindow("An SDL3 window", 640, 480, .OPENGL | .RESIZABLE | .HIGH_PIXEL_DENSITY);
    if window == null {
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }
    defer SDL_DestroyWindow(window);

    gl_context := SDL_GL_CreateContext(window);
    if !gl_context {
        print("Could not create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }
    defer SDL_GL_DestroyContext(gl_context); // Was SDL_GL_DeleteContext.

    SDL_GL_MakeCurrent(window, gl_context);
    SDL_GL_SetSwapInterval(1);

    // SDL_GL_GetProcAddress returns an SDL_FunctionPointer; the GL module wants a *void.
    gl_load(*gl, (name: *u8) -> *void #c_call { return cast(*void) SDL_GL_GetProcAddress(name); });
    using gl;

    print("GL Vendor = %\n",  to_string(glGetString(GL_VENDOR)));
    print("GL Version = %\n", to_string(glGetString(GL_VERSION)));

    // The window size is in "screen coordinates"; for glViewport we want pixels.
    // (SDL_GL_GetDrawableSize is gone, use SDL_GetWindowSizeInPixels.)
    w, h: s32;
    SDL_GetWindowSizeInPixels(window, *w, *h);

    fullscreen := false;
    exit := false;
    while !exit {
        event: SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == {
                case .QUIT;                                     // Was SDL_QUIT.
                    exit = true;

                case .KEY_UP;                                   // Was SDL_KEYUP.
                    if event.key.key == SDLK_ESCAPE exit = true;  // Was event.key.keysym.sym.
                    if event.key.key == SDLK_F11 {
                        fullscreen = !fullscreen;
                        SDL_SetWindowFullscreen(window, fullscreen);  // Takes a bool now.
                    }

                case .WINDOW_PIXEL_SIZE_CHANGED;                // Window events are top-level events now, no more SDL_WINDOWEVENT.
                    w = event.window.data1;
                    h = event.window.data2;
            }
        }

        t := cast(float) (cast(float64) SDL_GetTicks() / 1000.0);
        glViewport(0, 0, xx w, xx h);
        glClearColor(0.5 + 0.5 * sin(t), 0.3, 0.5 + 0.5 * cos(t), 1);
        glClear(GL_COLOR_BUFFER_BIT);

        SDL_GL_SwapWindow(window);
    }
}

#import "Basic";
#import "Math";
#import "GL";
#import "SDL3";
