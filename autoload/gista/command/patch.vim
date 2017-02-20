let s:V = gista#vital()
let s:List = s:V.import('Data.List')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_content(expr) abort
  let content = join(bufexists(a:expr)
        \ ? getbufline(a:expr, 1, '$')
        \ : readfile(a:expr),
        \ "\n")
  let content = gista#util#ensure_eol(content)
  return { 'content': content }
endfunction
function! s:assign_gista_filenames(gistid, bufnums) abort
  let winnums = s:List.uniq(map(copy(a:bufnums), 'bufwinnr(v:val)'))
  let previous = winnr()
  for winnum in winnums
    execute printf('keepjump %dwincmd w', winnum)
    let filename = expand('%:t')
    let bufname = gista#command#open#bufname({
          \ 'gistid': a:gistid,
          \ 'filename': filename,
          \})
    silent execute printf('file %s', bufname)
  endfor
  execute printf('keepjump %dwincmd w', previous)
endfunction

function! gista#command#patch#call(...) abort
  let options = extend({
        \ 'stay': 0,
        \ 'gist': {},
        \ 'gistid': '',
        \ 'filenames': [],
        \ 'contents': [],
        \ 'bufnums': [],
        \}, get(a:000, 0, {}))
  try
    let gistid = gista#resource#local#get_valid_gistid(empty(options.gist)
          \ ? options.gistid
          \ : options.gist.id
          \)
    let gist = gista#resource#remote#patch(gistid, options)
    if !options.stay
      " Assign gista filename to buffer existing in the current tabpage
      call s:assign_gista_filenames(gist.id, options.bufnums)
    endif
    let client = gista#client#get()
    call gista#util#prompt#indicate(options, printf(
          \ 'Changes of %s in gist %s is posted to %s',
          \ join(options.filenames, ', '), gistid, client.apiname,
          \))
    let result = {
          \ 'gist': gist,
          \ 'gistid': gistid,
          \ 'filenames': options.filenames,
          \}
    silent call gista#util#doautocmd('Patch', result)
    return result
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista patch',
          \ 'description': 'Patch a current buffer content into an existing gist',
          \ 'complete_unknown': s:ArgumentParser.complete_files,
          \ 'unknown_description': '[filenames...]',
          \})
    call s:parser.add_argument(
          \ '--description', '-d',
          \ 'A description of a gist', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'Patch a gist even a remote content of the gist is modified', {
          \   'default': 0,
          \   'deniable': 1,
          \})
    call s:parser.add_argument(
          \ '--stay',
          \ 'Do not open a posted gist', {
          \   'default': 0,
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
    let filename = expand('%:t')
    let filename = empty(filename)
          \ ? 'gista-file'
          \ : filename
    let content = gista#util#ensure_eol(
          \ join(call('getline', options.__range__), "\n")
          \)
    let options.filenames = [filename]
    let options.contents = [{ 'content': content }]
    let options.bufnums = [bufnr('%')]
  else
    call filter(options.filenames, 'bufexists(v:val) || filereadable(v:val)')
    let options.contents = map(
          \ copy(options.filenames),
          \ 's:get_content(v:val)'
          \)
    let options.bufnums = filter(map(
          \ copy(options.filenames),
          \ 'bufnr(v:val)'
          \), 'v:val != -1')
    call map(options.filenames, 'fnamemodify(v:val, ":t")')
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
