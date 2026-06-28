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

# Bind kubectl to a cluster based on directory, so the wrong cluster can't be
# inherited between terminals. Unknown dirs unset KUBECONFIG → no silent default.
function __kube_autoselect --on-variable PWD
    switch $PWD
        case '/home/lorenzo/Projects/misc/homelab' '/home/lorenzo/Projects/misc/homelab/*'
            set -gx KUBECONFIG ~/.kube/homelab.yaml
        case '/home/lorenzo/Projects/Work' '/home/lorenzo/Projects/Work/*'
            set -gx KUBECONFIG ~/.kube/work.yaml
        case '*'
            set -e KUBECONFIG
    end
end
__kube_autoselect

function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
