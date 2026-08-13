{ config, ... }:
let
  domain = "blinker.demo";
  email = "admin@blinker.demo";
in
{
  networking.firewall = {
    allowedTCPPorts = [
      443
    ];
  };
  sops.templates = {
    "acme.env".content = ''
      CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder."cloudflare/dnsToken"}
    '';
  };
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = email;
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      environmentFile = config.sops.templates."acme.env".path;
      dnsPropagationCheck = true;
      group = config.services.nginx.group;
    };
  };

  users.groups."www-data".members = [ config.services.nginx.user ];
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;

    virtualHosts.fun = {
      serverName = "fun.${domain}";
      forceSSL = true;
      enableACME = true;
      acmeRoot = null;
      locations."/" = {
        extraConfig = ''
          proxy_read_timeout 86400s;
          proxy_send_timeout 86400s;
          proxy_buffering off;
        '';
        proxyPass = "http://127.0.0.1:5678/";
        recommendedProxySettings = true;
        proxyWebsockets = true;
      };
    };
  };
}
