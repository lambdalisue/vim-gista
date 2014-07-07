"******************************************************************************
" Gista utility
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! gista#utils#datetime(str_datetime) abort " {{{
  " Create DateTime object from GitHub API datetime format
  let datetime_obj = gista#utils#vital#from_format(a:str_datetime, "%FT%T%z")
  " return formatted string
  return datetime_obj
endfunction " }}}
function! gista#utils#trancate(str, length) abort " {{{
  if len(a:str) > a:length
    return a:str[0:a:length-5] . ' ...'
  endif
  return a:str
endfunction " }}}
function! gista#utils#get_bufwidth() abort " {{{
  if &l:number
    let gwidth = &l:numberwidth
  else
    let gwidth = 0
  endif
  let fwidth = &l:foldcolumn
  let wwidth = winwidth(0)
  return wwidth - gwidth - fwidth
endfunction " }}}
function! gista#utils#call_on_buffer(expr, funcref, ...) abort " {{{
  let cbufnr = bufnr('%')
  let save_lazyredraw = &lazyredraw
  let &lazyredraw = 1
  if type(a:expr) == 0
    let tbufnr = a:expr
  else
    let tbufnr = bufnr(a:expr)
  endif
  if tbufnr == -1
    " no buffer is opened yet
    return 0
  endif
  let cwinnr = winnr()
  let twinnr = bufwinnr(tbufnr)
  if twinnr == -1
    " no window is opened
    execute tbufnr . 'buffer'
    call call(a:funcref, a:000)
    execute cbufnr . 'buffer'
  else
    execute twinnr . 'wincmd w'
    call call(a:funcref, a:000)
    execute cwinnr . 'wincmd w'
  endif
  let &lazyredraw = save_lazyredraw
  return 1
endfunction " }}}
function! gista#utils#provide_filename(filename, filetype, ...) " {{{
  let magicnum = get(a:000, 0, 0)
  let filename = fnamemodify(a:filename, ':t')
  let default_filename = g:gista#gist_default_filename
  if empty(filename) && !empty(a:filetype)
    let ext = gista#utils#guess_extension(a:filetype)
    if !empty(ext)
      let filename = printf('%s%d%s', default_filename, magicnum, ext)
    endif
  endif
  if empty(filename)
    let filename = printf('%s%d.txt', default_filename, magicnum)
  endif
  return filename
endfunction " }}}
function! gista#utils#guess_extension(filetype) " {{{
  if len(a:filetype) == 0
    return ''
  elseif has_key(s:consts.EXTMAP, a:filetype)
    return s:consts.EXTMAP[a:filetype]
  endif
  return '.' + a:filetype
endfunction " }}}
function! gista#utils#input_yesno(message, ...) "{{{
  " forked from Shougo/unite.vim
  " AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
  " License: MIT license  {{{
  "     Permission is hereby granted, free of charge, to any person obtaining
  "     a copy of this software and associated documentation files (the
  "     "Software"), to deal in the Software without restriction, including
  "     without limitation the rights to use, copy, modify, merge, publish,
  "     distribute, sublicense, and/or sell copies of the Software, and to
  "     permit persons to whom the Software is furnished to do so, subject to
  "     the following conditions:
  "
  "     The above copyright notice and this permission notice shall be included
  "     in all copies or substantial portions of the Software.
  "
  "     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  "     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  "     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  "     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  "     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  "     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  "     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  " }}}
  let default = get(a:000, 0, '')
  let yesno = input(a:message . ' [yes/no]: ', default)
  while yesno !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if yesno == ''
      echo 'Canceled.'
      break
    endif
    " Retry.
    call unite#print_error('Invalid input.')
    let yesno = input(a:message . ' [yes/no]: ')
  endwhile
  redraw
  return yesno =~? 'y\%[es]'
endfunction " }}}
function! gista#utils#get_gist_url(gist, ...) abort " {{{
  let url = get(a:gist, 'html_url', 'https://gist.github.com/' . a:gist.id)
  let filename = substitute(get(a:000, 0, ''), '\.', '-', '')
  if !empty(filename)
    let url = url . '#file-' . filename
  endif
  return url
endfunction " }}}
function! gista#utils#browse(url) abort " {{{
  try
    call openbrowser#open(a:url)
  catch /E117.*/
    " exists("*openbrowser#open") could not be used while this might be the
    " first time to call an autoload function.
    " Thus catch "E117: Unknown function" exception to check if there is a
    " newly implemented function or not.
    redraw
    echohl WarningMsg
    echo  'vim-gista require "tyru/open-browser.vim" plugin to oepn browsers. '
    echon 'It seems you have not installed that plugin yet. So ignore it.'
    echohl None
  endtry
endfunction " }}}
function! gista#utils#find_gistid(lnum, ...) " {{{
  if exists('b:gistinfo')
    return b:gistinfo.gistid
  endif
  let gistid_pattern = 'GistID:\s*\zs\w\+\ze'
  let content = join(getline(a:lnum, get(a:000, 0, a:lnum)), "\n")
  let gistid = matchstr(content, gistid_pattern)
  return gistid
endfunction " }}}
function! gista#utils#getbufvar(expr, name, ...) abort " {{{
  " Ref: https://github.com/vim-jp/issues/issues/245#issuecomment-13858947
  let default = get(a:000, 0, '')
  if v:version > 703 || (v:version == 703 && has('patch831'))
    return getbufvar(a:expr, a:name, default)
  else
    let value = getbufvar(a:expr, a:name)
    if type(value) == 1 && empty(value)
      return default
    endif
    return default
  endif
endfunction " }}}


let s:consts = {}
let s:consts.EXTMAP = {
      \ "actionscript": ".as",
      \ "php": ".aw",
      \ "csharp": ".cs",
      \ "lisp": ".el",
      \ "erlang": ".erl",
      \ "haskell": ".hs",
      \ "javascript": ".js",
      \ "objc": ".m",
      \ "markdown": ".md",
      \ "perl": ".pl",
      \ "python": ".py",
      \ "ruby": ".rb",
      \ "scheme": ".scm",
      \ "smalltalk": ".st",
      \ "smarty": ".tpl",
      \ "verilog": ".v",
      \ "vbnet": ".vb",
      \ "xquery": ".xq",
      \ "yaml": ".yml",
      \}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
