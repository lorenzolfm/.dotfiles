function claude --description 'Run Claude Code, adding work-only settings inside work checkouts'
    # Work-specific auto mode rules live outside this public repo. The
    # classifier ignores autoMode in a repo's .claude/ files, so pass them
    # per invocation with --settings instead of putting them in user settings.
    set -l work_root ~/Projects/blindpay-v2
    set -l work_settings ~/.config/claude-blindpay/settings.json
    if string match -q -- "$work_root*" $PWD; and test -f $work_settings
        command claude --settings $work_settings $argv
    else
        command claude $argv
    end
end
