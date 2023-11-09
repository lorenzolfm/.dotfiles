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
    'tpope/vim-rhubarb',
    'lewis6991/gitsigns.nvim',
    'scrooloose/nerdcommenter',
    'simrat39/rust-tools.nvim',
    'nvimdev/lspsaga.nvim',
    'github/copilot.vim',
    'windwp/nvim-autopairs',
    'ellisonleao/carbon-now.nvim',
    'kristijanhusak/vim-dadbod-completion',
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
    'neovim/nvim-lspconfig',
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/nvim-cmp',
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',
    'hrsh7th/cmp-cmdline',
    'L3MON4D3/LuaSnip',
    {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate'
    },
    {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v3.x'
    },
    {
        'nvim-telescope/telescope.nvim',
        version = '0.1.4',
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
        'j-hui/fidget.nvim',
        version = 'legacy',
    },
    {
        'ggandor/leap.nvim',
        dependencies = 'tpope/vim-repeat',
        config = function()
            require('leap').add_default_mappings();
        end
    },
    {
        'ThePrimeagen/harpoon',
        dependencies = 'nvim-lua/plenary.nvim'
    },
    {
        'kristijanhusak/vim-dadbod-ui',
        dependencies = 'tpope/vim-dadbod',
    },
}

require("lazy").setup(plugins, {})
