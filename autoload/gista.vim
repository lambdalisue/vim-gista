let s:save_cpo = &cpo
set cpo&vim

function! gista#vital() abort
  if !exists('s:V')
    let s:V = vital#of('vim_gista')
  endif
  return s:V
endfunction
function! gista#define_variables(prefix, defaults) abort
  " Note:
  "   Funcref is not supported while the variable must start with a capital
  let prefix = empty(a:prefix)
        \ ? 'g:gista'
        \ : printf('g:gista#%s', a:prefix)
  for [key, value] in items(a:defaults)
    let name = printf('%s#%s', prefix, key)
    if !exists(name)
      silent execute printf('let %s = %s', name, string(value))
    endif
    unlet value
  endfor
endfunction

function! gista#indicate(options, message) abort
  if get(a:options, 'verbose')
    redraw | call gista#util#prompt#echo(a:message)
  endif
endfunction

call gista#define_variables('', {
      \ 'debug': 0,
      \ 'develop': 1,
      \})

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
