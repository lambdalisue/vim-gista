let s:save_cpo = &cpo
set cpo&vim

function! gista#validate#apiname(apiname) abort " {{{
  call gista#util#validate#no_empty(a:apiname,
        \ 'An API name cannot be empty',
        \)
  call gista#util#validate#pattern(
        \ '^[a-zA-Z0-9_\-]\+$', a:apiname,
        \ 'An API name "%value" need to follow "%pattern"'
        \)
endfunction " }}}
function! gista#validate#baseurl(baseurl) abort " {{{
  call gista#util#validate#no_empty(
        \ a:baseurl,
        \ 'An API baseurl cannot be empty',
        \)
  call gista#util#validate#pattern(
        \ '^https\?://', a:baseurl,
        \ 'An API baseurl "%value" need to follow "%pattern"'
        \)
endfunction " }}}
function! gista#validate#username(username) abort " {{{
  call gista#util#validate#no_empty(
        \ a:username,
        \ 'An API account username cannot be empty',
        \)
  call gista#util#validate#pattern(
        \ '^[a-zA-Z0-9_\-]\+$', a:username,
        \ 'An API account username "%value" need to follow "%pattern"'
        \)
endfunction " }}}
function! gista#validate#gistid(gistid) abort " {{{
  call gista#util#validate#no_empty(
        \ a:gistid,
        \ 'A gist ID cannot be empty',
        \)
  call gista#util#validate#pattern(
        \ '^\w\+\%(/\w\+\)\?$', a:gistid,
        \ 'A gist ID "%value" need to follow "%pattern"'
        \)
endfunction " }}}
function! gista#validate#filename(filename) abort " {{{
  call gista#util#validate#no_empty(
        \ a:filename,
        \ 'A filename cannot be empty',
        \)
endfunction " }}}
function! gista#validate#lookup(lookup) abort " {{{
  let username = gista#api#get_current_username()
  if !empty(username) && a:lookup ==# username . '/starred'
    return
  endif
  call gista#util#validate#pattern(
        \ '^\w*$', a:lookup,
        \ 'A lookup "%value" need to follow "%pattern"'
        \)
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
