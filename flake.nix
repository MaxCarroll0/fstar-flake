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
          fmt = pkgs.writeShellApplication {
            name = "fmt-fstar";
            text = ''
              if (( $# )); then files=("$@"); else mapfile -t files < <(git ls-files 2>/dev/null); fi
              for f in "''${files[@]}"; do
                [[ -f "$f" && "$f" =~ \.fsti?$ ]] || continue
                sed -i 's/[ \t]*$//' "$f"
                if [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ]; then echo >> "$f"; fi
              done
            '';
          };

          pre-commit-hook = pkgs.writeShellScript "fmt-pre-commit" ''
            set -euo pipefail
            mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACM)
            (( ''${#staged[@]} )) || exit 0
            for fmt in fmt-lean fmt-agda fmt-isabelle fmt-fstar fmt-coq fmt-org fmt-ocaml; do
              command -v "$fmt" >/dev/null 2>&1 || continue
              "$fmt" "''${staged[@]}"
            done
            git add -- "''${staged[@]}"
          '';

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
              fail=0
              for f in "''${files[@]}"; do
                echo "-- fstar $f"
                fstar.exe --include "$(dirname "$f")" "$f" || fail=1
              done
              if (( fail )); then echo "FAIL  F*"; exit 1; else echo "PASS  F*"; fi
            '';
          };
        }
      );

      lib = eachSystem (
        system: pkgs: {
          mkBuild =
            {
              src,
              name ? "fstar-build",
              strict ? false,
            }:
            pkgs.stdenv.mkDerivation {
              inherit name;
              src = nixpkgs.lib.cleanSourceWith {
                inherit src;
                filter =
                  path: _type:
                  !(builtins.elem (baseNameOf path) [
                    ".git"
                    ".lake"
                    ".direnv"
                    "_build"
                    "latex"
                    "output"
                  ]);
              };
              buildPhase = ''
                export HOME="$TMPDIR"
                mkdir -p "$out"
                set +e
                ${self.packages.${system}.typecheck}/bin/typecheck-fstar > "$out/typecheck.log" 2>&1
                status=$?
                set -e
                if [ "$status" -eq 0 ]; then echo PASS > "$out/status"; else echo "FAIL ($status)" > "$out/status"; fi
                tail -n 20 "$out/typecheck.log"
                ${if strict then ''[ "$status" -eq 0 ] || exit "$status"'' else ""}
              '';
              installPhase = "true";
            };
        }
      );

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              self.packages.${system}.fstar
              self.packages.${system}.typecheck
              self.packages.${system}.fmt
            ];
            shellHook = ''
              if [ -d .git ] && [ ! -e .git/hooks/pre-commit ]; then
                install -m 755 ${self.packages.${system}.pre-commit-hook} .git/hooks/pre-commit
                echo "fmt pre-commit hook installed"
              fi
            '';
          };
        }
      );

      apps = eachSystem (
        system: pkgs: {
          typecheck = {
            type = "app";
            program = "${self.packages.${system}.typecheck}/bin/typecheck-fstar";
          };
          fmt = {
            type = "app";
            program = "${self.packages.${system}.fmt}/bin/fmt-fstar";
          };
        }
      );

      formatter = eachSystem (system: pkgs: pkgs.nixfmt-rfc-style);
    };
}
