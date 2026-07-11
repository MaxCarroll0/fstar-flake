{
  description = "F* dev environment: per-file verification with directory includes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
    }:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system: f system (import nixpkgs { inherit system; })
        );
    in
    {
      packages = eachSystem (
        system: pkgs: rec {
          fstar = pkgs.fstar or (import nixpkgs-unstable { inherit system; }).fstar;

          typecheck = pkgs.writeShellApplication {
            name = "typecheck-fstar";
            runtimeInputs = [ fstar ];
            text = ''
              mapfile -t files < <(
                find . \( -name .git -o -name .direnv -o -name '*.checked' \) -prune \
                  -o -type f \( -name '*.fst' -o -name '*.fsti' \) -print | sort
              )
              if (( ''${#files[@]} == 0 )); then
                echo "typecheck-fstar: no .fst or .fsti files under $PWD" >&2
                exit 1
              fi
              includes=()
              while IFS= read -r d; do
                includes+=(--include "$d")
              done < <(printf '%s\n' "''${files[@]}" | xargs -n1 dirname | sort -u)
              fail=0
              for f in "''${files[@]}"; do
                echo "-- fstar $f"
                fstar.exe "''${includes[@]}" "$f" || fail=1
              done
              if (( fail )); then echo "FAIL  F*"; exit 1; else echo "PASS  F*"; fi
            '';
          };
        }
      );

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              self.packages.${system}.fstar
              self.packages.${system}.typecheck
            ];
          };
        }
      );

      apps = eachSystem (
        system: pkgs: {
          typecheck = {
            type = "app";
            program = "${self.packages.${system}.typecheck}/bin/typecheck-fstar";
          };
        }
      );
    };
}
