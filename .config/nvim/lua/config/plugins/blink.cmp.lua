return {
    "saghen/blink.cmp",
    dependencies = {
        "rafamadriz/friendly-snippets",
        "kristijanhusak/vim-dadbod-completion",
    },
    version = "*",
    ---@module "blink.cmp"
    ---@type blink.cmp.Config
    opts = {
        keymap = {
            preset = "default",
            ["<C-1>"] = { function(cmp) cmp.accept({ index = 1 }) end },
            ["<C-2>"] = { function(cmp) cmp.accept({ index = 2 }) end },
            ["<C-3>"] = { function(cmp) cmp.accept({ index = 3 }) end },
            ["<C-4>"] = { function(cmp) cmp.accept({ index = 4 }) end },
            ["<C-5>"] = { function(cmp) cmp.accept({ index = 5 }) end },
            ["<C-6>"] = { function(cmp) cmp.accept({ index = 6 }) end },
            ["<C-7>"] = { function(cmp) cmp.accept({ index = 7 }) end },
            ["<C-8>"] = { function(cmp) cmp.accept({ index = 8 }) end },
            ["<C-9>"] = { function(cmp) cmp.accept({ index = 9 }) end },
            ["<C-0>"] = { function(cmp) cmp.accept({ index = 10 }) end },
        },
        appearance = {
            use_nvim_cmp_as_default = true,
            nerd_font_variant = "mono"
        },

        completion = {
            menu = {
                draw = {
                    columns = {
                        { "item_idx" },
                        { "label",     "label_description", gap = 1 },
                        { "kind_icon", "kind" }
                    },
                    components = {
                        item_idx = {
                            text = function(ctx)
                                return ctx.idx == 10 and "0" or ctx.idx >= 10 and " " or
                                    tostring(ctx.idx)
                            end,
                            highlight = "BlinkCmpItemIdx"
                        }
                    },
                }
            },
        },

        sources = {
            default = { "lsp", "path", "snippets", "buffer", "dadbod" },
            providers = {
                dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
            }
        },
    },
    opts_extend = { "sources.default" }
}
