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
  let bang = stridx(lookup, '!') != -1
  let lookup = substitute(lookup, '!', '', '')
  let lookup = empty(lookup) ? gista#gist#raw#get_authenticated_user() : lookup
  let lookup = empty(lookup) ? g:gista#github_user : lookup
  return [lookup, bang]
endfunction " }}}
function! s:get_gists(lookup, bang) abort " {{{
  if !exists('s:gists')
    let s:gists = {}
  endif
  if a:bang || !has_key(s:gists, a:lookup)
    let s:gists[a:lookup] = gista#gist#api#list(a:lookup)
  endif
  return s:gists[a:lookup]
endfunction " }}}
function! s:format_gist(gist) " {{{
  let files = printf("%2d)", len(a:gist.files))
  let gistid = printf("[%-20S]", a:gist.id)
  let update = printf("%s",
        \ gista#utils#translate_datetime(a:gist.updated_at))
  let private = a:gist.public ? "" : "<private>"
  let description = empty(a:gist.description) ?
        \ '<<No description>>' :
        \ a:gist.description
  let bwidth = gista#utils#get_bufwidth()
  let width = bwidth - len(files . private . gistid . update) - 4
  return printf(printf("%%s %%-%dS %%s %%s %%s", width),
        \ files,
        \ gista#utils#trancate(description, width),
        \ private,
        \ gistid,
        \ update)
endfunction " }}}
function! s:format_gist_file(gist, filename) " {{{
  let gistid = printf("%s", a:gist.id)
  let bwidth = gista#utils#get_bufwidth()
  let width = bwidth - len(gistid) - 1
  return printf(printf("%%s#%%-%dS", width),
        \ gistid,
        \ gista#utils#trancate(a:filename, width),
        \)
endfunction " }}}

let s:source_gist = {
      \ 'name': 'gist',
      \ 'description': 'Manipulate gists',
      \}

function! s:source_gist.change_candidates(args, context) abort " {{{
  let [lookup, bang] = s:parse_args(a:args)
  if !has_key(a:context, 'source__cache') || a:context.is_redraw
        \ || a:context.is_invalidate
    " Initialize cache.
    let a:context.source__cache = {}
    let bang = 1
  endif

  let gists = s:get_gists(lookup, bang)
  let input = a:context.input
  if input =~# '^.\{,20}#'
    let gistid = matchstr(input, '^\zs\(.\{,20}\)\ze#')
    if !has_key(a:context.source__cache, gistid)
      let gist = get(filter(copy(gists), 
            \ printf('v:val.id=="%s"', gistid)), 0, {})
      let candidates = []
      if !empty(gist)
        for filename in keys(gist.files)
          call add(candidates, {
                \ 'word': s:format_gist_file(gist, filename),
                \ 'kind': 'gist_file',
                \ 'source__gist': gist,
                \ 'source__filename': filename,
                \ 'action__gist': gist,
                \ 'action__filename': filename,
                \})
        endfor
      endif
      let a:context.source__cache[gistid] = candidates
    endif
    return copy(a:context.source__cache[gistid])
  else
    if !has_key(a:context.source__cache, lookup)
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
      let a:context.source__cache[lookup] = candidates
    endif
    return copy(a:context.source__cache[lookup])
  endif
endfunction " }}}
function! unite#sources#gista#define() " {{{
  return s:source_gist
endfunction " }}}

" TODO: remove the following codes in production
call unite#define_source(s:source_gist)


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
