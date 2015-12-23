let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:F = s:V.import('System.File')
let s:A = s:V.import('ArgumentParser')

function! s:handle_exception(exception) abort " {{{
  redraw
  let canceled_by_user_patterns = [
        \ '^vim-gista: Login canceled',
        \ '^vim-gista: ValidationError: An API name cannot be empty',
        \ '^vim-gista: ValidationError: An API account username cannot be empty',
        \ '^vim-gista: ValidationError: A gist ID cannot be empty',
        \ '^vim-gista: ValidationError: A filename cannot be empty',
        \]
  for pattern in canceled_by_user_patterns
    if a:exception =~# pattern
      call gista#util#prompt#warn('Canceled')
      return
    endif
  endfor
  " else
  call gista#util#prompt#error(a:exception)
endfunction " }}}
function! gista#command#browse#call(...) abort " {{{
  let options = extend({
        \ 'gistid': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let gist = gista#api#gists#get(
          \ options.gistid, options
          \)
    let filename = tolower(substitute(options.filename, '\.', '-', 'g'))
    let url = gist.html_url . (empty(filename) ? '' : '#file-' . filename)
    call s:F.open(url)
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
  endtry
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista browse',
          \ 'description': 'Open a gist with a system browser',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#api#gists#complete_gistid'),
          \   'type': s:A.types.value,
          \})
    call s:parser.add_argument(
          \ 'filename',
          \ 'A filename', {
          \   'complete': function('g:gista#api#gists#complete_filename'),
          \   'type': s:A.types.value,
          \   'required': 0,
          \})
  endif
  return s:parser
endfunction " }}}
function! gista#command#browse#command(...) abort " {{{
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#open#default_options),
        \ options,
        \)
  call gista#command#browse#call(options)
endfunction " }}}
function! gista#command#browse#complete(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction " }}}

call gista#define_variables('command#browse', {
      \ 'default_options': {},
      \})



let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
