let s:save_cpo = &cpo
set cpo&vim

let s:disable_interactive = 0

function! s:ensure_string(x) abort
  return type(a:x) == type('')
        \ ? a:x
        \ : string(a:x)
endfunction
function! s:echo(hl, msg) abort
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echo m
    endfor
  finally
    echohl None
  endtry
endfunction
function! s:echomsg(hl, msg) abort
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echomsg m
    endfor
  finally
    echohl None
  endtry
endfunction
function! s:input(hl, msg, ...) abort
  if s:disable_interactive
    return ''
  endif
  execute 'echohl' a:hl
  try
    if empty(get(a:000, 1, ''))
      return input(a:msg, get(a:000, 0, ''))
    else
      return input(a:msg, get(a:000, 0, ''), get(a:000, 1, ''))
    endif
  finally
    echohl None
  endtry
endfunction
function! s:inputlist(hl, msg, candidates, ...) abort
  if s:disable_interactive
    return 0
  endif
  execute 'echohl' a:hl
  try
    let candidates = map(
          \ copy(a:candidates),
          \ 'printf("%d. %s", v:key+1, v:val)'
          \)
    return inputlist(extend([a:msg], candidates))
  finally
    echohl None
  endtry
endfunction
function! s:throw(msg) abort
  let msg = type(a:msg) == type([]) ? join(a:msg, "\n") : a:msg
  throw printf('vim-gista: %s', msg)
endfunction


function! gista#util#prompt#echo(...) abort
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('None', join(args))
endfunction
function! gista#util#prompt#debug(...) abort
  if !g:gista#debug
    return
  endif
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('Comment', 'DEBUG: vim-gista: ' . join(args))
endfunction
function! gista#util#prompt#info(...) abort
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('Title', join(args))
endfunction
function! gista#util#prompt#warn(...) abort
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('WarningMsg', join(args))
endfunction
function! gista#util#prompt#error(...) abort
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('Error', join(args))
endfunction
function! gista#util#prompt#throw(...) abort
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:throw(args)
endfunction

function! gista#util#prompt#echomsg(...) abort
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('None', join(args))
endfunction
function! gista#util#prompt#debugmsg(...) abort
  if !g:gista#debug
    return
  endif
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('Comment', 'DEBUG: vim-gista: ' . join(args))
endfunction
function! gista#util#prompt#infomsg(...) abort
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('Title', join(args))
endfunction
function! gista#util#prompt#warnmsg(...) abort
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('WarningMsg', join(args))
endfunction
function! gista#util#prompt#errormsg(...) abort
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('Error', join(args))
endfunction

function! gista#util#prompt#input(msg, ...) abort
  let result = s:input(
        \ 'None', a:msg,
        \ get(a:000, 0, ''),
        \ get(a:000, 1, ''),
        \)
  redraw
  return result
endfunction
function! gista#util#prompt#inputlist(msg, candidates) abort
  let result = s:inputlist('Question', a:msg, a:candidates)
  redraw
  return result
endfunction
function! gista#util#prompt#ask(msg, ...) abort
  let result = s:input(
        \ 'Question', a:msg,
        \ get(a:000, 0, ''),
        \ get(a:000, 1, ''),
        \)
  redraw
  return result
endfunction
function! gista#util#prompt#asktf(msg, ...) abort
  let result = gista#util#prompt#ask(
        \ printf('%s (y[es]/n[o]): ', a:msg),
        \ get(a:000, 0, ''),
        \ 'customlist,gista#util#prompt#_asktf_complete_yes_or_no',
        \)
  while result !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if result ==# ''
      call gista#util#prompt#warn('Canceled.')
      break
    endif
    call gista#util#prompt#error('Invalid input.')
    let result = gista#util#prompt#ask(
          \ printf('%s (y[es]/n[o]): ', a:msg),
          \ get(a:000, 0, ''),
          \ 'customlist,gista#util#prompt#_asktf_complete_yes_or_no',
          \)
  endwhile
  redraw
  return result =~? 'y\%[es]'
endfunction
function! gista#util#prompt#_asktf_complete_yes_or_no(arglead, cmdline, cursorpos) abort
  return filter(['yes', 'no'], 'v:val =~# "^" . a:arglead')
endfunction

function! gista#util#prompt#enable_interactive() abort
  let s:disable_interactive = 0
endfunction
function! gista#util#prompt#disable_interactive() abort
  let s:disable_interactive = 1
endfunction


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
