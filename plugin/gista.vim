if exists('g:loaded_gista')
  finish
endif
let g:loaded_gista = 1

command! -nargs=? -range=% -bang
      \ -complete=customlist,gista#command#complete
      \ Gista
      \ :call gista#command#command(<q-bang>, [<line1>, <line2>], <f-args>)

augroup vim_gista_read_file
  autocmd!
  autocmd BufReadCmd  gista://* call gista#autocmd#call('BufReadCmd')
  autocmd FileReadCmd gista://* call gista#autocmd#call('FileReadCmd')
  try
    autocmd SourceCmd gista://* call gista#autocmd#call('SourceCmd')
  catch /-Vim\%((\a\+)\)\=E216/
    autocmd SourcePre gista://* call gista#autocmd#call('SourceCmd')
  endtry
augroup END

augroup vim_gista_write_file
  autocmd BufWriteCmd  gista://* call gista#autocmd#call('BufWriteCmd')
  autocmd FileWriteCmd gista://* call gista#autocmd#call('FileWriteCmd')
augroup END
