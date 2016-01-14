let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:C = s:V.import('Vim.Compat')

function! gista#util#clip(content) abort
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction

function! gista#util#doautocmd(name) abort
  let expr = printf('User Gista%s', a:name)
  call s:C.doautocmd(expr, 1)
endfunction

function! gista#util#ensure_eol(text) abort
  return a:text =~# '\n$' ? a:text : a:text . "\n"
endfunction

function! gista#util#handle_exception(exception) abort
  redraw
  let known_exception_patterns = [
        \ '^vim-gista: Cancel',
        \ '^vim-gista: Login canceled',
        \ '^vim-gista: ValidationError:',
        \]
  for pattern in known_exception_patterns
    if a:exception =~# pattern
      call gista#util#prompt#warn(matchstr(a:exception, '^vim-gista: \zs.*'))
      return
    endif
  endfor
  " else
  call gista#util#prompt#error(a:exception)
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
