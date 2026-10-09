{
  config,
  pkgs,
  lib,
  ...
}:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Asia/Tokyo";

  hardware.enableRedistributableFirmware = true;

  networking.hostName = "ria";
  networking.useNetworkd = true;
  services.resolved.enable = false;

  systemd.network.networks."10-enp4s0" = {
    matchConfig.Name = "enp4s0";
    networkConfig.DHCP = "yes";
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/private";
    peers = [
      {
        # aiha (nixos-develop)
        publicKey = "FCiP2J1xLRlRqbrSHFHD+zCMfL8c2ihFDpJIrgtxTwc=";
        allowedIPs = [ "10.0.0.2/32" ];
      }
      {
        # honon (bazzite-os)
        publicKey = "h/qyR6sX1Je3xPqvwBca4ELmWvXTOA38LMy2Twsmk2Y=";
        allowedIPs = [ "10.0.0.3/32" ];
      }
      {
        # rina (iphone)
        publicKey = "IiOdLf9WT48gBFrAh8XrDW/cI1Mcm+ATAqNI8maSZ1I=";
        allowedIPs = [ "10.0.0.4/32" ];
      }
    ];
  };

  # 友人間 VPN
  networking.wireguard.interfaces.wg1 = {
    ips = [ "10.0.10.1/24" ];
    listenPort = 51821;
    privateKeyFile = "/etc/wireguard/maril-network/private";
    peers = [
      {
        # aiha (nixos-develop)
        publicKey = "Y9qHNh3YyWqntvodQ2ZjVpOpDvD8/w9+hazPU/F1DBY=";
        allowedIPs = [ "10.0.10.2/32" ];
      }
      {
        # akaz
        publicKey = "6hhYJwWIEvwEkdIEzdS2A0CS6IG4xJey6gLEdv4Hi00=";
        allowedIPs = [ "10.0.10.3/32" ];
      }
      {
        # tmak
        publicKey = "Z3k/Cj+d1E8GLUFtDhtqcWNLvKzBjQ51IQpXOHsUgCY=";
        allowedIPs = [ "10.0.10.4/32" ];
      }
      {
        # ryouma
        publicKey = "KT24u/N6eNTs6wm0aFVxqfwRvcyr9Q2ea1WQ2q/XkXU=";
        allowedIPs = [ "10.0.10.5/32" ];
      }
    ];
  };

  # VPS Relay
  networking.wireguard.interfaces.wg-relay = {
    ips = [ "10.0.20.1/24" ];
    listenPort = 51822;
    privateKeyFile = "/etc/wireguard/relay/private";
    peers = [
      {
        # VPS
        publicKey = "D8sC4zMXS5NohFRnX3acc779nemfTaWN3vm2fARSzUg=";
        allowedIPs = [ "10.0.20.2/32" ];
      }
    ];
  };

  networking.nftables.enable = true;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [
      "wg0"
    ];
    networking.firewall.interfaces."enp4s0".allowedUDPPorts = [ 6343 ];
    allowedTCPPorts = [
      80
      443
    ];
    allowedUDPPorts = [
      51820
      51821
      51822
    ];
    extraForwardRules = ''
      iifname "wg1" oifname "wg1" accept
    '';
  };

  services.caddy = {
    enable = true;
    virtualHosts."maril.blue".extraConfig = ''
      reverse_proxy https://marukun712.github.io {
        header_up Host marukun712.github.io
      }
    '';
    virtualHosts."mattermost.maril.blue".extraConfig = "reverse_proxy localhost:8065";
    virtualHosts."ll-wiki.maril.blue".extraConfig = "reverse_proxy localhost:8000";
    virtualHosts."n-lovehigh.maril.blue".extraConfig = "reverse_proxy localhost:8002";
    virtualHosts."nijiiro.maril.blue".extraConfig = "reverse_proxy localhost:8001";
    virtualHosts."files.maril.blue".extraConfig = ''
      root * /var/www
      file_server
      header Access-Control-Allow-Origin "*"
    '';
  };

  systemd.services.process-compose = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "maril";
      Group = "users";
      ExecStart = "${pkgs.process-compose}/bin/process-compose --tui=false -f ${./process-compose.yaml} up";
      Environment = "PATH=/run/current-system/sw/bin:/usr/bin:/bin";
      Restart = "always";
    };
  };

  services.immich = {
    enable = true;
    mediaLocation = "/var/lib/photo/immich";
    host = "0.0.0.0";
  };

  services.mattermost = {
    enable = true;
    siteUrl = "https://mattermost.maril.blue";
  };

  systemd.services.goflow2 = {
    description = "GoFlow2 sFlow collector";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = ''
        ${pkgs.goflow2}/bin/goflow2 \
          -listen sflow://:6343 \
          -format json \
          -addr 127.0.0.1:8080
      '';
      DynamicUser = true;
      Restart = "on-failure";
    };
  };

  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;

      server = {
        http_listen_port = 3100;
        grpc_listen_port = 9096;
        log_level = "info";
        grpc_server_max_concurrent_streams = 1000;
      };

      common = {
        instance_addr = "127.0.0.1";
        path_prefix = "/var/lib/loki";
        storage.filesystem = {
          chunks_directory = "/var/lib/loki/chunks";
          rules_directory = "/var/lib/loki/rules";
        };
        replication_factor = 1;
        ring = {
          kvstore = {
            store = "inmemory";
          };
        };
      };

      query_range = {
        results_cache = {
          cache = {
            embedded_cache = {
              enabled = true;
              max_size_mb = 100;
            };
          };
        };
      };

      limits_config = {
        metric_aggregation_enabled = true;
      };

      schema_config = {
        configs = [
          {
            from = "2020-10-24";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };

      pattern_ingester = {
        enabled = true;
        metric_aggregation = {
          loki_address = "localhost:3100";
        };
      };

      ruler = {
        alertmanager_url = "http://localhost:9093";
      };

      frontend = {
        encoding = "protobuf";
      };
    };
  };

  services.alloy.enable = true;

  environment.etc."alloy/config.alloy".text = ''
    local.file_match "local_files" {
      path_targets = [{"__path__" = "/var/log/*.log"}]
      sync_period  = "5s"
    }

    loki.source.file "log_scrape" {
      targets       = local.file_match.local_files.targets
      forward_to    = [loki.process.filter_logs.receiver]
      tail_from_end = true
    }

    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
    }

    loki.source.journal "read" {
      forward_to    = [loki.process.filter_logs.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels        = {job = "systemd-journal"}
    }

    loki.process "filter_logs" {
      forward_to = [loki.write.grafana_loki.receiver]
    }

    loki.write "grafana_loki" {
      endpoint {
        url = "http://localhost:3100/loki/api/v1/push"
      }
    }
  '';

  services.prometheus = {
    enable = true;
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [
          "systemd"
          "logind"
        ];
      };
      snmp = {
        enable = true;
        listenAddress = "127.0.0.1";
        enableConfigCheck = false;
        configurationPath = "${pkgs.prometheus-snmp-exporter.src}/snmp.yml";
      };
    };
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [ { targets = [ "localhost:9100" ]; } ];
      }
      {
        job_name = "snmp";
        metrics_path = "/snmp";
        params = {
          module = [ "if_mib" ];
          auth = [ "public_v2" ];
        };
        static_configs = [ { targets = [ "192.168.20.1" ]; } ];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9116";
          }
        ];
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings.server = {
      http_addr = "10.0.0.1";
      http_port = 3000;
    };
    settings.security.secret_key = "$__file{/etc/grafana/private}";
    declarativePlugins = with pkgs.grafanaPlugins; [
      yesoreyeram-infinity-datasource
    ];
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          uid = "prometheus";
          access = "proxy";
          url = "http://localhost:9090";
          isDefault = true;
        }
        {
          name = "Infinity";
          type = "yesoreyeram-infinity-datasource";
          access = "proxy";
          isDefault = false;
        }
        {
          name = "Loki";
          type = "loki";
          uid = "loki";
          access = "proxy";
          url = "http://localhost:3100";
        }
      ];
    };
  };

  services.logind.settings.Login.HandleLidSwitch = "ignore";
  services.tailscale.enable = true;
  services.atd.enable = true;

  users.users.maril = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  programs.nix-ld.enable = true;
  programs.nh.enable = true;

  environment.systemPackages = [
    pkgs.git
    pkgs.wireguard-tools
    pkgs.nixfmt-tree
    pkgs.bash
    pkgs.biome
    pkgs.eza
    pkgs.tcpdump
    pkgs.baresip
    pkgs.at
    pkgs.unar
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
  };

  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ls = "eza --icons --group-directories-first";
      ll = "eza -la --icons --group-directories-first --git";
      lt = "eza --tree --level=2 --icons";
    };
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.05";
}
