" load plugins
if filereadable(expand("~/.config/nvim/dein_init.toml"))
  source ~/.config/nvim/dein_init.toml
endif


" syntax
syntax on
set t_Co=256
colorscheme molokai

" graphical
set number
set title
set list
set listchars=tab:»-,trail:-,eol:↲,extends:»,precedes:«,nbsp:%
" set listchars=tab:>-,trail:-
set ruler
set wrap
set showcmd

" encodie
set encoding=utf8
set fileencoding=utf-8

" space, tab, indent
set ambiwidth=double
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent

" backup, swap
set noswapfile
set nowritebackup
set nobackup

" control
set clipboard=unnamedplus
set nrformats-=octal
set hidden
set history=50
set virtualedit=block
set nostartofline
set whichwrap=b,s,[,],<,>
set backspace=indent,eol,start
set wildmenu
set scrolloff=5
set vb t_vb=
set novisualbell
set noswapfile

filetype plugin indent on
