# rules_dart_proto

Bazel rules for generating Dart code from Protocol Buffer definitions.

Bridges [`rules_dart`](https://github.com/aran/rules_dart), [`rules_proto`](https://github.com/bazelbuild/rules_proto), and the Dart [`protoc_plugin`](https://pub.dev/packages/protoc_plugin) package.

Requires Bazel 9.0 or newer.

## Road to 1.0

This project is getting dangerously close to being good. It's still a beta, but
we're approaching parity with the native tools, getting good performance, and
successfully using it to build Flutter apps across several platforms. There have
been several PRs and forks. Of course, the process of using AI to build software
like this is more like sculpting than careful assembly. Here, the form is taking
shape. In the latest round of changes, we made as many breaking changes as we
could, in the hopes of reducing how many breaking changes will need to be made
going forward. I'm still not committed to avoiding breaking changes, but I think
it's fair to discuss what it'll take to ship a 1.0 where there will be an
expectation that APIs will remain stable for quite some time.

As context, there are varying degrees of success possible for this project, and
I don't know where it will land. One possibility is that it remains small, used
by myself and a couple of others for small-scale, largely non-professional
projects. In this world, I'll label it 1.0 as a retroactive, descriptive
process. That is, when a few months go by where development has been happening
but the APIs have remained stable, we'll assume that they can probably be kept
stable for some time going forward, and we'll label it 1.0. This is probably the
most likely outcome.

Somewhere else in the range of possibilities, this project could get picked up
for professional use by others. It could even attract attention, and we could
end up with actual collaboration with teams within Google and others in the
Flutter and Bazel ecosystem. In an optimistic case, two or three profitable
companies start using it in production, and Google is potentially even tacitly
supportive of it, or at least not hostile to it. In this scenario, the road to
1.0 will be a little more formal and aligned with the interests and
contributions of those companies. In that scenario, we'll probably see a formal,
published release cycle, likely tied closely to Dart, Flutter and Bazel release
cycles. 1.0 will be tagged with a consensus of the early production users.

Now, of course, everything can change quickly in this world. Google could change
the way it supports Flutter or Bazel. Dart 4 is on its way and may engender
changes to projects like these. Everyone's expectations should be set
accordingly. I welcome discussions of this direction by email or in
[GitHub issues](https://github.com/aran/rules_dart_proto/issues), and of course, if
you are using or considering using this project professionally, please contact
me so we can collaborate.

## Setup

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_dart", version = "...")
bazel_dep(name = "rules_dart_proto", version = "...")
bazel_dep(name = "rules_proto", version = "7.1.0")
bazel_dep(name = "protobuf", version = "36.2")

dart = use_extension("@rules_dart//dart:extensions.bzl", "dart")
dart.toolchain(dart_version = "3.13.7")
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

Create one analysis package per `dart_proto_library` target:

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

Then point pub at the generated package from your `pubspec.yaml`:

```yaml
dependency_overrides:
  echo_dart_proto:
    path: echo_analysis
```

Run `dart pub get` and the analysis server will pick up the proto types.

`dart pub get` records `echo_dart_proto` in `pubspec.lock` as a `path`
package, and `pub.from_lock` fails on a `path` package it is not told how to
build. Map it to the `dart_proto_library`, which must be
`//visibility:public`:

```starlark
pub.from_lock(
    name = "pub_deps",
    lock = "//:pubspec.lock",
    resolve = {"echo_dart_proto": "//echo:echo_dart_proto"},
)
```

`@pub_deps//:echo_dart_proto` is then that target, so Gazelle can resolve
`package:echo_dart_proto` imports without a `# gazelle:resolve` directive.

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
3. The generated code is returned as `DartInfo`, so it composes seamlessly with `dart_binary`, `dart_library`, and `dart_test`, along with an analyzer summary that `rules_dart`'s `dart_analyze` reads instead of re-analyzing the generated code

The `protoc-gen-dart` plugin is compiled from source using `rules_dart`, so no system Dart or PATH configuration is needed. The `protobuf` and `grpc` runtime libraries are provided by the consumer via `dart_proto_toolchain` to ensure type identity with the rest of the application.

Complete working examples:

- [`e2e/simple_proto/`](e2e/simple_proto/): interdependent protos and `package_name`
- [`e2e/grpc_proto/`](e2e/grpc_proto/): gRPC services
- [`e2e/diamond_proto/`](e2e/diamond_proto/): two protos sharing a dependency
- [`e2e/deep_import_proto/`](e2e/deep_import_proto/): protos in Bazel packages at different depths
- [`e2e/import_roots/`](e2e/import_roots/): protos under an import prefix or generated into an output directory
- [`e2e/analysis_pkg/`](e2e/analysis_pkg/): `dart_proto_analysis_package` with Gazelle

## Migrating from 0.8

This release needs the `rules_dart` release that follows 0.8.1. Most of the
work is `rules_dart`'s: follow its
[Migrating from 0.8](https://github.com/aran/rules_dart#migrating-from-08)
guide, which covers the Dart SDK version (3.13.2 or later) and the
`pub.from_lock` changes. For `rules_dart_proto` itself:

1. A `dart_proto_analysis_package` named in `pubspec.yaml` lands in
   `pubspec.lock` as a `path` package, which `pub.from_lock` now refuses until
   it is mapped:
   `resolve = {"<package>": "<dart_proto_library>"}`, as in
   [IDE analysis support](#ide-analysis-support).
2. `dart_analyze` reads the analyzer summary of each `dart_proto_library`
   dependency. If that hits an SDK summary bug,
   `--@rules_dart//dart:analysis_summaries=false` turns summaries off.
3. Rules that read the `DartInfo` of a `dart_proto_library` find its package in
   `DartInfo.packages` (one `DartPackageInfo`), not in `DartInfo.package_name`
   and `lib_root`; see the guide's steps for rule authors.
