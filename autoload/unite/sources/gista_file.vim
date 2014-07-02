"******************************************************************************
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


let s:source = {
      \ 'name': 'gista_file',
      \ 'description': 'manipulate gist files',
      \ 'is_listed': 0,
      \}
function! s:source.gather_candidates(args, context) abort " {{{
  " A gist instance is passed as a context value
  let gist = a:context.source__gist
  let candidates = []
  for filename in keys(gist.files)
    call add(candidates, {
          \ 'word': filename,
          \ 'kind': 'gista_file',
          \ 'source__gist': gist,
          \ 'source__filename': filename,
          \ 'action__path': gista#utils#get_gist_url(gist, filename),
          \ 'action__text': printf("%s/%s", gist.id, filename),
          \})
  endfor
  return candidates
endfunction " }}}
function! unite#sources#gista_file#define() " {{{
  return s:source
endfunction " }}}
call unite#define_source(s:source)  " Required for reloading



let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
