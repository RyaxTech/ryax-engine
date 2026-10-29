{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flakeUtils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flakeUtils }:
    # Change values here to support more arch
    flakeUtils.lib.eachSystem [ "aarch64-linux" "x86_64-linux" "x86_64-darwin" ]
      (system:
        let
          pkgs = import nixpkgs { inherit system; };
          python = pkgs.python3;
        in
        {
          devShell = pkgs.mkShell {
            packages = [
              python
              pkgs.uv
              pkgs.ruff
              pkgs.stdenv.cc.cc
              pkgs.kubernetes-helm
              pkgs.scaleway-cli
              pkgs.kubectl
              pkgs.k9s
              pkgs.agent-browser
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.chromium ];
            # agent-browser downloads Chrome for Testing otherwise
            env = pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
              AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
            };
          };
          # Enable autoformat
          formatter = pkgs.nixpkgs-fmt;
        }
      );
}
