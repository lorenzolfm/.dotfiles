return {
    "neovim/nvim-lspconfig",
    dependencies = {
        {
            "folke/lazydev.nvim",
            ft = "lua",
            opts = {
                library = {
                    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
                },
            },
        }
    },
    config = function()
        local lspconfig = require("lspconfig")
        local keymap = vim.keymap.set

        keymap("n", "gd", function() vim.lsp.buf.definition() end)
        keymap("n", "gh", function() vim.lsp.buf.references() end)
        keymap("n", "<leader>d", function() vim.diagnostic.open_float() end)
        keymap("n", "[e", function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR }) end)
        keymap("n", "]e", function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR }) end)
        keymap("n", "<F2>", function() vim.lsp.buf.rename() end);

        vim.diagnostic.config({
            signs = {
                text = {
                    [vim.diagnostic.severity.ERROR] = "🔺",
                    [vim.diagnostic.severity.WARN] = "🔸",
                    [vim.diagnostic.severity.HINT] = "▫️",
                    [vim.diagnostic.severity.INFO] = "🔹",
                }
            }
        })

        vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                local client = vim.lsp.get_client_by_id(args.data.client_id)
                if not client then return end

                if client.supports_method("textDocument/formatting") then
                    vim.api.nvim_create_autocmd("BufWritePre", {
                        buffer = args.buf,
                        callback = function()
                            vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
                        end,
                    })
                end
            end,
        })

        local capabilities = require("blink.cmp").get_lsp_capabilities()

        local servers = {
            bashls = { single_file_support = true, capabilities = capabilities },
            jq = { single_file_support = true, capabilities = capabilities },
            lua_ls = { capabilities = capabilities },
            nil_ls = { single_file_support = true, capabilities = capabilities },
            protols = { single_file_support = true, capabilities = capabilities },
            rust_analyzer = { capabilities = capabilities },
            svelte = { single_file_support = true, capabilities = capabilities },
            yamlls = { single_file_support = true, capabilities = capabilities },
        };

        for server, config in pairs(servers) do
            lspconfig[server].setup(config);
        end;
    end
}
