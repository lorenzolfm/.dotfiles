-- Updates every plugin as far as its spec allows, then writes a Markdown list of the pins that
-- moved, each with a compare link, to the file named by $UPDATE_SUMMARY.
--
-- XDG_CONFIG_HOME=$PWD/.config nvim --headless --cmd "luafile .github/nvim-update.lua"

local function pins(lockfile)
    local commits = {}
    for name, pin in pairs(vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n"))) do
        commits[name] = pin.commit
    end
    return commits
end

local function moved(name, url, from, to)
    if url == nil then
        return ("- %s: `%s` → `%s`"):format(name, from:sub(1, 7), to:sub(1, 7))
    end
    return ("- [%s](%s/compare/%s...%s)"):format(name, (url:gsub("%.git$", "")), from:sub(1, 7), to:sub(1, 7))
end

local function update()
    local config = require("lazy.core.config")
    local before = pins(config.options.lockfile)
    require("lazy").update({ wait = true, show = false })
    local after = pins(config.options.lockfile)

    local lines = {}
    for name, commit in vim.spairs(after) do
        if before[name] == nil then
            table.insert(lines, ("- %s: added at `%s`"):format(name, commit:sub(1, 7)))
        elseif before[name] ~= commit then
            local plugin = config.plugins[name]
            table.insert(lines, moved(name, plugin and plugin.url, before[name], commit))
        end
    end
    vim.fn.writefile(lines, vim.env.UPDATE_SUMMARY)
end

vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = vim.schedule_wrap(function()
        local ok, err = pcall(update)
        if not ok then
            io.stderr:write(err, "\n")
        end
        vim.cmd(ok and "qall!" or "cquit 1")
    end),
})
