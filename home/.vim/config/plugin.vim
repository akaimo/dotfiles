if isdirectory(expand("~/.vim/plugged/nerdtree"))
  let NERDTreeShowHidden=1
endif

if isdirectory(expand("~/.vim/plugged/vim-auto-save"))
  let g:auto_save = 1
  let g:auto_save_in_insert_mode = 0
endif

if isdirectory(expand("~/.vim/plugged/indentLine"))
  let g:indentLine_color_term = 239
  let g:indentLine_char = '¦'
endif

if isdirectory(expand("~/.vim/plugged/vim-json"))
  let g:vim_json_syntax_conceal = 0
endif

if isdirectory(expand("~/.vim/plugged/fern.vim"))
  let g:fern#default_hidden = 1
endif

if isdirectory(expand("~/.vim/plugged/vim-vsnip"))
  let g:vsnip_snippet_dir = expand('~/.vim/vsnip')
endif

