{
  config,
  pkgs,
  lib,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.enableRedistributableFirmware = true;

  networking.hostName = "ria";
  networking.useNetworkd = true;

  systemd.network.networks."10-enp4s0" = {
    matchConfig.Name = "enp4s0";
    networkConfig.DHCP = "yes";
  };

  networking.interfaces.wlp2s0.ipv4.addresses = [
    {
      address = "192.168.10.1";
      prefixLength = 24;
    }
  ];

  networking.interfaces.wlp2s0.ipv6.addresses = [
    {
      address = "fd00::1";
      prefixLength = 64;
    }
  ];

  services.hostapd = {
    enable = true;
    radios.wlp2s0 = {
      band = "2g";
      channel = 6;
      wifi5.enable = true;
      networks.wlp2s0 = {
        ssid = "何それ？知らん！LAN！";
        authentication = {
          mode = "wpa2-sha1";
          wpaPasswordFile = "/etc/hostapd/wpa_passphrase";
        };
      };
    };
  };

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config.interfaces = [ "wlp2s0" ];
      subnet4 = [
        {
          id = 1;
          subnet = "192.168.10.0/24";
          pools = [ { pool = "192.168.10.10 - 192.168.10.100"; } ];
          option-data = [
            {
              name = "routers";
              data = "192.168.10.1";
            }
            {
              name = "domain-name-servers";
              data = "1.1.1.1, 8.8.8.8";
            }
          ];
        }
      ];
    };
  };

  services.radvd = {
    enable = true;
    config = ''
      interface wlp2s0 {
        AdvSendAdvert on;
        MinRtrAdvInterval 3;
        MaxRtrAdvInterval 10;
        prefix fd00::/64 {
          AdvOnLink on;
          AdvAutonomous on;
        };
        RDNSS 2606:4700:4700::1111 2001:4860:4860::8888 {};
      };
    '';
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "wlp2s0" ];
    externalInterface = "enp4s0";
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/private";
    peers = [
      {
        # aiha
        publicKey = "FCiP2J1xLRlRqbrSHFHD+zCMfL8c2ihFDpJIrgtxTwc=";
        allowedIPs = [ "10.0.0.2/32" ];
      }
      {
        # honon
        publicKey = "h/qyR6sX1Je3xPqvwBca4ELmWvXTOA38LMy2Twsmk2Y=";
        allowedIPs = [ "10.0.0.3/32" ];
      }
    ];
  };

  networking.nftables.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [
      "wg0"
      "wlp2s0"
    ];
    allowedTCPPorts = [
      80
      443
    ];
    allowedUDPPorts = [
      51820
    ];
  };

  services.caddy = {
    enable = true;
    virtualHosts."maril.blue".extraConfig = ''
      reverse_proxy https://marukun712.github.io {
        header_up Host marukun712.github.io
      }
    '';
  };

  services.immich = {
    enable = true;
    mediaLocation = "/var/lib/photo/immich";
  };

  services.samba = {
    enable = true;
    settings = {
      global.workgroup = "WORKGROUP";
      photos = {
        path = "/var/lib/photo/samba";
        "valid users" = "maril";
        writable = "yes";
      };
    };
  };
  services.samba-wsdd.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = false;
  };

  services.logind.settings.Login.HandleLidSwitch = "ignore";

  users.users.maril = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  environment.systemPackages = [
    pkgs.git
    pkgs.wireguard-tools
    pkgs.nixfmt-tree
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.05";
}
