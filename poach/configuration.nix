{
  imports = [
    ./filesystem.nix
  ];
  # case for LAN without dhcp
  networking = {
    hostName = "poach";
    interfaces.ens3 = {
      ipv4 = {
        addresses = [
          {
            address = "11.45.148.10";
            prefixLength = 24;
          }
        ];
      };
    };
    defaultGateway = {
      address = "11.45.148.1";
      interface = "ens3";
    };
    nameservers = [
      "1.1.1.1"
    ];
  };
  # legacy bios
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };
  system.stateVersion = "26.05";
}
