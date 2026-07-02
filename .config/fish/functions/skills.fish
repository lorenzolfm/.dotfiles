function skills --description 'npx skills, auto-committing changes into dotfiles'
    npx skills $argv
    set -l rc $status
    if contains -- "$argv[1]" add remove update
        git -C ~/.dotfiles add .agents .claude/skills
        if not git -C ~/.dotfiles diff --cached --quiet
            git -C ~/.dotfiles commit -m "chore(skills): skills $argv"
        end
    end
    return $rc
end
