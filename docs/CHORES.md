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

**Trigger**: New tag on https://github.com/aran/rules_dart.

**Files**:

- `MODULE.bazel` — `git_override` tag for `rules_dart`
- `e2e/simple_proto/MODULE.bazel` — `git_override` tag
- `e2e/grpc_proto/MODULE.bazel` — `git_override` tag
- `e2e/diamond_proto/MODULE.bazel` — `git_override` tag
- `e2e/deep_import_proto/MODULE.bazel` — `git_override` tag
- `e2e/analysis_pkg/MODULE.bazel` — `git_override` tag

**Procedure**:

1. Update the `tag` in all `git_override` blocks
2. Check if the new tag supports newer Dart SDK versions (bump if so)
3. Regenerate lock files
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

**Workspaces** (directories containing `MODULE.bazel`):

- `.` (root)
- `e2e/simple_proto`
- `e2e/grpc_proto`
- `e2e/diamond_proto`
- `e2e/deep_import_proto`
- `e2e/analysis_pkg`

**Procedure**:

1. Run `dart pub get` in `dart_proto/` and each e2e workspace to refresh
   `pubspec.lock` files
2. Run `bazel mod deps --lockfile_mode=update` in the root workspace
3. Run `bazel mod deps --lockfile_mode=update` in each e2e workspace

**Verification**: All workspaces report success; lock files are committed.

---

## Multitool Version Bumps

**Trigger**: Periodic (monthly) or when a managed tool releases a needed version.

**Files**:

- `multitool.lock.json` — tool versions, URLs, and SHA-256 hashes
- `.pre-commit-config.yaml` — matching `rev:` values for yamlfmt and typos

**Managed tools**: `yamlfmt`, `typos`

**Procedure**:

1. For each tool in `multitool.lock.json`, check GitHub releases for newer versions
2. Download archives for all platform variants (macOS/Linux, arm64/x86_64)
3. Compute SHA-256 hashes and update the lockfile entries
4. Update matching `rev:` in `.pre-commit-config.yaml`
5. Regenerate Bazel lock files
6. Run `bazel run @multitool//tools/yamlfmt -- -lint .` and
   `bazel run @multitool//tools/typos -- .` to verify

**Verification**: Both tools run successfully against the repo.

---

## Pre-commit Hook Bumps

**Trigger**: New versions of pre-commit hooks.

**Files**:

- `.pre-commit-config.yaml`

**Hooks and current versions**:

- `pre-commit/pre-commit-hooks` — general file checks
- `keith/pre-commit-buildifier` — buildifier formatting/linting
- `commitizen-tools/commitizen` — conventional commit enforcement
- `pre-commit/mirrors-prettier` — prettier formatting
- `google/yamlfmt` — YAML formatting (keep in sync with `multitool.lock.json`)
- `crate-ci/typos` — spell checking (keep in sync with `multitool.lock.json`)

**Procedure**: Mostly handled by Renovate (`:enablePreCommit` preset). For
yamlfmt and typos, ensure versions match `multitool.lock.json`.

**Verification**: `pre-commit run --all-files` passes.

---

## GitHub Workflow Dependency Bumps

**Trigger**: Periodic or when a dependency releases a needed version.

**Files**: `.github/workflows/*.yaml`

**Dependencies** (all `uses:` references):

- `actions/checkout`
- `amannn/action-semantic-pull-request`
- `smlx/ccv`
- `pre-commit/action`
- `technote-space/workflow-conclusion-action`
- `bazel-contrib/.github` (reusable CI + release workflows)
- `bazel-contrib/publish-to-bcr`

**Procedure**:

1. For each `uses:` reference, check the repo for newer versions
2. Update version refs
3. Review changelogs for breaking changes in reusable workflows

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
