let s:V = vital#of('vim_gista')
let s:Compat = s:V.import('Vim.Compat')

function! gista#vital() abort
  return s:V
endfunction

function! gista#throw(msg) abort
  throw printf('vim-gista: %s', a:msg)
endfunction

function! gista#define_variables(prefix, defaults) abort
  " Note:
  "   Funcref is not supported while the variable must start with a capital
  let prefix = empty(a:prefix)
        \ ? 'g:gista'
        \ : printf('g:gista#%s', a:prefix)
  for [key, value] in items(a:defaults)
    let name = printf('%s#%s', prefix, key)
    if !exists(name)
      silent execute printf('let %s = %s', name, string(value))
    endif
    unlet value
  endfor
endfunction

let s:_pattern1 = printf(
      \ '^gista://\(%s\)/\(%s\)/\(%s\)$',
      \ '[^/]\+',
      \ '[^/]\+\|[^/]\+/[^/]\+',
      \ '[^/]\+',
      \)
let s:_pattern2 = printf(
      \ '^gista://\(%s\)/\(%s\)\.json$',
      \ '[^/]\+',
      \ '[^/]\+\|[^/]\+/[^/]\+',
      \)
let s:schemes = [
      \ [s:_pattern1, {
      \   'apiname': 1,
      \   'gistid': 2,
      \   'filename': 3,
      \   'content_type': 'raw',
      \ }],
      \ [s:_pattern2, {
      \   'apiname': 1,
      \   'gistid': 2,
      \   'content_type': 'json',
      \ }],
      \]
function! gista#parse_filename(filename) abort
  for scheme in s:schemes
    if a:filename !~# scheme[0]
      continue
    endif
    let m = matchlist(a:filename, scheme[0])
    let o = {}
    for [key, value] in items(scheme[1])
      if type(value) == type(0)
        let o[key] = m[value]
      else
        let o[key] = value
      endif
      unlet value
    endfor
    return o
  endfor
  return {}
endfunction
function! gista#get(expr) abort
  let filename = expand(a:expr)
  let gista = s:Compat.getbufvar(a:expr, 'gista', {})
  let gista = extend(copy(gista), gista#parse_filename(filename))
  return gista
endfunction

call gista#define_variables('', {
      \ 'test': 0,
      \ 'debug': 0,
      \ 'develop': 0,
      \})
