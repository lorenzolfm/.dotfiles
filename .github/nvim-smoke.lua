-- Starts the config, loads every plugin, and exits 1 if Neovim showed an error while doing so.
-- An error a plugin hides with `:silent!` is not shown, so it does not count.
--
-- XDG_CONFIG_HOME=$PWD/.config nvim --headless --cmd "luafile .github/nvim-smoke.lua"

local errors = {}
local checked = false
local notify = vim.notify

local error_kinds = { emsg = true, echoerr = true, lua_error = true, rpc_error = true }

vim.ui_attach(vim.api.nvim_create_namespace("nvim-smoke"), { ext_messages = true }, function(event, kind, content)
    if event == "msg_show" and error_kinds[kind] then
        local text = {}
        for _, chunk in ipairs(content) do
            table.insert(text, chunk[2])
        end
        table.insert(errors, table.concat(text))
    end
end)

-- Lazy reports a failing `config`, `init` or `build` through `vim.schedule`.
local function flush()
    local flushed = false
    vim.schedule(function()
        flushed = true
    end)
    vim.wait(5000, function()
        return flushed
    end)
end

local function check()
    local lazy = require("lazy")
    for _, plugin in ipairs(lazy.plugins()) do
        lazy.load({ plugins = { plugin } })
        -- noice replaces `vim.notify`, and would swallow the errors of every plugin after it.
        vim.notify = notify
        flush()
        if not plugin._.loaded then
            table.insert(errors, plugin.name .. " did not load")
        end
    end
    io.stdout:write(#lazy.plugins() .. " plugins loaded\n")
end

-- A config that makes Neovim quit during start-up would otherwise pass.
vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        if not checked then
            io.stderr:write("Neovim exited before the smoke test ran\n")
            os.exit(1)
        end
    end,
})

vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = vim.schedule_wrap(function()
        local ok, err = pcall(check)
        if not ok then
            table.insert(errors, err)
        end
        checked = true
        for _, msg in ipairs(errors) do
            io.stderr:write(msg, "\n")
        end
        vim.cmd(#errors == 0 and "qall!" or "cquit 1")
    end),
})
