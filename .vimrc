syntax on
colorscheme molokai

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

"auto insert
inoremap {<Enter> {}<Left><CR><ESC><S-o>
inoremap [ []<LEFT>
inoremap ( ()<LEFT>
"inoremap < <><LEFT>
inoremap " ""<LEFT>
inoremap ' ''<LEFT>
function! DeleteParenthesesAdjoin()
    let pos = col(".") - 1
    let str = getline(".")
    let parentLList = ["(", "[", "{", "\'", "\""]
    let parentRList = [")", "]", "}", "\'", "\""]
    let cnt = 0
    let output = ""

    if pos == strlen(str)
        return "\b"
    endif
    for c in parentLList
        if str[pos-1] == c && str[pos] == parentRList[cnt]
            call cursor(line("."), pos + 2)
            let output = "\b"
            break
        endif
        let cnt += 1
    endfor
    return output."\b"
endfunction
inoremap <silent> <BS> <C-R>=DeleteParenthesesAdjoin()<CR>
