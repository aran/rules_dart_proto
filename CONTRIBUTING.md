# How to Contribute

## Using devcontainers

If you are using [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers)
and/or [codespaces](https://github.com/features/codespaces) then you can start
contributing immediately and skip the next step.

## Formatting

Starlark files must be formatted by buildifier, and YAML files by yamlfmt.
Git hooks check this, along with prettier, typos, file hygiene and the commit
message policy. They run with [prek](https://github.com/j178/prek), which reads
`.pre-commit-config.yaml`. Install prek with [uv](https://docs.astral.sh/uv/)
and set up the hooks once per clone:

```shell
uv tool install prek
prek install -f
```

`-f` replaces hooks already in the clone, such as ones pre-commit installed;
without it prek keeps them and runs them too. The installed hook calls the
prek at `~/.local/bin/prek`, which stays put across `uv tool upgrade prek` and
`bazel clean`. Set `PREK_QUIET=1` in your shell profile for hooks that print
nothing unless one fails.

To run every hook without installing anything beyond Bazel:

```shell
bazel run @overhead//lint:prek -- run --all-files
```

## Commit messages

Commit messages follow the policy in [AGENTS.md](AGENTS.md): a
conventional-commit subject and, for user-visible changes, a `Changelog:`
trailer. The commit-msg hook that `prek install` sets up checks each commit;
run the check on a range with `bazel run @overhead//changelog:check -- --range A..B`.

## Running tests

### End-to-end tests (separate Bazel workspaces)

Each directory under `e2e/` is a self-contained Bazel workspace that tests rules_dart_proto
as an external dependency.

```shell
# Basic proto codegen + dart_binary
cd e2e/simple_proto && bazel build //...

# gRPC proto codegen
cd e2e/grpc_proto && bazel build //...

# Diamond-shaped proto dependencies
cd e2e/diamond_proto && bazel build //...

# Deeply nested proto imports
cd e2e/deep_import_proto && bazel build //...

# IDE analysis package support
cd e2e/analysis_pkg && bazel test //...
```

## Using this as a development dependency of other rules

To always tell Bazel to use this local checkout rather than a release
artifact or a version fetched from the registry, run this from this
directory:

```sh
OVERRIDE="--override_module=rules_dart_proto=$(pwd)"
echo "common $OVERRIDE" >> ~/.bazelrc
```

This means that any usage of `@rules_dart_proto` on your system will point to this folder.

## Releasing

rules_dart_proto releases only after a rules_dart release, and at exactly
that version: rules_dart 0.9.0 is followed by rules_dart_proto 0.9.0, never by
a version number of its own. With no new rules_dart release, commits wait for
the next one.

A release bumps the rules_dart pin and the overhead pin to the released
rules_dart (see "rules_dart Version Bump" in [docs/CHORES.md](docs/CHORES.md)),
tests against the published module with any local overrides in
`.bazelrc.user` set aside, and pushes. Once CI is green on that commit, tag
it with the same version, signed and annotated:

```sh
git fetch
git tag -s -m "rules_dart_proto v0.9.0" v0.9.0 origin/main
git push origin v0.9.0
```

The tag push runs `.github/workflows/release.yaml`, which makes the GitHub
Release and opens the BCR pull request. It does not check CI itself, so tag
only a commit whose CI run is green.
