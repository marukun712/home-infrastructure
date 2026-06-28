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
    crystalBinaries.n-high-lovelive = {
      src = "src/n-high-lovelive.cr";
    };
  };
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "ria";

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/private";
    peers = [ ];
  };

  networking.nftables.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "wg0" ];
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
  };

  containers.photo = {
    autoStart = true;
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
          initialPassword = "changeme";
        };
        system.stateVersion = "26.05";
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

  system.stateVersion = "26.05";
}
