"""Implementation of the dart_proto_library rule."""

load("@protobuf//bazel/common:proto_info.bzl", "ProtoInfo")
load("@rules_dart//dart:providers.bzl", "DartInfo", "DartPackageInfo")

def _dart_proto_library_impl(ctx):
    proto_infos = [dep[ProtoInfo] for dep in ctx.attr.deps]

    # Declare a tree artifact: <rule_name>/lib/
    # Generated .pb.dart files go inside, making them accessible via
    # package:<rule_name>/... imports through the standard packageUri: "lib/".
    lib_dir = ctx.actions.declare_directory(ctx.label.name + "/lib")

    # Collect all sources across all deps into a single protoc invocation.
    # Bazel requires exactly one action per declared output directory.
    #
    # We generate code for ALL transitive proto sources (not just direct ones)
    # because protoc-gen-dart generates imports between .pb.dart files — if
    # person.proto imports address.proto, person.pb.dart references Address
    # from address.pb.dart, so both must be generated together.
    all_srcs = {}  # File -> True, used as ordered set for dedup
    import_paths = {}
    transitive_src_depsets = []
    for proto_info in proto_infos:
        for src in proto_info.transitive_sources.to_list():
            all_srcs[src] = True
        for path in proto_info.transitive_proto_path.to_list():
            if path:
                import_paths[path] = True
        transitive_src_depsets.append(proto_info.transitive_sources)

    if all_srcs:
        args = ctx.actions.args()

        plugin = ctx.executable._plugin
        args.add("--plugin=protoc-gen-dart=%s" % plugin.path)

        if ctx.attr.grpc:
            args.add("--dart_out=grpc:%s" % lib_dir.path)
        else:
            args.add("--dart_out=%s" % lib_dir.path)

        for path in import_paths:
            args.add("-I%s" % path)

        # Always include the exec root for well-known protos
        args.add("-I.")

        for src in all_srcs:
            args.add(src.path)

        ctx.actions.run(
            mnemonic = "DartProtoGen",
            executable = ctx.executable._protoc,
            arguments = [args],
            inputs = depset(
                transitive = transitive_src_depsets,
            ),
            tools = [plugin],
            outputs = [lib_dir],
            progress_message = "Generating Dart protobuf code for %{label}",
        )

    # Collect DartInfo from the protobuf runtime
    runtime_info = ctx.attr._protobuf_runtime[DartInfo]

    # lib_root: the path to the package root (parent of lib/).
    # For generated files in bazel-out, we use the full exec-root-relative path
    # so the package_config.json rootUri resolves correctly.
    # lib_dir.path is "bazel-out/<config>/bin/<pkg>/<name>/lib"
    # We need "bazel-out/<config>/bin/<pkg>/<name>" (strip trailing /lib).
    lib_root = lib_dir.path.rsplit("/", 1)[0]

    package_name = ctx.label.name

    this_pkg = DartPackageInfo(
        package_name = package_name,
        lib_root = lib_root,
    )

    transitive_srcs = depset(
        direct = [lib_dir],
        transitive = [runtime_info.transitive_srcs],
    )

    transitive_packages = depset(
        direct = [this_pkg],
        transitive = [runtime_info.transitive_packages],
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
    },
    doc = """\
Generates Dart protobuf code from proto_library targets.

Returns DartInfo so the generated code can be used as a dependency of
dart_binary, dart_library, or dart_test targets.
""",
)
