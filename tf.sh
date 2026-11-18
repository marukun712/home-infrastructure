#!/usr/bin/env bash
set -eu

export NB_PAT=$(cat netbird-pat)

nix build ".#netbird-tf" -o out/netbird-tf
install -m 644 out/netbird-tf tf/config.tf.json
cd tf
tofu init
tofu "$@"
