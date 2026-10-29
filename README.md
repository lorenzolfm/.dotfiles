# Dotfiles

This is the best config you'll ever lay your eyes upon.

Powered by GNU-Stow

## Checks

`nix fmt` formats everything, and `nix flake check` runs the gates CI runs, except for the two
that need the network (`.github/workflows/ci.yml`). The flake sees only the files git tracks, so
`git add` a new file before checking it.

Every Monday, `.github/workflows/update.yml` opens a pull request for each of Neovim's plugins,
the installed skills, and `flake.lock`.
