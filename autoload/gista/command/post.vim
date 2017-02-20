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
function! s:interactive_description(options) abort
  if type(a:options.description) == type(0)
    if a:options.description
      unlet a:options.description
      let a:options.description = gista#util#prompt#ask(
            \ 'Please input a description of a gist: ',
            \)
    else
      unlet a:options.description
      return
    endif
  endif
  if empty(a:options.description) && !g:gista#command#post#allow_empty_description
    call gista#throw(join([
          \ 'An empty description is not allowed',
          \ 'See ":help g:gista#command#post#allow_empty_description" for detail',
          \]))
  endif
endfunction

function! gista#command#post#call(...) abort
  let options = extend({
        \ 'stay': 0,
        \ 'description': g:gista#command#post#interactive_description,
        \ 'public': g:gista#command#post#default_public,
        \ 'filenames': [],
        \ 'contents': [],
        \ 'bufnums': [],
        \}, get(a:000, 0, {}))
  call s:interactive_description(options)
  try
    let gist = gista#resource#remote#post(
          \ options.filenames,
          \ options.contents,
          \ options,
          \)
    let client = gista#client#get()
    if !options.stay
      " Assign gista filename to buffer existing in the current tabpage
      call s:assign_gista_filenames(gist.id, options.bufnums)
    endif
    call gista#util#prompt#indicate(options, printf(
          \ 'A content of the current buffer is posted to a gist %s in %s',
          \ gist.id, client.apiname,
          \))
    let result = {
          \ 'gist': gist,
          \ 'gistid': gist.id,
          \ 'filenames': options.filenames,
          \}
    silent call gista#util#doautocmd('Post', result)
    return result
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista post',
          \ 'description': 'Post contents into a new gist',
          \ 'complete_unknown': s:ArgumentParser.complete_files,
          \ 'unknown_description': '[filenames...]',
          \})
    call s:parser.add_argument(
          \ '--description', '-d',
          \ 'A description of a gist', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--public', '-p',
          \ 'Post a gist as a public gist', {
          \   'conflicts': ['private'],
          \})
    call s:parser.add_argument(
          \ '--private', '-P',
          \ 'Post a gist as a private gist', {
          \   'conflicts': ['public'],
          \})
    call s:parser.add_argument(
          \ '--stay',
          \ 'Do not open a posted gist', {
          \   'default': 0,
          \})
    function! s:parser.hooks.post_validate(options) abort
      if has_key(a:options, 'private')
        let a:options.public = !a:options.private
        unlet a:options.private
      endif
    endfunction
  endif
  return s:parser
endfunction
function! gista#command#post#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#post#default_options),
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
  call gista#command#post#call(options)
endfunction
function! gista#command#post#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#post', {
      \ 'default_options': {},
      \ 'default_public': 1,
      \ 'interactive_description': 1,
      \ 'allow_empty_description': 0,
      \})
