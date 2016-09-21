let s:V = gista#vital()
let s:Compat = s:V.import('Vim.Compat')
let s:Guard = s:V.import('Vim.Guard')

function! gista#util#clip(content) abort
  let @" = a:content
  if has('clipboard')
    call setreg(v:register, a:content)
  endif
endfunction

function! gista#util#doautocmd(name, ...) abort
  let guard = s:Guard.store(['g:gista#avars'])
  let g:gista#avars = extend(
        \ get(g:, 'gista#avars', {}),
        \ get(a:000, 0, {})
        \)
  try
    let expr = printf('User Gista%s', a:name)
    call s:Compat.doautocmd(expr, 1)
  finally
    call guard.restore()
  endtry
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
