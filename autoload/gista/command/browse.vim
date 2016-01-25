let s:V = gista#vital()
let s:File = s:V.import('System.File')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:create_url(html_url, filename) abort
  let suffix = empty(a:filename) ? '' : '#file-' . a:filename
  let suffix = substitute(suffix, '\.', '-', 'g')
  return a:html_url . suffix
endfunction

function! gista#command#browse#call(...) abort
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
    let filename = empty(options.filename)
          \ ? ''
          \ : gista#resource#local#get_valid_filename(gist, options.filename)
    let url = s:create_url(gist.html_url, filename)
    let result = {
          \ 'url': url,
          \ 'gist': gist,
          \ 'gistid': gistid,
          \ 'filename': filename,
          \}
    return result
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return {}
  endtry
endfunction
function! gista#command#browse#open(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let result = gista#command#browse#call(options)
  if !empty(result)
    call s:File.open(result.url)
  endif
  silent call gista#util#doautocmd('Browse', result)
endfunction
function! gista#command#browse#yank(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let result = gista#command#browse#call(options)
  if !empty(result)
    call gista#util#clip(result.url)
  endif
  silent call gista#util#doautocmd('Browse', result)
endfunction
function! gista#command#browse#echo(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let result = gista#command#browse#call(options)
  if !empty(result)
    echo result.url
  endif
  silent call gista#util#doautocmd('Browse', result)
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista browse',
          \ 'description': 'Open a URL of a gist with a system browser',
          \})
    call s:parser.add_argument(
          \ '--echo', '-e',
          \ 'Echo a URL instead of open', {
          \   'conflicts': ['yank'],
          \})
    call s:parser.add_argument(
          \ '--yank', '-y',
          \ 'Yank a URL instead of open', {
          \   'conflicts': ['echo'],
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
function! gista#command#browse#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gista#option#assign_gistid(options, '%')
  call gista#option#assign_filename(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#browse#default_options),
        \ options,
        \)
  if get(options, 'yank')
    call gista#command#browse#yank(options)
  elseif get(options, 'echo')
    call gista#command#browse#echo(options)
  else
    call gista#command#browse#open(options)
  endif
endfunction
function! gista#command#browse#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gista#define_variables('command#browse', {
      \ 'default_options': {},
      \})
