{
  description = "My home infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    {
      nixosConfigurations = {
        router = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./router.nix ];
        };

        photo = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./photo.nix ];
        };

        services = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./services.nix ];
        };
      };
    };
}
