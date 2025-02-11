source ~/.config/fish/aliases

if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -g fish_greeting

fish_vi_key_bindings

direnv hook fish | source

atuin init fish | source
starship init fish | source
zoxide init fish | source
