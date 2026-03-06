"""Implementation of the dart_proto_library rule."""

load("@protobuf//bazel/common:proto_info.bzl", "ProtoInfo")
load("@rules_dart//dart:providers.bzl", "DartInfo", "DartPackageInfo")

DartProtoInfo = provider(
    doc = "Proto-specific info for downstream dart_proto_library deps.",
    fields = {
        "package_name": "Dart package name",
        "input_root": "Directory of proto sources as seen by protoc (inputRoot for BazelPackages)",
        "transitive_proto_infos": "Depset of structs: (package_name, input_root)",
    },
)

def _file_path(file):
    return file.path

def _common_dir_prefix(a, b):
    """Find the longest common directory prefix of two directory paths."""
    if a == b:
        return a

    # Split into components and find common prefix
    a_parts = a.split("/")
    b_parts = b.split("/")
    common_parts = []
    for i in range(min(len(a_parts), len(b_parts))):
        if a_parts[i] == b_parts[i]:
            common_parts.append(a_parts[i])
        else:
            break
    return "/".join(common_parts)

def _compute_input_root(direct_srcs):
    """Compute the inputRoot for BazelPackages from direct source paths.

    The inputRoot must be the directory prefix of proto files as they appear
    to protoc (exec-root-relative paths passed on the command line). This is
    what protoc_plugin's _findPackage() walks up to match.

    proto_source_root from ProtoInfo is typically "" or "." (the repo root)
    which _findPackage cannot match, so we derive it from the actual files.
    """
    if not direct_srcs:
        fail("dart_proto_library: proto_library has no direct sources")

    # Find the common directory prefix across all direct sources.
    # For a well-formed proto_library, all sources share the same directory,
    # but we handle the general case by finding the longest common prefix.
    dirs = []
    for src in direct_srcs:
        path = src.path
        if "/" in path:
            dirs.append(path.rsplit("/", 1)[0])
        else:
            return ""  # Root-level proto — _findPackage can't match this
    if not dirs:
        return ""

    common = dirs[0]
    for d in dirs[1:]:
        common = _common_dir_prefix(common, d)
    return common

def _dart_proto_library_impl(ctx):
    if len(ctx.attr.deps) != 1:
        fail("dart_proto_library requires exactly 1 proto_library dep, got %d" % len(ctx.attr.deps))

    proto_info = ctx.attr.deps[0][ProtoInfo]

    package_name = ctx.attr.package_name or ctx.label.name
    for c in package_name.elems():
        if not (c.isalnum() or c == "_"):
            fail("package_name %r contains invalid character %r; must be alphanumeric or underscore" % (package_name, c))

    # Declare a tree artifact: <package_name>/lib/
    lib_dir = ctx.actions.declare_directory(package_name + "/lib")

    # Only generate for DIRECT sources (1:1 model)
    direct_srcs = proto_info.direct_sources

    # Compute inputRoot from actual file paths, NOT from proto_source_root.
    # proto_source_root is typically "" or "." which _findPackage cannot match.
    input_root = _compute_input_root(direct_srcs)

    # Build BazelPackages option for cross-package imports
    bazel_entries = []

    # This target: output_root = "." so files land directly in lib_dir
    bazel_entries.append("%s|%s|." % (package_name, input_root))

    # Deps: collect from DartProtoInfo (transitive)
    seen_roots = {input_root: True}
    for dep in ctx.attr.dart_deps:
        dpi = dep[DartProtoInfo]
        for info in dpi.transitive_proto_infos.to_list():
            if info.input_root not in seen_roots:
                seen_roots[info.input_root] = True
                bazel_entries.append("%s|%s|." % (
                    info.package_name,
                    info.input_root,
                ))

    bazel_packages_opt = ";".join(bazel_entries)
    dart_out_opt = "BazelPackages=%s" % bazel_packages_opt
    if ctx.attr.grpc:
        dart_out_opt = "grpc," + dart_out_opt

    args = ctx.actions.args()

    plugin = ctx.executable._plugin
    args.add("--plugin=protoc-gen-dart=%s" % plugin.path)
    args.add("--dart_out=%s:%s" % (dart_out_opt, lib_dir.path))

    # Import paths from transitive proto path
    import_paths = {}
    for path in proto_info.transitive_proto_path.to_list():
        if path:
            import_paths[path] = True
    for path in sorted(import_paths.keys()):
        args.add("-I" + path)

    # Always include the exec root for well-known protos
    args.add("-I.")

    # Only direct sources as positional args (fileToGenerate)
    args.add_all(direct_srcs, map_each = _file_path)

    ctx.actions.run(
        mnemonic = "DartProtoGen",
        executable = ctx.executable._protoc,
        arguments = [args],
        inputs = proto_info.transitive_sources,  # all transitive for import resolution
        tools = [plugin],
        outputs = [lib_dir],
        progress_message = "Generating Dart protobuf code for %{label}",
    )

    # Collect DartInfo from runtime libraries.
    runtime_deps = [ctx.attr._protobuf_runtime[DartInfo]]
    if ctx.attr.grpc:
        runtime_deps.append(ctx.attr._grpc_runtime[DartInfo])

    dart_dep_infos = [dep[DartInfo] for dep in ctx.attr.dart_deps]
    all_dep_infos = runtime_deps + dart_dep_infos

    # lib_root: short_path to the package root (parent of lib/).
    lib_root = lib_dir.short_path.rsplit("/", 1)[0]

    this_pkg = DartPackageInfo(
        package_name = package_name,
        lib_root = lib_root,
    )

    transitive_srcs = depset(
        direct = [lib_dir],
        transitive = [dep.transitive_srcs for dep in all_dep_infos],
    )

    transitive_packages = depset(
        direct = [this_pkg],
        transitive = [dep.transitive_packages for dep in all_dep_infos],
    )

    # DartProtoInfo for downstream dart_proto_library targets
    this_struct = struct(package_name = package_name, input_root = input_root)
    transitive_proto_infos = depset(
        direct = [this_struct],
        transitive = [dep[DartProtoInfo].transitive_proto_infos for dep in ctx.attr.dart_deps],
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
        DartProtoInfo(
            package_name = package_name,
            input_root = input_root,
            transitive_proto_infos = transitive_proto_infos,
        ),
    ]

dart_proto_library = rule(
    implementation = _dart_proto_library_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "Exactly one proto_library target to generate Dart code for.",
            mandatory = True,
            providers = [ProtoInfo],
        ),
        "dart_deps": attr.label_list(
            doc = "dart_proto_library targets for proto deps.",
            default = [],
            providers = [DartProtoInfo, DartInfo],
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
            doc = "The protoc-gen-dart plugin (Bazel-aware).",
            default = "//dart_proto:protoc_gen_dart_bazel",
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
Generates Dart protobuf code from a single proto_library target.

Each dart_proto_library wraps exactly one proto_library and generates code
only for its direct sources. Use dart_deps to link to other dart_proto_library
targets that correspond to the proto_library's deps.

Returns DartInfo so the generated code can be used as a dependency of
dart_binary, dart_library, or dart_test targets.
""",
)
