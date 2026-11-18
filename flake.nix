{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    kubenix = {
      url = "github:hall/kubenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      kubenix,
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
          apps = render ./k8s/apps.nix;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            talosctl
            kubectl
            kubernetes-helm
            age
            sops
          ];
          shellHook = ''
            export TALOSCONFIG="$PWD/talosconfig"
            export KUBECONFIG="$PWD/kubeconfig"
          '';
        };
      }
    );
}
