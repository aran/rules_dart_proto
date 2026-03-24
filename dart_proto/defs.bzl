"""Public API for rules_dart_proto."""

load("//dart_proto/private:dart_proto_library.bzl", _DartProtoInfo = "DartProtoInfo", _dart_proto_library = "dart_proto_library")
load("//dart_proto/private:toolchain.bzl", _DartProtoToolchainInfo = "DartProtoToolchainInfo", _dart_proto_toolchain = "dart_proto_toolchain")

dart_proto_library = _dart_proto_library
dart_proto_toolchain = _dart_proto_toolchain
DartProtoInfo = _DartProtoInfo
DartProtoToolchainInfo = _DartProtoToolchainInfo
