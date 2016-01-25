let s:V = gista#vital()
let s:Prompt = s:V.import('Vim.Prompt')

function! s:is_debug() abort
  return g:gista#debug
endfunction
function! s:is_batch() abort
  return g:gista#test
endfunction

function! gista#util#prompt#debug(...) abort
  call call(s:Prompt.debug, a:000, s:Prompt)
endfunction
function! gista#util#prompt#info(...) abort
  call call(s:Prompt.info, a:000, s:Prompt)
endfunction
function! gista#util#prompt#warn(...) abort
  call call(s:Prompt.warn, a:000, s:Prompt)
endfunction
function! gista#util#prompt#error(...) abort
  call call(s:Prompt.error, a:000, s:Prompt)
endfunction
function! gista#util#prompt#ask(...) abort
  return call(s:Prompt.ask, a:000, s:Prompt)
endfunction
function! gista#util#prompt#select(...) abort
  return call(s:Prompt.select, a:000, s:Prompt)
endfunction
function! gista#util#prompt#confirm(...) abort
  return call(s:Prompt.confirm, a:000, s:Prompt)
endfunction

function! gista#util#prompt#indicate(options, message) abort
  if get(a:options, 'verbose')
    redraw | echo a:message
  endif
endfunction

call s:Prompt.set_config({
      \ 'debug': function('s:is_debug'),
      \ 'batch': function('s:is_batch'),
      \})
