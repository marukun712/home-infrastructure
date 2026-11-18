{
  kubenix,
  lib,
  config,
  ...
}:
let
  prometheusChart = kubenix.lib.helm.fetch {
    repo = "https://prometheus-community.github.io/helm-charts";
    chart = "prometheus";
    version = "29.47.2";
    sha256 = "sha256-6ro1K+ryqrNyo4uq2BQJ/BMVVfSsDSHRuWd5/dZ1gr4=";
  };
in
{
  imports = with kubenix.modules; [
    k8s
    helm
  ];

  kubenix.project = "my-cluster";
  kubernetes.version = "1.37";

  # https://github.com/hall/kubenix/issues/97
  kubernetes.resources.deployments.prometheus-server.spec.template.spec.containers.prometheus-server.ports =
    lib.mkForce [
      {
        containerPort = 9090;
        protocol = "TCP";
      }
    ];

  kubernetes.helm.releases.prometheus = {
    chart = prometheusChart;
    namespace = "monitoring";
    values = {
      server.persistentVolume.size = "20Gi";
    };
  };
}
