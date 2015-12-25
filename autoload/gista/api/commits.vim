let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')

function! gista#api#commit#list(gistid, ...) abort
  call gista#util#prompt#throw(
        \ 'Not implemented yet'
        \)
endfunction

" Configure variables
call gista#define_variables('api#commit', {})

let &cpo = s:save_cpo
unlet! s:save_cpo
