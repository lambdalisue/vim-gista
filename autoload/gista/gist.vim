let s:save_cpo = &cpo
set cpo&vim

function! s:pick_necessary_params_of_content(content) abort " {{{
  return {
        \ 'size': a:content.size,
        \ 'type': a:content.type,
        \ 'language': a:content.language,
        \}
endfunction " }}}
function! s:sort_fn(lhs, rhs) abort " {{{
  return a:lhs.updated_at ==# a:rhs.updated_at
        \ ? 0
        \ : a:lhs.updated_at > a:rhs.updated_at
        \   ? -1
        \   : 1
endfunction " }}} 
function! s:mark_fetched(entry) abort " {{{
  let a:entry._gista_fetched = 1
  return a:entry
endfunction " }}}
function! s:mark_modified(entry) abort " {{{
  let a:entry._gista_modified = 1
  return a:entry
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
        \ 'created_at': a:gist.created_at,
        \ 'updated_at': a:gist.updated_at,
        \ '_gista_partial': get(a:gist, '_gista_partial', 1),
        \ '_gista_modified': get(a:gist, '_gista_modified', 0),
        \}
endfunction " }}}
function! gista#gist#sort_entries(entries) abort " {{{
  return sort(a:entries, 's:sort_fn')
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
function! gista#gist#get_meta(expr) abort " {{{
  let bufnum = bufnr(a:expr)
  let bufname = expand(a:expr)
  let gista = gista#util#compat#getbufvar(bufnum, 'gista', {})
  if bufnum && !empty(gista)
    return {
          \ 'apiname': gista.apiname,
          \ 'username': gista.username,
          \ 'gistid': gista.gistid,
          \ 'filename': get(gista, 'filename', fnamemodify(bufname, ':t')),
          \}
  elseif bufname =~# '^gista:.*:.*:.*$'
    let m = matchlist(bufname, '^gista:\(.*\):\(.*\):\(.*\)$')
    return {
          \ 'apiname': m[1],
          \ 'gistid': m[2],
          \ 'filename': m[3],
          \}
  else
    return {}
  endif
endfunction " }}}

function! gista#gist#is_fetched(gist_or_entry) abort " {{{
  return get(a:gist_or_entry, '_gista_fetched')
endfunction " }}}
function! gista#gist#is_modified(gist_or_entry) abort " {{{
  return get(a:gist_or_entry, '_gista_modified')
endfunction " }}}
function! gista#gist#mark_fetched(gist_or_entry) abort " {{{
  let a:gist_or_entry._gista_fetched = 1
  return a:gist_or_entry
endfunction " }}}
function! gista#gist#mark_modified(gist_or_entry) abort " {{{
  let a:gist_or_entry._gista_modified = 1
  return a:gist_or_entry
endfunction " }}}
function! gista#gist#unmark_fetched(gist_or_entry) abort " {{{
  if has_key(a:gist_or_entry, '_gista_fetched')
    unlet a:gist_or_entry._gista_fetched
  endif
  return a:gist_or_entry
endfunction " }}}
function! gista#gist#unmark_modified(gist_or_entry) abort " {{{
  if has_key(a:gist_or_entry, '_gista_modified')
    unlet a:gist_or_entry._gista_modified
  endif
  return a:gist_or_entry
endfunction " }}}

function! gista#gist#apply_to_content_cache(client, gistid, fn) abort " {{{
  let content = a:client.content_cache.get(a:gistid, {})
  let content = a:fn(content)
  if empty(content)
    call a:client.content_cache.remove(a:gistid)
  else
    call a:client.content_cache.set(a:gistid, content)
  endif
endfunction " }}}
function! gista#gist#apply_to_entry_cache(client, gistid, fn) abort " {{{
  let content = a:client.content_cache.get(a:gistid, {})
  let lookups = ['public']
  let username = get(get(content, 'owner', {}), 'login', '')
  if !empty(username)
    call add(lookups, username)
    call add(lookups, username . '/starred')
  endif
  for lookup in lookups
    if a:client.entry_cache.has(lookup)
      let entries = a:client.entry_cache.get(lookup)
      call map(entries, 'v:val.id ==# a:gistid ? a:fn(v:val) : v:val')
      call a:client.entry_cache.set(lookup, gista#gist#sort_entries(entries))
    endif
  endfor
endfunction " }}}


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
