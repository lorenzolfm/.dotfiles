{
  description = "Lorenzo's dotfiles, and the gates every change to them passes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [inputs.treefmt-nix.flakeModule];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem = {
        pkgs,
        lib,
        ...
      }: let
        lock = (lib.importJSON ./.agents/.skill-lock.json).skills;
        locked = lib.attrNames lock;
        installed = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.agents/skills));

        # A gate passes when its script exits 0.
        gate = name: tools: script:
          pkgs.runCommand name {nativeBuildInputs = tools;} ''
            export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR
            ${script}
            touch $out
          '';

        fail = message: ''
          echo ${lib.escapeShellArg message} >&2
          failed=1
        '';
      in {
        treefmt = {
          projectRootFile = "flake.nix";
          programs = {
            actionlint.enable = true;
            alejandra.enable = true;
            fish_indent = {
              enable = true;
              includes = ["*.fish" ".config/fish/aliases"];
            };
            rustfmt = {
              enable = true;
              # rust-script's edition, which runs the hooks.
              edition = "2021";
            };
            shellcheck = {
              enable = true;
              includes = ["*.sh" ".local/bin/cargo-notify"];
            };
            stylua = {
              enable = true;
              settings = {
                indent_type = "Spaces";
                indent_width = 4;
                call_parentheses = "Input";
              };
            };
            taplo.enable = true;
          };
          settings = {
            on-unmatched = "debug";
            global.excludes = [
              # Installed from upstream and pinned by the lock file, so a local edit is lost on update.
              ".agents/skills/**"
              # Written by wt, which would undo any formatting on its next save.
              ".config/wt/config.toml"
            ];
          };
        };

        # One derivation per gate, so a failure in one does not hide the others.
        checks =
          {
            hooks = gate "hooks" [pkgs.clippy pkgs.rustc] ''
              for hook in ${./.claude/hooks}/*.rs; do
                clippy-driver --edition 2021 --crate-type bin --emit metadata -D warnings -o "$TMPDIR/hook" "$hook"
              done
            '';

            fish = gate "fish" [pkgs.fish] ''
              for file in $(find ${./.config/fish} -type f); do
                fish --no-execute "$file"
              done
            '';

            json = gate "json" [pkgs.jq] ''
              jq empty \
                ${./.claude/settings.json} \
                ${./.agents/.skill-lock.json} \
                ${./.config/hypr/.luarc.json} \
                ${./.config/nvim/lazy-lock.json} \
                ${./.config/waybar/config.jsonc}
            '';

            zellij = gate "zellij" [pkgs.zellij] ''
              zellij --config ${./.config/zellij/config.kdl} setup --check
            '';

            # Every installed skill is one the lock file pins, byte for byte: the lock records
            # each skill's git tree hash, so a local edit, which `skills update` would silently
            # overwrite, changes the hash.
            skills = gate "skills" [pkgs.git] ''
              failed=
              ${lib.concatMapStrings (name: fail "${name} is not in .agents/.skill-lock.json. Publish it to lorenzolfm/skills and install it with `skills add`.")
                (lib.subtractLists locked installed)}
              ${lib.concatMapStrings (name: fail "${name} is in .agents/.skill-lock.json but not installed.")
                (lib.subtractLists installed locked)}

              export GIT_DIR=$TMPDIR/git GIT_WORK_TREE=${./.agents/skills}
              git init --quiet
              git add --all --force
              tree=$(git write-tree)
              ${lib.concatMapStrings (name: ''
                  if [ "$(git rev-parse "$tree:${name}")" != ${lock.${name}.skillFolderHash} ]; then
                    ${fail "${name} differs from the version the lock file pins. Publish the edit upstream, or revert it."}
                  fi
                '')
                (lib.intersectLists installed locked)}

              [ -z "$failed" ]
            '';
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            hyprland = gate "hyprland" [pkgs.hyprland] ''
              Hyprland --verify-config --config ${./.config/hypr/hyprland.lua}
            '';
          };

        devShells = {
          # Plugins clone with git, fff and blink fetch their binaries with curl, and
          # nvim-treesitter compiles parsers with tree-sitter and a C compiler.
          nvim = pkgs.mkShell {
            packages = with pkgs; [
              curl
              git
              neovim
              tree-sitter
            ];
          };

          skills = pkgs.mkShellNoCC {
            packages = with pkgs; [
              git
              nodejs
            ];
          };
        };
      };
    };
}
