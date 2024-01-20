{
  description = "Nix Flake for Julia Environment";

  inputs = {
    nixpkgs-julia.url = "github:NixOS/nixpkgs/?ref=refs/pull/225513/head";

    systems.url = "github:nix-systems/x86_64-linux";
    utils.url = "github:numtide/flake-utils";
    utils.inputs.systems.follows = "systems";

    devshell.url = "github:numtide/devshell";
  };

  outputs = { self, nixpkgs, utils, nixpkgs-julia, devshell, ... }: utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; overlays = [ devshell.overlays.default ]; };
      l = pkgs.lib // builtins;

      julia = nixpkgs-julia.legacyPackages.${system}.julia_19;
      # pluto manages environment for each notebook independently, so there is no need to include `Plots` here.
      plutoEnv = (julia.withPackages
        [
          "Pluto"
        ]);
    in
    {

      packages = {
        pluto = with pkgs; writeShellScriptBin "plutoEnv" ''
          export PATH=${
            l.strings.makeBinPath [
              plutoEnv
            ]
          }
          julia -e "import Pluto; Pluto.run()"
        '';

        jlfmt = with pkgs; writeShellScriptBin "jlfmt" ''
          export PATH=${
            l.strings.makeBinPath [
              (julia.withPackages [ "ArgParse" "JuliaFormatter" ])
            ]
          }
          julia ${./misc/jlfmt.jl}
        '';
      };

      apps = rec {
        fmt = utils.lib.mkApp {
          drv = with pkgs; writeShellScriptBin "fmt" ''
            export PATH=${
              l.strings.makeBinPath [
                findutils
                nixpkgs-fmt
                shfmt
                shellcheck
              ]
            }
            find . -type f -name '*.sh' -exec shellcheck {} +
            find . -type f -name '*.sh' -exec shfmt -w {} +
            find . -type f -name '*.nix' -exec nixpkgs-fmt {} +
          '';
        };

        jlfmt = utils.lib.mkApp {
          drv = self.packages.${system}.jlfmt;
        };

        pluto = utils.lib.mkApp {
          drv = self.packages.${system}.pluto;
        };
        default = pluto;
      };

      devShells = rec {
        default = pkgs.devshell.mkShell {
          commands = with pkgs; [
            {
              name = "fmt";
              command = self.apps.${system}.fmt.program;
              help = "Format nix and shell files";
            }
            {
              name = "pluto";
              command = self.apps.${system}.pluto.program;
              help = "Launch Pluto";
            }
            {
              name = "jlfmt";
              command = self.apps.${system}.jlfmt.program;
              help = "Format Julia codes";
            }
          ];

          packages = [
            julia
          ];
          name = "devShell with Julia";
        };
      };
    });
}
