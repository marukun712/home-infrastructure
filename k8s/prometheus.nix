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
  imports = [ kubenix.modules.k8s ];

  kubenix.project = "my-cluster";
  kubernetes.version = "1.37";

  kubernetes.objects = lib.importJSON (
    kubenix.lib.helm.chart2json {
      chart = prometheusChart;
      name = "prometheus";
      namespace = "monitoring";
      kubeVersion = config.kubernetes.version;
      values = {
        server = {
          service.type = "LoadBalancer";
          persistentVolume.size = "20Gi";
        };
      };
    }
  );
}
