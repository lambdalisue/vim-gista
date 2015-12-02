let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')

let s:current_lookup = ''

function! s:ask_lookup(...) abort " {{{
  redraw
  return gista#util#prompt#ask(
        \ 'Please input a lookup: ', '',
        \ 'customlist,gista#complete#lookup',
        \)
endfunction " }}}
function! s:set_current_lookup(value) abort " {{{
  let s:current_lookup = a:value
endfunction " }}}
function! s:find_page(res, rel) abort " {{{
  let index = match(a:res.header, 'Link')
  if index == -1
    return 0
  endif
  let links = split(get(a:res.header, index, ''), ',')
  let index = match(links, printf('rel="%s"', a:rel))
  if index == -1
    return 0
  endif
  let page = matchstr(get(links, index, ''), 'page=\zs\d\+')
  return empty(page) ? 0 : str2nr(page)
endfunction " }}}
function! s:sort_fn(lhs, rhs) abort " {{{
  let lts = a:lhs.updated_at
  let rts = a:rhs.updated_at
  return lts ==# rts ? 0 : lts > rts ? -1 : 1
endfunction " }}} 

function! gista#api#list#get_lookup(lookup) abort " {{{
  let username = gista#api#get_current_username()
  let lookup = empty(a:lookup)
        \ ? empty(g:gista#api#list#default_lookup)
        \   ? username
        \   : g:gista#api#list#default_lookup
        \ : a:lookup
  if lookup ==# 'starred' && !empty(username)
    let lookup = username . '/starred'
  endif
  call gista#validate#lookup(lookup)
  return lookup
endfunction " }}}
function! gista#api#list#get_current_lookup() abort " {{{
  return s:current_lookup
endfunction " }}}
function! gista#api#list#call(client, ...) abort " {{{
  let options = extend({
        \ 'verbose': 1,
        \ 'lookup': '',
        \ 'page': 1,
        \ 'since': 1,
        \ 'recursive': 1,
        \ 'fresh': 0,
        \}, get(a:000, 0, {})
        \)
  let anonymous = gista#api#get_current_anonymous()
  let lookup = gista#api#list#get_lookup(options.lookup)
  if !options.fresh && a:client.entry_cache.has(lookup)
    call s:set_current_lookup(lookup)
    return a:client.entry_cache.get(lookup)
  endif
  " assign page/since/last_page
  let cached_entries = a:client.entry_cache.get(lookup, [])
  let page = options.page
  let since = type(options.since) == type(0)
        \ ? options.since
        \   ? len(cached_entries)
        \     ? cached_entries[0].updated_at
        \     : ''
        \   : ''
        \ : options.since
  let last_page  = 0
  " find a corresponding url
  let authorized_username = a:client.get_authorized_username()
  let is_authorized = !empty(authorized_username)
  if lookup ==# 'public'
    let url = 'gists/public'
  elseif is_authorized && lookup ==# authorized_username
    let url = 'gists'
  elseif is_authorized && lookup ==# authorized_username . '/starred'
    let url = 'gists/starred'
  elseif !empty(lookup)
    let url = printf('users/%s/gists', lookup)
  else
    let url = 'gists/public'
  endif
  " fetch entries
  let fetched_entries = []
  while page > 0
    if options.verbose
      redraw
      call gista#util#prompt#echo(printf(
            \ 'Requesting gists of %s in %s%s%s ...',
            \ empty(lookup) ? 'public' : lookup,
            \ a:client.name,
            \ anonymous
            \   ? ' as an anonymous user'
            \   : '',
            \ last_page
            \   ? printf(' %d/%d', page, last_page)
            \   : printf(' %d/?', page)
            \))
    endif

    let params = filter({
          \   'page': page,
          \   'since': since,
          \ },
          \ '!empty(v:val)'
          \)
    let res = a:client.get(url, params, {}, {
          \ 'verbose': options.verbose,
          \ 'anonymous': anonymous,
          \})
    let res.content = get(res, 'content', '')
    let res.content = empty(res.content) ? [] : s:J.decode(res.content)
    if res.status == 200
      call map(
            \ res.content,
            \ 'gista#gist#pick_necessary_params_of_entry(v:val)',
            \)
      call extend(fetched_entries, res.content)
      if !options.recursive
        break
      endif
      let page = s:find_page(res, 'next')
      let last_page = last_page == 0
            \ ? s:find_page(res, 'last')
            \ : last_page
    else
      call gista#util#prompt#throw(
            \ printf('%s: %s', res.status, res.statusText),
            \ get(res.content, 'message', ''),
            \)
    endif
  endwhile

  if empty(options.since)
    " fetched_entries are corresponding to the actual entries in API
    " so overwrite cache_entries with fetched_entries
    let entries = fetched_entries
  else
    " fetched_entries are partial entries in API
    " so merge entries with cached_entries
    if options.verbose
      redraw
      call gista#util#prompt#echo('Removing duplicated gist entries ...')
    endif
    let entries = gista#gist#merge_entries(
          \ fetched_entries, cached_entries
          \)

    if options.page > 1
      if options.verbose
        redraw
        call gista#util#prompt#echo('Sorting gist entries ...')
      endif
      let entries = sort(entries, 's:sort_fn')
    endif
  endif

  if options.verbose
    redraw
    call gista#util#prompt#echo(printf(
          \ '%d gist entries were listed.',
          \ len(fetched_entries),
          \))
  endif
  call s:set_current_lookup(lookup)
  call a:client.entry_cache.set(lookup, entries)
  " update content cache of fetched_entries as well
  for entry in fetched_entries
    let content = extend(
          \ a:client.content_cache.get(entry.id, {}),
          \ entry,
          \)
    call a:client.content_cache.set(entry.id, content)
  endfor
  return entries
endfunction " }}}

" Configure variables
call gista#define_variables('api#list', {
      \ 'default_lookup': '',
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
