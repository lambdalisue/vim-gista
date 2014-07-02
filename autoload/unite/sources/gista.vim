"******************************************************************************
" Unite source of vim-gista/gist
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! s:parse_args(args) abort " {{{
  let lookup = get(a:args, 0, '')
  let lookup = empty(lookup) ? gista#gist#raw#get_authenticated_user() : lookup
  let lookup = empty(lookup) ? g:gista#github_user : lookup
  if empty(lookup)
    redraw
    echohl GistaError
    echo 'No GitHub user is specified'
    echohl None
    echo 'No GitHub user is specified neither in arguments nor'
          \ 'g:gista#github_user.'
          \ 'vim-gista cannot determine the username while you are not logged'
          \ 'in yet. You have to login or specify username first.'
    echohl GistaError
    echo 'Canceled.'
    echohl None
    return 0
  endif
  return lookup
endfunction " }}}
function! s:format_gist(gist) " {{{
  return printf("%s %s %s %s %s %s",
        \ len(a:gist.files),
        \ a:gist.id,
        \ gista#utils#datetime(a:gist.updated_at).format('%Y/%m/%d %H:%M:%S'),
        \ gista#utils#datetime(a:gist.created_at).format('%Y/%m/%d %H:%M:%S'),
        \ a:gist.description,
        \ a:gist.public ? "" : "<private>" 
        \)
endfunction " }}}
function! s:get_candidates(lookup, nocache) abort " {{{
  if !exists('s:candidates')
    let s:candidates = {}
  endif
  if a:nocache || !has_key(s:candidates, a:lookup)
    let gists = gista#gist#api#list(a:lookup, {
          \ 'page': -1,
          \ 'nocache': 0,
          \})
    let candidates = []
    if !empty(gists)
      for gist in gists
        call add(candidates, {
              \ 'word': s:format_gist(gist),
              \ 'kind': 'gista',
              \ 'source__gist': gist,
              \ 'action__gist': gist,
              \ 'action__path': gista#utils#get_gist_url(gist),
              \ 'action__text': gist.id,
              \})
      endfor
    endif
    let s:candidates[a:lookup] = candidates
  endif
  return s:candidates[a:lookup]
endfunction " }}}


let s:source = {
      \ 'name': 'gista',
      \ 'description': 'manipulate gists',
      \}
function! s:source.gather_candidates(args, context) abort " {{{
  let lookup = s:parse_args(a:args)
  if type(lookup) == 0
    " Canceled
    return []
  endif

  let candidates = s:get_candidates(lookup, 1)
  return copy(candidates)
endfunction " }}}
function! unite#sources#gista#define() " {{{
  return s:source
endfunction " }}}
call unite#define_source(s:source)  " Required for reloading

" define this converter as a default converter
call unite#custom_source('gista', 'converters', 'converter_gista_full')


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
