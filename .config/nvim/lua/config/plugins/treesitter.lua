return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
        local treesitter = require("nvim-treesitter.configs")

        treesitter.setup({
              -- A list of parser names, or "all" (the listed parsers MUST always be installed)
              ensure_installed = {
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
                "vim",
                "vimdoc",
            },

            -- Install parsers synchronously (only applied to `ensure_installed`)
            sync_install = false,

          -- Automatically install missing parsers when entering buffer
          -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
          auto_install = true,

              -- List of parsers to ignore installing (or "all")
              ignore_install = {},

              highlight = {
                enable = true,

                -- Disable treesitter on large files
                disable = function(lang, buf)
                    local max_filesize = 100 * 1024 -- 100 KB
                    local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
                    if ok and stats and stats.size > max_filesize then
                        return true
                    end
                end,

                additional_vim_regex_highlighting = false,
              },
        })

        vim.api.nvim_command("set foldmethod=expr")
        vim.api.nvim_command("set foldexpr=nvim_treesitter#foldexpr()")
        vim.api.nvim_command("set nofoldenable")
    end
}
