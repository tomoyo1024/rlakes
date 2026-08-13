{
  fileSystems = {
    "/boot" = {
      device = "/dev/vda2";
      fsType = "vfat";
    };
    "/" = {
      device = "/dev/vda3";
      fsType = "ext4";
      options = [
        "defaults"
        "noatime"
      ];
    };
  };
}
