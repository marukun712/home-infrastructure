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

  metallbChart = kubenix.lib.helm.fetch {
    repo = "https://metallb.github.io/metallb";
    chart = "metallb";
    version = "0.16.2";
    sha256 = "sha256-ZeF3xM82BKqd0JAtjgiINyWPf6LBXCgwQk3TPedGZrg=";
  };
  metallbValues.frrk8s.enabled = false;

  withDefaultProtocol =
    obj:
    if obj.kind == "Service" && obj ? spec.ports then
      lib.recursiveUpdate obj { spec.ports = map (p: { protocol = "TCP"; } // p) obj.spec.ports; }
    else
      obj;
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
    metallb-system.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
      "pod-security.kubernetes.io/audit" = "privileged";
      "pod-security.kubernetes.io/warn" = "privileged";
    };
  };

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

  kubernetes.helm.releases.metallb = {
    chart = metallbChart;
    namespace = "metallb-system";
    values = metallbValues;
    objects = lib.mkForce (
      map withDefaultProtocol (
        lib.importJSON (
          kubenix.lib.helm.chart2json {
            chart = metallbChart;
            name = "metallb";
            namespace = "metallb-system";
            values = metallbValues;
            kubeVersion = config.kubernetes.version;
          }
        )
      )
    );
  };
}
