# Lockfile Reference

This page details the lockfile format and fields used in Ryax actions. For instructions on how to use lockfiles, see the [reproducible build guide](../tutorials/reproducible_action_build.md).

## Overview

The lockfile (`ryax_lock.json`) must be placed in the action's folder, alongside `ryax_metadata.yaml`. It records the exact environment used to build your action.

## Lockfile Structure

Here's an example lockfile with explanations of each field:

```json
{
  "actionNix": "59e618d90c065f55ae48446f307e8c09565d5ab0",
  "actionNixOriginal": "nixos-24.11",
  "nixpkgsPython": "7c550bca7e6cf95898e32eb2173efe7ebb447460",
  "python": {
    "lockedRequirements": "",
    "originalRequirements": "",
    "pythonVersion": "3.12.8",
    "pythonVersionOriginal": ""
  },
  "wrapperRevision": "971dbb1ad47925987f9b873be2740593560a5234"
}
```

## Field Descriptions

Most fields have an associated `*Original` version that records what was specified during the initial build. During rebuilds, these original values are compared with current specifications - any differences will cause the build to ignore the locked values.

### Core Fields

**actionNix**: Commit hash of the `nixpkgs` repository used during build
**actionNixOriginal**: User-specified `nixpkgs` version (from `spec.options.nixpkgs.version` in `ryax_metadata.yaml`)
**nixpkgsPython**: Revision of [nixpkgs-python](https://github.com/cachix/nixpkgs-python) used to find Python versions
**wrapperRevision**: Version of the build wrapper (used for debugging)

### Python Configuration

The python object contains:

**pythonVersion**: Locked Python version
**pythonVersionOriginal**: Python version from `spec.option.python.version`
**lockedRequirements**: Output of pip freeze showing all action dependencies
**originalRequirements**: Content of the action's `requirements.txt` file

