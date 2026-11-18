{
  kubenix,
  pkgs,
  lib,
  config,
  ...
}:
let
  lppSrc = pkgs.fetchFromGitHub {
    owner = "rancher";
    repo = "local-path-provisioner";
    rev = "v0.0.37";
    hash = "sha256-H/YuDKAXmh8TpkSuIo/v1v12mxmO2qWOCB638PSdLEs=";
  };
  lppChart = pkgs.runCommand "local-path-provisioner-chart" { } ''
    cp -r ${lppSrc}/deploy/chart/local-path-provisioner $out
  '';

  certManagerChart = kubenix.lib.helm.fetch {
    repo = "https://charts.jetstack.io";
    chart = "cert-manager";
    version = "v1.21.3";
    sha256 = "sha256-kjGAYWkePhiNrUUdpesTcGa9jlpFk1/gZs8sztLElRw=";
  };
in
{
  imports = with kubenix.modules; [
    k8s
    helm
  ];

  kubenix.project = "my-cluster";
  kubernetes.version = "1.37";

  kubernetes.resources.namespaces = {
    local-path-storage.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
    };
    monitoring.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
      "pod-security.kubernetes.io/audit" = "privileged";
      "pod-security.kubernetes.io/warn" = "privileged";
    };
  };

  kubernetes.resources.namespaces.immich = { };

  kubernetes.resources.namespaces.cert-manager = { };

  kubernetes.helm.releases.local-path-provisioner = {
    chart = lppChart;
    namespace = "local-path-storage";
    values = {
      storageClass.defaultClass = true;
      nodePathMap = [
        {
          node = "DEFAULT_PATH_FOR_NON_LISTED_NODES";
          paths = [ "/var/mnt/local-path-provisioner" ];
        }
      ];
    };
  };

  kubernetes.helm.releases.cert-manager = {
    chart = certManagerChart;
    namespace = "cert-manager";
    overrideNamespace = false;
    values.crds.enabled = true;
  };
}
