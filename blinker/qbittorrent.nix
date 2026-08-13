{
  pkgs,
  ...
}:
{
  services.qbittorrent = {
    enable = true;
    torrentingPort = 12312;
    webuiPort = 8080;
    openFirewall = true;
    serverConfig = {
      Preferences = {
        WebUI = {
          AlternativeUIEnabled = true;
          RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
        };
      };
    };
  };
}
