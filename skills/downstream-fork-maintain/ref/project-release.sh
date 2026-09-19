#!/usr/bin/env bash
set -euo pipefail

# Reference contract for a projected downstream release.
# Adapt SOURCE_SUBDIR and the output-only transformations for the target fork.

usage() {
	printf 'usage: SOURCE_SUBDIR=path %s SOURCE_ROOT OUTPUT_ROOT\n' "${0##*/}" >&2
	exit 2
}

die() {
	printf 'project-release: %s\n' "$*" >&2
	exit 1
}

[[ $# -eq 2 ]] || usage
: "${SOURCE_SUBDIR:?set SOURCE_SUBDIR to the upstream path to project}"
command -v realpath >/dev/null 2>&1 || die "realpath is required"

source_root=$(realpath -e -- "$1")
output_root=$(realpath -m -- "$2")
project_root="$source_root/$SOURCE_SUBDIR"

[[ -d "$project_root" ]] || die "source subtree does not exist: $SOURCE_SUBDIR"
[[ "$output_root" != "$source_root" ]] || die "output must differ from source"
case "$output_root/" in
	"$source_root/"*) die "output must not be inside source" ;;
esac
case "$source_root/" in
	"$output_root/"*) die "output must not contain source" ;;
esac
if [[ -e "$output_root" ]] && [[ -n $(find "$output_root" -mindepth 1 -maxdepth 1 -print -quit) ]]; then
	die "output directory must be empty"
fi

mkdir -p -- "$output_root"
cp -a -- "$project_root"/. "$output_root"/

# Project-specific layout changes belong below this line. Restrict destructive
# operations to OUTPUT_ROOT; never mutate SOURCE_ROOT. Examples:
# mv -- "$output_root/old" "$output_root/new"
# cp -a -- "$source_root/shared/license" "$output_root/LICENSE"
# rm -rf -- "$output_root/upstream-only"

[[ -n $(find "$output_root" -mindepth 1 -maxdepth 1 -print -quit) ]] || die "projection produced an empty tree"
