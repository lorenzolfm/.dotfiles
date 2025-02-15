-- TODO
-- []: sql lsp capabilities
-- []: make telescope grepable on the dotfiles dir
-- []: make telescope open already opened buffer window instead of opening a new window

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

local plugins = {
    'wbthomason/packer.nvim',
    'nvim-tree/nvim-web-devicons',
    'ellisonleao/gruvbox.nvim',
    'nvim-lualine/lualine.nvim',
    'mhinz/vim-startify',
    'tpope/vim-fugitive',
    'lewis6991/gitsigns.nvim',
    'scrooloose/nerdcommenter',
    'simrat39/rust-tools.nvim',
    'nvimdev/lspsaga.nvim',
    'kristijanhusak/vim-dadbod-completion',
    {
        'saghen/blink.cmp',
        dependencies = 'rafamadriz/friendly-snippets',
        version = '*',
        ---@module 'blink.cmp'
        ---@type blink.cmp.Config
        opts = {
            keymap = { preset = 'default' },
            appearance = {
                use_nvim_cmp_as_default = true,
                nerd_font_variant = 'mono'
            },

            sources = {
                default = { 'lsp', 'path', 'snippets', 'buffer', 'dadbod' },
                providers = {
                    dadbod = { name = 'Dadbod', module = 'vim_dadbod_completion.blink' }
                }
            },
        },
        opts_extend = { "sources.default" }
    },
    {
        'neovim/nvim-lspconfig',
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
        }
    },
    'j-hui/fidget.nvim',
    'github/copilot.vim',
    {
        'stevearc/oil.nvim',
        config = function()
            require('oil').setup {
                view_options = {
                    show_hidden = true
                }
            }
            vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
        end
    },
    {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate'
    },
    {
        'nvim-telescope/telescope.nvim',
        -- version = '0.1.8',
        dependencies = { { 'nvim-lua/plenary.nvim' } },
    },
    {
        'folke/noice.nvim',
        dependencies = {
            'MunifTanjim/nui.nvim',
            'rcarriga/nvim-notify',
        }
    },
    {
        'ThePrimeagen/harpoon',
        dependencies = 'nvim-lua/plenary.nvim'
    },
    {
        'kristijanhusak/vim-dadbod-ui',
        dependencies = 'tpope/vim-dadbod',
    },
    {
        "folke/flash.nvim",
        event = "VeryLazy",
        ---@type Flash.Config
        opts = {},
        keys = {
            { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
            { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
            { "r",     mode = { "o" },           function() require("flash").remote() end,            desc = "Remote Flash" },
            { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
            { "<c-s>", mode = { "c" },           function() require("flash").toggle() end,            desc = "Toggle Flash Search" },
        },
    },
}

require("lazy").setup(plugins, {})
