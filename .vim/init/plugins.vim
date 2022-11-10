" Function to source only if file exists {
function! SourceIfExists(file)
  if filereadable(expand(a:file))
    exe 'source' a:file
  endif
endfunction
" }

call plug#begin()
" The default plugin directory will be as follows:
"   - Vim (Linux/macOS): '~/.vim/plugged'
"   - Vim (Windows): '~/vimfiles/plugged'
"   - Neovim (Linux/macOS/Windows): stdpath('data') . '/plugged'
" You can specify a custom plugin directory by passing it as the argument
"   - e.g. `call plug#begin('~/.vim/plugged')`
"   - Avoid using standard Vim directory names like 'plugin'

" Make sure you use single quotes

Plug 'AndrewRadev/splitjoin.vim'             " Switch between single-line and multiline forms of code
Plug 'RRethy/vim-illuminate'                 " illuminate.vim - Vim plugin for automatically highlighting other uses of the word under the cursor. Integrates with Neovim's LSP client for intelligent highlighting.
if !has("nvim")
  " Replaced by lewis6991/gitsigns.nvim in NeoVim
  Plug 'airblade/vim-gitgutter'              " A Vim plugin which shows git diff markers in the sign column and stages/previews/undoes hunks and partial hunks.
endif
Plug 'bfontaine/Brewfile.vim'                " Brewfile syntax for Vim
Plug 'editorconfig/editorconfig-vim'         " EditorConfig plugin for Vim
Plug 'farmergreg/vim-lastplace'              " Intelligently reopen files at your last edit position in Vim.
Plug 'francoiscabrol/ranger.vim'             " Ranger integration in vim and neovim
Plug 'junegunn/fzf'                          " 🌸 A command-line fuzzy finder
Plug 'junegunn/fzf.vim'                      " fzf ❤️ vim
Plug 'junegunn/vim-easy-align'               " 🌻 A Vim alignment plugin
Plug 'kdheepak/lazygit.nvim'                 " Plugin for calling lazygit from within neovim.
Plug 'mtdl9/vim-log-highlighting'            " Provides syntax highlighting for generic log files in VIM.
if has("nvim")
  Plug 'lukas-reineke/indent-blankline.nvim' " Indent guides for Neovim
else
  Plug 'nathanaelkane/vim-indent-guides'     " A Vim plugin for visually displaying indent levels in code
endif
if has("nvim")
  Plug 'nvim-tree/nvim-web-devicons'         " optional, for file icons
  Plug 'nvim-tree/nvim-tree.lua'             " A File Explorer For Neovim Written In Lua

  Plug 'folke/lsp-colors.nvim'               " 🌈 Plugin that creates missing LSP diagnostics highlight groups for color schemes that don't yet support the Neovim 0.5 builtin LSP client.
  Plug 'folke/trouble.nvim'                  " 🚦 A pretty diagnostics, references, telescope results, quickfix and location list to help you solve all the trouble your code is causing.

  Plug 'junnplus/lsp-setup.nvim'             " A simple wrapper for nvim-lspconfig and mason-lspconfig to easily setup LSP servers.
  Plug 'neovim/nvim-lspconfig'               " Quickstart configs for Nvim LSP
  Plug 'williamboman/mason.nvim'             " Portable package manager for Neovim that runs everywhere Neovim runs. Easily install and manage LSP servers, DAP servers, linters, and formatters.

  Plug 'lukas-reineke/lsp-format.nvim'       " A wrapper around Neovims native LSP formatting.

  Plug 'nvim-lua/plenary.nvim'               " plenary: full; complete; entire; absolute; unqualified. All the lua functions I don't want to write twice.
  Plug 'jose-elias-alvarez/null-ls.nvim'     " Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua.
  Plug 'jayp0521/mason-null-ls.nvim'         " mason-null-ls bridges mason.nvim with the null-ls plugin - making it easier to use both plugins together.

  Plug 'lewis6991/gitsigns.nvim'             " Git integration for buffers

  Plug 'nvim-treesitter/nvim-treesitter',
    \ {'do': ':TSUpdate'}                    " Nvim Treesitter configurations and abstraction layer

  Plug 'sindrets/diffview.nvim'              " Single tabpage interface for easily cycling through diffs for all modified files for any git rev.
endif
Plug 'nishigori/increment-activator'         " Vim Plugin for enhance to increment candidates U have defined.
Plug 'gruvbox-community/gruvbox'             " Retro groove color scheme for Vim - community maintained edition (with black background)
Plug 'preservim/nerdcommenter'               " Vim plugin for intensely nerdy commenting powers
Plug 'rmagatti/auto-session'                 " A small automated session manager for Neovim
Plug 'ruanyl/vim-gh-line'                    " vim plugin that open the link of current line on github
Plug 'ryanoasis/vim-devicons'                " Adds file type icons to Vim plugins such as: NERDTree, vim-airline, CtrlP, unite, Denite, lightline, vim-startify and many more
Plug 'skywind3000/asyncrun.vim'              " 🚀 Run Async Shell Commands in Vim 8.0 / NeoVim and Output to the Quickfix Window !!
Plug 'tmux-plugins/vim-tmux'                 " Vim plugin for .tmux.conf
Plug 'tpope/vim-abolish'                     " abolish.vim: easily search for, substitute, and abbreviate multiple variants of a word
Plug 'tpope/vim-commentary'                  " commentary.vim: comment stuff out
Plug 'tpope/vim-dispatch'                    " dispatch.vim: Asynchronous build and test dispatcher
Plug 'tpope/vim-endwise'                     " endwise.vim: Wisely add
Plug 'tpope/vim-eunuch'                      " eunuch.vim: Helpers for UNIX
Plug 'tpope/vim-fugitive'                    " fugitive.vim: A Git wrapper so awesome, it should be illegal
Plug 'tpope/vim-repeat'                      " repeat.vim: enable repeating supported plugin maps with '.'
Plug 'tpope/vim-sensible'                    " sensible.vim: Defaults everyone can agree on
Plug 'tpope/vim-sleuth'                      " sleuth.vim: Heuristically set buffer options
Plug 'tpope/vim-speeddating'                 " speeddating.vim: use CTRL-A/CTRL-X to increment dates, times, and more
Plug 'tpope/vim-surround'                    " surround.vim: Delete/change/add parentheses/quotes/XML-tags/much more with ease
Plug 'tpope/vim-unimpaired'                  " unimpaired.vim: Pairs of handy bracket mappings
if has("nvim")
  Plug 'kdheepak/tabline.nvim'
  Plug 'nvim-lualine/lualine.nvim'           " A blazing fast and easy to configure neovim statusline plugin written in pure lua.
else
  Plug 'vim-airline/vim-airline'             " lean & mean status/tabline for vim that's light as air
  Plug 'vim-airline/vim-airline-themes'      " A collection of themes for vim-airline
endif

Plug 'vim-test/vim-test'                     " Run your tests at the speed of thought
Plug 'wsdjeg/vim-fetch'                      " Make Vim handle line and column numbers in file names with a minimum of fuss

call SourceIfExists("~/.vim/init/specific-plugins.vim")

" Initialize plugin system
call plug#end()

" Optional: Auto-install plugins if directory does not yet exist
if has("nvim")
  let s:plugged_dir = stdpath('data') . '/plugged'
else
  let s:plugged_dir=expand('$HOME/.vim/plugged')
endif
if ! isdirectory(s:plugged_dir)
  PlugInstall
endif

