"******************************************************************************
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

" github user
if !exists('g:github_user')
  let g:github_user = gista#vital#system('git config --get github.user')
  let g:github_user = substitute(g:github_user, "\n", '', '')
  if strlen(g:github_user) == 0
    let g:github_user = $GITHUB_USER
  endif
endif

" gist api url
if !exists('g:gist_api_url')
  let g:gist_api_url = gista#vital#system('git config --get github.apiurl')
  let g:gist_api_url = substitute(g:gist_api_url, "\n", '', '')
  if strlen(g:gist_api_url) == 0
    let g:gist_api_url = get(g:, 'github_api_url', 'https://api.github.com/')
  endif
endif


function! s:Gista(...) " {{{
  return gista#Gista(call("gista#option#parse", a:000))
endfunction " }}}


command! -nargs=? -range=% -bang Gista
      \ :call s:Gista(<q-bang>, [<line1>, <line2>], <f-args>)


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
