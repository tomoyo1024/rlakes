{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs.url = "github:serokell/deploy-rs";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    facter = {
      url = "github:numtide/nixos-facter-modules";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      disko,
      sops-nix,
      facter,
      deploy-rs,
      ...
    }:
    let
      sopsModules = [
        sops-nix.nixosModules.sops
        ./sops.nix
      ];
    in
    {
      # initinal templates for new machine via nixos-anywhere
      nixosConfigurations.init = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          templates/minimal/configuration.nix
          disko.nixosModules.disko
          facter.nixosModules.facter
          { config.facter.reportPath = ./facter.json; }
        ];
      };
      # machine blinker use nixpkgs
      nixosConfigurations.blinker = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = sopsModules ++ [
          blinker/configuration.nix
          disko.nixosModules.disko
          facter.nixosModules.facter
          { config.facter.reportPath = poach/facter.json; }
        ];
      };
      # machine poach use nixpkgs-unstable
      nixosConfigurations.poach = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = sopsModules ++ [
          poach/configuration.nix
          disko.nixosModules.disko
          facter.nixosModules.facter
          { config.facter.reportPath = poach/facter.json; }
        ];
      };
      # nodes structure via deploy-rs
      deploy.nodes = {
        blinker = {
          hostname = "blinker.demo";
          profiles.system = {
            sshUser = "nixos";
            user = "root";
            remoteBuild = false;
            magicRollback = false;
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.blinker;
          };
        };
        poach = {
          hostname = "poach.demo";
          profiles.system = {
            sshUser = "nixos";
            user = "root";
            remoteBuild = false;
            magicRollback = false;
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.poach;
          };
        };
      };
      # This is highly advised, and will prevent many possible mistakes
      # checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    };
}
