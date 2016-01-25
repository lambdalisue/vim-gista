let s:V = gista#vital()
let s:JSON = s:V.import('Web.JSON')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! gista#command#json#call(...) abort
  let options = extend({
        \ 'gist': {},
        \ 'gistid': '',
        \}, get(a:000, 0, {}))
  try
    let gistid = gista#resource#local#get_valid_gistid(empty(options.gist)
          \ ? options.gistid
          \ : options.gist.id
          \)
    let gist = gista#resource#remote#get(gistid, options)
    let result = {
          \ 'gist': gist,
          \ 'gistid': gistid,
          \}
    return result
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
endfunction
function! gista#command#json#read(...) abort
  silent doautocmd FileReadPre
  let options = extend({}, get(a:000, 0, {}))
  let result = gista#command#json#call(options)
  if empty(result)
    return
  endif
  let content = split(s:JSON.encode(result.gist, { 'indent': 2 }), "\r\\?\n")
  call gista#util#buffer#read_content(content)
  silent doautocmd FileReadPost
  silent call gista#util#doautocmd('JsonRead', result)
endfunction
function! gista#command#json#edit(...) abort
  silent doautocmd BufReadPre
  let options = extend({}, get(a:000, 0, {}))
  let result = gista#command#json#call(options)
  if empty(result)
    return
  endif
  let client = gista#client#get()
  let apiname = client.apiname
  let username = client.get_authorized_username()
  let b:gista = {
        \ 'apiname': apiname,
        \ 'username': username,
        \ 'gistid': result.gistid,
        \ 'content_type': 'json',
        \}
  let content = split(s:JSON.encode(result.gist, { 'indent': 2 }), "\r\\?\n")
  call gista#util#buffer#edit_content(content)
  setlocal buftype=nowrite
  setlocal nomodifiable
  setlocal filetype=json
  silent doautocmd BufReadPost
  silent call gista#util#doautocmd('Json', result)
endfunction
function! gista#command#json#open(...) abort
  let options = extend({
        \ 'opener': '',
        \ 'cache': 1,
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:gista#command#json#default_opener
        \ : options.opener
  let bufname = gista#command#json#bufname(options)
  if !empty(bufname)
    call gista#util#buffer#open(bufname, {
          \ 'opener': opener . (options.cache ? '' : '!'),
          \})
    " BufReadCmd will execute gista#command#json#edit()
  endif
endfunction
function! gista#command#json#bufname(...) abort
  let options = extend({
        \ 'gist': {},
        \ 'gistid': '',
        \}, get(a:000, 0, {}))
  try
    let gistid = gista#resource#local#get_valid_gistid(empty(options.gist)
          \ ? options.gistid
          \ : options.gist.id
          \)
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return
  endtry
  let client = gista#client#get()
  let apiname = client.apiname
  return 'gista://' . join([apiname, gistid . '.json'], '/')
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista json',
          \ 'description': 'Open a JSON content of a gist',
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--cache',
          \ 'Use cached content whenever possible.', {
          \   'default': 1,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#option#complete_gistid'),
          \   'type': s:ArgumentParser.types.value,
          \})
  endif
  return s:parser
endfunction
function! gista#command#json#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#option#assign_gistid(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#json#default_options),
        \ options,
        \)
  call gista#command#json#open(options)
endfunction
function! gista#command#json#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#json', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})
