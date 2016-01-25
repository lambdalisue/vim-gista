let s:V = gista#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! gista#command#logout#call(...) abort
  let options = extend({
        \ 'apiname': '',
        \}, get(a:000, 0, {}))
  try
    let apiname = gista#client#get_valid_apiname(options.apiname)
    call gista#client#set(apiname, { 'username': '' })
    let client = gista#client#get()
    echo printf('Logout from %s', client.apiname)
    let result = {
          \ 'apiname': apiname,
          \}
    silent call gista#util#doautocmd('Logout', result)
    return result
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista logout',
          \ 'description': 'Logout from a specified API',
          \})
    call s:parser.add_argument(
          \ '--apiname', '-n',
          \ 'An API name', {
          \   'complete': function('gista#option#complete_apiname'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#logout#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#logout#default_options),
        \ options,
        \)
  call gista#command#logout#call(options)
endfunction
function! gista#command#logout#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#logout', {
      \ 'default_options': {},
      \})
