{ kubenix, ... }:
{
  imports = [ kubenix.modules.k8s ];

  kubenix.project = "my-cluster";
  kubernetes.version = "1.37";

  kubernetes.customTypes = [
    {
      group = "metallb.io";
      version = "v1beta1";
      kind = "IPAddressPool";
      attrName = "ipaddresspools";
    }
    {
      group = "metallb.io";
      version = "v1beta1";
      kind = "L2Advertisement";
      attrName = "l2advertisements";
    }
  ];

  kubernetes.resources.ipaddresspools.default-pool = {
    metadata.namespace = "metallb-system";
    spec.addresses = [ "192.168.20.240-192.168.20.250" ];
  };
  kubernetes.resources.l2advertisements.default = {
    metadata.namespace = "metallb-system";
    spec.ipAddressPools = [ "default-pool" ];
  };

  kubernetes.resources.persistentVolumeClaims.nginx-html.spec = {
    accessModes = [ "ReadWriteOnce" ];
    resources.requests.storage = "128Mi";
  };

  kubernetes.resources.deployments.nginx.spec = {
    replicas = 1;
    selector.matchLabels.app = "nginx";
    template = {
      metadata.labels.app = "nginx";
      spec = {
        initContainers.init-html = {
          image = "busybox:1.37";
          command = [
            "sh"
            "-c"
            "[ -f /html/index.html ] || echo 'hello from talos + kubenix' > /html/index.html"
          ];
          volumeMounts = [
            {
              name = "html";
              mountPath = "/html";
            }
          ];
        };
        containers.nginx = {
          image = "nginx:stable";
          ports = [
            {
              name = "http";
              containerPort = 80;
            }
          ];
          volumeMounts = [
            {
              name = "html";
              mountPath = "/usr/share/nginx/html";
            }
          ];
        };
        volumes = [
          {
            name = "html";
            persistentVolumeClaim.claimName = "nginx-html";
          }
        ];
      };
    };
  };

  kubernetes.resources.services.nginx.spec = {
    type = "LoadBalancer";
    selector.app = "nginx";
    ports = [
      {
        name = "http";
        port = 80;
        targetPort = 80;
      }
    ];
  };
}
