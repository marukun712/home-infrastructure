#!/usr/bin/env bash
set -eu

for name in infra prometheus grafana immich netbird; do
  nix build ".#$name" -o "out/$name.yaml"
done
