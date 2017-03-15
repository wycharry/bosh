#!/usr/bin/env bash

set -eu

mv director-state/* .
mv director-state/.bosh $HOME/

export BOSH_ENVIRONMENT=`bosh-cli int director-state/director-creds.yml --path /external_ip`
export BOSH_CA_CERT=`bosh-cli int director-state/director-creds.yml --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh-cli int director-state/director-creds.yml --path /admin_password`

set +e

bosh-cli deployments | cut -f1 | grep '[^[:space:]]' | xargs -n1 bosh delete-deployment
bosh-cli clean-up -n --all
bosh-cli delete-env -n director-state/director.yml -l director-state/director-creds.yml
