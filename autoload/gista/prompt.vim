let s:save_cpoptions = &cpoptions
set cpoptions&vim

function! s:ensure_string(x) abort " {{{
  return type(a:x) == type('')
        \ ? a:x
        \ : string(a:x)
endfunction " }}}
function! s:echo(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echo m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! s:echomsg(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echomsg m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! s:input(hl, msg, ...) abort " {{{
  if get(g:, 'gita#test')
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
endfunction " }}}

function! gista#prompt#echo(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('None', join(args))
endfunction " }}}
function! gista#prompt#debug(...) abort " {{{
  if !g:gita#debug
    return
  endif
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('Comment', 'DEBUG: vim-gita: ' . join(args))
endfunction " }}}
function! gista#prompt#info(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('Title', join(args))
endfunction " }}}
function! gista#prompt#warn(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('WarningMsg', join(args))
endfunction " }}}
function! gista#prompt#error(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echo('Error', join(args))
endfunction " }}}

function! gista#prompt#echomsg(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('None', join(args))
endfunction " }}}
function! gista#prompt#debugmsg(...) abort " {{{
  if !g:gita#debug
    return
  endif
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('Comment', 'DEBUG: vim-gita: ' . join(args))
endfunction " }}}
function! gista#prompt#infomsg(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('Title', join(args))
endfunction " }}}
function! gista#prompt#warnmsg(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('WarningMsg', join(args))
endfunction " }}}
function! gista#prompt#errormsg(...) abort " {{{
  let args = map(deepcopy(a:000), 's:ensure_string(v:val)')
  call s:echomsg('Error', join(args))
endfunction " }}}

function! gista#prompt#input(msg, ...) abort " {{{
  let result = s:input(
        \ 'None', a:msg,
        \ get(a:000, 0, ''),
        \ get(a:000, 1, ''),
        \)
  redraw
  return result
endfunction " }}}
function! gista#prompt#ask(msg, ...) abort " {{{
  let result = s:input(
        \ 'Question', a:msg,
        \ get(a:000, 0, ''),
        \ get(a:000, 1, ''),
        \)
  redraw
  return result
endfunction " }}}
function! gista#prompt#asktf(msg, ...) abort " {{{
  let result = gista#prompt#ask(
        \ printf('%s (y[es]/n[o]): ', a:msg),
        \ get(a:000, 0, ''),
        \ 'customlist,gista#prompt#_asktf_complete_yes_or_no',
        \)
  while result !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if result == ''
      call gista#prompt#warn('Canceled.')
      break
    endif
    call gista#prompt#error('Invalid input.')
    let result = gista#prompt#ask(
          \ printf('%s (y[es]/n[o]): ', a:msg),
          \ get(a:000, 0, ''),
          \ 'customlist,gista#prompt#_asktf_complete_yes_or_no',
          \)
  endwhile
  redraw
  return result =~? 'y\%[es]'
endfunction " }}}
function! gista#prompt#_asktf_complete_yes_or_no(arglead, cmdline, cursorpos) abort " {{{
  return filter(['yes', 'no'], 'v:val =~# "^" . a:arglead')
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
