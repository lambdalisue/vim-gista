let s:V = gista#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! gista#command#delete#call(...) abort
  let options = extend({
        \ 'gist': {},
        \ 'gistid': '',
        \ 'force': 0,
        \ 'confirm': 1,
        \}, get(a:000, 0, {}))
  try
    let client = gista#client#get()
    let gistid = gista#resource#local#get_valid_gistid(empty(options.gist)
          \ ? options.gistid
          \ : options.gist.id
          \)
    if options.confirm
      if !gista#util#prompt#confirm(printf(
            \ 'Remove %s in %s? ',
            \ gistid, client.apiname,
            \))
        call gista#throw('Cancel')
      endif
    endif
    call gista#resource#remote#delete(gistid, options)
    call gista#util#prompt#indicate(options, printf(
          \ 'A gist %s is deleted from %s',
          \ gistid, client.apiname,
          \))
    let result = {
          \ 'gistid': gistid,
          \}
    silent call gista#util#doautocmd('Delete', result)
    return result
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista delete',
          \ 'description': 'Delete a gist',
          \})
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'Delete a gist even a remote content of the gist is modified', {
          \   'default': 0,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ '--confirm',
          \ 'Confirm before delete', {
          \   'default': 1,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#option#complete_gistid'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#delete#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#option#assign_gistid(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#delete#default_options),
        \ options,
        \)
  call gista#command#delete#call(options)
endfunction
function! gista#command#delete#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#delete', {
      \ 'default_options': {},
      \})
