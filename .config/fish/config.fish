if status is-interactive
    # Commands to run in interactive sessions can go here
end

fish_vi_key_bindings

source ~/.config/fish/aliases

atuin init fish | source
starship init fish | source
zoxide init fish | source
