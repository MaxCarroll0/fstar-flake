# fstar-flake

Nix dev environment for F*. App: `typecheck` verifies every `.fst`/`.fsti` under `$PWD`, passing each containing directory as `--include` so cross-module references resolve.

## Use

```sh
# .envrc — follow HEAD (picks up updates automatically)
use flake "github:MaxCarroll0/fstar-flake"

# or pin an exact commit for reproducibility, bumping deliberately
use flake "github:MaxCarroll0/fstar-flake?rev=<sha>"
```

## Commands

```sh
nix run 'github:MaxCarroll0/fstar-flake#typecheck'
```

Emacs: `fstar-mode` (MELPA) picks up `fstar.exe` from the direnv PATH.

## Ground-up builds

Build hermetically from scratch with `nix build` (typecheck + document outputs as a derivation; no devshell involved). From the project root:

```sh
nix build --impure --expr \
  '(builtins.getFlake "github:MaxCarroll0/fstar-flake").lib.${builtins.currentSystem}.mkBuild { src = ./.; }'
```

The result contains `typecheck.log`, a `status` file (`PASS`/`FAIL`), and generated artifacts where applicable. The build itself succeeds either way so the log is always inspectable; pass `strict = true;` to fail the build on a typecheck error. Planned: a generated index of postulates, holes, and incomplete proofs alongside the log.
