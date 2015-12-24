let s:save_cpo = &cpo
set cpo&vim

command! -nargs=? -range=% -bang
      \ -complete=customlist,gista#command#complete
      \ Gista
      \ :call gista#command#command(<q-bang>, [<line1>, <line2>], <f-args>)

augroup vim_gista_read_file
  autocmd!
  autocmd SourceCmd   gista:*:*:* call gista#autocmd#call('SourceCmd')
  autocmd BufReadCmd  gista:*:*:* call gista#autocmd#call('BufReadCmd')
  autocmd FileReadCmd gista:*:*:* call gista#autocmd#call('FileReadCmd')

  autocmd BufReadCmd  gista:*:*.json call gista#autocmd#call('BufReadCmd')
  autocmd FileReadCmd gista:*:*.json call gista#autocmd#call('FileReadCmd')

  autocmd BufReadCmd  gista-list:*:* call gista#autocmd#call('BufReadCmd')
  autocmd BufReadCmd  gista-list:*:*/* call gista#autocmd#call('BufReadCmd')
  autocmd FileReadCmd gista-list:*:* call gista#autocmd#call('FileReadCmd')
  autocmd FileReadCmd gista-list:*:*/* call gista#autocmd#call('FileReadCmd')
augroup END

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
