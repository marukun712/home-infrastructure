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

  kubernetes.resources.namespaces = {
    local-path-storage.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
    };
    metallb-system.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
      "pod-security.kubernetes.io/audit" = "privileged";
      "pod-security.kubernetes.io/warn" = "privileged";
    };
    monitoring.metadata.labels = {
      "pod-security.kubernetes.io/enforce" = "privileged";
      "pod-security.kubernetes.io/audit" = "privileged";
      "pod-security.kubernetes.io/warn" = "privileged";
    };
  };

  kubernetes.resources.namespaces.immich = { };

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

  kubernetes.resources.ipaddresspools.default-pool = {
    metadata.namespace = "metallb-system";
    spec.addresses = [ "192.168.20.240-192.168.20.250" ];
  };
  kubernetes.resources.l2advertisements.default = {
    metadata.namespace = "metallb-system";
    spec.ipAddressPools = [ "default-pool" ];
  };

  kubernetes.helm.releases.metallb = {
    chart = metallbChart;
    namespace = "metallb-system";
    values.frrk8s.enabled = false;
  };
}
