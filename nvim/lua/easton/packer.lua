vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)

  use 'wbthomason/packer.nvim'

  use {
	  'nvim-telescope/telescope.nvim', tag = '0.1.5',
	  requires = { {'nvim-lua/plenary.nvim'} }
  }

  use { "catppuccin/nvim", as = "catppuccin" }

  use { "nvim-treesitter/nvim-treesitter", { run = ":TSUpdate" } }
  use { "nvim-treesitter/playground" }

  use { "theprimeagen/harpoon" }

  use { "mbbill/undotree" }

  use { "tpope/vim-fugitive" }

  use { "folke/zen-mode.nvim" }
  use { "folke/twilight.nvim" }

  use { 'numtoStr/Comment.nvim' }

  use {
      'nvim-lualine/lualine.nvim',
      requires = { 'nvim-tree/nvim-web-devicons', opt = true }
  }

  use { "christoomey/vim-tmux-navigator" }

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
