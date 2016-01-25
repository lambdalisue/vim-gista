let s:V = gista#vital()
let s:Dict = s:V.import('Data.Dict')
let s:ArgumentParser = s:V.import('ArgumentParser')

let s:registry = {}

function! gista#command#is_registered(name) abort
  return index(keys(s:registry), a:name) != -1
endfunction
function! gista#command#register(name, command, complete, ...) abort
  try
    call gista#util#validate#key_not_exists(
          \ a:name, s:registry,
          \ 'A command "%value" has already been registered',
          \)
    let s:registry[a:name] = {
          \ 'command': type(a:command) == type('')
          \   ? function(a:command)
          \   : a:command,
          \ 'complete': type(a:complete) == type('')
          \   ? function(a:complete)
          \   : a:complete,
          \}
  catch /^vim-gista: ValidationError/
    call gista#util#handle_exception(v:exception)
  endtry
endfunction
function! gista#command#unregister(name) abort
  try
    call gista#util#validate#key_exists(
          \ a:name, s:registry,
          \ 'A command "%value" has not been registered yet',
          \)
    unlet s:registry[a:name]
  catch /^vim-gista: ValidationError/
    call gista#util#handle_exception(v:exception)
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gista#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gista',
          \ 'description': [
          \   'A gist manipulation command',
          \ ],
          \})
    call s:parser.add_argument(
          \ '--apiname', '-n', [
          \   'A temporary API name used only in this command execution',
          \ ], {
          \   'complete': function('gista#option#complete_apiname'),
          \})
    call s:parser.add_argument(
          \ '--username', '-u', [
          \   'Temporary login as USERNAME only in this command execution',
          \ ], {
          \   'complete': function('gista#option#complete_username'),
          \   'conflicts': ['anonymous'],
          \})
    call s:parser.add_argument(
          \ '--anonymous', '-a', [
          \   'Temporary logout only in this command execution',
          \ ], {
          \   'conflicts': ['username'],
          \})
    call s:parser.add_argument(
          \ 'action', [
          \   'An action name of vim-gista. The following actions are available:',
          \   '- status  : Show a current API status',
          \   '- login   : Login to a specified username of a specified API',
          \   '- logout  : Logout from a specified API',
          \   '- open    : Get and open a file of a gist',
          \   '- json    : Get and open a gist as a json file',
          \   '- browse  : Browse an existing gist in a system browser',
          \   '- list    : List gist entries of a lookup',
          \   '- commits : List commits of a gist',
          \   '- post    : Post content(s) to a gist',
          \   '- patch   : Post content to an existing gist',
          \   '- rename  : Rename a file of an existing gist',
          \   '- remove  : Remove a file of an existing gist',
          \   '- delete  : Delete an existing gist',
          \   '- fork    : Fork an existing gist',
          \   '- star    : Star an existing gist',
          \   '- unstar  : Unstar an existing gist',
          \ ], {
          \   'required': 1,
          \   'terminal': 1,
          \   'complete': function('s:complete_action'),
          \})
    function! s:parser.hooks.post_validate(options) abort
      if get(a:options, 'anonymous')
        let a:options.username = ''
        unlet a:options.anonymous
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction
function! s:complete_action(arglead, cmdline, cursorpos, ...) abort
  let available_commands = ['login', 'logout'] + keys(s:registry)
  return filter(available_commands, 'v:val =~# "^" . a:arglead')
endfunction
function! gista#command#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if !empty(options)
    let bang  = a:1
    let range = a:2
    let args  = join(options.__unknown__)
    let name  = get(options, 'action', '')
    if name ==# 'login'
      call gista#command#login#command(
            \ bang, range, args,
            \ s:Dict.pick(options, ['apiname', 'username']),
            \)
    elseif name ==# 'logout'
      call gista#command#logout#command(
            \ bang, range, args,
            \ s:Dict.pick(options, ['apiname']),
            \)
    elseif name ==# 'status'
      call gista#command#status#command(
            \ bang, range, args,
            \)
    elseif gista#command#is_registered(name)
      let session = gista#client#session(options)
      try
        if session.enter()
          call s:registry[name].command(bang, range, args)
        endif
      finally
        call session.exit()
      endtry
    else
      echo parser.help()
    endif
  endif
endfunction
function! gista#command#complete(arglead, cmdline, cursorpos, ...) abort
  let bang    = a:cmdline =~# '\v^Gista!'
  let cmdline = substitute(a:cmdline, '\C^Gista!\?\s', '', '')
  let cmdline = substitute(cmdline, '[^ ]\+$', '', '')
  let parser  = s:get_parser()
  let options = call(parser.parse, [bang, [0, 0], cmdline], parser)
  if !empty(options)
    let name = get(options, 'action', '')
    if name ==# 'login'
      return gista#command#login#complete(
            \ a:arglead, cmdline, a:cursorpos,
            \ s:Dict.pick(options, ['apiname', 'username']),
            \)
    elseif name ==# 'logout'
      return gista#command#logout#complete(
            \ a:arglead, cmdline, a:cursorpos,
            \ s:Dict.pick(options, ['apiname']),
            \)
    elseif name ==# 'status'
      return gista#command#status#complete(
            \ a:arglead, cmdline, a:cursorpos,
            \)
    elseif gista#command#is_registered(name)
      let session = gista#client#session(options)
      try
        if session.enter()
          return s:registry[name].complete(a:arglead, cmdline, a:cursorpos)
        endif
      finally
        call session.exit()
      endtry
    endif
  endif
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

" Register sub commands
call gista#command#register('open',
      \ 'gista#command#open#command',
      \ 'gista#command#open#complete',
      \)
call gista#command#register('json',
      \ 'gista#command#json#command',
      \ 'gista#command#json#complete',
      \)
call gista#command#register('browse',
      \ 'gista#command#browse#command',
      \ 'gista#command#browse#complete',
      \)
call gista#command#register('list',
      \ 'gista#command#list#command',
      \ 'gista#command#list#complete',
      \)
call gista#command#register('commits',
      \ 'gista#command#commits#command',
      \ 'gista#command#commits#complete',
      \)
call gista#command#register('post',
      \ 'gista#command#post#command',
      \ 'gista#command#post#complete',
      \)
call gista#command#register('patch',
      \ 'gista#command#patch#command',
      \ 'gista#command#patch#complete',
      \)
call gista#command#register('rename',
      \ 'gista#command#rename#command',
      \ 'gista#command#rename#complete',
      \)
call gista#command#register('remove',
      \ 'gista#command#remove#command',
      \ 'gista#command#remove#complete',
      \)
call gista#command#register('delete',
      \ 'gista#command#delete#command',
      \ 'gista#command#delete#complete',
      \)
call gista#command#register('fork',
      \ 'gista#command#fork#command',
      \ 'gista#command#fork#complete',
      \)
call gista#command#register('star',
      \ 'gista#command#star#command',
      \ 'gista#command#star#complete',
      \)
call gista#command#register('unstar',
      \ 'gista#command#unstar#command',
      \ 'gista#command#unstar#complete',
      \)
