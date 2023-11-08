require 'nvim-treesitter.configs'.setup {
    ensure_installed = {
        "gitcommit",
        "javascript",
        "lua",
        "proto",
        "rust",
        "typescript",
        "vim",
    },
    sync_install = false,
    auto_install = true,
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
    },
}

vim.api.nvim_command("set foldmethod=expr")
vim.api.nvim_command("set foldexpr=nvim_treesitter#foldexpr()")
vim.api.nvim_command("set nofoldenable")
