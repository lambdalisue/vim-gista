let s:V = gista#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! gista#command#star#call(...) abort
  let options = extend({
        \ 'gist': {},
        \ 'gistid': '',
        \}, get(a:000, 0, {}))
  try
    let client = gista#client#get()
    let gistid = gista#resource#local#get_valid_gistid(empty(options.gist)
          \ ? options.gistid
          \ : options.gist.id
          \)
    call gista#resource#remote#star(gistid, options)
    call gista#util#prompt#indicate(options, printf(
          \ 'A gist %s in %s is starred',
          \ gistid, client.apiname,
          \))
    let result = {
          \ 'gistid': gistid,
          \}
    silent call gista#util#doautocmd('Star', result)
    return result
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista star',
          \ 'description': 'Star an existing gist',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#option#complete_gistid'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#star#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#option#assign_gistid(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#star#default_options),
        \ options,
        \)
  call gista#command#star#call(options)
endfunction
function! gista#command#star#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#star', {
      \ 'default_options': {},
      \})
