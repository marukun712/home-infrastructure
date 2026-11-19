#!/usr/bin/env bash
set -eu

for name in infra prometheus grafana immich netbird caddy wg-relay; do
  nix build ".#$name" -o "out/$name.yaml"
done
