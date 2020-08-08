if !isdirectory(expand("~/.vim/plugged/ale"))
  finish
endif

let g:ale_fix_on_save = 0
let g:ale_fix_on_text_changed = 'never'
let g:ale_sign_column_always = 1

let g:ale_linters = {
\   'go': ['gopls', 'go vet', 'golint'],
\   'python': ['flake8'],
\   'yaml': ['yamllint'],
\}
let g:ale_fixers = {
\   'go': ['gofmt'],
\   'python': ['black', 'isort'],
\   'terraform': ['terraform'],
\   'yaml': ['prettier'],
\}

let g:ale_python_flake8_options = '--max-line-length=88'

