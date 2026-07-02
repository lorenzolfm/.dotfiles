function skills --description 'npx skills, staging changes in dotfiles for review'
    npx skills $argv
    set -l rc $status
    if contains -- "$argv[1]" add remove update
        git -C ~/.dotfiles add .agents .claude/skills
        if not git -C ~/.dotfiles diff --cached --quiet
            echo "skills: staged the following in ~/.dotfiles (review, then commit):"
            git -C ~/.dotfiles status --short .agents .claude/skills
        end
    end
    return $rc
end
