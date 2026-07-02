function skills --description 'npx skills, showing dotfiles changes for manual handling'
    npx skills $argv
    set -l rc $status
    if contains -- "$argv[1]" add remove update
        set -l changes (git -C ~/.dotfiles status --short .agents .claude/skills)
        if test -n "$changes"
            echo "skills: changes in ~/.dotfiles (stage & commit yourself):"
            printf '%s\n' $changes
        end
    end
    return $rc
end
