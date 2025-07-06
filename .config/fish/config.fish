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

function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
