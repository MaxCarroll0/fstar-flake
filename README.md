# fstar-flake

Nix dev environment for F*. App: `typecheck` verifies every `.fst`/`.fsti` under `$PWD`, passing each containing directory as `--include` so cross-module references resolve.

## Use

```sh
# .envrc — pin an exact commit; bump deliberately, one update at a time
use flake "github:MaxCarroll0/fstar-flake?rev=<sha>"
```

## Commands

```sh
nix run 'github:MaxCarroll0/fstar-flake?rev=<sha>#typecheck'
```

Emacs: `fstar-mode` (MELPA) picks up `fstar.exe` from the direnv PATH.
