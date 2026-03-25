# rules_dart_proto

Bazel rules for generating Dart code from Protocol Buffer definitions.

Bridges [`rules_dart`](https://github.com/aran/rules_dart), [`rules_proto`](https://github.com/bazelbuild/rules_proto), and the Dart [`protoc_plugin`](https://pub.dev/packages/protoc_plugin) package.

Requires Bazel 9+.

## Setup

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_dart", version = "...")
bazel_dep(name = "rules_dart_proto", version = "...")
bazel_dep(name = "rules_proto", version = "7.1.0")
bazel_dep(name = "protobuf", version = "34.0.bcr.1")

dart = use_extension("@rules_dart//dart:extensions.bzl", "dart")
dart.toolchain(dart_version = "3.11.1")
use_repo(dart, "dart_toolchains")
register_toolchains("@dart_toolchains//:all")

# Dart pub dependencies — must include protobuf (and grpc if using grpc = True)
pub = use_extension("@rules_dart//dart/pub:extensions.bzl", "pub")
pub.from_lock(
    name = "pub_deps",
    lock = "//:pubspec.lock",
)
use_repo(pub, "pub_deps")

register_toolchains("//:dart_proto_toolchain")
```

### Toolchain registration

`dart_proto_library` requires a registered `dart_proto_toolchain` that provides the
Dart `protobuf` (and optionally `grpc`) runtime libraries from your own pub
dependencies. This avoids type-identity conflicts when your application code and
generated proto code both use these packages.

Add to your root `BUILD.bazel`:

```starlark
load("@rules_dart_proto//dart_proto:defs.bzl", "dart_proto_toolchain")

dart_proto_toolchain(
    name = "dart_proto_toolchain_impl",
    protobuf_runtime = "@pub_deps//:protobuf",
    # grpc_runtime = "@pub_deps//:grpc",  # uncomment if using grpc = True
)

toolchain(
    name = "dart_proto_toolchain",
    toolchain = ":dart_proto_toolchain_impl",
    toolchain_type = "@rules_dart_proto//dart_proto:toolchain_type",
)
```

The build tools (`protoc` and `protoc-gen-dart`) are provided by default. Only the
runtime libraries need to come from your dependency graph.

## Usage

```starlark
load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_dart_proto//dart_proto:defs.bzl", "dart_proto_library")
load("@rules_dart//dart:defs.bzl", "dart_binary")

proto_library(
    name = "person_proto",
    srcs = ["person.proto"],
)

dart_proto_library(
    name = "person_dart_proto",
    deps = [":person_proto"],
)

dart_binary(
    name = "app",
    main = "main.dart",
    deps = [":person_dart_proto"],
)
```

Generated code is imported via `package:<dart_proto_library name>/<proto_name>.pb.dart`:

```dart
import 'package:person_dart_proto/person.pb.dart';
```

### Interdependent protos

Each `proto_library` needs its own `dart_proto_library`. Use `dart_deps` to wire the Dart-level dependencies between them:

```starlark
proto_library(
    name = "address_proto",
    srcs = ["address.proto"],
)

dart_proto_library(
    name = "address_dart_proto",
    deps = [":address_proto"],
)

proto_library(
    name = "person_proto",
    srcs = ["person.proto"],
    deps = [":address_proto"],
)

dart_proto_library(
    name = "person_dart_proto",
    deps = [":person_proto"],
    dart_deps = [":address_dart_proto"],
)
```

### gRPC

Set `grpc = True` to also generate `.pbgrpc.dart` files. The toolchain must provide `grpc_runtime` when any target uses `grpc = True`:

```starlark
dart_proto_library(
    name = "greeter_dart_proto",
    deps = [":greeter_proto"],
    grpc = True,
)
```

### Custom package name (dual build)

By default, the Dart package name matches the rule name. Use `package_name` to override it — useful when you also generate proto code with `build_runner` and need both build systems to use the same package name:

```starlark
dart_proto_library(
    name = "person_protos_gen",
    package_name = "my_app",
    deps = [":person_proto"],
)
```

Generated code is then imported as `package:my_app/person.pb.dart` instead of `package:person_protos_gen/person.pb.dart`.

### IDE analysis support

By default, generated proto code lives only in Bazel's output tree, so the Dart
analysis server (and your IDE) cannot see it. The `dart_proto_analysis_package`
macro copies generated files to the source tree and creates a `pubspec.yaml`,
making them visible to the analysis server.

Add `aspect_bazel_lib` to your `MODULE.bazel`:

```starlark
bazel_dep(name = "aspect_bazel_lib", version = "2.22.5")
```

Then create one analysis package per `dart_proto_library` target:

```starlark
load("@rules_dart_proto//dart_proto:analysis.bzl", "dart_proto_analysis_package")

dart_proto_analysis_package(
    name = "write_echo_analysis_pkg",
    dart_proto = "//echo:echo_dart_proto",
    path = "echo_analysis",
)
```

Sync the files:

```sh
bazel run //:write_echo_analysis_pkg
```

Then add the generated package as a path dependency in your `pubspec.yaml`:

```yaml
dependency_overrides:
  echo_dart_proto:
    path: echo_analysis
```

Run `dart pub get` and the analysis server will pick up the proto types.

**CI staleness check:** A `write_echo_analysis_pkg_tests` target is
auto-generated. Add it to your test suite to catch stale analysis packages.

**Gazelle:** If you use the `rules_dart` Gazelle plugin, add
`# gazelle:exclude <path>` directives to prevent it from processing the
generated Dart files:

```starlark
# gazelle:exclude echo_analysis
```

**gRPC:** Pass `grpc = True` when the `dart_proto_library` uses gRPC, so the
generated `pubspec.yaml` includes the `grpc` dependency:

```starlark
dart_proto_analysis_package(
    name = "write_greeter_analysis_pkg",
    dart_proto = "//greeter:greeter_dart_proto",
    path = "greeter_analysis",
    grpc = True,
)
```

## How it works

1. `proto_library` defines your `.proto` sources (from `rules_proto`)
2. `dart_proto_library` runs `protoc` with the `protoc-gen-dart` plugin to generate `.pb.dart`, `.pbenum.dart`, `.pbjson.dart` (and optionally `.pbgrpc.dart`) files
3. The generated code is returned as `DartInfo`, so it composes seamlessly with `dart_binary`, `dart_library`, and `dart_test`

The `protoc-gen-dart` plugin is compiled from source using `rules_dart`, so no system Dart or PATH configuration is needed. The `protobuf` and `grpc` runtime libraries are provided by the consumer via `dart_proto_toolchain` to ensure type identity with the rest of the application.

See `e2e/simple_proto/`, `e2e/grpc_proto/`, `e2e/diamond_proto/`, `e2e/deep_import_proto/`, and `e2e/analysis_pkg/` for complete working examples.
