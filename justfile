# Default target - build the flake
default:
    nix build

# Build with explicit experimental features
build:
    nix build . --extra-experimental-features 'nix-command flakes'

# Generate hardware config using nixos-facter
nixos-anywhere target:
    nix run github:nix-community/nixos-anywhere -- --generate-hardware-config nixos-facter ./facter.json --flake .#init --target-host root@{{ target }} --build-on-remote

# Deploy using deploy-rs
deploy node:
    nix run github:serokell/deploy-rs {{ node }}
