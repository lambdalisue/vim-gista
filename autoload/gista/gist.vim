let s:save_cpo = &cpo
set cpo&vim

function! s:pick_necessary_params_of_content(content) abort " {{{
  return {
        \ 'size': a:content.size,
        \ 'type': a:content.type,
        \ 'language': a:content.language,
        \}
endfunction " }}}

function! gista#gist#pick_necessary_params_of_entry(gist) abort " {{{
  return {
        \ 'id': a:gist.id,
        \ 'description': a:gist.description,
        \ 'public': a:gist.public,
        \ 'files': map(
        \   copy(a:gist.files),
        \   's:pick_necessary_params_of_content(v:val)'
        \ ),
        \ 'updated_at': a:gist.updated_at,
        \ '_gista_partial': get(a:gist, '_gista_partial', 1),
        \ '_gista_modified': get(a:gist, '_gista_modified', 0),
        \}
endfunction " }}}
function! gista#gist#merge_entries(lhs, rhs) abort " {{{
  let known_gistids = map(copy(a:lhs), 'v:val.id')
  return extend(
        \ copy(a:lhs),
        \ filter(
        \   copy(a:rhs),
        \   'index(known_gistids, v:val.id) == -1',
        \ ),
        \)
endfunction " }}}
function! gista#gist#update_entry_cache(client, lookup, entries) abort " {{{
  let update_entries = type(a:entries) == type([]) ? a:entries : [a:entries]
  let cached_entries = a:client.entry_cache.get(a:lookup, [])
  let entries = gista#gist#merge_entries(
        \ map(
        \   copy(update_entries),
        \   'gista#gist#pick_necessary_params_of_entry(v:val)',
        \ ),
        \ cached_entries,
        \)
  call a:client.entry_cache.set(a:lookup, entries)
endfunction " }}}
function! gista#gist#get_meta(expr) abort " {{{
  let bufnum = bufnr(a:expr)
  let bufname = expand(a:expr)
  let gista = gista#util#compat#getbufvar(bufnum, 'gista', {})
  if bufnum && !empty(gista)
    return {
          \ 'apiname': gista.apiname,
          \ 'gistid': gista.gistid,
          \ 'filename': fnamemodify(bufname, ':t'),
          \ 'anonymous': gista.anonymous,
          \}
  elseif bufname =~# '^gista:.*:.*:.*$'
    let m = matchlist(bufname, '^gista:\(.*\):\(.*\):\(.*\)$')
    return {
          \ 'apiname': m[1],
          \ 'gistid': m[2],
          \ 'filename': m[3],
          \ 'anonymous': 0,
          \}
  else
    return {}
  endif
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
