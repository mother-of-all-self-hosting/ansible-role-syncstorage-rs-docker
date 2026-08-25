#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# The version block of defaults/main.yml, carrying the traps the real file has:
# a commented-out example of the version variable, and two image variables
# derived from it through Jinja. `syncstorage_rs_docker_container_image_self_build_repo_version`
# is the dangerous one - it holds the literal string `{{ syncstorage_rs_docker_version }}`,
# and reading it instead of the leaf would produce a `v{{-0` tag.
#
# The first argument decides whether the derived variables come before or after
# the leaf, because a `sed ... | head -n1` that was anchored less strictly would
# only misbehave in one of the two orders.
write_defaults() {
	local version="$1" order="${2:-leaf-first}"

	{
		printf '# syncstorage_rs_docker_version: 9.9.9\n'

		if [ "$order" = 'derived-first' ]; then
			printf '%s\n' \
				'syncstorage_rs_docker_container_image_self_build_repo_version: "{{ syncstorage_rs_docker_version }}"' \
				'syncstorage_rs_docker_container_image_self_build_name: "shirahara/syncstorage-rs-docker:{{ syncstorage_rs_docker_container_image_self_build_repo_version }}"'
		fi

		printf '# renovate: datasource=git-tags depName=https://iris.radicle.network/z4J84n7U8ea9A91oD1WjAVY6ybU7g.git\n'
		printf 'syncstorage_rs_docker_version: %s\n' "$version"

		if [ "$order" != 'derived-first' ]; then
			printf '%s\n' \
				'syncstorage_rs_docker_container_image_self_build_repo_version: "{{ syncstorage_rs_docker_version }}"' \
				'syncstorage_rs_docker_container_image_self_build_name: "shirahara/syncstorage-rs-docker:{{ syncstorage_rs_docker_container_image_self_build_repo_version }}"'
		fi
	} > defaults/main.yml
}

# Starts a scenario with a repository at syncstorage-rs-docker 0.21.0 which has
# already seen nine releases of it (v0.21.0-0 ... v0.21.0-8), preceded by the
# five releases of 0.18.3 this repository really carries. Releases of the older
# version must not be counted as releases of the current one.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	write_defaults 0.21.0 "${2:-leaf-first}"
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v0.18.3-0 v0.18.3-1 v0.18.3-2 v0.18.3-3 v0.18.3-4 \
		v0.21.0-0 v0.21.0-1 v0.21.0-2 v0.21.0-3 v0.21.0-4 \
		v0.21.0-5 v0.21.0-6 v0.21.0-7 v0.21.0-8; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version='write_defaults 0.22.0'
revert_version='write_defaults 0.21.0'
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_meta="printf 'a line\n' >> meta/main.yml"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v0.22.0-0 "$(merge "$bump_version")"
expect 'task edit'    v0.22.0-1 "$(merge "$edit_task")"
expect 'template'     v0.22.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v0.21.0-9 "$(merge "$edit_task")"
expect 'version bump' v0.22.0-0 "$(merge "$bump_version")"

# The releases of 0.18.3 must not be mistaken for releases of 0.21.0, and the
# Jinja-derived image variables must not be mistaken for the version.
scenario 'The releases of the previous version'
expect 'a task' v0.21.0-9 "$(merge "$edit_task")"

scenario 'The Jinja-derived image variables listed before the version' derived-first
expect 'a task' v0.21.0-9 "$(merge "$edit_task")"

scenario 'Commits that do not affect the role'
expect 'README'   ''         "$(merge "$edit_readme")"
expect 'a script' ''         "$(merge "$edit_script")"
expect 'meta'     v0.21.0-9  "$(merge "$edit_meta")"

scenario 'Release numbers past 9'
for release_number in 9 10; do
	git tag "v0.21.0-$release_number"
done
expect 'a task' v0.21.0-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v0.21.0-8 already published, so there is
# nothing new to release.
expect 'a revert' ''         "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v0.21.0-9 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
