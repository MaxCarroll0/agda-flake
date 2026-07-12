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
          fmt = pkgs.writeShellApplication {
            name = "fmt-agda";
            text = ''
              if (( $# )); then files=("$@"); else mapfile -t files < <(git ls-files 2>/dev/null); fi
              for f in "''${files[@]}"; do
                [[ -f "$f" && "$f" =~ \.agda$|\.lagda$|\.lagda\.tex$|\.lagda\.md$ ]] || continue
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
              fmt
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
            program = "${self.packages.${system}.typecheck}/bin/typecheck-agda";
          };
          doc = {
            type = "app";
            program = "${self.packages.${system}.doc}/bin/doc-agda";
          };
          fmt = {
            type = "app";
            program = "${self.packages.${system}.fmt}/bin/fmt-agda";
          };
        }
      );

      formatter = eachSystem (system: pkgs: pkgs.nixfmt-rfc-style);
    };
}
