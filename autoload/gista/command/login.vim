let s:V = gista#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! gista#command#login#call(...) abort
  let options = extend({
        \ 'apiname': '',
        \ 'username': '',
        \}, get(a:000, 0, {}))
  try
    let apiname = gista#client#get_valid_apiname(options.apiname)
    let username = gista#client#get_valid_username(apiname, options.username)
    call gista#client#set(apiname, {
          \ 'username': username,
          \})
    let client = gista#client#get()
    echo printf(
          \ 'Login into %s as %s',
          \ client.apiname,
          \ client.get_authorized_username(),
          \)
    let result = {
          \ 'apiname': apiname,
          \ 'username': username,
          \}
    silent call gista#util#doautocmd('Login', result)
    return result
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista login',
          \ 'description': 'Login as a specified username to a specified API',
          \})
    call s:parser.add_argument(
          \ '--apiname', '-n',
          \ 'An API name', {
          \   'complete': function('gista#option#complete_apiname'),
          \})
    call s:parser.add_argument(
          \ 'username',
          \ 'A username of an API account', {
          \   'complete': function('gista#option#complete_username'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#login#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#login#default_options),
        \ options,
        \)
  call gista#command#login#call(options)
endfunction
function! gista#command#login#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#login', {
      \ 'default_options': {},
      \})
