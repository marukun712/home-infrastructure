{ kubenix, ... }:
let
  grafanaChart = kubenix.lib.helm.fetch {
    repo = "https://grafana.github.io/helm-charts";
    chart = "grafana";
    version = "10.5.15";
    sha256 = "sha256-Mu0AEXTV5xU9zMrmFkHWJRQyOrmDSZeMwKMXEpS7Gy8=";
  };
in
{
  imports = with kubenix.modules; [
    k8s
    helm
  ];

  kubenix.project = "my-cluster";
  kubernetes.version = "1.37";

  kubernetes.helm.releases.grafana = {
    chart = grafanaChart;
    namespace = "monitoring";
    noHooks = true;
    values = {
      service.type = "LoadBalancer";
      persistence = {
        enabled = true;
        size = "10Gi";
      };
      admin.existingSecret = "grafana-admin";
      datasources."datasources.yaml" = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://prometheus-server.monitoring.svc.cluster.local";
            isDefault = true;
          }
        ];
      };
    };
  };
}
