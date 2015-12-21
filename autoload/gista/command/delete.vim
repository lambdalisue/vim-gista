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
function! gista#command#delete#call(...) abort " {{{
  let options = extend({
        \ 'gistid': '',
        \}, get(a:000, 0, {}),
        \)
  try
    let gist = gista#api#gists#delete_cache(
          \ options.gistid, options,
          \)
    let client = gista#api#get_current_client()
    for filename in options.filenames
      if bufexists(filename)
        call setbufvar(bufnr(filename), 'gista', {
              \ 'apiname': client.apiname,
              \ 'username': client.get_authorized_username(),
              \ 'gistid': gist.id,
              \ 'filename': fnamemodify(expand(filename), ':t'),
              \})
      endif
    endfor
    redraw
    call gista#command#list#update_if_necessary()
    call gista#util#prompt#info(printf(
          \ 'The content(s) has posted to a gist "%s"',
          \ gist.id,
          \))
    return gist
  catch /^vim-gista:/
    call s:handle_exception(v:exception)
    return ''
  endtry
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:A.new({
          \ 'name': 'Gista delete',
          \ 'description': 'Delete a gist',
          \})
    call s:parser.add_argument(
          \ '--remote', '-r',
          \ 'Delete a gist from remote as well', {
          \   'type': s:A.types.value,
          \})
  endif
  return s:parser
endfunction " }}}
function! gista#command#delete#command(...) abort " {{{
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
  if empty(options.__unknown__)
    " Get content from the current buffer
    let filenames = [expand('%')]
    let contents = [
          \ call('getline', options.__range__)
          \]
  else
    let filenames = filter(
          \ map(options.__unknown__, 'expand(v:val)'),
          \ 'bufexists(v:val) || filereadable(v:val)',
          \)
    let contents = map(
          \ copy(filenames),
          \ 'bufexists(v:val) ? getbufline(v:val, 1, "$") : readfile(v:val)',
          \)
  endif
  let options.filenames = map(filenames, 'fnamemodify(v:val, ":t")')
  let options.contents = contents
  call gista#command#post#call(options)
endfunction " }}}
function! gista#command#delete#complete(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction " }}}

call gista#define_variables('command#delete', {
      \ 'default_options': {},
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
