syntax on
colorscheme molokai

if filereadable(expand("~/.local/share/nvim/site/autoload/plug.vim"))
  if filereadable(expand("~/.config/nvim/vimrc.plugin"))
    source ~/.config/nvim/vimrc.plugin
  endif
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
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent

"backup, swap
set noswapfile
set nowritebackup
set nobackup

"control
set clipboard=unnamed
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
