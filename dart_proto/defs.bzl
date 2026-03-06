"""Public API for rules_dart_proto."""

load("//dart_proto/private:dart_proto_library.bzl", _DartProtoInfo = "DartProtoInfo", _dart_proto_library = "dart_proto_library")

dart_proto_library = _dart_proto_library
DartProtoInfo = _DartProtoInfo
