local Worktree = require("git-worktree")
local uv = vim.loop

Worktree.on_tree_change(function(op, metadata)
    if op == Worktree.Operations.Switch or op == Worktree.Operations.Create then
        local files_to_check = { ".env", ".env.lnd" }

        -- Construct the parent directory path based on the worktree path
        local parent_dir = vim.fn.fnamemodify(metadata.path, ":h:h")

        for _, file in ipairs(files_to_check) do
            local src = parent_dir .. "/" .. file
            local dest = metadata.path .. "/" .. file

            -- Check if the file does not exist in the new worktree
            if not uv.fs_stat(dest) then
                -- Copy the file from the parent directory
                local command = string.format("cp -r '%s' '%s'", src, dest)
                os.execute(command)
            end
        end
    end
end)
