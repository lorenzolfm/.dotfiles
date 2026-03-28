vim.opt.exrc = true
vim.opt.relativenumber = true
vim.opt.nu = true
vim.opt.hlsearch = false
vim.opt.hidden = true
vim.opt.errorbells = false
vim.opt.wrap = false
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.autoindent = true
vim.opt.incsearch = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.api.nvim_command("set invlist")
vim.opt.list = true
vim.api.nvim_command([[set listchars=eol:¬,trail:⋅,extends:❯,precedes:❮,tab:¦\]])
if vim.env.SSH_TTY then
    local osc52_cache = { ["+"] = {}, ["*"] = {} }
    local osc52 = require("vim.ui.clipboard.osc52")
    vim.g.clipboard = {
        name = "OSC 52",
        copy = {
            ["+"] = function(lines, regtype)
                osc52_cache["+"] = { lines, regtype }
                osc52.copy("+")(lines, regtype)
            end,
            ["*"] = function(lines, regtype)
                osc52_cache["*"] = { lines, regtype }
                osc52.copy("*")(lines, regtype)
            end,
        },
        paste = {
            ["+"] = function() return osc52_cache["+"] end,
            ["*"] = function() return osc52_cache["*"] end,
        },
    }
end
vim.opt.clipboard = "unnamedplus"
vim.opt.inccommand = "split"
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
vim.opt.cursorline = true
vim.opt.updatetime = 300
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.termguicolors = true
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevelstart = 99
