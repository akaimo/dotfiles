syntax on
colorscheme molokai


if has('vim_starting')
  set rtp+=~/.vim/bundle/neobundle.vim
endif
call neobundle#begin()
NeoBundleFetch 'Shougo/neobundle.vim'

NeoBundle 'tpope/vim-endwise'

call neobundle#end()
filetype plugin indent on

if !has('vim_starting')
  call neobundle#call_hook('on_source')
endif


"graphical
set number
set title
set list
set listchars=tab:»-,trail:-,eol:↲,extends:»,precedes:«,nbsp:%
set ruler
set wrap
set showcmd

"encodie
set encoding=utf8
set fileencoding=utf-8

"space, tab, indent
set ambiwidth=double
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent

"backup, swap
set noswapfile
set nowritebackup
set nobackup

"control
set clipboard=unnamed,autoselect
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

filetype plugin indent on
