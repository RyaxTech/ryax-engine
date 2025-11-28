#!/usr/bin/env bash

# Variables
#
# CI_COMMIT_TAG
# GITLAB_TOKEN
# RYAX_PROJECTS

# For each entry of RYAX_PROJECTS, add the version of the staging commit sha to
# the entry. Edits in place RYAX_PROJECTS.

RYAX_PROJECTS=${RYAX_PROJECTS-"./ryax_projects.json"}
CURL_HEADER="Authorization: Bearer $GITLAB_TOKEN"
API_PREFIX="https://gitlab.com/api/v4"
FROM_TAG="staging"

ryax_projects=($(jq -r '.[] | .name, .id' -- $RYAX_PROJECTS))
exit_code=0
while ! [ -z "$ryax_projects" ]; do
  service_name="${ryax_projects[0]}"
  project_id="${ryax_projects[1]}"

  commit_sha=$(curl -s --header "$CURL_HEADER" "$API_PREFIX/projects/$project_id/repository/tags/$FROM_TAG" | jq .commit.short_id | tr -d \")
  if [ $commit_sha == "null" ]; then
    echo "Could not find a staging tag for $service_name"
    exit_code=1
  else
    echo $service_name staging commit is $commit_sha
    cat $RYAX_PROJECTS | jq -r ".[] | if .name == \"$service_name\" then . + {staging_commit_sha: \"$commit_sha\"} else . end" | jq -n ". |= [inputs]" | sponge $RYAX_PROJECTS
  fi

  ryax_projects=(${ryax_projects[@]:2})
done

exit $exit_code
