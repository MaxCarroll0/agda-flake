# agda-flake

Nix dev environment for Agda, wrapped with **standard-library** and **agda-categories**. Apps: `typecheck` (all `.agda`/`.lagda*` under `$PWD`, requires a `*.agda-lib`) and `doc` (runs `agda --latex` on each `.lagda.tex`, emitting into `<section>/latex/`).

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

The result contains `typecheck.log`, a `status` file (`PASS`/`FAIL`), and generated artifacts where applicable. The build itself succeeds either way so the log is always inspectable; pass `strict = true;` to fail the build on a typecheck error. Planned: a generated index of postulates, holes, and incomplete proofs alongside the log.
