{ pkgs, ... }:
{
  imports = [
    ./disko.nix
    ./networking.nix
    ./qbittorrent.nix
    ./nginx.nix
  ];
  nixpkgs.config.allowUnfree = true;
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=1month'';
  nix.settings = {
    trusted-users = [
      "@wheel"
    ];
  };
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
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
    inetutils
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
    # make sure efi support by vender
    efiSupport = true;
    enable = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05"; # Did you read the comment?
}
