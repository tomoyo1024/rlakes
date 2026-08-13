{ pkgs, ... }:
{
  imports = [
    ./disko.nix
  ];
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    trusted-users = [
      "@wheel"
    ];
  };
  networking = {
    hostName = "nixos";
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      AllowUsers = [ "nixos" ];
    };
  };
  environment.systemPackages = with pkgs; [
    fastfetch
    curl
    wget
    git
    rsync
    rclone
    htop
    nix-tree
    nano
    vim
    openssl
  ];

  services.xserver.enable = false;

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
    ];
    hashedPassword = "";
    openssh.authorizedKeys.keys = [
      ""
    ];
  };

  security.sudo.wheelNeedsPassword = false;
  boot.loader.grub = {
    enable = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
  ];
  system.stateVersion = "26.05"; # Did you read the comment?
}
