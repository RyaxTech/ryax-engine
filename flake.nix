{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          devShell = (pkgs.buildFHSEnv {
            name = "dev-shell";
            targetPkgs = pkgs: [ pkgs.uv ];
          }).env;

          formatter = pkgs.nixpkgs-fmt;
        }
      );
}
