{
  config,
  pkgs,
  lib,
  ...
}:
let
  # ポート割り当てルール
  #   固定  : 外部 (ルーター・VPN peer・クライアント) が依存するため変更しない
  #   80x0  : Caddy 配下の Web アプリ
  #   90x0  : 監視基盤 (可視化・収集・保存)
  #   91x0  : Prometheus exporter
  # 各サービスに 10 番のスロットを割り当て、末尾 0 = メイン, +1, +2 ... = 補助ポート
  ports = {
    public = {
      http = 80;
      https = 443;
      sflow = 6343;
    };
    wireguard = {
      wg0 = 51820;
      wg1 = 51821; # 友人間 VPN
      relay = 51822; # VPS Relay
    };

    web = {
      mattermost = 8065;
      llWiki = 8000;
      nijiiro = 8001;
      nLovehigh = 8002;
    };

    monitoring = {
      grafana = 9010;
      prometheus = 9020;
      alertmanager = 9030;
      lokiHttp = 9040;
      lokiGrpc = 9041;
      goflow2Http = 9050;
    };

    exporters = {
      node = 9110;
      snmp = 9120;
    };
  };

  p = lib.mapAttrsRecursive (_: toString) ports;
  allPorts = lib.collect lib.isInt ports;
in
{
  assertions = [
    {
      assertion = lib.allUnique allPorts;
      message = "ports に重複があります: ${toString allPorts}";
    }
  ];

  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Asia/Tokyo";

  hardware.enableRedistributableFirmware = true;

  networking.hostName = "ria";
  networking.useNetworkd = true;
  networking.nameservers = [
    "1.1.1.1"
  ];
  services.resolved.enable = false;

  systemd.network.networks."10-enp4s0" = {
    matchConfig.Name = "enp4s0";
    networkConfig.DHCP = "yes";
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.0.0.1/24" ];
    listenPort = ports.wireguard.wg0;
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
    listenPort = ports.wireguard.wg1;
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
    listenPort = ports.wireguard.relay;
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
    interfaces."enp4s0".allowedUDPPorts = [ ports.public.sflow ];
    allowedTCPPorts = [
      ports.public.http
      ports.public.https
    ];
    allowedUDPPorts = lib.attrValues ports.wireguard;
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
    virtualHosts."mattermost.maril.blue".extraConfig = "reverse_proxy localhost:${p.web.mattermost}";
    virtualHosts."ll-wiki.maril.blue".extraConfig = "reverse_proxy localhost:${p.web.llWiki}";
    virtualHosts."n-lovehigh.maril.blue".extraConfig = "reverse_proxy localhost:${p.web.nLovehigh}";
    virtualHosts."nijiiro.maril.blue".extraConfig = "reverse_proxy localhost:${p.web.nijiiro}";
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
    port = ports.web.mattermost;
  };

  systemd.services.goflow2 = {
    description = "GoFlow2 sFlow collector";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = ''
        ${pkgs.goflow2}/bin/goflow2 \
          -listen sflow://:${p.public.sflow} \
          -format json \
          -addr 127.0.0.1:${p.monitoring.goflow2Http}
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
        http_listen_port = ports.monitoring.lokiHttp;
        grpc_listen_port = ports.monitoring.lokiGrpc;
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
          loki_address = "localhost:${p.monitoring.lokiHttp}";
        };
      };

      ruler = {
        alertmanager_url = "http://localhost:${p.monitoring.alertmanager}";
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
        url = "http://localhost:${p.monitoring.lokiHttp}/loki/api/v1/push"
      }
    }
  '';

  services.prometheus = {
    enable = true;
    port = ports.monitoring.prometheus;
    exporters = {
      node = {
        enable = true;
        port = ports.exporters.node;
        enabledCollectors = [
          "systemd"
          "logind"
        ];
      };
      snmp = {
        enable = true;
        port = ports.exporters.snmp;
        listenAddress = "127.0.0.1";
        enableConfigCheck = false;
        configurationPath = "${pkgs.prometheus-snmp-exporter.src}/snmp.yml";
      };
    };
    extraFlags = [ "--web.enable-admin-api" ];
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "localhost:${p.exporters.node}" ];
            labels.instance = "ria";
          }
        ];
      }
      {
        job_name = "snmp";
        metrics_path = "/snmp";
        params = {
          module = [
            "if_mib"
            "nec_ix"
          ];
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
            replacement = "127.0.0.1:${p.exporters.snmp}";
          }
        ];
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings.server = {
      http_addr = "10.0.0.1";
      http_port = ports.monitoring.grafana;
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
          url = "http://localhost:${p.monitoring.prometheus}";
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
          url = "http://localhost:${p.monitoring.lokiHttp}";
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
    pkgs.trippy
    pkgs.jq
    pkgs.dust
    pkgs.busybox
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
