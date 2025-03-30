vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)

  use {'wbthomason/packer.nvim', opt = true}

  use {
	  'nvim-telescope/telescope.nvim', tag = '0.1.5',
	  requires = { {'nvim-lua/plenary.nvim'} }
  }

  use { "catppuccin/nvim", as = "catppuccin" }

  use { "nvim-treesitter/nvim-treesitter", { run = ":TSUpdate" } }
  use { "nvim-treesitter/playground" }

  use {'kevinhwang91/nvim-ufo', requires = 'kevinhwang91/promise-async'}

  use { "theprimeagen/harpoon" }

  use { "mbbill/undotree" }

  use { "tpope/vim-fugitive" }

  use { "andweeb/presence.nvim" }

  use { "folke/zen-mode.nvim" }
  use { "folke/twilight.nvim" }

  use {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup({
        toggler = {
          line = 'gcc',
          block = 'gbc',
        }
      })
    end
  }

  use {
      'nvim-lualine/lualine.nvim',
      requires = { 'nvim-tree/nvim-web-devicons', opt = true }
  }

  use { "christoomey/vim-tmux-navigator" }

  use({
      "iamcco/markdown-preview.nvim",
      run = function()
        vim.fn["mkdp#util#install"]()
      end,
      setup = function()
        local g = vim.g
        g.mkdp_preview_options = {
          disable_filename = 1,
        }
      end,
  })

  use {
      "nvim-neo-tree/neo-tree.nvim",
      branch = "v3.x",
      requires = {
          "nvim-lua/plenary.nvim",
          "nvim-tree/nvim-web-devicons",
          "MunifTanjim/nui.nvim",
      }
  }

  use {
	  'VonHeikemen/lsp-zero.nvim',
	  branch = 'v3.x',
	  requires = {

		  -- LSP Support
		  {'neovim/nvim-lspconfig'},
		  {'williamboman/mason.nvim'},
		  {'williamboman/mason-lspconfig.nvim'},

		  -- Autocompletion
		  {'hrsh7th/nvim-cmp'},
		  {'hrsh7th/cmp-buffer'},
		  {'hrsh7th/cmp-path'},
		  {'hrsh7th/cmp-nvim-lua'},
		  {'hrsh7th/cmp-nvim-lsp'},
		  {'saadparwaiz1/cmp_luasnip'},

		  -- Snippets
		  {'L3MON4D3/LuaSnip'},
		  {'rafamadriz/friendly-snippets'},
	  }
  }

end)
