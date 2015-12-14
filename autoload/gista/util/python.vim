let s:save_cpo = &cpo
set cpo&vim

let s:repository_root = expand('<sfile>:p:h:h:h:h')
let s:major_version = has('python') ? 2 : has('python3') ? 3 : 0

function! s:ensure_initialized_py2() abort " {{{
  if !has('python') || exists('s:python_initialized')
    return
  endif
  let s:python_initialized = 1
python <<EOF
import sys, vim, os
sys.path.insert(0, os.path.join(vim.eval('s:repository_root'), 'lib'))
EOF
endfunction " }}}
function! s:ensure_initialized_py3() abort " {{{
  if !has('python3') || exists('s:python3_initialized')
    return
  endif
  let s:python3_initialized = 1
python3 <<EOF
import sys, vim, os
sys.path.insert(0, os.path.join(vim.eval('s:repository_root'), 'lib'))
EOF
endfunction " }}}

function! gista#util#python#is_enabled() abort " {{{
  return has('python') || has('python3')
endfunction " }}}

function! gista#util#python#exec_code(code) abort " {{{
  if has('python') && has('python3')
    call s:major_version == 2
          \ ? gista#util#python#exec_code_py2(a:code)
          \ : gista#util#python#exec_code_py3(a:code)
  elseif has('python')
    call gista#util#python#exec_code_py2(a:code)
  elseif has('python3')
    call gista#util#python#exec_code_py3(a:code)
  endif
endfunction " }}}
function! gista#util#python#exec_code_py2(code) abort " {{{
  if has('python')
    call s:ensure_initialized_py2()
    execute printf(
          \ 'python %s',
          \ type(a:code) == type('') ? a:code : join(a:code, "\n"),
          \)
  endif
endfunction " }}}
function! gista#util#python#exec_code_py3(code) abort " {{{
  if has('python3')
    call s:ensure_initialized_py3()
    execute printf(
          \ 'python3 %s',
          \ type(a:code) == type('') ? a:code : join(a:code, "\n"),
          \)
  endif
endfunction " }}}

function! gista#util#python#eval_code(code) abort " {{{
  if has('python') && has('python3')
    return s:major_version == 2
          \ ? gista#util#python#eval_code_py2(a:code)
          \ : gista#util#python#eval_code_py3(a:code)
  elseif has('python')
    return gista#util#python#eval_code_py2(a:code)
  elseif has('python3')
    return gista#util#python#eval_code_py3(a:code)
  endif
endfunction " }}}
function! gista#util#python#eval_code_py2(code) abort " {{{
  if has('python')
    call s:ensure_initialized_py2()
    return pyeval(
          \ type(a:code) == type('') ? a:code : join(a:code, "\n"),
          \)
  endif
endfunction " }}}
function! gista#util#python#eval_code_py3(code) abort " {{{
  if has('python3')
    call s:ensure_initialized_py3()
    return py3eval(
          \ type(a:code) == type('') ? a:code : join(a:code, "\n"),
          \)
  endif
endfunction " }}}

function! gista#util#python#exec_file(path) abort " {{{
  if has('python') && has('python3')
    call s:major_version == 2
          \ ? gista#util#python#exec_file_py2(a:path)
          \ : gista#util#python#exec_file_py3(a:path)
  elseif has('python')
    call gista#util#python#exec_file_py2(a:path)
  elseif has('python3')
    call gista#util#python#exec_file_py3(a:path)
  endif
endfunction " }}}
function! gista#util#python#exec_file_py2(path) abort " {{{
  if has('python')
    call s:ensure_initialized_py2()
    execute printf('pyfile %s', fnameescape(a:path))
  endif
endfunction " }}}
function! gista#util#python#exec_file_py3(path) abort " {{{
  if has('python3')
    call s:ensure_initialized_py3()
    execute printf('py3file %s', fnameescape(a:path))
  endif
endfunction " }}}

function! gista#util#python#get_major_version() abort " {{{
  if has('python') && has('python3')
    return s:major_version
  elseif has('python')
    return 2
  elseif has('python3')
    return 3
  else
    return 0
  endif
endfunction " }}}
function! gista#util#python#set_major_version(version) abort " {{{
  if a:version == 3 && has('python3')
    let s:major_version = 3
  elseif a:version == 2 && has('python2')
    let s:major_version = 2
  endif
endfunction " }}}


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
