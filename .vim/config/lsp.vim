if !isdirectory(expand("~/.vim/plugged/vim-lsp"))
  finish
endif

let g:lsp_log_verbose = 1
let g:lsp_log_file = expand('/tmp/vim-lsp.log')

let g:lsp_diagnostics_enabled = 0         " disable diagnostics support

nnoremap <C-]> :LspDefinition<CR>
nnoremap <Leader>h :LspHover<CR>

if executable('clangd')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'clangd',
        \ 'cmd': {server_info->['clangd', '-background-index']},
        \ 'whitelist': ['c', 'cpp', 'objc', 'objcpp', 'cc'],
        \ })
endif

augroup LspGo
  au!
  autocmd User lsp_setup call lsp#register_server({
      \ 'name': 'go-lang',
      \ 'cmd': {server_info->['gopls']},
      \ 'whitelist': ['go'],
      \ 'workspace_config': {'gopls': {
      \     'completeUnimported': v:true,
      \     'caseSensitiveCompletion': v:true,
      \     'usePlaceholders': v:true,
      \     'completionDocumentation': v:true,
      \     'watchFileChanges': v:true,
      \     'experimentalWorkspaceModule': v:true,
      \   }},
      \ })
  autocmd FileType go setlocal omnifunc=lsp#complete
augroup END

if executable('pyls')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'pyls',
        \ 'cmd': { server_info -> ['pyls'] },
        \ 'whitelist': ['python'],
        \ 'workspace_config': {'pyls': {'plugins': {
        \   'jedi_definition': {'follow_imports': v:true, 'follow_builtin_imports': v:true},}}}
        \})
endif

if executable('typescript-language-server')
  au User lsp_setup call lsp#register_server({
        \ 'name': 'typescript-language-server',
        \ 'cmd': {server_info->[&shell, &shellcmdflag, 'typescript-language-server --stdio']},
        \ 'root_uri':{server_info->lsp#utils#path_to_uri(lsp#utils#find_nearest_parent_file_directory(lsp#utils#get_buffer_path(), 'package.json'))},
        \ 'whitelist': ['typescript', 'typescript.tsx', 'javascript', 'javascript.jsx'],
        \ })
endif

au User lsp_setup call lsp#register_server({
   \ 'name': 'intelephense',
   \ 'cmd': {server_info->['node', expand(substitute(system('npm root -g'), "\n", "", "g") . '/intelephense/lib/intelephense.js'), '--stdio']},
   \ 'initialization_options': {"storagePath": "/tmp/intelephense"},
   \ 'whitelist': ['php'],
   \ })

au User lsp_setup call lsp#register_server({
 \ 'name': 'yaml-language-server',
 \ 'cmd': {server_info->['node', expand(substitute(system('npm root -g'), "\n", "", "g") . '/yaml-language-server/out/server/src/server.js'), '--stdio']},
 \ 'whitelist': ['yaml'],
 \ })

if executable('terraform-ls')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'terraform-ls',
        \ 'cmd': {server_info->['terraform-ls', 'serve']},
        \ 'whitelist': ['terraform'],
        \ })
endif

if executable('vim-language-server')
  au User lsp_setup call lsp#register_server({
        \ 'name': 'vim-language-server',
        \ 'cmd': {server_info->['node', expand(substitute(system('npm root -g'), "\n", "", "g") . '/vim-language-server/bin/index.js'), '--stdio']},
        \ 'whitelist': ['vim'],
        \ })
endif

