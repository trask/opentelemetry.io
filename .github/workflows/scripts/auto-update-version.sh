#!/bin/bash -e
#
# Use `--dry-run` to perform a dry run of `gh` and `git` commands that might change your environment.
# Set env var `latest_version`` to force a specific version (or for testing purposes).
#
# This uses a lot of the code from:
# https://github.com/grafana/opentelemetry-collector-components/blob/main/scripts/update-to-latest-otelcol.sh

repo=$1
file_name=$2
variable_name=$3

GH=gh
GIT=git

if [[ "$4" == "--dry-run" ]]; then
  echo Doing a dry run.
  GH="echo > DRY RUN: gh "
  GIT="echo > DRY RUN: git "
fi

# Get the latest tag, without the "v" prefix
latest_version=$(gh api -q .tag_name "repos/open-telemetry/$repo/releases/latest" | sed 's/^v//')

echo "Repo: $repo"
echo "Latest version: $latest_version"

sed -i -e "s/$variable_name: .*/$variable_name: $latest_version/" "$file_name"

if git diff --quiet "$file_name"; then
    echo "We are already at the latest version."
    exit 0
else
  echo "Version update necessary:"
  git diff "$file_name"
  echo
fi

message="Update $repo version to $latest_version"
body="Update $repo version to \`$latest_version\`."

existing_pr_count=$(gh pr list --state all --search "in:title $message" | wc -l)
if [ "$existing_pr_count" -gt 0 ]; then
    echo "PR for this version was already created, exiting."
    exit 0
fi

branch="opentelemetrybot/auto-update-$repo-$latest_version"

$GIT checkout -b "$branch"
$GIT add "$file_name"
$GIT commit -m "$message"
$GIT push --set-upstream origin "$branch"

echo "Creating a pull request on your behalf."
$GH pr create --label auto-update \
             --title "$message" \
             --body "$body"
