{ kubenix, ... }:
let
  relayEndpoint = "syakechan.maril.blue:51820";
  relayPublicKey = "S6EOBw/TUwuK1zEswS7ovh8t4GENfHAeRRJN/zP3u2g=";
  clusterAddress = "10.10.0.2/24";
  wgMtu = 1280;
  relaySubnet = "10.10.0.0/24";

  publish = [
    {
      name = "caddy";
      port = 80;
      protocol = "tcp";
      target = "caddy.web.svc.cluster.local:80";
    }
  ];

  wgSetup = ''
    set -e
    ip link add wg0 type wireguard
    wg set wg0 private-key /etc/wireguard/privatekey \
      peer ${relayPublicKey} \
      endpoint ${relayEndpoint} \
      allowed-ips ${relaySubnet} \
      persistent-keepalive 25
    ip address add ${clusterAddress} dev wg0
    ip link set wg0 mtu ${toString wgMtu}
    ip link set wg0 up
  '';

  socatArgs =
    item:
    if item.protocol == "udp" then
      [
        "-T"
        "60"
        "UDP-LISTEN:${toString item.port},fork,reuseaddr"
        "UDP:${item.target}"
      ]
    else
      [
        "TCP-LISTEN:${toString item.port},fork,reuseaddr"
        "TCP:${item.target}"
      ];

  proxies = builtins.listToAttrs (
    map (item: {
      name = item.name;
      value = {
        image = "alpine/socat:1.8.1.3";
        args = socatArgs item;
        ports = [
          {
            name = item.name;
            containerPort = item.port;
            protocol = if item.protocol == "udp" then "UDP" else "TCP";
          }
        ];
      };
    }) publish
  );
in
{
  imports = with kubenix.modules; [
    k8s
  ];

  kubenix.project = "my-cluster";
  kubernetes.version = "1.37";

  kubernetes.resources.deployments.wg-relay = {
    metadata.namespace = "relay";
    spec = {
      replicas = 1;
      strategy.type = "Recreate";
      selector.matchLabels.app = "wg-relay";
      template = {
        metadata.labels.app = "wg-relay";
        spec = {
          initContainers.wireguard = {
            image = "lscr.io/linuxserver/wireguard:1.0.20260223-r0-ls130";
            command = [
              "sh"
              "-c"
              wgSetup
            ];
            securityContext.capabilities.add = [ "NET_ADMIN" ];
            volumeMounts = [
              {
                name = "wg-key";
                mountPath = "/etc/wireguard";
                readOnly = true;
              }
            ];
          };
          containers = proxies;
          volumes = [
            {
              name = "wg-key";
              secret.secretName = "wg-relay";
            }
          ];
        };
      };
    };
  };
}
