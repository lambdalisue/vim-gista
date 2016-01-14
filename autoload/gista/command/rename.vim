let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! gista#command#rename#call(...) abort
  let options = extend({
        \ 'gist': {},
        \ 'gistid': '',
        \ 'filename': '',
        \ 'new_filename': '',
        \ 'force': 0,
        \}, get(a:000, 0, {}),
        \)
  try
    if !empty(options.gist)
      let gist = options.gist
      let gistid = gist.id
    else
      let gistid = gista#option#get_valid_gistid(options)
      let gist = gista#resource#remote#get(gistid, options)
    endif
    let filename = gista#option#get_valid_filename(options)
    if empty(options.new_filename)
      let options.new_filename = gista#util#prompt#ask(
            \ filename . ' -> ', filename,
            \ 'customlist,gista#option#complete_filename',
            \)
    endif
    let new_filename = options.new_filename

    let gist = gista#resource#remote#patch(gistid, {
          \ 'force': options.force,
          \ 'filenames': [filename],
          \ 'contents': [{
          \   'filename': new_filename,
          \   'content': gist.files[filename].content,
          \ }],
          \})
    call gista#util#doautocmd('CacheUpdatePost')
    let client = gista#client#get()
    call gista#indicate(options, printf(
          \ 'A %s in a gist %s in %s is renamed to %s',
          \ filename, gistid, client.apiname, new_filename,
          \))
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista rename',
          \ 'description': 'Rename a filename in a gist',
          \})
    call s:parser.add_argument(
          \ '--force',
          \ 'Rename a filename in a gist even a remote content of the gist is modified', {
          \   'default': 0,
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
    call s:parser.add_argument(
          \ 'new_filename',
          \ 'A new filename', {
          \   'complete': function('g:gista#option#complete_filename'),
          \})
  endif
  return s:parser
endfunction
function! gista#command#rename#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#option#assign_gistid(options, '%')
  call gista#option#assign_filename(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#rename#default_options),
        \ options,
        \)
  call gista#command#rename#call(options)
endfunction
function! gista#command#rename#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#rename', {
      \ 'default_options': {},
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
