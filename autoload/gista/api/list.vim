let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')

function! s:remove_unmodified(content_cache, gistid) abort " {{{
  if !a:content_cache.has(a:gistid)
    return
  endif
  if !gista#gist#is_modified(a:content_cache.get(a:gistid))
    call a:content_cache.remove(a:gistid)
  endif
endfunction " }}}

function! s:get_valid_lookup(lookup) abort " {{{
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  if !empty(username)
        \ && (a:lookup ==# username || a:lookup ==# username . '/starred')
    return a:lookup
  endif
  call gista#util#validate#pattern(
        \ a:lookup, '^\w*$',
        \ 'A lookup "%value" requires to follow "%pattern"'
        \)
  return a:lookup
endfunction " }}}
function! s:get_lookup(lookup) abort " {{{
  let client = gista#api#get_current_client()
  let username = client.get_authorized_username()
  let lookup = empty(a:lookup)
        \ ? empty(g:gista#api#list#default_lookup)
        \   ? empty(username)
        \     ? 'public'
        \     : username
        \   : g:gista#api#list#default_lookup
        \ : a:lookup
  return s:get_valid_lookup(lookup)
endfunction " }}}
function! gista#api#list#list_cache(lookup) abort " {{{
  let client = gista#api#get_current_client()
  let lookup = s:get_lookup(a:lookup)
  let entries = client.entry_cache.get(lookup, [])
  return {
        \ 'lookup': lookup,
        \ 'entries': entries,
        \ 'since': len(entries)
        \   ? entries[0].updated_at
        \   : '',
        \}
endfunction " }}}
function! gista#api#list#list(lookup, ...) abort " {{{
  let options = extend({
        \ 'since': 1,
        \ 'fresh': 0,
        \ 'python': has('python') || has('python3'),
        \}, get(a:000, 0, {})
        \)
  let cached_content = gista#api#list#list_cache(a:lookup)
  if !options.fresh && !empty(cached_content.entries)
    return cached_content
  endif
  " assign page/since/last_page
  let client = gista#api#get_current_client()
  let lookup = s:get_lookup(a:lookup)
  let since = type(options.since) == type(0)
        \ ? options.since
        \   ? len(cached_content.entries)
        \     ? cached_content.entries[0].updated_at
        \     : ''
        \   : ''
        \ : options.since
  " find a corresponding url
  let username = client.get_authorized_username()
  if lookup ==# 'public'
    let url = 'gists/public'
  elseif !empty(username) && lookup ==# username
    let url = 'gists'
  elseif !empty(username) && lookup ==# username . '/starred'
    let url = 'gists/starred'
  elseif !empty(lookup)
    let url = printf('users/%s/gists', lookup)
  else
    let url = 'gists/public'
  endif

  " fetch entries
  let indicator = printf(
        \ 'Requesting gists of "%s" in %s as %s %%%%d/%%d ...',
        \ lookup,
        \ client.apiname,
        \ empty(username)
        \   ? 'an anonymous user'
        \   : username,
        \)
  if options.python
    let fetched_entries = gista#api#fetch#python(url, indicator, {
          \ 'since': since,
          \})
  else
    let fetched_entries = gista#api#fetch#vim(url, indicator, {
          \ 'since': since,
          \})
  endif
  redraw
  call gista#util#prompt#echo('Removing unnecessary params ...')
  call map(
        \ fetched_entries,
        \ 'gista#gist#pick_necessary_params_of_entry(v:val)'
        \)

  if empty(since)
    " fetched_entries are corresponding to the actual entries in API
    " so overwrite cache_entries with fetched_entries
    let entries = fetched_entries
  else
    " fetched_entries are partial entries in API
    " so merge entries with cached_entries
    redraw
    call gista#util#prompt#echo('Removing duplicated gist entries ...')
    let entries = gista#gist#merge_entries(
          \ fetched_entries, cached_content.entries
          \)
  endif

  redraw
  call gista#util#prompt#echo('Updating entry caches ...')
  call client.entry_cache.set(lookup, entries)

  redraw
  call gista#util#prompt#echo('Removing corresponding content caches ...')
  call map(
        \ copy(fetched_entries),
        \ 's:remove_unmodified(client.content_cache, v:val.id)'
        \)

  redraw
  call gista#util#prompt#echo(printf(
        \ '%d gist entries were listed.',
        \ len(fetched_entries),
        \))
  return {
        \ 'lookup': lookup,
        \ 'entries': entries,
        \ 'since': since,
        \}
endfunction " }}}

" Configure variables
call gista#define_variables('api#list', {
      \ 'default_lookup': '',
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
