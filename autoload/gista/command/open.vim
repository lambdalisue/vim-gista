let s:V = gista#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! gista#command#open#call(...) abort
  let options = extend({
        \ 'gist': {},
        \ 'gistid': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  try
    let gistid = gista#resource#local#get_valid_gistid(empty(options.gist)
          \ ? options.gistid
          \ : options.gist.id
          \)
    let gist = gista#resource#remote#get(gistid, options)
    let filename = gista#resource#local#get_valid_filename(gist, options.filename)
    let file = gista#resource#remote#file(gist, options.filename, options)
    let result = {
          \ 'gist': gist,
          \ 'file': file,
          \ 'gistid': gistid,
          \ 'filename': filename,
          \}
    return result
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
endfunction
function! gista#command#open#read(...) abort
  silent doautocmd FileReadPre
  let options = extend({}, get(a:000, 0, {}))
  let result = gista#command#open#call(options)
  if empty(result)
    return
  endif
  call gista#util#buffer#read_content(split(result.file.content, '\r\?\n'))
  redraw
  silent doautocmd FileReadPost
  silent call gista#util#doautocmd('OpenRead', result)
endfunction
function! gista#command#open#edit(...) abort
  silent doautocmd BufReadPre
  let options = extend({}, get(a:000, 0, {}))
  let result = gista#command#open#call(options)
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
        \ 'filename': result.filename,
        \ 'content_type': 'raw',
        \}
  call gista#util#buffer#edit_content(split(result.file.content, '\r\?\n'))
  silent doautocmd BufReadPost
  silent call gista#util#doautocmd('Open', result)
endfunction
function! gista#command#open#open(...) abort
  let options = extend({
        \ 'opener': '',
        \ 'cache': 1,
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:gista#command#open#default_opener
        \ : options.opener
  let bufname = gista#command#open#bufname(options)
  if !empty(bufname)
    call gista#util#buffer#open(bufname, {
          \ 'opener': opener . (options.cache ? '' : '!'),
          \})
    " BufReadCmd will execute gista#command#open#edit()
  endif
endfunction
function! gista#command#open#bufname(...) abort
  let options = extend({
        \ 'gist': {},
        \ 'gistid': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  try
    let gistid = gista#resource#local#get_valid_gistid(empty(options.gist)
          \ ? options.gistid
          \ : options.gist.id
          \)
    let gist = gista#resource#remote#get(gistid, options)
    let filename = gista#resource#local#get_valid_filename(gist, options.filename)
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return
  endtry
  let client = gista#client#get()
  let apiname = client.apiname
  return 'gista://' . join([apiname, gistid, filename], '/')
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista open',
          \ 'description': 'Open a content of a particular gist',
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--cache',
          \ 'Use cached content whenever possible', {
          \   'default': 1,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#option#complete_gistid'),
          \})
    call s:parser.add_argument(
          \ 'filename',
          \ 'A filename', {
          \   'complete': function('g:gista#option#complete_filename'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#open#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#option#assign_gistid(options, '%')
  call gista#option#assign_filename(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#open#default_options),
        \ options,
        \)
  call gista#command#open#open(options)
endfunction
function! gista#command#open#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#open', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})
