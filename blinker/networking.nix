{ ... }:
{

  services.dnsproxy = {
    enable = true;
    settings = {
      upstream = [ "tls://8.8.8.8" ];
      listen-addrs = [ "0.0.0.0" ];
      listen-ports = [ 53 ];
      tls-port = [ 853 ];
      https-port = [ 443 ];
    };
  };

  networking = {
    nameservers = [
      "127.0.0.1"
      "::1"
    ];
    networkmanager.dns = "none";
    enableIPv6 = true;
    tempAddresses = "disabled";
    dhcpcd.IPv6rs = true;
    hostName = "blinker";
    networkmanager.enable = true;
    firewall = {
      allowPing = true;
      allowedTCPPorts = [
        22
      ];
    };
  };
}
