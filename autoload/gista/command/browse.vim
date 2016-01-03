let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:F = s:V.import('System.File')
let s:A = s:V.import('ArgumentParser')

function! s:get_absolute_url(gistid, filename) abort
    let gistid = gista#meta#get_valid_gistid(a:gistid)
    let gist   = gista#resource#gists#get(gistid)
    let filename = tolower(substitute(a:filename, '\.', '-', 'g'))
    return gist.html_url . (empty(filename) ? '' : '#file-' . filename)
endfunction

function! s:handle_exception(exception) abort
  redraw
  let canceled_by_user_patterns = [
        \ '^vim-gista: Login canceled',
        \ '^vim-gista: ValidationError:',
        \]
  for pattern in canceled_by_user_patterns
    if a:exception =~# pattern
      call gista#util#prompt#warn('Canceled')
      return
    endif
  endfor
  " else
  call gista#util#prompt#error(a:exception)
endfunction
function! gista#command#browse#call(...) abort
  let options = extend({
        \ 'gistid': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let gistid = gista#meta#get_valid_gistid(options.gistid)
    let filename = empty(options.filename)
          \ ? ''
          \ : gista#meta#get_valid_filename(gistid, options.filename)
    let gist = gista#resource#gists#get(gistid)
    if has_key(gist, 'html_url')
      return gist.html_url . (
            \ empty(filename)
            \   ? ''
            \   : '#file-' . tolower(substitute(filename, '\.', '-', 'g'))
            \)
    else
      return ''
    endif
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return ''
  endtry
endfunction
function! gista#command#browse#open(...) abort
  let options = get(a:000, 0, {})
  let url = gista#command#browse#call(options)
  if !empty(url)
    call s:F.open(url)
  endif
endfunction
function! gista#command#browse#yank(...) abort
  let options = get(a:000, 0, {})
  let url = gista#command#browse#call(options)
  if !empty(url)
    call gista#util#clip(url)
  endif
endfunction
function! gista#command#browse#echo(...) abort
  let options = get(a:000, 0, {})
  let url = gista#command#browse#call(options)
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
          \   'complete': function('g:gista#meta#complete_filename'),
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
          \   'complete': function('g:gista#meta#complete_gistid'),
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
  call gista#meta#assign_gistid(options, '%')
  call gista#meta#assign_filename(options, '%')
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#browse#default_options),
        \ options,
        \)
  if options.yank
    call gista#command#browse#yank(options)
  elseif options.echo
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
