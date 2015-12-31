let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:F = s:V.import('System.File')
let s:A = s:V.import('ArgumentParser')

function! s:get_absolute_url(gistid, filename) abort
    let gistid = gista#meta#get_valid_gistid(a:gistid)
    let gist   = gista#api#gists#get(gistid)
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
function! gista#command#browse#open(...) abort
  let options = extend({
        \ 'gistid': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let url = s:get_absolute_url(options.gistid, options.filename)
    call s:F.open(url)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction
function! gista#command#browse#yank(...) abort
  let options = extend({
        \ 'gistid': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let url = s:get_absolute_url(options.gistid, options.filename)
    call gista#util#clip(url)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction
function! gista#command#browse#echo(...) abort
  let options = extend({
        \ 'gistid': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let url = s:get_absolute_url(options.gistid, options.filename)
    echo url
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista browse',
          \ 'description': 'Open a gist with a system browser',
          \})
    call s:parser.add_argument(
          \ '--filename',
          \ 'A filename', {
          \   'complete': function('g:gista#meta#complete_filename'),
          \})
    call s:parser.add_argument(
          \ '--action',
          \ 'An action', {
          \   'choices': ['open', 'yank', 'echo'],
          \   'default': 'open',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#meta#complete_gistid'),
          \})
    call s:parser.hooks.validate()
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
  if options.action ==# 'open'
    call gista#command#browse#open(options)
  elseif options.action ==# 'yank'
    call gista#command#browse#yank(options)
  elseif options.action ==# 'echo'
    call gista#command#browse#echo(options)
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
