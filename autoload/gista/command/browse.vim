let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:F = s:V.import('System.File')
let s:A = s:V.import('ArgumentParser')

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
    return [s:create_url(gist.html_url, filename), gistid, filename]
  catch /^vim-gista:/
    call gista#util#handle_exception(v:exception)
    return ''
  endtry
endfunction
function! gista#command#browse#open(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let [url, gistid, filename] = gista#command#browse#call(options)
  if !empty(url)
    call s:F.open(url)
  endif
endfunction
function! gista#command#browse#yank(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let [url, gistid, filename] = gista#command#browse#call(options)
  if !empty(url)
    call gista#util#clip(url)
  endif
endfunction
function! gista#command#browse#echo(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let [url, gistid, filename] = gista#command#browse#call(options)
  if !empty(url)
    echo url
  endif
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista browse',
          \ 'description': 'Open a URL of a gist with a system browser',
          \})
    call s:parser.add_argument(
          \ '--filename',
          \ 'A filename', {
          \   'complete': function('g:gista#option#complete_filename'),
          \})
    call s:parser.add_argument(
          \ '--echo',
          \ 'Echo a URL instead of open', {
          \   'conflicts': ['yank'],
          \})
    call s:parser.add_argument(
          \ '--yank',
          \ 'Yank a URL instead of open', {
          \   'conflicts': ['echo'],
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#option#complete_gistid'),
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


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
