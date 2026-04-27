return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local parsers = {
            "gitcommit",
            "javascript",
            "lua",
            "markdown",
            "markdown_inline",
            "proto",
            "rust",
            "svelte",
            "typescript",
            "vim",
            "vimdoc",
        }
        require("nvim-treesitter").install(parsers)

        vim.api.nvim_create_autocmd("FileType", {
            pattern = {
                "gitcommit",
                "javascript",
                "lua",
                "markdown",
                "proto",
                "rust",
                "svelte",
                "typescript",
                "vim",
                "help",
            },
            callback = function()
                vim.treesitter.start()
                vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
                vim.wo[0][0].foldmethod = "expr"
            end,
        })
    end,
}
