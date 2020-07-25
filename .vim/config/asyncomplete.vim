if !isdirectory(expand("~/.vim/plugged/asyncomplete.vim"))
  finish
endif

let g:asyncomplete_log_file = '/tmp/vim.log'

call asyncomplete#register_source(asyncomplete#sources#file#get_source_options({
    \ 'name': 'file',
    \ 'whitelist': ['*'],
    \ 'priority': 10,
    \ 'completor': function('asyncomplete#sources#file#completor')
    \ }))

call asyncomplete#register_source(asyncomplete#sources#buffer#get_source_options({
   \ 'name': 'buffer',
   \ 'allowlist': ['*'],
   \ 'completor': function('asyncomplete#sources#buffer#completor'),
   \ 'config': {
   \    'max_buffer_size': 5000000,
   \  },
   \ }))

