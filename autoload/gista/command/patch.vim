let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

function! s:handle_exception(exception) abort " {{{
  redraw
  let canceled_by_user_patterns = [
        \ '^vim-gista: Login canceled',
        \ '^vim-gista: ValidationError: An API name cannot be empty',
        \ '^vim-gista: ValidationError: An API account username cannot be empty',
        \ '^vim-gista: ValidationError: A gist ID cannot be empty',
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
function! gista#command#patch#call(...) abort " {{{
  let options = get(a:000, 0, {})
  try
    let content = gista#api#call_patch(options)
    let b:gista = {
          \ 'apiname': gista#api#get_current_apiname(),
          \ 'username': gista#api#get_current_username(),
          \ 'anonymous': 0,
          \ 'gistid': gista#api#patch#get_current_gistid(),
          \}
    redraw
    call gista#util#prompt#info(printf(
          \ 'The content has patched to the gist "%s"',
          \ content.id,
          \))
    return content
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return ''
  endtry
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:A.new({
          \ 'name': 'Gista patch',
          \ 'description': 'Patch a current buffer content into an existing gist',
          \})
    call s:parser.add_argument(
          \ 'gistid',
          \ 'A gist ID', {
          \   'complete': function('g:gista#api#complete_gistid'),
          \})
    call s:parser.add_argument(
          \ '--apiname',
          \ 'An API name', {
          \   'type': s:A.types.value,
          \   'complete': function('g:gista#api#complete_apiname'),
          \})
    call s:parser.add_argument(
          \ '--username',
          \ 'A username of an API account.', {
          \   'type': s:A.types.value,
          \   'complete': function('g:gista#api#complete_username'),
          \})
    call s:parser.add_argument(
          \ '--description', '-d',
          \ 'A description of a gist', {
          \   'type': s:A.types.value,
          \})
  endif
  return s:parser
endfunction " }}}
function! gista#command#patch#command(bang, range, ...) abort " {{{
  let options = s:get_parser().parse(a:bang, a:range, get(a:000, 0, ''))
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gista#command#patch#default_options),
        \ options,
        \)
  " get filenames
  " not like post, patch only support a current buffer
  let options.filenames = [expand('%:t')]
  let options.contents  = [getline(1, '$')]
  call gista#command#patch#call(options)
endfunction " }}}
function! gista#command#patch#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:get_parser().complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

call gista#define_variables('command#patch', {
      \ 'default_options': {},
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
