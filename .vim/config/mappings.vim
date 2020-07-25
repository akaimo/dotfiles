" asyncomplete
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <expr> <CR>    pumvisible() ? "\<C-y>" : "\<CR>"
imap <F5> <Plug>(asyncomplete_force_refresh)

" vsnip
" You can use other key to expand snippet.
imap <expr> <C-j> vsnip#available(1)  ? '<Plug>(vsnip-expand)'         : '<C-j>'
" Expand selected placeholder with <C-j> (see https://github.com/hrsh7th/vim-vsnip/pull/51)
smap <expr> <C-j> vsnip#expandable()  ? '<Plug>(vsnip-expand)'         : '<C-j>'
imap <expr> <C-l> vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
" Jump to the next placeholder with <C-l>
smap <expr> <C-l> vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
imap <expr> <C-n> vsnip#available(1)  ? '<Plug>(vsnip-jump-next)'      : '<C-n>'
smap <expr> <C-n> vsnip#available(1)  ? '<Plug>(vsnip-jump-next)'      : '<C-n>'
imap <expr> <C-b> vsnip#available(-1) ? '<Plug>(vsnip-jump-prev)'      : '<C-b>'
smap <expr> <C-b> vsnip#available(-1) ? '<Plug>(vsnip-jump-prev)'      : '<C-b>'

" ALE
nmap <C-L> :ALEFix<CR>
nmap <C-A>p :ALEDetail<CR>

" caw.vim
nmap <C-K> <Plug>(caw:zeropos:toggle)
vmap <C-K> <Plug>(caw:zeropos:toggle)

" fzf
" Similarly, we can apply it to fzf#vim#grep. To use ripgrep instead of ag:
command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --column --line-number --no-heading --color=always --smart-case '.shellescape(<q-args>), 1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0)

" Likewise, Files command with preview window
command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)

nnoremap <Leader>f :Files<CR>
nnoremap <Leader>s :Rg<CR>
nnoremap <Leader>b :Buffer<CR>

" nerdtree
map <Leader>t :NERDTreeToggle<CR>

