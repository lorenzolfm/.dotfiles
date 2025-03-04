return {
    "stevearc/conform.nvim",
    config = function()
        local conform = require("conform");

        conform.setup({
            formatters_by_ft = {
                sql = { "sql_formatter" },
                nix = { "nixfmt" },
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
