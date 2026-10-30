// Generates "generated.jai" from the official SDL3 headers in "include/SDL3".
//
// Usage (from this directory):
//     jai generate.jai
//
// The output is meant to be used on both Linux and Windows. Run the generator on Linux:
// the few declarations that differ between platforms (wchar_t, C long, Windows-only
// functions from SDL_system.h, printf format macros) are excluded here and declared by hand
// in "platform.jai".
//
// SDL3 declares most of its flag sets as "typedef Uint32 SDL_FooFlags;" plus a bunch of
// #defines. MACRO_ENUMS below turns those into proper Jai enums / enum_flags, so that
// SDL_CreateWindow(..., .OPENGL | .RESIZABLE) works. After the generated declarations we
// emit global aliases for all enum members with their original C names (SDL_WINDOW_OPENGL,
// SDL_EVENT_QUIT, SDLK_ESCAPE, ...) so code ported from C or from the SDL2 module keeps working.

AT_COMPILE_TIME :: true;

OUTPUT_FILE   :: "generated.jai";
HEADER_PATH   :: "include";
LIBRARY_PATH  :: "linux";
TEMP_PATH     :: ".generate_tmp"; // Preprocessed copy of the headers, deleted after generating.

Macro_Enum :: struct {
    prefix:    string;
    enum_name: string;
    is_flags:  bool;
    suffix:    string;   // If set, the macro must also end with this.
}

// Order matters: the first matching entry wins, so put more specific prefixes first.
MACRO_ENUMS :: Macro_Enum.[
    .{"SDL_INIT_",                          "SDL_InitFlags",                  true,  ""},
    .{"SDL_WINDOW_SURFACE_VSYNC_",          "",                               false, ""}, // Plain constants, not window flags.
    .{"SDL_WINDOW_",                        "SDL_WindowFlags",                true,  ""},
    .{"SDLK_",                              "SDL_Keycode",                    false, ""},
    .{"SDL_KMOD_",                          "SDL_Keymod",                     true,  ""},
    .{"SDL_SURFACE_",                       "SDL_SurfaceFlags",               true,  ""},
    .{"SDL_MESSAGEBOX_BUTTON_",             "SDL_MessageBoxButtonFlags",      true,  ""},
    .{"SDL_MESSAGEBOX_COLOR",               "",                               false, ""},
    .{"SDL_MESSAGEBOX_",                    "SDL_MessageBoxFlags",            true,  ""},
    .{"SDL_PEN_INPUT_",                     "SDL_PenInputFlags",              true,  ""},
    .{"SDL_GLOB_",                          "SDL_GlobFlags",                  true,  ""},
    .{"SDL_TRAYENTRY_",                     "SDL_TrayEntryFlags",             true,  ""},
    .{"SDL_GPU_TEXTUREUSAGE_",              "SDL_GPUTextureUsageFlags",       true,  ""},
    .{"SDL_GPU_BUFFERUSAGE_",               "SDL_GPUBufferUsageFlags",        true,  ""},
    .{"SDL_GPU_SHADERFORMAT_",              "SDL_GPUShaderFormat",            true,  ""},
    .{"SDL_GPU_COLORCOMPONENT_",            "SDL_GPUColorComponentFlags",     true,  ""},
    .{"SDL_GL_CONTEXT_PROFILE_",            "SDL_GLProfile",                  true,  ""},
    .{"SDL_GL_CONTEXT_RELEASE_BEHAVIOR_",   "SDL_GLContextReleaseFlag",       true,  ""},
    .{"SDL_GL_CONTEXT_RESET_",              "SDL_GLContextResetNotification", true,  ""},
    .{"SDL_GL_CONTEXT_",                    "SDL_GLContextFlag",              true,  "_FLAG"},
    .{"SDL_BLENDMODE_",                     "SDL_BlendMode",                  false, ""},
];

// Declarations that are platform-specific or otherwise hand-written in "platform.jai" / "helpers.jai".
OMIT_DECLARATIONS :: string.[
    // Generated from the Linux side of #ifdefs:
    "SDL_PLATFORM_LINUX", "SDL_PLATFORM_UNIX", "SDL_DISABLE_OLD_NAMES", "SDL_MAIN_HANDLED",
    "SDL_PRILL_PREFIX", "SDL_PRIs64", "SDL_PRIu64", "SDL_PRIx64", "SDL_PRIX64",
    "SDL_PRIs32", "SDL_PRIu32", "SDL_PRIx32", "SDL_PRIX32",
    "SDL_PRILLd", "SDL_PRILLu", "SDL_PRILLx", "SDL_PRILLX",
    "SDL_BYTEORDER", "SDL_FLOATWORDORDER",
    // "long" is 32 bits on Windows but 64 bits on Linux:
    "SDL_wcstol", "SDL_ltoa", "SDL_ultoa", "SDL_strtol", "SDL_strtoul", "SDL_lround", "SDL_lroundf",
    // Its values are defined with the function-like macro SDL_BUTTON_MASK(), so we write this enum by hand in helpers.jai.
    "SDL_MouseButtonFlags",
    // Declared per platform in platform.jai:
    "SDL_wchar_t",
    // A wide-character printf. Not useful from Jai, and the generated print-like wrapper would be wrong.
    "SDL_swprintf",
];

#if AT_COMPILE_TIME {
    #run,stallable {
        set_build_options_dc(.{do_output=false});
        if !generate() {
            compiler_set_workspace_status(.FAILED);
        }
    }
} else {
    #import "System";

    main :: () {
        set_working_directory(path_strip_filename(get_path_of_running_executable()));
        if !generate() {
            exit(1);
        }
    }
}

generate :: () -> bool {
    #if OS != .LINUX {
        log_error("Please run the SDL3 bindings generator on Linux. (See the comment at the top of generate.jai.)");
        return false;
    }

    if !copy_preprocessed_headers() return false;
    defer delete_directory(TEMP_PATH);

    options: Generate_Bindings_Options;
    {
        using options;

        // Only used to check that every function we bind actually exists in the library.
        array_add(*library_search_paths, LIBRARY_PATH);
        array_add(*libraries, .{filename="libSDL3", identifier="SDL3"});
        generate_library_declarations = false;

        array_add(*include_paths, TEMP_PATH);
        array_add(*source_files, tprint("%/SDL3/SDL.h", TEMP_PATH));
        array_add(*source_files, tprint("%/SDL3/SDL_main.h", TEMP_PATH)); // SDL_SetMainReady, SDL_RunApp, SDL_EnterAppMainCallbacks
        array_add(*extra_clang_arguments, "-x", "c", "-DSDL_DISABLE_OLD_NAMES", "-DSDL_MAIN_HANDLED");

        // The generator only consults convert_macro_value_to_enum_callback while iterating over this list,
        // so it needs at least one (never matching) entry.
        array_add(*generate_enums_from_macros_with_prefixes, "__SDL3_JAI_NEVER_MATCHES__");
        convert_macro_value_to_enum_callback = macro_to_enum;

        strip_enum_prefixes        = true;
        auto_detect_enum_prefixes  = true;
        alias_original_enum_names  = false; // We emit global aliases ourselves, see append_global_enum_aliases().

        generate_compile_time_struct_checks = false;
        log_stripped_declarations = true;
        mimic_spacing_flags = .ALL;

        visitor_with_data   = sdl_visitor;
        will_print_bindings = fix_up_declarations;

        header = HEADER;
    }

    if !generate_bindings(options, OUTPUT_FILE) return false;

    // Append the global aliases that fix_up_declarations collected.
    // (We can't look at the declarations anymore at this point; the generator has freed them.)
    text, ok := read_entire_file(OUTPUT_FILE);
    if !ok return false;
    text = align_union_primary_fields(text);
    builder: String_Builder;
    append(*builder, text);
    append(*builder, builder_to_string(*alias_builder));
    return write_entire_file(OUTPUT_FILE, *builder);
}

// Jai does not take #overlay fields into account for a struct's alignment, so a C union whose largest member
// is less aligned than another member (e.g. SDL_HapticEffect, where only SDL_HapticCustom contains a pointer)
// would get the wrong size and alignment. Put an explicit #align on the primary field of those unions.
align_union_primary_fields :: (text: string) -> string {
    builder: String_Builder;
    current_struct := "";
    for line: split(text, "\n") {
        if it_index > 0 append(*builder, "\n");

        if line.count && line[0] != #char " " && contains(line, " :: struct {") {
            found: bool;
            found, current_struct = split_from_left(line, " :: struct {");
        } else if line == "}" {
            current_struct = "";
        }

        for union_alignments {
            if it.struct_name != current_struct continue;
            prefix := tprint("    %:", it.field_name);
            if !begins_with(line, prefix) continue;

            found, declaration, rest := split_from_left(line, #char ";");
            assert(found);
            print_to_builder(*builder, "% #align %;%", declaration, it.alignment, rest);
            remove it;
            continue line;
        }
        append(*builder, line);
    }

    for union_alignments log_error("Could not find primary field %.% to align", it.struct_name, it.field_name);
    return builder_to_string(*builder);
}

// We parse a slightly preprocessed copy of the headers:
//
// * The generator looks at the raw tokens of a macro and can't evaluate calls of function-like macros.
//   SDL uses SDL_UINT64_C(0x...) for all 64-bit flags (e.g. SDL_WindowFlags), so we replace those
//   calls by their argument.
// * wchar_t is 4 bytes on Linux but 2 bytes on Windows. Declarations that use it get "SDL_wchar_t"
//   instead, which we can then declare per platform in platform.jai.
copy_preprocessed_headers :: () -> bool {
    source_dir := tprint("%/SDL3", HEADER_PATH);
    target_dir := tprint("%/SDL3", TEMP_PATH);
    if !make_directory_if_it_does_not_exist(target_dir, recursive = true) return false;

    files := file_list(source_dir);
    for path: files {
        if !ends_with(path, ".h") continue;
        text, ok := read_entire_file(path);
        if !ok return false;

        is_stdinc := path_filename(path) == "SDL_stdinc.h";
        builder: String_Builder;
        for line: split(text, "\n") {
            if is_stdinc && line == "#include <SDL3/SDL_begin_code.h>" {
                append(*builder, "typedef wchar_t SDL_wchar_t;\n");
            }

            processed := replace_uint64_macro_calls(line);
            trimmed := trim_left(processed);
            is_comment := begins_with(trimmed, "*") || begins_with(trimmed, "/*") || begins_with(trimmed, "//");
            if !is_comment && contains(processed, "wchar_t") {
                processed = replace_word(processed, "wchar_t", "SDL_wchar_t");
            }

            append(*builder, processed);
            append(*builder, "\n");
        }

        if !write_entire_file(tprint("%/%", target_dir, path_filename(path)), *builder) return false;
    }
    return true;
}

replace_uint64_macro_calls :: (line: string) -> string {
    MACRO :: "SDL_UINT64_C(";
    if !contains(line, MACRO) return line;

    builder: String_Builder;
    remaining := line;
    while true {
        found, before, after := split_from_left(remaining, MACRO);
        if !found {
            append(*builder, remaining);
            break;
        }
        append(*builder, before);
        found_paren, argument, rest := split_from_left(after, #char ")");
        if !found_paren || !is_hex_literal(argument) {
            append(*builder, MACRO); // Leave the macro definition itself and anything unusual alone.
            remaining = after;
            continue;
        }
        append(*builder, argument);
        remaining = rest;
    }
    return builder_to_string(*builder);
}

// Replaces whole-word occurrences only.
replace_word :: (s: string, word: string, replacement: string) -> string {
    is_ident_char :: (c: u8) -> bool { return is_alnum(c) || c == #char "_"; }

    builder: String_Builder;
    i := 0;
    while i < s.count {
        if i + word.count <= s.count && slice(s, i, word.count) == word
            && (i == 0 || !is_ident_char(s[i-1]))
            && (i + word.count == s.count || !is_ident_char(s[i + word.count])) {
            append(*builder, replacement);
            i += word.count;
        } else {
            append(*builder, s[i]);
            i += 1;
        }
    }
    return builder_to_string(*builder);
}

is_hex_literal :: (s: string) -> bool {
    if !begins_with(s, "0x") || s.count < 3 return false;
    for 2..s.count-1 {
        c := s[it];
        if !((c >= #char "0" && c <= #char "9") || (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F")) return false;
    }
    return true;
}

HEADER :: #string END
// SDL3 bindings for Jai, generated from the official SDL 3.4 headers.
// Do not edit by hand. Hand-written additions live in helpers.jai and platform.jai.

END

macro_to_enum :: (decl: *Declaration) -> string {
    for MACRO_ENUMS {
        if !begins_with(decl.name, it.prefix) continue;
        if it.suffix && !ends_with(decl.name, it.suffix) continue;
        return it.enum_name; // Empty string means: keep it as a plain constant.
    }
    return "";
}

// Filled in by the visitor, consumed in fix_up_declarations and append_global_enum_aliases.
global_enums:     [..] *Enum;
flag_typedefs:    [..] *Typedef;
event_type_enum:  *Enum;
event_type_users: [..] *Declaration; // "type" members that should be SDL_EventType instead of Uint32.
unions:           [..] *Struct;

Union_Alignment :: struct {
    struct_name: string;
    field_name:  string;
    alignment:   s64;
}
union_alignments: [..] Union_Alignment; // Heap-allocated, survives generate_bindings().

sdl_visitor :: (decl: *Declaration, parent_decl: *Declaration, user_data: *void) -> Declaration_Visit_Result {
    if !parent_decl {
        if array_find(OMIT_DECLARATIONS, decl.name) {
            decl.decl_flags |= .OMIT_FROM_OUTPUT;
            return .STOP;
        }

        if decl.kind == .ENUM {
            _enum := cast(*Enum) decl;
            array_add(*global_enums, _enum);
            if decl.name == "SDL_EventType" event_type_enum = _enum;
        }

        if decl.kind == .STRUCT && (cast(*Struct) decl).flags & .IS_UNION {
            array_add(*unions, cast(*Struct) decl);
        }

        if decl.kind == .TYPEDEF {
            for MACRO_ENUMS {
                if it.enum_name && it.enum_name == decl.name {
                    array_add(*flag_typedefs, cast(*Typedef) decl);
                    break;
                }
            }
        }
    }

    // SDL declares SDL_Event.type and SDL_CommonEvent.type as Uint32 so that user-registered event types fit.
    // A Jai enum can hold any value of its underlying type, so we can use SDL_EventType and allow "event.type == .QUIT".
    if parent_decl && (parent_decl.name == "SDL_Event" || parent_decl.name == "SDL_CommonEvent") && decl.name == "type" {
        array_add(*event_type_users, decl);
    }

    // The generator moves this field to the top of the struct (for #overlay) and prepends a "//" line to its
    // comment, which breaks the multi-line /* */ comment it already has.
    if parent_decl && parent_decl.name == "SDL_Event" && decl.name == "padding" {
        decl.comment.text = "";
    }

    return .RECURSE;
}

fix_up_declarations :: () {
    // Give the enums we built from macros the underlying type of the C typedef and drop the typedef,
    // so that all uses of e.g. SDL_WindowFlags refer to the enum.
    for td: flag_typedefs {
        found := false;
        for _enum: global_enums {
            if _enum.name != td.name continue;
            _enum.type = td.type;
            for MACRO_ENUMS {
                if it.enum_name == _enum.name && it.is_flags {
                    _enum.flags |= .IS_ENUM_FLAGS | .VALUES_IN_HEX;
                    break;
                }
            }
            td.decl_flags |= .OMIT_FROM_OUTPUT;
            found = true;
            break;
        }
        if !found log_error("No enum was generated for typedef %", td.name);
    }

    if event_type_enum {
        for event_type_users {
            it.type = create_type_of_enum(event_type_enum);
        }
    }

    // The generator runs this on a pool allocator that is released before generate_bindings() returns,
    // so put everything we need afterwards on the heap.
    push_allocator(context.default_allocator);

    for unions {
        if !it.type || !it.primary_field || !it.primary_field.type continue;
        if it.primary_field.type.alignment >= it.type.alignment continue;
        array_add(*union_alignments, .{copy_string(it.output_name), copy_string(it.primary_field.output_name), it.type.alignment});
    }

    append_global_enum_aliases(*alias_builder);
}

alias_builder: String_Builder;

append_global_enum_aliases :: (builder: *String_Builder) {
    // The generated file ends with "#scope_file" (for its #import "Basic"), so switch back first.
    append(builder, "\n#scope_export\n\n// Global aliases with the original C names, e.g. SDL_WINDOW_OPENGL :: SDL_WindowFlags.OPENGL.\n");
    for _enum: global_enums {
        if _enum.decl_flags & .OMIT_FROM_OUTPUT continue;
        if !_enum.output_name continue;

        append(builder, "\n");
        for _enum.enumerates {
            if it.decl_flags & .OMIT_FROM_OUTPUT continue;
            if !it.output_name || it.name == it.output_name continue;
            print_to_builder(builder, "% :: %.%;\n", it.name, _enum.output_name, it.output_name);
        }
    }
}

#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "String";
