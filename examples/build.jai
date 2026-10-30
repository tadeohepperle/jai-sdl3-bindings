// Builds the examples into examples/bin and puts the SDL3 shared library next to them.
//
//     jai build.jai
//
// This module has to be importable as "SDL3", i.e. live in a directory called SDL3 inside one of your
// module directories (see README.md). Otherwise tell the compiler where to find it:
//
//     jai build.jai -import_dir /path/to/directory/containing/SDL3

EXAMPLES :: string.["renderer.jai", "opengl.jai"];

#run {
    set_build_options_dc(.{do_output=false});

    output_path := tprint("%bin", #filepath);
    make_directory_if_it_does_not_exist(output_path);

    for EXAMPLES {
        w := compiler_create_workspace(it);
        options := get_build_options(w);
        copy_commonly_propagated_fields(get_build_options(), *options);
        options.output_path = output_path;
        options.output_executable_name = path_strip_extension(it);
        options.import_path = get_build_options().import_path; // Keeps any -import_dir from the command line.
        set_build_options(options, w);
        add_build_file(tprint("%1%2", #filepath, it), w);
    }

    if !SDL3_copy_shared_library(output_path) {
        compiler_report("Could not copy the SDL3 shared library next to the examples.");
    }
}

#import "Basic";
#import "Compiler";
#import "File";
#import "String";
#import "SDL3";
