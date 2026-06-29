{
  config,
  pkgs,
  lib,
  ...
}:
let
  loveliveSource = pkgs.fetchFromGitHub {
    owner = "marukun712";
    repo = "n-high-lovelive";
    rev = "1b61854aa2a41b26ddbf824a66539b37b7d91367";
    hash = "sha256-LpfukTiTUn7XhEJu9UOSkt1u9vK6Z0PfPfUEvOJJSyA=";
  };
  lovehigh = pkgs.crystal.buildCrystalPackage {
    pname = "n-high-lovelive";
    version = "0.1.0";
    src = loveliveSource;
    format = "crystal";
    shardsFile = loveliveSource + "/shards.nix";
    nativeBuildInputs = [ pkgs.shards ];
    doInstallCheck = false;
    crystalBinaries.n-high-lovelive = {
      src = "src/n-high-lovelive.cr";
    };
  };
in
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

  networking.nat = {
    enable = true;
    internalInterfaces = [ "wlp2s0" ];
    externalInterface = "enp4s0";
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

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
    virtualHosts."n-lovehigh.maril.blue".extraConfig = "reverse_proxy localhost:4000";
    virtualHosts."maril.blue".extraConfig = ''
      reverse_proxy https://marukun712.github.io {
        header_up Host marukun712.github.io
      }
    '';
  };

  containers.photo = {
    autoStart = true;
    bindMounts."/var/lib/photo" = {
      hostPath = "/var/lib/photo";
      isReadOnly = false;
    };
    config =
      { pkgs, ... }:
      {
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
        users.users.maril = {
          isNormalUser = true;
        };
        system.stateVersion = "26.05";
      };
  };

  containers.services = {
    autoStart = true;
    config =
      { pkgs, ... }:
      {
        systemd.services.lovehigh = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            ExecStart = "${lovehigh}/bin/n-high-lovelive";
            Restart = "always";
            User = "maril";
          };
        };
        users.users.maril = {
          isNormalUser = true;
        };
        system.stateVersion = "26.05";
      };
  };

  services.openssh.enable = true;

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
