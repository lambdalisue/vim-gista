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
  " Unite gista:{lookup}:{options}
  let lookup = get(a:args, 0, '')
  let settings = {
        \ 'page': -1,
        \ 'nocache': 0,
        \ '!': 0
        \}
  let index = 1
  while index < len(a:args)
    let arg = a:args[index]
    if arg ==# '!'
      let settings['!'] = 1
    elseif arg ==# 'nocache'
      let settings['nocache'] = 1
    elseif arg ==# 'page'
      if index + 1 == len(a:args)
        throw '"page" option requires number like "Unite gista:page:5"'
      endif
      let settings['page'] = a:args[index+1]
      let index += 1
    else
      throw 'Unknown option "' . arg . '" is specified.'
    endif
  endwhile
  return [lookup, settings]
endfunction " }}}
function! s:get_gists(args) abort " {{{
  let [lookup, settings] = s:parse_args(a:args)
  let key = join(a:args, ":")
  let key = empty(key) ? 'default' : key
  if !exists('s:gists')
    let s:gists = {}
  endif
  if settings['!'] || settings.nocache || !has_key(s:gists, key)
    let s:gists[key] = gista#gist#api#list(lookup, settings)
  endif
  return s:gists[key]
endfunction " }}}

function! s:format_gist(gist) " {{{
  let width = winwidth(0)
  let length = len(a:gist.id)
  let format = printf("%%-%dS %%s", width - length - 1)
  return printf(format, a:gist.description, a:gist.id)
endfunction " }}}
function! s:format_gist_file(gist, filename) " {{{
  return "    " . a:filename
endfunction " }}}


let s:source_gist = {
      \ 'name': 'gist',
      \ 'description': 'Manipulate gists',
      \}

function! s:source_gist.gather_candidates(args, context) abort
  let gists = s:get_gists(a:args)
  let candidates = []
  if !empty(gists)
    for gist in gists
      call add(candidates, {
            \ 'word': s:format_gist(gist),
            \ 'kind': 'gist',
            \ 'source__gist': gist,
            \ 'action__gist': gist,
            \})
    endfor
  endif
  return candidates
endfunction


function! unite#sources#gista#define()
  return s:source_gist
endfunction

" TODO: remove the following codes in production
call unite#define_source(s:source_gist)


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
