{
  description = "Agda dev environment: standard-library + agda-categories, typecheck and literate-LaTeX apps";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system: f system (import nixpkgs { inherit system; })
        );

      sourcesFind = ''
        find . \( -name .git -o -name _build -o -name .direnv -o -name latex \) -prune \
          -o -type f \( -name '*.agda' -o -name '*.lagda' -o -name '*.lagda.tex' -o -name '*.lagda.md' \) -print | sort
      '';
    in
    {
      packages = eachSystem (
        system: pkgs: rec {
          agda-with-libs = pkgs.agda.withPackages (p: [
            p.standard-library
            p.agda-categories
          ]);

          typecheck = pkgs.writeShellApplication {
            name = "typecheck-agda";
            runtimeInputs = [ agda-with-libs ];
            text = ''
              shopt -s nullglob
              agda_libs=(*.agda-lib)
              shopt -u nullglob
              if (( ''${#agda_libs[@]} == 0 )); then
                echo "typecheck-agda: no *.agda-lib in $PWD" >&2
                exit 1
              fi
              fail=0
              while IFS= read -r f; do
                echo "-- agda $f"
                agda "$f" || fail=1
              done < <(${sourcesFind})
              if (( fail )); then echo "FAIL  Agda"; exit 1; else echo "PASS  Agda"; fi
            '';
          };

          doc = pkgs.writeShellApplication {
            name = "doc-agda";
            runtimeInputs = [ agda-with-libs ];
            text = ''
              while IFS= read -r f; do
                case "$f" in
                  *.lagda.tex)
                    dir=$(dirname "$f")
                    echo "-- agda --latex $f"
                    agda --latex --latex-dir="$dir/latex" "$f"
                    ;;
                esac
              done < <(${sourcesFind})
            '';
          };
        }
      );

      lib = eachSystem (
        system: pkgs: {
          mkBuild =
            {
              src,
              name ? "agda-build",
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
                ${self.packages.${system}.typecheck}/bin/typecheck-agda > "$out/typecheck.log" 2>&1
                status=$?
                set -e
                if [ "$status" -eq 0 ]; then echo PASS > "$out/status"; else echo "FAIL ($status)" > "$out/status"; fi
                tail -n 20 "$out/typecheck.log"
                if [ "$status" -eq 0 ]; then
                  ${self.packages.${system}.doc}/bin/doc-agda 2>&1 | tee "$out/doc.log"
                  find . -type d -name latex -exec cp -r --parents {} "$out/" \;
                fi
                ${if strict then ''[ "$status" -eq 0 ] || exit "$status"'' else ""}
              '';
              installPhase = "true";
            };
        }
      );

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = with self.packages.${system}; [
              agda-with-libs
              typecheck
              doc
            ];
          };
        }
      );

      apps = eachSystem (
        system: pkgs: {
          typecheck = {
            type = "app";
            program = "${self.packages.${system}.typecheck}/bin/typecheck-agda";
          };
          doc = {
            type = "app";
            program = "${self.packages.${system}.doc}/bin/doc-agda";
          };
        }
      );
    };
}
