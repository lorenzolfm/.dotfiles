return {
    "stevearc/conform.nvim",
    config = function()
        local conform = require("conform");

        conform.setup({
            formatters_by_ft = {
                sql = { "sql_formatter" },
                nix = { "nixfmt" },
                yaml = { "yamlfmt" },
            },
            formatters = {
                -- Run yamlfmt from the project root so it discovers a repo-local
                -- `.yamlfmt` regardless of nvim's cwd. Repos that ship one (e.g.
                -- homelab) tune yamlfmt to match their yamllint CI gate.
                yamlfmt = {
                    cwd = require("conform.util").root_file({ ".yamlfmt", ".git" }),
                },
            },
        })

        vim.api.nvim_create_autocmd("BufWritePre", {
            pattern = "*",
            callback = function(args)
                require("conform").format({ bufnr = args.buf })
            end,
        })
    end,
}
