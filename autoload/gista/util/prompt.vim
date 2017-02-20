let s:V = gista#vital()
let s:Console = s:V.import('Vim.Console')
let s:t_string = type('')

function! gista#util#prompt#debug(...) abort
  call s:apply_config()
  call s:Console.debug(s:normalize_attrs(a:000))
endfunction
function! gista#util#prompt#info(...) abort
  call s:apply_config()
  call s:Console.info(s:normalize_attrs(a:000))
endfunction
function! gista#util#prompt#warn(...) abort
  call s:apply_config()
  call s:Console.warn(s:normalize_attrs(a:000))
endfunction
function! gista#util#prompt#error(...) abort
  call s:apply_config()
  call s:Console.error(s:normalize_attrs(a:000))
endfunction
function! gista#util#prompt#ask(...) abort
  call s:apply_config()
  return call(s:Console.ask, a:000, s:Console)
endfunction
function! gista#util#prompt#select(...) abort
  call s:apply_config()
  return call(s:Console.select, a:000, s:Console)
endfunction
function! gista#util#prompt#confirm(...) abort
  call s:apply_config()
  return call(s:Console.confirm, a:000, s:Console)
endfunction

function! gista#util#prompt#indicate(options, message) abort
  if get(a:options, 'verbose')
    redraw | echo a:message
  endif
endfunction

function! s:ensure_string(x) abort
  return type(a:x) == s:t_string ? a:x : string(a:x)
endfunction

function! s:normalize_attrs(attrs) abort
  return join(map(copy(a:attrs), 's:ensure_string(v:val)'), "\n")
endfunction

function! s:apply_config() abort
  if g:gista#test
    let s:Console.status = s:Console.STATUS_BATCH
  elseif g:gista#debug
    let s:Console.status = s:Console.STATUS_DEBUG
  else
    let s:Console.status = ''
  endif
endfunction
