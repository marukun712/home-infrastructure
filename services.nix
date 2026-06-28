{
  config,
  modulesPath,
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
  systemd.services.lovehigh = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${lovehigh}/bin/n-high-lovelive";
      Restart = "always";
      User = "maril";
    };
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
    pkgs.wget
  ];

  networking.interfaces.ens18.useDHCP = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 4000 ];
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  system.stateVersion = "25.05";
}
