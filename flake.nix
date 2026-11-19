{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    kubenix = {
      url = "github:hall/kubenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      kubenix,
      terranix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        render = module: (kubenix.evalModules.${system} { inherit module; }).config.kubernetes.result;
      in
      {
        packages = {
          infra = render ./k8s/infra.nix;
          grafana = render ./k8s/grafana.nix;
          prometheus = render ./k8s/prometheus.nix;
          immich = render ./k8s/immich.nix;
          netbird = render ./k8s/netbird.nix;
          caddy = render ./k8s/caddy.nix;
          wg-relay = render ./k8s/wg-relay.nix;
          netbird-tf = terranix.lib.terranixConfiguration {
            inherit pkgs;
            modules = [ ./tf/netbird.nix ];
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            talosctl
            kubectl
            kubernetes-helm
            age
            sops
            biome
            ansible
            opentofu
          ];
          shellHook = ''
            export TALOSCONFIG="$PWD/talosconfig"
            export KUBECONFIG="$PWD/kubeconfig"
          '';
        };
      }
    );
}
