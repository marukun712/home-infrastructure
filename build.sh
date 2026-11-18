#!/usr/bin/env bash
set -eu

for name in infra prometheus grafana immich; do
  nix build ".#$name" -o "out/$name"
done
