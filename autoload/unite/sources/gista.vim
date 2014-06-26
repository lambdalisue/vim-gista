"******************************************************************************
" Unite source of vim-gista
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! s:format_gist(gist) " {{{
  return a:gist.description
endfunction " }}}
function! s:format_gist_file(gist, filename) " {{{
  return "    " . a:filename
endfunction " }}}


let s:source = {
      \ 'name': 'gista',
      \ 'description': 'Manipulate gists',
      \ 'is_grouped': 1,
      \}

function! s:source.gather_candidates(args, context) abort
  let lookup = ''
  let settings = {
        \ 'page': -1,
        \ 'nocache': 0,
        \}
  if type(a:args) == 3
    " Unite gista:{lookup}:{options}
    let lookup = get(a:args, 0, '')
    let index = 1
    while index < len(a:args)
      let arg = a:args[index]
      if arg == 'nocache'
        let settings['nocache'] = 1
      elseif arg == 'page'
        if index + 1 == len(a:args)
          throw '"page" option requires number like "Unite gista:page:5"'
        endif
        let settings['page'] = a:args[index+1]
        let index += 1
      else
        throw 'Unknown option "' . arg . '" is specified.'
      endif
    endwhile
  endif

  let res = gista#raw#gets(lookup, settings)
  let candidates = []
  if res.status == 200
    let gists = res.content
    for gist in gists
      call add(candidates, {
            \ 'word': s:format_gist(gist),
            \ 'kind': 'gista',
            \ 'group': gist.id,
            \ 'source_gist': gist,
            \ 'action__gist': gist,
            \})
      for filename in keys(gist.files)
        call add(candidates, {
              \ 'word': s:format_gist_file(gist, filename),
              \ 'kind': 'gista',
              \ 'group': gist.id,
              \ 'source_gist': gist,
              \ 'source_filename': filename,
              \ 'action__gist': gist,
              \ 'action__filename': filename,
              \})
      endfor
    endfor
  endif
  return candidates
endfunction


function! unite#sources#gista#define()
  return s:source
endfunction
" for reload
call unite#define_source(s:source)


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
