if !filereadable(expand("~/.vim/autoload/plug.vim"))
  finish
endif

call plug#begin('~/.vim/plugged')

Plug 'prabirshrestha/vim-lsp'
Plug 'prabirshrestha/async.vim'
Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-buffer.vim'
Plug 'prabirshrestha/asyncomplete-file.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'

Plug 'hrsh7th/vim-vsnip'
Plug 'hrsh7th/vim-vsnip-integ'

Plug 'hashivim/vim-terraform', { 'for': 'terraform' }
Plug 'elzr/vim-json', { 'for': 'json' }

" Check syntax (linting) and fix files asynchronously
Plug 'w0rp/ale'

" Comment functions
Plug 'tyru/caw.vim'
" Auto close parentheses
Plug 'cohama/lexima.vim'

" fuzzy finder
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'

" tree explorer
Plug 'scrooloose/nerdtree'

" auto save
Plug 'vim-scripts/vim-auto-save'

" shows a git diff
Plug 'airblade/vim-gitgutter'

" status bar
Plug 'itchyny/lightline.vim'
Plug 'tpope/vim-fugitive'
Plug 'maximbaz/lightline-ale'

" display the indention levels with thin vertical lines
Plug 'Yggdroot/indentLine'

call plug#end()

