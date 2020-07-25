if !filereadable(expand("~/.vim/autoload/plug.vim"))
  finish
endif

call plug#begin('~/.vim/plugged')

Plug 'prabirshrestha/vim-lsp'
Plug 'prabirshrestha/async.vim'

Plug 'prabirshrestha/asyncomplete.vim'
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <expr> <CR>    pumvisible() ? "\<C-y>" : "\<CR>"
imap <F5> <Plug>(asyncomplete_force_refresh)

Plug 'prabirshrestha/asyncomplete-buffer.vim'
Plug 'prabirshrestha/asyncomplete-file.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'

Plug 'hrsh7th/vim-vsnip'
Plug 'hrsh7th/vim-vsnip-integ'

" You can use other key to expand snippet.
imap <expr> <C-j>   vsnip#available(1)  ? '<Plug>(vsnip-expand)'         : '<C-j>'
" Expand selected placeholder with <C-j> (see https://github.com/hrsh7th/vim-vsnip/pull/51)
smap <expr> <C-j>   vsnip#expandable()  ? '<Plug>(vsnip-expand)'         : '<C-j>'
imap <expr> <C-l>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
" Jump to the next placeholder with <C-l>
smap <expr> <C-l>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
imap <expr> <C-n>   vsnip#available(1)  ? '<Plug>(vsnip-jump-next)'      : '<C-n>'
smap <expr> <C-n>   vsnip#available(1)  ? '<Plug>(vsnip-jump-next)'      : '<C-n>'
imap <expr> <S-Tab> vsnip#available(-1) ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>'
smap <expr> <S-Tab> vsnip#available(-1) ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>'

Plug 'hashivim/vim-terraform' , { 'for': 'terraform'}

" Check syntax (linting) and fix files asynchronously
Plug 'w0rp/ale'

nmap <C-L> :ALEFix<CR>
nmap <C-A>p :ALEDetail<CR>

" Comment functions
Plug 'tyru/caw.vim'
nmap <C-K> <Plug>(caw:zeropos:toggle)
vmap <C-K> <Plug>(caw:zeropos:toggle)

" Auto close parentheses
Plug 'cohama/lexima.vim'

" fuzzy finder
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
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

" fzf mapping
nnoremap <Leader>f :Files<CR>
nnoremap <Leader>s :Rg<CR>
nnoremap <Leader>b :Buffer<CR>

" tree explorer
Plug 'scrooloose/nerdtree'
let NERDTreeShowHidden=1
map <Leader>t :NERDTreeToggle<CR>

" auto save
Plug 'vim-scripts/vim-auto-save'
let g:auto_save = 1
let g:auto_save_in_insert_mode = 0

" shows a git diff
Plug 'airblade/vim-gitgutter'

" status bar
Plug 'itchyny/lightline.vim'
Plug 'tpope/vim-fugitive'
Plug 'maximbaz/lightline-ale'

Plug 'Yggdroot/indentLine'
let g:indentLine_color_term = 239
let g:indentLine_char = '¦'

Plug 'elzr/vim-json'
let g:vim_json_syntax_conceal = 0

call plug#end()

