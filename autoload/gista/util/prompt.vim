let s:V = gista#vital()
let s:Console = s:V.import('Vim.Console')

function! s:is_debug() abort
  return g:gista#debug
endfunction
function! s:is_batch() abort
  return g:gista#test
endfunction

function! gista#util#prompt#debug(...) abort
  call call(s:Console.debug, a:000, s:Console)
endfunction
function! gista#util#prompt#info(...) abort
  call call(s:Console.info, a:000, s:Console)
endfunction
function! gista#util#prompt#warn(...) abort
  call call(s:Console.warn, a:000, s:Console)
endfunction
function! gista#util#prompt#error(...) abort
  call call(s:Console.error, a:000, s:Console)
endfunction
function! gista#util#prompt#ask(...) abort
  return call(s:Console.ask, a:000, s:Console)
endfunction
function! gista#util#prompt#select(...) abort
  return call(s:Console.select, a:000, s:Console)
endfunction
function! gista#util#prompt#confirm(...) abort
  return call(s:Console.confirm, a:000, s:Console)
endfunction

function! gista#util#prompt#indicate(options, message) abort
  if get(a:options, 'verbose')
    redraw | echo a:message
  endif
endfunction

call s:Console.set_config({
      \ 'debug': function('s:is_debug'),
      \ 'batch': function('s:is_batch'),
      \})
