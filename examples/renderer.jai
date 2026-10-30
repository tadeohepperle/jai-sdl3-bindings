// Opens a window and draws with SDL_Renderer.
// Arrow keys move the square, clicking moves it to the mouse, Escape quits.

main :: () {
    if !SDL_Init(.VIDEO) {
        print("SDL_Init failed: %\n", to_string(SDL_GetError()));
        return;
    }
    defer SDL_Quit();

    print("SDL % (%) on %, video driver: %\n",
        SDL_GetVersion(), to_string(SDL_GetRevision()), to_string(SDL_GetPlatform()), to_string(SDL_GetCurrentVideoDriver()));

    window: *SDL_Window;
    renderer: *SDL_Renderer;
    if !SDL_CreateWindowAndRenderer("SDL3 renderer example", 800, 600, .RESIZABLE | .HIGH_PIXEL_DENSITY, *window, *renderer) {
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }
    defer SDL_DestroyWindow(window);
    defer SDL_DestroyRenderer(renderer);

    SDL_SetRenderVSync(renderer, 1);

    square := SDL_FRect.{x = 100, y = 100, w = 80, h = 80};
    speed: float = 400; // pixels per second

    last_ticks := SDL_GetTicksNS();
    running := true;
    while running {
        event: SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == {
                case .QUIT;
                    running = false;

                case .KEY_DOWN;
                    if event.key.key == .ESCAPE running = false;

                case .MOUSE_BUTTON_DOWN;
                    if event.button.button == SDL_BUTTON_LEFT {
                        square.x = event.button.x - square.w / 2;
                        square.y = event.button.y - square.h / 2;
                    }

                case .WINDOW_RESIZED;
                    print("Window resized to %x%\n", event.window.data1, event.window.data2);
            }
        }

        now := SDL_GetTicksNS();
        dt := cast(float) (cast(float64) (now - last_ticks) / 1_000_000_000.0);
        last_ticks = now;

        // Polling the keyboard state works too:
        keys := SDL_GetKeyboardState(null);
        if keys[SDL_Scancode.LEFT]  square.x -= speed * dt;
        if keys[SDL_Scancode.RIGHT] square.x += speed * dt;
        if keys[SDL_Scancode.UP]    square.y -= speed * dt;
        if keys[SDL_Scancode.DOWN]  square.y += speed * dt;

        mouse_x, mouse_y: float;
        buttons := SDL_GetMouseState(*mouse_x, *mouse_y);

        SDL_SetRenderDrawColor(renderer, 30, 30, 40, SDL_ALPHA_OPAQUE);
        SDL_RenderClear(renderer);

        SDL_SetRenderDrawColor(renderer, 230, 120, 40, SDL_ALPHA_OPAQUE);
        SDL_RenderFillRect(renderer, *square);

        // Crosshair at the mouse position, green while the left button is held.
        if buttons & .LMASK  SDL_SetRenderDrawColor(renderer, 80, 220, 80, SDL_ALPHA_OPAQUE);
        else                 SDL_SetRenderDrawColor(renderer, 220, 220, 220, SDL_ALPHA_OPAQUE);
        SDL_RenderLine(renderer, mouse_x - 10, mouse_y, mouse_x + 10, mouse_y);
        SDL_RenderLine(renderer, mouse_x, mouse_y - 10, mouse_x, mouse_y + 10);

        SDL_SetRenderDrawColor(renderer, 255, 255, 255, SDL_ALPHA_OPAQUE);
        SDL_RenderDebugText(renderer, 10, 10, "Arrow keys / click to move, Escape to quit");

        SDL_RenderPresent(renderer);
    }
}

#import "Basic";
#import "SDL3";
