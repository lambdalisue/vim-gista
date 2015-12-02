let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:A = s:V.import('ArgumentParser')

let s:registry = {}

function! gista#command#is_registered(name) abort " {{{
  return index(keys(s:registry), a:name) != -1
endfunction " }}}
function! gista#command#register(name, command, complete, ...) abort " {{{
  if gista#command#is_registered(a:name) && !g:gista#debug
    throw printf(
          \ 'vim-gista: a command "%s" has already been registered.',
          \ a:name,
          \)
  endif
  let s:registry[a:name] = {
        \ 'command': a:command,
        \ 'complete': a:complete,
        \ 'instance': get(a:000, 0, {}),
        \}
endfunction " }}}
function! gista#command#unregister(name) abort " {{{
  if !gista#command#is_registered(a:name)
    throw printf(
          \ 'vim-gista: a command "%s" has not been registered.',
          \ a:name,
          \)
  endif
  unlet! s:registry[a:name]
endfunction " }}}

function! s:get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:A.new({
          \ 'name': 'Gista',
          \ 'description': [
          \   'A gist manipulation command',
          \ ],
          \})
    call s:parser.add_argument(
          \ 'action', [
          \   'An action name of vim-gista. The following actions are available:',
          \   '- get  : Get and open a gist',
          \   '- list : Fetch and display a list of gist entries',
          \ ], {
          \   'terminal': 1,
          \   'completer': function('gista#command#complete_action'),
          \})
  endif
  return s:parser
endfunction " }}}
function! gista#command#complete_action(arglead, cmdline, cursorpos, ...) abort " {{{
  return filter(keys(s:registry), 'v:val =~# "^" . a:arglead')
endfunction " }}}
function! gista#command#command(bang, range, ...) abort " {{{
  let options = s:get_parser().parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let name = get(options, 'action')
    if gista#command#is_registered(name)
      let command = s:registry[name]
      let args = [a:bang, a:range, join(options.__unknown__)]
      if empty(get(command, 'instance', {}))
        call call(command.command, args)
      else
        call call(command.command, args, command.instance)
      endif
    else
      echo s:parser.help()
    endif
  endif
endfunction " }}}
function! gista#command#complete(arglead, cmdline, cursorpos) abort " {{{
  let bang = a:cmdline =~# '\v^Gista!'
  let cmdline = substitute(a:cmdline, '\C\v^Gista!?\s', '', '')
  let cmdline = substitute(cmdline, '\v[^ ]*$', '', '')
  let options = s:get_parser().parse(bang, [0, 0], cmdline)
  let name = get(options, 'action', 'help')

  if options.__bang__ || !gista#command#is_registered(name)
    let candidates = s:get_parser().complete(
          \ a:arglead, a:cmdline, a:cursorpos, options
          \)
  else
    let command = s:registry[name]
    let args = [a:arglead, cmdline, a:cursorpos]
    if empty(get(command, 'instance', {}))
      let candidates = call(command.complete, args)
    else
      let candidates = call(command.complete, args, command.instance)
    endif
  endif
  return candidates
endfunction " }}}

" Register commands
call gista#command#register('read',
      \ 'gista#command#read#command',
      \ 'gista#command#read#complete',
      \)
call gista#command#register('list',
      \ 'gista#command#list#command',
      \ 'gista#command#list#complete',
      \)
call gista#command#register('post',
      \ 'gista#command#post#command',
      \ 'gista#command#post#complete',
      \)

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
