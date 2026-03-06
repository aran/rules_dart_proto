"""Implementation of the dart_proto_library rule."""

load("@protobuf//bazel/common:proto_info.bzl", "ProtoInfo")
load("@rules_dart//dart:providers.bzl", "DartInfo", "DartPackageInfo")

def _file_path(file):
    return file.path

def _dart_proto_library_impl(ctx):
    proto_infos = [dep[ProtoInfo] for dep in ctx.attr.deps]

    package_name = ctx.attr.package_name or ctx.label.name
    for c in package_name.elems():
        if not (c.isalnum() or c == "_"):
            fail("package_name %r contains invalid character %r; must be alphanumeric or underscore" % (package_name, c))

    # Declare a tree artifact: <package_name>/lib/
    # Generated .pb.dart files go inside, making them accessible via
    # package:<package_name>/... imports through the standard packageUri: "lib/".
    lib_dir = ctx.actions.declare_directory(package_name + "/lib")

    # Collect all transitive sources and import paths across all deps.
    # We generate code for ALL transitive proto sources (not just direct ones)
    # because protoc-gen-dart generates imports between .pb.dart files — if
    # person.proto imports address.proto, person.pb.dart references Address
    # from address.pb.dart, so both must be generated together.
    #
    # Import paths are collected eagerly (small set of strings), but sources
    # stay as depsets to avoid flattening during analysis.
    import_paths = {}
    transitive_src_depsets = []
    for proto_info in proto_infos:
        for path in proto_info.transitive_proto_path.to_list():
            if path:
                import_paths[path] = True
        transitive_src_depsets.append(proto_info.transitive_sources)

    all_srcs = depset(transitive = transitive_src_depsets)

    args = ctx.actions.args()

    plugin = ctx.executable._plugin
    args.add("--plugin=protoc-gen-dart=%s" % plugin.path)

    if ctx.attr.grpc:
        args.add("--dart_out=grpc:%s" % lib_dir.path)
    else:
        args.add("--dart_out=%s" % lib_dir.path)

    for path in sorted(import_paths.keys()):
        args.add("-I" + path)

    # Always include the exec root for well-known protos
    args.add("-I.")

    args.add_all(all_srcs, map_each = _file_path)

    ctx.actions.run(
        mnemonic = "DartProtoGen",
        executable = ctx.executable._protoc,
        arguments = [args],
        inputs = all_srcs,
        tools = [plugin],
        outputs = [lib_dir],
        progress_message = "Generating Dart protobuf code for %{label}",
    )

    # Collect DartInfo from runtime libraries.
    runtime_deps = [ctx.attr._protobuf_runtime[DartInfo]]
    if ctx.attr.grpc:
        runtime_deps.append(ctx.attr._grpc_runtime[DartInfo])

    # lib_root: short_path to the package root (parent of lib/).
    # e.g. lib_dir.short_path is "<name>/lib", lib_root is "<name>".
    lib_root = lib_dir.short_path.rsplit("/", 1)[0]

    this_pkg = DartPackageInfo(
        package_name = package_name,
        lib_root = lib_root,
    )

    transitive_srcs = depset(
        direct = [lib_dir],
        transitive = [dep.transitive_srcs for dep in runtime_deps],
    )

    transitive_packages = depset(
        direct = [this_pkg],
        transitive = [dep.transitive_packages for dep in runtime_deps],
    )

    return [
        DefaultInfo(
            files = depset([lib_dir]),
            runfiles = ctx.runfiles(files = [lib_dir]),
        ),
        DartInfo(
            package_name = package_name,
            lib_root = lib_root,
            transitive_srcs = transitive_srcs,
            transitive_packages = transitive_packages,
        ),
    ]

dart_proto_library = rule(
    implementation = _dart_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "proto_library targets to generate Dart code for.",
            mandatory = True,
            providers = [ProtoInfo],
        ),
        "package_name": attr.string(
            doc = "Dart package name for the generated code. Defaults to the rule name.",
        ),
        "grpc": attr.bool(
            doc = "If True, also generate .pbgrpc.dart files for gRPC services.",
            default = False,
        ),
        "_protoc": attr.label(
            doc = "The protoc compiler.",
            default = "@protobuf//:protoc",
            executable = True,
            cfg = "exec",
        ),
        "_plugin": attr.label(
            doc = "The protoc-gen-dart plugin.",
            default = "//dart_proto:protoc_gen_dart",
            executable = True,
            cfg = "exec",
        ),
        "_protobuf_runtime": attr.label(
            doc = "The Dart protobuf runtime library.",
            default = "@dart_proto_deps//:protobuf",
            providers = [DartInfo],
        ),
        "_grpc_runtime": attr.label(
            doc = "The Dart gRPC runtime library (used when grpc = True).",
            default = "@dart_proto_deps//:grpc",
            providers = [DartInfo],
        ),
    },
    doc = """\
Generates Dart protobuf code from proto_library targets.

Returns DartInfo so the generated code can be used as a dependency of
dart_binary, dart_library, or dart_test targets.
""",
)
