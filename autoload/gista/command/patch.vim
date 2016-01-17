let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! s:get_content(expr) abort
  let content = join(bufexists(a:expr)
        \ ? getbufline(a:expr, 1, '$')
        \ : readfile(a:expr),
        \ "\n")
  let content = gista#util#ensure_eol(content)
  return { 'content': content }
endfunction

function! gista#command#patch#call(...) abort
  let options = extend({
        \ 'gist': {},
        \ 'gistid': '',
        \ 'filenames': [],
        \ 'contents': [],
        \}, get(a:000, 0, {}))
  try
    let gistid = gista#resource#local#get_valid_gistid(empty(options.gist)
          \ ? options.gistid
          \ : options.gist.id
          \)
    let gist = gista#resource#remote#patch(gistid, options)
    if index(options.filenames, expand('%:t'))
      let filename = fnamemodify(gista#option#guess_filename('%'), ':t')
      let bufname = gista#command#open#bufname({
            \ 'gistid': gistid,
            \ 'filename': filename,
            \})
      silent execute printf('file %s', bufname)
    endif
    call gista#util#doautocmd('CacheUpdatePost')
    let client = gista#client#get()
    call gista#indicate(options, printf(
          \ 'Changes of %s in gist %s is posted to %s',
          \ join(options.filenames, ', '), gistid, client.apiname,
          \))
    return [gist, gistid, options.filenames]
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return [{}, gistid, options.filenames]
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista patch',
          \ 'description': 'Patch a current buffer content into an existing gist',
          \ 'complete_unknown': s:A.complete_files,
          \ 'unknown_description': '[filename, ...]',
          \})
    call s:parser.add_argument(
          \ '--description', '-d',
          \ 'A description of a gist', {
          \   'type': s:A.types.value,
          \})
    call s:parser.add_argument(
          \ '--force',
          \ 'Patch a gist even a remote content of the gist is modified', {
          \   'default': 0,
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
function! gista#command#patch#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#option#assign_gistid(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#patch#default_options),
        \ options,
        \)
  let options.filenames = options.__unknown__
  if empty(get(options, 'filenames'))
    let filename = fnamemodify(gista#option#guess_filename('%'), ':t')
    let filename = empty(filename)
          \ ? 'gista-file'
          \ : filename
    let content = gista#util#ensure_eol(
          \ join(call('getline', options.__range__), "\n")
          \)
    let options.filenames = [filename]
    let options.contents = [{ 'content': content }]
  else
    call filter(options.filenames, 'bufexists(v:val) || filereadable(v:val)')
    let options.contents = map(
          \ copy(options.filename),
          \ 's:get_content(v:val)'
          \)
  endif
  call gista#command#patch#call(options)
endfunction
function! gista#command#patch#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#patch', {
      \ 'default_options': {},
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
