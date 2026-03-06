"""Module extension for rules_dart_proto.

This extension is currently a no-op placeholder. All pub.dev dependencies
(protoc_plugin, protobuf runtime, and their transitive deps) are fetched
internally by rules_dart_proto via pub.from_lock() in MODULE.bazel.

Users do NOT need to call this extension. It exists for future extensibility
(e.g., allowing users to override protoc_plugin or protobuf versions).
"""

def _dart_proto_impl(_ctx):
    pass

dart_proto = module_extension(
    implementation = _dart_proto_impl,
    tag_classes = {},
    doc = "Module extension for rules_dart_proto (currently a no-op placeholder).",
)
