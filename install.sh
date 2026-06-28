#!/usr/bin/env bash
set -e

sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko \
  --flake .#server

sudo nixos-install --flake .#server
