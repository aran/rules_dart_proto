"""Toolchain definition for dart_proto rules."""

load("@rules_dart//dart:providers.bzl", "DartInfo")

DartProtoToolchainInfo = provider(
    doc = """\
Runtime and tool configuration for dart_proto_library.

Consumers must register a toolchain of type
@rules_dart_proto//dart_proto:toolchain_type that provides this info.
Build tools (protoc, plugin) have sensible defaults; runtime libraries
(protobuf, grpc) must be explicitly provided from the consumer's own
dependency graph to avoid type-identity conflicts (the "diamond problem").
""",
    fields = {
        "protoc": "FilesToRunProvider for the protoc compiler.",
        "plugin": "FilesToRunProvider for the protoc-gen-dart plugin.",
        "protobuf_runtime": "DartInfo for the Dart protobuf runtime library.",
        "grpc_runtime": "DartInfo for the Dart gRPC runtime library, or None.",
    },
)

def _dart_proto_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        dart_proto_toolchain_info = DartProtoToolchainInfo(
            protoc = ctx.attr.protoc[DefaultInfo].files_to_run,
            plugin = ctx.attr.plugin[DefaultInfo].files_to_run,
            protobuf_runtime = ctx.attr.protobuf_runtime[DartInfo],
            grpc_runtime = ctx.attr.grpc_runtime[DartInfo] if ctx.attr.grpc_runtime else None,
        ),
    )]

dart_proto_toolchain = rule(
    implementation = _dart_proto_toolchain_impl,
    doc = """\
Declares a dart_proto toolchain carrying build tools and runtime libraries.

Register this toolchain in your MODULE.bazel:

    register_toolchains("//path/to:my_toolchain")

Wrap it in a native toolchain() rule:

    dart_proto_toolchain(
        name = "my_toolchain_impl",
        protobuf_runtime = "@my_pub_deps//:protobuf",
        grpc_runtime = "@my_pub_deps//:grpc",  # only if using grpc
    )

    toolchain(
        name = "my_toolchain",
        toolchain = ":my_toolchain_impl",
        toolchain_type = "@rules_dart_proto//dart_proto:toolchain_type",
    )
""",
    attrs = {
        "protoc": attr.label(
            doc = "The protoc compiler. Defaults to the protobuf module's protoc.",
            executable = True,
            cfg = "exec",
            default = Label("@protobuf//:protoc"),
        ),
        "plugin": attr.label(
            doc = "The protoc-gen-dart plugin. Defaults to the bundled Bazel-aware plugin.",
            executable = True,
            cfg = "exec",
            default = Label("//dart_proto:protoc_gen_dart_bazel"),
        ),
        "protobuf_runtime": attr.label(
            doc = "The Dart protobuf runtime library from the consumer's pub dependencies.",
            mandatory = True,
            providers = [DartInfo],
        ),
        "grpc_runtime": attr.label(
            doc = "The Dart gRPC runtime library from the consumer's pub dependencies. Required when any dart_proto_library uses grpc = True.",
            providers = [DartInfo],
        ),
    },
)
