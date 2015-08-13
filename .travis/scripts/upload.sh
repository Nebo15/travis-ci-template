#!/bin/bash

echo -e "[I] Downloading IPA file to builds storage."
curl -u${API_USER}:${API_SECRET} \
     -F "name=${APPLICATION}" \
     -F "version=${BUILD_VERSION_SHORT}" \
     -F "build=${BUILD_VERSION}" \
     -F "slug=${TRAVIS_REPO_SLUG}" \
     -F "travis_build_id=${TRAVIS_BUILD_ID}" \
     -F "travis_build_number=${TRAVIS_BUILD_NUMBER}" \
     -F "travis_job_id=${TRAVIS_JOB_ID}" \
     -F "travis_job_number=${TRAVIS_JOB_NUMBER}" \
     -F "branch=${TRAVIS_BRANCH}" \
     -F "commit=${TRAVIS_COMMIT}" \
     -F "commit_range=${TRAVIS_COMMIT_RANGE}" \
     -F "bundle=${MAIN_BUNDLE_ID}" \
     -F "server_id=${MAIN_SERVER_ID}" \
     -F "build_file=@${IPA_PATH}" \
     -F "build_app_file=@${APP_ARCH_PATH}" \
     https://builds.nebo15.com/upload.json >> /dev/null
