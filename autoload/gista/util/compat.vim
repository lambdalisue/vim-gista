let s:save_cpo = &cpo
set cpo&vim

" function! gista#util#compat#getcurpos() abort " {{{
if exists('*getcurpos')
  function! gista#util#compat#getcurpos() abort
    return getcurpos()
  endfunction
else
  function! gista#util#compat#getcurpos() abort
    return getpos('.')
  endfunction
endif
" }}}
" function! gista#util#compat#doautocmd(name) abort " {{{
" doautocmd User with <nomodeline>
" https://github.com/vim-jp/vim/commit/8399b184df06f80ca030b505920dd3e97be72f20
if (v:version == 703 && has('patch438')) || v:version >= 704
  function! gista#util#compat#doautocmd(name) abort
    execute 'doautocmd <nomodeline> User ' . a:name
  endfunction
else
  function! gista#util#compat#doautocmd(name) abort
    execute 'doautocmd User ' . a:name
  endfunction
endif
" }}}
" function! gista#util#compat#getbufvar(expr, varname, ...) abort " {{{
" https://github.com/vim-jp/vim/commit/51d92c00e8c731c3b8f79b1e5f3e6b47cb1d1192
if (v:version == 703 && has('patch831')) || v:version >= 704
  function! gista#util#compat#getbufvar(...) abort
    return call('getbufvar', a:000)
  endfunction
else
  function! gista#util#compat#getbufvar(expr, varname, ...) abort
    let v = getbufvar(a:expr, a:varname)
    return empty(v) ? get(a:000, 0, '') : v
  endfunction
endif
" }}}
" function! gista#util#compat#getwinvar(expr, varname, ...) abort " {{{
" https://github.com/vim-jp/vim/commit/51d92c00e8c731c3b8f79b1e5f3e6b47cb1d1192
if (v:version == 703 && has('patch831')) || v:version >= 704
  function! gista#util#compat#getwinvar(...) abort
    return call('getwinvar', a:000)
  endfunction
else
  function! gista#util#compat#getwinvar(expr, varname, ...) abort
    let v = getwinvar(a:expr, a:varname)
    return empty(v) ? get(a:000, 0, '') : v
  endfunction
endif
" }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
