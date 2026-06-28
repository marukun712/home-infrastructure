{
  config,
  pkgs,
  lib,
  ...
}:
let
  lovehigh = pkgs.crystal.buildCrystalPackage {
    pname = "n-high-lovelive";
    version = "0.1.0";
    src = /home/maril/workspace/n-high-lovelive;
    shardsFile = /home/maril/workspace/n-high-lovelive/shards.nix;
    crystalBinaries.n-high-lovelive = {
      source = "src/n-high-lovelive.cr";
    };
  };
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ria";

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/private";
    peers = [ ];
  };

  networking.nftables.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      445
      2283
      4000
    ];
    allowedUDPPorts = [
      51820
      137
      138
    ];
  };

  containers.photo = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.200.0.1";
    localAddress = "10.200.0.2";
    forwardPorts = [
      {
        hostPort = 2283;
        containerPort = 2283;
        protocol = "tcp";
      }
      {
        hostPort = 445;
        containerPort = 445;
        protocol = "tcp";
      }
      {
        hostPort = 137;
        containerPort = 137;
        protocol = "udp";
      }
      {
        hostPort = 138;
        containerPort = 138;
        protocol = "udp";
      }
    ];
    bindMounts."/mnt/data" = {
      hostPath = "/mnt/data";
      isReadOnly = false;
    };
    config =
      { pkgs, ... }:
      {
        services.immich = {
          enable = true;
          mediaLocation = "/mnt/data/immich";
        };
        services.samba = {
          enable = true;
          settings = {
            global.workgroup = "WORKGROUP";
            photos = {
              path = "/mnt/data/samba";
              "valid users" = "maril";
              writable = "yes";
            };
          };
        };
        services.samba-wsdd.enable = true;
        users.users.maril = {
          isNormalUser = true;
          initialPassword = "changeme";
        };
        networking.firewall.enable = false;
        system.stateVersion = "25.05";
      };
  };

  containers.services = {
    autoStart = true;
    privateNetwork = true;
    hostAddress = "10.200.1.1";
    localAddress = "10.200.1.2";
    forwardPorts = [
      {
        hostPort = 4000;
        containerPort = 4000;
        protocol = "tcp";
      }
    ];
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
          initialPassword = "changeme";
        };
        networking.firewall.enable = false;
        system.stateVersion = "25.05";
      };
  };

  services.openssh.enable = true;

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
