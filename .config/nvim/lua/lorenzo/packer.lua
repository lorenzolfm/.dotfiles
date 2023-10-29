vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
    use { 'wbthomason/packer.nvim' }

    -- Colorscheme
    use { 'ellisonleao/gruvbox.nvim' }

    -- Statusline
    use {
        'nvim-lualine/lualine.nvim',
        requires = { 'nvim-tree/nvim-web-devicons', opt = true }
    }
    -- A fancy start screen
    use { 'mhinz/vim-startify' }

    -- Git
    use { 'tpope/vim-fugitive' }
    use { 'tpope/vim-rhubarb' }
    use { 'lewis6991/gitsigns.nvim' }

    -- Commenting code
    use { 'scrooloose/nerdcommenter' }

    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v3.x',
        requires = {
            -- LSP Support
            { 'neovim/nvim-lspconfig' },             -- Required
            { 'williamboman/mason.nvim' },           -- Optional
            { 'williamboman/mason-lspconfig.nvim' }, -- Optional

            -- Autocompletion
            { 'hrsh7th/nvim-cmp' },     -- Required
            { 'hrsh7th/cmp-nvim-lsp' }, -- Required
            { 'hrsh7th/cmp-buffer' },   -- Optional
            { 'hrsh7th/cmp-path' },     -- Optional
            { 'hrsh7th/cmp-cmdline' },  -- Optional

            -- Snippets
            { 'L3MON4D3/LuaSnip' }, -- Required
        }
    }

    use { 'simrat39/rust-tools.nvim' }

    use {
        'nvimdev/lspsaga.nvim',
        after = 'nvim-lspconfig',
    }

    use { 'nvim-treesitter/nvim-treesitter', { run = ':TSUpdate' } }

    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.4',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }

    use { 'j-hui/fidget.nvim', tag = 'legacy' }

    use { 'nvim-tree/nvim-web-devicons' }

    use {
        'folke/noice.nvim',
        requires = {
            'MunifTanjim/nui.nvim',
            'rcarriga/nvim-notify',
        }
    }

    use {
        'ggandor/leap.nvim',
        dependencies = 'tpope/vim-repeat',
        config = function()
            require('leap').add_default_mappings();
        end
    }

    use {
        'ThePrimeagen/harpoon',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }

    use { 'github/copilot.vim' }

    use { 'windwp/nvim-autopairs' }

    use { 'ellisonleao/carbon-now.nvim' }

    use { 'tpope/vim-dadbod' }

    use { 'kristijanhusak/vim-dadbod-completion' }

    use {
        'kristijanhusak/vim-dadbod-ui',
        dependencies = {
            { 'tpope/vim-dadbod' },
        },
    }
end)
