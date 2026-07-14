# agda-flake

Nix dev environment for Agda, wrapped with **standard-library** and **agda-categories**. Apps: `typecheck` (all `.agda`/`.lagda*` under `$PWD`, requires a `*.agda-lib` or `.agda-lib`), `doc` (runs `agda --latex` on each `.lagda.tex`, emitting into `<section>/latex/`), and `scan-postulates-and-holes` (reports Agda `postulate` declarations and proof holes as Org links to their source locations).

## Use

```sh
# .envrc — follow HEAD (picks up updates automatically)
use flake "github:MaxCarroll0/agda-flake"

# or pin an exact commit for reproducibility, bumping deliberately
use flake "github:MaxCarroll0/agda-flake?rev=<sha>"
```

## Commands

```sh
nix run 'github:MaxCarroll0/agda-flake#typecheck'
nix run 'github:MaxCarroll0/agda-flake#doc'
nix run 'github:MaxCarroll0/agda-flake#scan-postulates-and-holes'
```

## Emacs

Do not pin agda2-mode globally; load the elisp shipped with this flake's agda so mode and binary always match:

```elisp
(load-file (string-trim (shell-command-to-string "agda-mode locate")))
```

run from a buffer whose direnv environment has this flake on PATH. PDF compilation of the generated LaTeX is handled by org-literate-flake (or any latexmk with `agda.sty` from the `latex/` output dir on `TEXINPUTS`).

## Ground-up builds

Build hermetically from scratch with `nix build` (typecheck + document outputs as a derivation; no devshell involved). From the project root:

```sh
nix build --impure --expr \
  '(builtins.getFlake "github:MaxCarroll0/agda-flake").lib.${builtins.currentSystem}.mkBuild { src = ./.; }'
```

The result contains `typecheck.log`, a `status` file (`PASS`/`FAIL`), `postulates-and-holes.org` from the Haskell scanner, and generated artifacts where applicable. The build itself succeeds either way so the log and scanner report are always inspectable; pass `strict = true;` to fail the build on a typecheck error.

## Formatting

`nix run .#fmt` (binary `fmt-agda`) normalizes sources: trailing whitespace stripped, final newline ensured (these languages have no standard formatter, so formatting is deliberately conservative). Entering the devshell installs a git pre-commit hook that runs every `fmt-*` binary on the PATH over staged files and re-stages them, so stacked language flakes compose. `nix fmt` formats the flake's own nix code (nixfmt-rfc-style). A `.envrc` is included for using this repo directly.
