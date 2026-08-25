#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<syncstorage-rs-docker version>-<release>`, which is what this
# repository has always published (v0.18.3-0 ... v0.21.0-8):
#
# - if defaults/main.yml points at a version that has never been released, the
#   release counter restarts at 0 (`v0.22.0-0`)
# - otherwise the counter is incremented (`v0.21.0-9`), but only if something
#   that actually affects the role has changed since the last release
#
# Determining the version from defaults/main.yml, rather than from the commit
# message of the pull request that got merged, makes the result independent of
# the order in which pull requests get merged, and lets any change to the role
# (bugfix, feature, dependency bump) release itself without a human tagging.
#
# The commit-message approach this replaced could only ever fire on a commit
# authored by `renovate[bot]` whose subject contained "docker tag to ". No such
# commit has ever landed here - the version is bumped by hand - so every one of
# this repository's tags was in fact cut by hand, and any hand-merged fix went
# out unreleased until somebody remembered.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit
# touching only other paths (a README fix, CI configuration) does not change
# what a playbook run does, and releasing it would only create churn in the
# repositories that consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
)

# Anchored on `syncstorage_rs_docker_version:` so that
# `syncstorage_rs_docker_container_image_self_build_repo_version`, which is
# derived from it through Jinja, cannot be mistaken for it. That variable holds
# the literal string `{{ syncstorage_rs_docker_version }}`, which would produce
# a `v{{-0` tag if it were ever read instead.
version="$(sed -nE 's|^syncstorage_rs_docker_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1|p' "$defaults_path" | head -n1)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the syncstorage-rs-docker version from $defaults_path"
	exit 1
fi

# The version is carried without a leading `v` (the tags of the syncstorage-rs-docker
# repository which the role builds from carry none either), but tolerate one so
# that a future change of convention does not produce a doubled prefix.
tag_prefix="v${version#v}-"

# Of all releases of this version, the highest release number. Sorted
# numerically, so that -10 is recognized as newer than -9.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version $version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
