let s:save_cpo = &cpoptions
set cpoptions&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

let s:V = gista#vital()
let s:D = s:V.import('Data.Dict')
let s:C = s:V.import('System.Cache')
let s:G = s:V.import('Web.API.GitHub')

let s:parser = s:A.new({
      \ 'name': 'Gista list',
      \ 'description': 'List or request gists',
      \})
call s:parser.add_argument(
      \ '--baseurl',
      \ 'A baseurl or alias of a gist API.',
      \)
call s:parser.add_argument(
      \ '--username',
      \ 'A username of a gist API.', {
      \   'conflicts': ['anonymous'],
      \})
call s:parser.add_argument(
      \ '--anonymous',
      \ 'Request gists as an anonymous user', {
      \   'conflicts': ['username'],
      \})
call s:parser.add_argument(
      \ '--lookup',
      \ 'Request gists of a particular lookup', {
      \})
call s:parser.add_argument(
      \ '--page',
      \ 'Request gists in a particular page', {
      \})
call s:parser.add_argument(
      \ '--since',
      \ 'Request gists only after a paricular datetime', {
      \})
call s:parser.add_argument(
      \ '--fetch',
      \ 'Fetch gists and create cache', {
      \   'conflicts': ['opener', 'clear'],
      \})
call s:parser.add_argument(
      \ '--clear',
      \ 'Clear the cache of gists', {
      \   'conflicts': ['opener', 'fetch'],
      \})
call s:parser.add_argument(
      \ '--opener',
      \ 'Post a gist as a public gist', {
      \   'default': g:gista#command#list#opener,
      \   'conflicts': ['fetch', 'clear'],
      \})

function! s:get_gists_cache(baseurl) abort " {{{
  let name = printf('gists:%s', a:baseurl)
  let cache = gista#util#get_cache(name)
  return cache
endfunction " }}}
function! s:fetch(options) abort " {{{
  let baseurl = gista#client#get_baseurl(get(a:options, 'baseurl', ''))
  let client = gista#client#get(baseurl)
  if !a:options.anonymous
    if !gista#client#login_required(client, a:options)
      " login failed.
      call gista#prompt#warn(
            \ 'To fetch gists as an anonymous user, use "--anonymous" option.'
            \)
      return []
    endif
  endif
  let lookup = get(options, 'lookup', '')
  let lookup = empty(lookup)
        \ ? client.get_authorized_username()
        \ : lookup
  let res = gista#operation#fetch(client, lookup, options)
  if get(res, 'status') == 200
    " update cache
    let gists = s:get_gists_cache(baseurl)
    call gists.set(lookup, extend(res.content, gists.get(lookup, [])))
  endif
endfunction " }}}

function! gista#command#list#exec(...) abort " {{{
  let options = extend({
        \ 'anonymous': 0,
        \ 'description': '',
        \ 'interactive_description':
        \   g:gista#command#post#interactive_description,
        \ 'interactive_visibility':
        \   g:gista#command#post#interactive_visibility,
        \ 'allow_empty': g:gista#command#post#allow_empty,
        \}, get(a:000, 0, {})
        \)
  let baseurl = gista#client#get_baseurl(get(options, 'baseurl', ''))
  let client = gista#client#get(baseurl)
  let gists = s:get_gists_cache(baseurl)
  if !a:options.anonymous
    if !gista#client#login_required(client, a:options)
      " login failed.
      call gista#prompt#warn(
            \ 'To fetch gists as an anonymous user, use "--anonymous" option.'
            \)
      return []
    endif
  endif
  let options.lookup = get(options, 'lookup', '')
  let options.lookup = empty(options.lookup)
        \ ? client.get_authorized_username()
        \ : options.lookup

  if len(gists.get(options.lookup)) == 0
    redraw
    if gista#prompt#ask(printf(
          \ 'It seems you have not fetched gists of "%s" on "%s".',
          \ options.username,
          \ options.baseurl,
          \),
          \ 'Would you like to fetch first?',
          \)
      let options.fetch = 1
    endif
  endif

  if get(options, 'fetch')
    let res = gista#operation#fetch(client, options.lookup, options)
    if get(res, 'status') == 200
      " update cache
      call gists.set(options.lookup, extend(
            \ res.content,
            \ gists.get(options.lookup, [])
            \))
    endif
  elseif get(options, 'clear')
    call gists.remove(options.lookup)
  endif
  return gists.get(options.lookup)
endfunction " }}}
function! gista#command#post#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#post#default_options),
        \ options,
        \)
  " extend filenames and contents
  if !empty(options.__unknown__)
    " use values of '__unknown__' as filenames and contents
    let filenames = filter(copy(options.__unknown__), 'filereadable(v:val)')
    let contents  = map(copy(filenames), 'readfile(v:val)')
  else
    " use content of the current buffer
    let filenames = [expand('%')]
    let contents  = [getline(1, '$')]
  endif
  " use only the tail part of the filename (basename)
  call map(filenames, 'fnamemodify(v:val, ":t")')
  call gista#command#post#exec(filenames, contents, options)
endfunction " }}}
function! gista#command#post#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}


call gista#util#init('command#post', {
      \ 'default_options': {},
      \ 'interactive_description': 1,
      \ 'interactive_visibility': 1,
      \ 'post_as_private': 0,
      \ 'allow_empty': 0,
      \})


let &cpoptions = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
