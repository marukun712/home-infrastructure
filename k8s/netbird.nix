{ kubenix, ... }:
let
  operatorChart = kubenix.lib.helm.fetch {
    chart = "netbird-operator";
    chartUrl = "oci://ghcr.io/netbirdio/helm-charts/netbird-operator";
    version = "0.9.0";
    sha256 = "sha256-gn7ixSrmFExR+FJOKJCuRcgd80kWneal8Sju/i8MHJc=";
  };
in
{
  imports = with kubenix.modules; [
    k8s
    helm
  ];

  kubenix.project = "my-cluster";
  kubernetes.version = "1.37";

  kubernetes.customTypes = [
    {
      group = "cert-manager.io";
      version = "v1";
      kind = "Issuer";
      attrName = "issuers";
    }
    {
      group = "cert-manager.io";
      version = "v1";
      kind = "Certificate";
      attrName = "certificates";
    }
    {
      group = "netbird.io";
      version = "v1alpha1";
      kind = "NetworkRouter";
      attrName = "networkrouters";
    }
    {
      group = "netbird.io";
      version = "v1alpha1";
      kind = "NetworkResource";
      attrName = "networkresources";
    }
  ];

  kubernetes.resources.namespaces.netbird.metadata.labels = {
    "pod-security.kubernetes.io/enforce" = "privileged";
    "pod-security.kubernetes.io/audit" = "privileged";
    "pod-security.kubernetes.io/warn" = "privileged";
  };

  kubernetes.helm.releases.netbird-operator = {
    chart = operatorChart;
    namespace = "netbird";
    includeCRDs = true;
    values = {
      managementURL = "https://netbird.maril.blue";
      cluster = {
        name = "my-cluster";
        dns = "svc.cluster.local";
      };
      webhook.failurePolicy = "Ignore";
    };
  };

  kubernetes.resources.networkrouters.cluster = {
    metadata.namespace = "netbird";
    spec = {
      dnsZoneRef.name = "syakechan.internal";
      workloadOverride.replicas = 1;
    };
  };

  kubernetes.resources.networkresources.grafana = {
    metadata.namespace = "monitoring";
    spec = {
      networkRouterRef = {
        name = "cluster";
        namespace = "netbird";
      };
      serviceRef.name = "grafana";
      groups = [ { name = "kubernetes-services"; } ];
    };
  };

  kubernetes.resources.networkresources.prometheus-server = {
    metadata.namespace = "monitoring";
    spec = {
      networkRouterRef = {
        name = "cluster";
        namespace = "netbird";
      };
      serviceRef.name = "prometheus-server";
      groups = [ { name = "kubernetes-services"; } ];
    };
  };

  kubernetes.resources.networkresources.immich-server = {
    metadata.namespace = "immich";
    spec = {
      networkRouterRef = {
        name = "cluster";
        namespace = "netbird";
      };
      serviceRef.name = "immich-server";
      groups = [ { name = "kubernetes-services"; } ];
    };
  };

  kubernetes.resources.networkresources.kubernetes = {
    metadata.namespace = "default";
    spec = {
      networkRouterRef = {
        name = "cluster";
        namespace = "netbird";
      };
      serviceRef.name = "kubernetes";
      groups = [ { name = "kubernetes-services"; } ];
    };
  };
}
