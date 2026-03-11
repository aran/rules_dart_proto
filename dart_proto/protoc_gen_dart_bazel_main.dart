import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:protoc_plugin/bazel.dart';
import 'package:protoc_plugin/protoc.dart';
import 'package:protoc_plugin/src/output_config.dart';

// ---------------------------------------------------------------------------
// Workaround: PosixBazelOutputConfiguration
// ---------------------------------------------------------------------------
//
// Why this exists
// ---------------
// `BazelOutputConfiguration` (from package:protoc_plugin/bazel.dart) uses the
// *platform-dependent* `package:path` context (`p.normalize`, `p.join`,
// `Uri.file`) to manipulate paths that are, by contract, always POSIX-style
// (forward-slash separated). On Windows this converts `/` to `\`, which
// breaks:
//
//   1. Map key lookup — `BazelPackage` stores its `inputRoot` via
//      `p.normalize(inputRoot)`, producing backslash keys on Windows
//      (e.g. `lib\shared\types`), while `_findPackage()` walks the search
//      path using `lastIndexOf('/')` and therefore only ever produces
//      forward-slash lookup keys (e.g. `lib/shared/types`).  Key mismatch →
//      lookup returns null → plugin crashes with status 255.
//
//   2. Output path construction — `p.join` and `Uri.file` in
//      `outputPathFor()` inject backslash separators on Windows, producing
//      URIs that protoc cannot consume.
//
// The bug only manifests when a Bazel package's `inputRoot` contains multiple
// path components (e.g. `lib/shared/types`).  Single-component roots like
// `common` survive because `p.normalize("common")` is the same on all
// platforms.
//
// What this does
// --------------
// `PosixBazelOutputConfiguration` subclasses `DefaultOutputConfiguration`
// (the same base class `BazelOutputConfiguration` extends) and re-implements
// the three methods — `outputPathFor`, `resolveImport`, and the private
// helper `_findPackage` — using `p.posix.*` so that path separators remain
// forward-slash on every platform.
//
// We still delegate option *parsing* to the upstream `BazelOptionParser` and
// `BazelPackage` classes (the parsing logic itself is correct; only the
// `p.normalize` in `BazelPackage`'s constructor is problematic, and we
// compensate for that with `_posix()` at every read-site).
//
// Upstream tracking
// -----------------
// TODO(aran): file issue / PR against https://github.com/google/protobuf.dart
// to replace `p.*` with `p.posix.*` in `lib/bazel.dart`.  Once fixed
// upstream and the fixed version is published, this workaround can be removed
// and `main()` can revert to using `BazelOutputConfiguration(packages)`
// directly.
// ---------------------------------------------------------------------------

/// A cross-platform-safe replacement for `BazelOutputConfiguration`.
///
/// All path manipulation uses [p.posix] so that forward-slash separators are
/// preserved regardless of the host platform.
class PosixBazelOutputConfiguration extends DefaultOutputConfiguration {
  final Map<String, BazelPackage> packages;

  PosixBazelOutputConfiguration(this.packages);

  /// Normalise a path that may have been backslash-mangled by
  /// `BazelPackage`'s `p.normalize()` on Windows back to forward slashes.
  static String _posix(String path) => path.replaceAll(r'\', '/');

  // ---------------------------------------------------------------------------
  // _findPackage — duplicated from BazelOutputConfiguration._findPackage
  //
  // Source: package:protoc_plugin 25.0.0, lib/bazel.dart, lines 103-112
  // Reason: the upstream method is private and cannot be called from a
  //         subclass.  Our copy is identical in logic but additionally handles
  //         the case where the `packages` map was keyed with backslashes (due
  //         to BazelPackage's p.normalize on Windows) by falling back to a
  //         backslash-form lookup.
  // ---------------------------------------------------------------------------
  /// Search for the most specific Bazel package above [searchPath].
  BazelPackage? _findPackage(String searchPath) {
    var index = searchPath.lastIndexOf('/');
    while (index > 0) {
      searchPath = searchPath.substring(0, index);
      // Primary lookup: forward-slash key (correct on Linux/macOS, and on
      // Windows if the upstream bug is ever fixed).
      // Fallback lookup: backslash key, matching what BazelPackage stores
      // on Windows today.
      final pkg =
          packages[searchPath] ?? packages[searchPath.replaceAll('/', r'\')];
      if (pkg != null) return pkg;
      index = searchPath.lastIndexOf('/');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // outputPathFor — replaces BazelOutputConfiguration.outputPathFor
  //
  // Source: package:protoc_plugin 25.0.0, lib/bazel.dart, lines 114-126
  // Changes from upstream:
  //   - `p.withoutExtension` → `p.posix.withoutExtension`
  //   - `p.join`             → `p.posix.join`
  //   - `Uri.file`           → `p.posix.toUri`
  //   - reads of `pkg.inputRoot` / `pkg.outputRoot` wrapped in `_posix()`
  // ---------------------------------------------------------------------------
  @override
  Uri outputPathFor(Uri inputPath, String extension) {
    final pkg = _findPackage(inputPath.path);
    if (pkg == null) {
      throw ArgumentError('Unable to locate package for input $inputPath.');
    }
    final inputRoot = _posix(pkg.inputRoot);
    final outputRoot = _posix(pkg.outputRoot);
    final relativeInput = inputPath.path.substring('$inputRoot/'.length);
    final base = p.posix.withoutExtension(relativeInput);
    final outputPath = p.posix.join(outputRoot, '$base$extension');
    return p.posix.toUri(outputPath);
  }

  // ---------------------------------------------------------------------------
  // resolveImport — replaces BazelOutputConfiguration.resolveImport
  //
  // Source: package:protoc_plugin 25.0.0, lib/bazel.dart, lines 128-146
  // Changes from upstream:
  //   - `p.withoutExtension` → `p.posix.withoutExtension`
  //   - uses our `_findPackage` / `_packageUriFor` (which apply `_posix()`)
  // ---------------------------------------------------------------------------
  @override
  Uri resolveImport(Uri target, Uri source, String extension) {
    final targetBase = p.posix.withoutExtension(target.path);
    final targetPkgUri = _packageUriFor('$targetBase$extension');
    final sourcePkgUri = _packageUriFor(source.path);

    if (targetPkgUri == null && sourcePkgUri != null) {
      throw 'ERROR: cannot generate import for $target from $source.';
    }

    if (targetPkgUri != null &&
        sourcePkgUri?.packageName != targetPkgUri.packageName) {
      return targetPkgUri.uri;
    }

    return super.resolveImport(target, source, extension);
  }

  // ---------------------------------------------------------------------------
  // _packageUriFor — duplicated from BazelOutputConfiguration._packageUriFor
  //
  // Source: package:protoc_plugin 25.0.0, lib/bazel.dart, lines 148-153
  // Changes from upstream:
  //   - reads `pkg.inputRoot` via `_posix()` to undo backslash mangling
  // ---------------------------------------------------------------------------
  _PackageUri? _packageUriFor(String target) {
    final pkg = _findPackage(target);
    if (pkg == null) return null;
    final inputRoot = _posix(pkg.inputRoot);
    final relPath = target.substring(inputRoot.length + 1);
    return _PackageUri(pkg.name, relPath);
  }
}

// ---------------------------------------------------------------------------
// _PackageUri — duplicated from bazel.dart
//
// Source: package:protoc_plugin 25.0.0, lib/bazel.dart, lines 87-93
// Reason: the upstream class is library-private and cannot be imported.
//         Reproduced verbatim.
// ---------------------------------------------------------------------------
class _PackageUri {
  final String packageName;
  final String path;
  Uri get uri => Uri.parse('package:$packageName/$path');
  _PackageUri(this.packageName, this.path);
}

void main() {
  final packages = <String, BazelPackage>{};
  CodeGenerator(stdin, stdout).generate(
    optionParsers: {bazelOptionId: BazelOptionParser(packages)},
    config: PosixBazelOutputConfiguration(packages),
  );
}
