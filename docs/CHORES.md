# Maintenance Chores

Central reference for all recurring maintenance tasks.

---

## Dart SDK Version Bump

**Trigger**: New stable Dart SDK release, constrained by rules_dart support.

**Files**:

- `MODULE.bazel` — `dart.toolchain(dart_version = "...")`
- `e2e/simple_proto/MODULE.bazel` — `dart.toolchain(dart_version = "...")`
- `e2e/grpc_proto/MODULE.bazel` — `dart.toolchain(dart_version = "...")`
- `e2e/diamond_proto/MODULE.bazel` — `dart.toolchain(dart_version = "...")`
- `e2e/deep_import_proto/MODULE.bazel` — `dart.toolchain(dart_version = "...")`
- `e2e/analysis_pkg/MODULE.bazel` — `dart.toolchain(dart_version = "...")`
- `README.md` — `dart.toolchain(dart_version = "...")` in installation snippet
- `dart_proto/pubspec.yaml` — `environment.sdk` constraint (if minimum changes)

**Procedure**:

1. Check which Dart versions the current `rules_dart` tag supports
2. Update `dart_version` in all MODULE.bazel files listed above
3. Update the version in `README.md` example
4. Regenerate lock files (see Lock File Refresh)
5. Run `bazel build //...` in root and at least one e2e workspace

**Verification**: Root and e2e workspaces build successfully.

---

## rules_dart Version Bump

**Trigger**: New rules_dart release on the BCR.

**Files**:

- `MODULE.bazel` and every `e2e/*/MODULE.bazel` — `bazel_dep(name = "rules_dart", version = "...")`

**Procedure**:

1. Update the `rules_dart` version in every MODULE.bazel file
2. Check if the new release supports newer Dart SDK versions (bump if so)
3. Regenerate lock files (see Lock File Refresh)
4. Build and test

**Verification**: All workspaces build successfully.

---

## Bazel Module Dependency Bumps

**Trigger**: Periodic (monthly) or when a dep releases a needed version.

**Files**:

- `MODULE.bazel` — `bazel_dep()` version strings
- E2e workspaces that duplicate deps:
  - `e2e/simple_proto/MODULE.bazel` — `rules_proto`, `protobuf`
  - `e2e/grpc_proto/MODULE.bazel` — `rules_proto`, `protobuf`
  - `e2e/diamond_proto/MODULE.bazel` — `rules_proto`, `protobuf`
  - `e2e/deep_import_proto/MODULE.bazel` — `rules_proto`, `protobuf`
  - `e2e/analysis_pkg/MODULE.bazel` — `rules_proto`, `protobuf`, `aspect_bazel_lib`, `gazelle`, `rules_go`
- `README.md` — version strings in example snippets

**Procedure**:

1. For each `bazel_dep` in root `MODULE.bazel`, check latest on BCR
2. Update versions in root and mirror to e2e workspaces
3. Update `README.md` example snippets
4. Regenerate lock files
5. Build and test

**Verification**: Root and all e2e workspaces build.

---

## Bazel Version Bump

**Trigger**: New Bazel release (typically patch within 9.x).

**Files**:

- `.bazelversion`
- `e2e/simple_proto/.bazelversion`
- `e2e/grpc_proto/.bazelversion`
- `e2e/diamond_proto/.bazelversion`
- `e2e/deep_import_proto/.bazelversion`
- `e2e/analysis_pkg/.bazelversion`
- `e2e/import_roots/.bazelversion`
- `.github/workflows/ci.yaml` — `bazel_versions`; must match `.bazelversion`,
  because the root lockfile records Bazel's built-in module versions
- `.bcr/presubmit.yml` — `bazel:` matrix value (if major version changes)
- `README.md` — "Requires Bazel 9+" (if major version changes)

**Procedure**:

1. Update all `.bazelversion` files to the new version
2. Regenerate lock files
3. Build and test

**Verification**: All workspaces build.

---

## Pub Package Version Bumps

**Trigger**: New versions of protoc_plugin, protobuf, grpc on pub.dev.

**Files**:

- `dart_proto/pubspec.yaml` — `protoc_plugin` version constraint
- `dart_proto/pubspec.lock` — regenerated
- `e2e/simple_proto/pubspec.yaml` — `protobuf` version
- `e2e/grpc_proto/pubspec.yaml` — `protobuf`, `grpc` versions
- `e2e/diamond_proto/pubspec.yaml` — `protobuf` version
- `e2e/deep_import_proto/pubspec.yaml` — `protobuf` version
- `e2e/analysis_pkg/pubspec.yaml` — `protobuf` version
- All corresponding `pubspec.lock` files

**Procedure**:

1. Check pub.dev for latest versions of `protoc_plugin`, `protobuf`, `grpc`
2. Update version constraints in `pubspec.yaml` files
3. Run `dart pub get` in each directory to regenerate lock files
4. Regenerate Bazel lock files
5. Build and test

**Verification**: All workspaces build; generated proto code compiles.

---

## Lock File Refresh

**Trigger**: After any change to `MODULE.bazel` files or pubspec files.

**Procedure**:

1. Run `dart pub get` in `dart_proto/` and each e2e workspace to refresh
   `pubspec.lock` files
2. Run `bazel run --lockfile_mode=off @overhead//locks:refresh` for every
   workspace (directories holding a `MODULE.bazel`), or name some:
   `bazel run --lockfile_mode=off @overhead//locks:refresh -- e2e/simple_proto`. It leaves out
   `.bazelrc.user`, whose overrides would otherwise end up in the lock.

**Verification**: `bazel run @overhead//locks:check` reports every workspace
current; lock files are committed.

---

## Dev Tool Version Bumps

git-cliff, prek, typos and yamlfmt are pinned in overhead
(`overhead/multitool.lock.json` in rules_dart), which this repository takes as
a dev dependency; bump them there. Here, bump the overhead `git_override`
commit in `MODULE.bazel` and the matching `aran/rules_dart/...@<sha>` refs in
`.github/workflows/` together, then run `bazel run @overhead//pins:check`.

---

## Git Hook Bumps

**Trigger**: New versions of the git hooks.

**Files**:

- `.pre-commit-config.yaml`

**Hooks and current versions**:

- `pre-commit/pre-commit-hooks` — general file checks
- `keith/pre-commit-buildifier` — buildifier formatting/linting
- `pre-commit/mirrors-prettier` — prettier formatting

**Procedure**: Renovate (`:enablePreCommit` preset) bumps the hook `rev:`
values in `.pre-commit-config.yaml`. The commit-message, yamlfmt and typos
hooks run through overhead at the versions it pins (see Dev Tool Version
Bumps).

**Verification**: `bazel run @overhead//lint:prek -- run --all-files` passes.

---

## GitHub Workflow Dependency Bumps

**Trigger**: Periodic or when a dependency releases a needed version.

**Files**: `.github/workflows/*.yaml`

**Dependencies** (all `uses:` references outside `./.github/workflows/`):

- `actions/checkout`
- `bazel-contrib/setup-bazel`
- `technote-space/workflow-conclusion-action`
- `bazel-contrib/.github` (reusable CI workflow)
- overhead's reusable workflows in `aran/rules_dart` (bumped with the
  overhead pin, under Dev Tool Version Bumps)

Every reference is pinned to a full commit SHA, with the version in a
trailing comment: `uses: owner/repo@<40-hex sha> # v1.2.3`. A tag can be
moved to other code; a SHA cannot.

**Procedure**:

1. For each `uses:` reference, check the repo for newer versions
2. Resolve the new tag to its commit:
   `git ls-remote --tags https://github.com/<owner>/<repo>`. For an
   annotated tag, take the `^{}` line, which is the commit
3. Update the SHA and its version comment together
4. Review changelogs for breaking changes in reusable workflows

**Verification**: CI workflow runs successfully.

---

## BCR Presubmit Config

**Trigger**: When adding/removing e2e workspaces or changing Bazel version requirements.

**Files**:

- `.bcr/presubmit.yml` — module_path, platform matrix, bazel matrix

**Procedure**: Update the YAML to match current e2e workspaces and Bazel version.

**Verification**: BCR presubmit passes after publishing.

---

## CI Folder List Sync

**Trigger**: When adding or removing an e2e workspace.

**Files**:

- `.github/workflows/ci.yaml` — `folders` array in the test job

**Procedure**:

1. Compare `e2e/*/MODULE.bazel` against the `folders` array in `ci.yaml`
2. Add/remove entries to match

**Verification**: CI runs all e2e workspaces.

---

## Documentation Accuracy

**Trigger**: After any structural change (new rules, new e2e workspaces, version bumps).

**Files**:

- `README.md` — example snippets, version references, e2e list
- `CONTRIBUTING.md` — development instructions

**Version references in README.md**:

- `rules_proto` version in example
- `protobuf` version in example
- `dart_version` in example
- `aspect_bazel_lib` version in example
- Bazel version requirement

**Procedure**: Review hardcoded versions and tables against actual state.

**Verification**: Visual inspection.
