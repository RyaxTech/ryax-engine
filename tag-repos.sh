#!/usr/bin/env bash

#set -u
#set -e
#set -x

# Required variables are
#
# CI_COMMIT_TAG
# GITLAB_TOKEN
# RYAX_PROJECTS (loaded from ./ryax_projects.json if not defined)
CURL_HEADER="Authorization: Bearer $GITLAB_TOKEN"
RYAX_PROJECTS=${RYAX_PROJECTS-./ryax_projects.json}

say() {
  # $1 service name
  # $2 log
  #
  # This is here to keep things tidy and readable. Also curl doesn't seem to
  # print newlines which is why we echo its output.
  ! [ -z "$2" ] && echo "[$1] $2"
}

tag_repo () {
  service_name=$1
  project_id=$2
  commit_sha=$3

  # Delete the tag if it exists
  # say $service_name "Deleting tag $CI_COMMIT_TAG"
  # say \
  #   $service_name \
  #   "$(curl -s --request DELETE --header "$CURL_HEADER" "https://gitlab.com/api/v4/projects/$project_id/repository/tags/$CI_COMMIT_TAG" | jq .)"

  # Tag the given ref
  say $service_name "Tagging $commit_sha with $CI_COMMIT_TAG"
  say \
    $service_name \
    "$(curl -s --request POST --header "$CURL_HEADER" "https://gitlab.com/api/v4/projects/$project_id/repository/tags/?tag_name=$CI_COMMIT_TAG&ref=$commit_sha" | jq .)" || true

  # Wait for the pipeline to complete
  say $service_name "Waiting for pipeline to complete"
  sleep 5 # wait for pipeline to initialize
  pipeline_id=$(curl -s --header "Authorization: Bearer $GITLAB_TOKEN" "https://gitlab.com/api/v4/projects/$project_id/pipelines?ref=$CI_COMMIT_TAG&order_by=updated_at&sort=desc" | jq -r ".[0].id")
  [ -z "$pipeline_id" ] && say $service_name "Couldn't find a pipeline with ref $CI_COMMIT_TAG" && exit 1

  pipeline_status=""
  while ! [ "$pipeline_status" = "success" -o "$pipeline_status" = "failed" -o "$pipeline_status" = "canceled" -o "$pipeline_status" = "skipped" ]; do
    pipeline_status="$(curl -s --header "Authorization: Bearer $GITLAB_TOKEN" "https://gitlab.com/api/v4/projects/$project_id/pipelines/$pipeline_id" | jq -r ".status")"
    say $service_name "Status : $pipeline_status"
    sleep 3
  done

  # echo escapes special characters
  printf "\n###### Pipeline finished ######\n\tService: $service_name\n\tStatus: $pipeline_status\n"
  [ "$pipeline_status" != "success" ] && exit 1
  exit 0 # we have to explicitely exit on a success
}

# Build a string array from ryax_projects.yaml
ryax_projects=($(jq -r '.[] | .name, .id, .staging_commit_sha' -- $RYAX_PROJECTS))
# Run everything in parallel
while ! [ -z "$ryax_projects" ]; do
  service_name="${ryax_projects[0]}"
  project_id="${ryax_projects[1]}"
  commit_sha="${ryax_projects[2]}"

  tag_repo $service_name $project_id $commit_sha &

  ryax_projects=(${ryax_projects[@]:3})
done

# Wait for all the pipelines to end and exit 1 if at least one of them was
# not successful
success=true
for job in $(jobs -p); do
  wait $job || success=false
done
[ "$success" == "false" ] && echo "There were errors in some pipelines" && exit 1

echo "All pipelines have succesfully completed"
exit 0 # explicitely exit
