# agda-flake

Nix dev environment for Agda, wrapped with **standard-library** and **agda-categories**. Apps: `typecheck` (all `.agda`/`.lagda*` under `$PWD`, requires a `*.agda-lib`) and `doc` (runs `agda --latex` on each `.lagda.tex`, emitting into `<section>/latex/`).

## Use

```sh
# .envrc — pin an exact commit; bump deliberately, one update at a time
use flake "github:MaxCarroll0/agda-flake?rev=<sha>"
```

## Commands

```sh
nix run 'github:MaxCarroll0/agda-flake?rev=<sha>#typecheck'
nix run 'github:MaxCarroll0/agda-flake?rev=<sha>#doc'
```

## Emacs

Do not pin agda2-mode globally; load the elisp shipped with this flake's agda so mode and binary always match:

```elisp
(load-file (string-trim (shell-command-to-string "agda-mode locate")))
```

run from a buffer whose direnv environment has this flake on PATH. PDF compilation of the generated LaTeX is handled by org-literate-flake (or any latexmk with `agda.sty` from the `latex/` output dir on `TEXINPUTS`).
