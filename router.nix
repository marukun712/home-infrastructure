{
  config,
  pkgs,
  ...
}:
{
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/private";
    peers = [ ]; # 各クライアントをここに追加していく
  };

  networking.interfaces.eth0.ipv4.addresses = [
    {
      address = "10.100.0.2";
      prefixLength = 30;
    }
  ];

  networking.defaultGateway = {
    address = "10.100.0.1";
    interface = "eth0";
  };

  networking.interfaces.eth1.ipv4.addresses = [
    {
      address = "192.168.10.1";
      prefixLength = 24;
    }
  ];

  networking.nftables.enable = true;

  networking.nat = {
    enable = true;
    internalInterfaces = [ "eth1" ]; # LAN側 (VM群)
    externalInterface = "eth0"; # WAN側 (PVEホスト方向)
  };

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config.interfaces = [ "eth1" ];
      subnet4 = [
        {
          subnet = "192.168.10.0/24";
          pools = [ { pool = "192.168.10.10 - 192.168.10.254"; } ];
          option-data = [
            {
              name = "routers";
              data = "192.168.10.1";
            }
            {
              name = "domain-name-servers";
              data = "1.1.1.1";
            }
          ];
        }
      ];
    };
  };

  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 51820 ]; # WireGuard
  };

  users.users.root.initialPassword = "changeme";

  users.users.maril = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    initialPassword = "changeme";
  };

  programs.zsh.enable = true;

  environment.systemPackages = [
    pkgs.git
    pkgs.wireguard-tools
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.05";
}
