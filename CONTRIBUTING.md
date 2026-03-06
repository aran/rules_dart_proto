# How to Contribute

## Using devcontainers

If you are using [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers)
and/or [codespaces](https://github.com/features/codespaces) then you can start
contributing immediately and skip the next step.

## Formatting

Starlark files must be formatted by buildifier, and YAML files by yamlfmt.
We suggest using a pre-commit hook to automate this. Two options:

### Option A — Git hook (no extra tools needed)

Copy the script below to `.git/hooks/pre-commit` and make it executable.
It runs buildifier, yamlfmt, and typos via `bazel run`, so no additional
installs are needed beyond Bazel.

```shell
#!/usr/bin/env bash
set -euo pipefail

echo "Running buildifier check..."
bazel run //.github/workflows:buildifier.check

echo "Running yamlfmt check..."
bazel run @multitool//tools/yamlfmt -- -lint \
  .github/workflows/*.yaml \
  .pre-commit-config.yaml \
  .bcr/presubmit.yml

echo "Running typos check..."
bazel run @multitool//tools/typos -- .
```

```shell
cp .git/hooks/pre-commit.sample .git/hooks/pre-commit
# paste the script above, then:
chmod +x .git/hooks/pre-commit
```

### Option B — pre-commit

[Install pre-commit](https://pre-commit.com/#installation), then run:

```shell
pre-commit install
```

This runs the full hook suite including prettier, commitizen, and file
hygiene checks.

## Running tests

### End-to-end tests (separate Bazel workspaces)

Each directory under `e2e/` is a self-contained Bazel workspace that tests rules_dart_proto
as an external dependency.

```shell
# Basic proto codegen + dart_binary
cd e2e/simple_proto && bazel build //...

# gRPC proto codegen
cd e2e/grpc_proto && bazel build //...
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
