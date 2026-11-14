function cashu --description 'Start pi on a numes org-cashu-devs model'
    set -l provider numes-org-cashu-devs

    if test (count $argv) -eq 0; or contains -- --help $argv; or contains -- -h $argv
        echo "Usage: cashu <model> [extra pi arguments...]"
        echo
        echo "Starts pi (via numes run pi) on a numes org-cashu-devs model."
        echo "Tab-complete the model name; short unique names work (e.g. 'cashu glmf')."
        return 0
    end

    set -l models \
        dealignai/glm-5.3-flash-uncensored-fp8:org-cashu-devs \
        dealignai/glm-5.3-uncensored-fp8:org-cashu-devs \
        deepseek/deepseek-v4.1-flash-1017-uncensored:org-cashu-devs \
        deepseek/deepseek-v4.1-flash-1017:org-cashu-devs \
        uniboshi/kimi-k3-abliterated-v1:org-cashu-devs \
        z-ai/glm-5.3-flash:org-cashu-devs \
        z-ai/glm-5.3:org-cashu-devs

    set -l query $argv[1]
    set -l matches

    # Exact (full-ID) match first, then substring match.
    if contains -- $query $models
        set matches $query
    else
        for m in $models
            if string match -q -- "*$query*" $m
                set -a matches $m
            end
        end
    end

    switch (count $matches)
        case 0
            echo "cashu: no org-cashu-devs model matches '$query'" >&2
            echo "Available: "(string replace --all ':org-cashu-devs' '' $models | string join ', ') >&2
            return 1
        case 1
            numes run pi --provider $provider --model $matches[1] $argv[2..-1]
        case '*'
            echo "cashu: '$query' is ambiguous:" >&2
            printf '  %s\n' $matches >&2
            return 1
    end
end

function __cashu_models
    printf '%s\n' \
        dealignai/glm-5.3-flash-uncensored-fp8:org-cashu-devs \
        dealignai/glm-5.3-uncensored-fp8:org-cashu-devs \
        deepseek/deepseek-v4.1-flash-1017-uncensored:org-cashu-devs \
        deepseek/deepseek-v4.1-flash-1017:org-cashu-devs \
        uniboshi/kimi-k3-abliterated-v1:org-cashu-devs \
        z-ai/glm-5.3-flash:org-cashu-devs \
        z-ai/glm-5.3:org-cashu-devs
end

complete -c cashu -f
complete -c cashu -n 'test (count (commandline -opc)) -eq 1' -a "(__cashu_models)" -d 'org-cashu-devs model'
