{
  config,
  pkgs,
  ...
}:
{
  services.immich = {
    enable = true;
    mediaLocation = "/mnt/data/immich";
  };

  services.samba = {
    enable = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
      };
      photos = {
        path = "/mnt/data/samba";
        "valid users" = "maril";
        writable = "yes";
      };
    };
  };

  services.samba-wsdd.enable = true; # Windowsのネットワーク探索用

  networking.interfaces.ens18.useDHCP = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      445 # Samba
      2283 # Immich
    ];
    allowedUDPPorts = [
      137 # Samba (NetBIOS)
      138
    ];
  };

  users.users.root.initialPassword = "changeme";

  users.users.maril = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    initialPassword = "changeme";
  };

  programs.zsh.enable = true;

  environment.systemPackages = [ pkgs.git ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.05";
}
