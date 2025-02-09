if status is-interactive
    # Commands to run in interactive sessions can go here
end

fish_vi_key_bindings

source ~/.config/fish/aliases

starship init fish | source
