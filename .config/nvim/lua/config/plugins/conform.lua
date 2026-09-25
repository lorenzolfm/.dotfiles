return {
    "stevearc/conform.nvim",
    config = function()
        local conform = require("conform");

        conform.setup({
            formatters_by_ft = {
                sql = { "sql_formatter" },
                swift = { "swift_format" },
                -- Prefer the repo's own `nix fmt` when its flake declares a
                -- formatter (the CI gate uses the same one); nixfmt otherwise.
                nix = { "nix_fmt", "nixfmt", stop_after_first = true },
                yaml = { "yamlfmt" },
            },
            formatters = {
                nix_fmt = {
                    command = "nix",
                    args = { "fmt", "--", "$FILENAME" },
                    stdin = false,
                    cwd = require("conform.util").root_file({ "flake.nix" }),
                    require_cwd = true,
                    condition = function(_, ctx)
                        local root = require("conform.util").root_file({ "flake.nix" })(nil, ctx)
                        if not root then
                            return false
                        end
                        local f = io.open(root .. "/flake.nix")
                        if not f then
                            return false
                        end
                        local text = f:read("a")
                        f:close()
                        return text:find("formatter%s*=") ~= nil
                    end,
                },
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
