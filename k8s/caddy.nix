{ kubenix, ... }:
{
  imports = with kubenix.modules; [
    k8s
  ];

  kubenix.project = "my-cluster";
  kubernetes.version = "1.37";

  kubernetes.resources.configMaps.caddy = {
    metadata.namespace = "web";
    data = {
      Caddyfile = ''
        :80 {
        	root * /srv
        	file_server {
        		index mai.html
        	}
        }
      '';
      "mai.html" = builtins.readFile ../static/mai.html;
    };
  };

  kubernetes.resources.deployments.caddy = {
    metadata.namespace = "web";
    spec = {
      replicas = 1;
      selector.matchLabels.app = "caddy";
      template = {
        metadata.labels.app = "caddy";
        spec = {
          containers.caddy = {
            image = "caddy:2.11.9-alpine";
            ports = [
              {
                name = "http";
                containerPort = 80;
              }
            ];
            volumeMounts = [
              {
                name = "caddyfile";
                mountPath = "/etc/caddy";
              }
              {
                name = "site";
                mountPath = "/srv";
              }
            ];
          };
          volumes = [
            {
              name = "caddyfile";
              configMap = {
                name = "caddy";
                items = [
                  {
                    key = "Caddyfile";
                    path = "Caddyfile";
                  }
                ];
              };
            }
            {
              name = "site";
              configMap = {
                name = "caddy";
                items = [
                  {
                    key = "mai.html";
                    path = "mai.html";
                  }
                ];
              };
            }
          ];
        };
      };
    };
  };

  kubernetes.resources.services.caddy = {
    metadata.namespace = "web";
    spec = {
      selector.app = "caddy";
      ports = [
        {
          name = "http";
          port = 80;
          targetPort = 80;
        }
      ];
    };
  };
}
