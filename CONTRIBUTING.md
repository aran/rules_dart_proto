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
bazel run @multitool//tools/prek -- -C "$PWD" run --all-files
```

## Commit messages

Commit messages follow the policy in [AGENTS.md](AGENTS.md): a
conventional-commit subject and, for user-visible changes, a `Changelog:`
trailer. The commit-msg hook that `prek install` sets up checks each commit;
run the check on a range with `bazel run //tools/changelog:check -- --range A..B`.

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

Releases are automated on a cron trigger.
The new version is determined automatically from the commit history, assuming the commit messages follow conventions, using
https://github.com/marketplace/actions/conventional-commits-versioner-action.
If you do nothing, eventually the newest commits will be released automatically as a patch or minor release.
This automation is defined in .github/workflows/tag.yaml.

Rather than wait for the cron event, you can trigger manually. Navigate to
https://github.com/aran/rules_dart_proto/actions/workflows/tag.yaml
and press the "Run workflow" button.

If you need control over the next release version, for example when making a release candidate for a new major,
then: tag the repo and push the tag, for example

```sh
% git fetch
% git tag v1.0.0-rc0 origin/main
% git push origin v1.0.0-rc0
```

Then watch the automation run on GitHub actions which creates the release.
