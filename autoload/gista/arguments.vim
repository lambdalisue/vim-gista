"******************************************************************************
" Gista command options
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! s:get_parser() " {{{
  if !exists('s:parser') || 1
    let s:parser = gista#utils#vital#ArgumentParesr()
    call s:parser.add_argument(
          \ '--login',
          \ 'Login Gist API', {
          \   'kind': s:parser.kinds.any,
          \   'conflict_with': 'command',
          \})
    call s:parser.add_argument(
          \ '--logout',
          \ 'Logout Gist API', {
          \   'conflict_with': 'command',
          \})
    call s:parser.add_argument(
          \ '--permanently',
          \ 'Logout permanently', {
          \   'subordination_of': 'logout',
          \})
    call s:parser.add_argument(
          \ '--list', '-l',
          \ 'List gists and show in gist list window', {
          \   'kind': s:parser.kinds.any,
          \   'conflict_with': 'command',
          \})
    call s:parser.add_argument(
          \ '--page',
          \ 'Specify a page index of gist list', {
          \   'kind': s:parser.kinds.value,
          \   'subordination_of': 'list',
          \})
    call s:parser.add_argument(
          \ '--nocache',
          \ 'Get gist list without using cache', {
          \   'subordination_of': 'list',
          \})
    call s:parser.add_argument(
          \ '--open', '-o',
          \ 'Open a specified gist in a gist buffer', {
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--post',
          \ 'Post a buffer to create/modify a gist', {
          \   'conflict_with': 'command',
          \})
    call s:parser.add_argument(
          \ '--description', '-d',
          \ 'A description of the posting gist', {
          \   'kind': s:parser.kinds.value,
          \   'subordination_of': 'post',
          \})
    call s:parser.add_argument(
          \ '--multiple', '-m',
          \ 'Post a gist with all visible buffers', {
          \   'subordination_of': 'post',
          \})
    call s:parser.add_argument(
          \ '--anonymous', '-a',
          \ 'Post a gist as an anonymous gist', {
          \   'conflict_with': 'publish_status',
          \   'subordination_of': 'post',
          \})
    call s:parser.add_argument(
          \ '--private', '-p',
          \ 'Post a gist as a private gist', {
          \   'conflict_with': 'publish_status',
          \   'subordination_of': 'post',
          \})
    call s:parser.add_argument(
          \ '--public', '-P',
          \ 'Post a gist as a public gist', {
          \   'conflict_with': 'publish_status',
          \   'subordination_of': 'post',
          \})
    call s:parser.add_argument(
          \ '--gistid',
          \ 'Specify a gist ID', {
          \   'kind': s:parser.kinds.value,
          \   'subordination_of': [
          \     'open', 'post', 'rename', 'remove', 'delete',
          \     'star', 'unstar', 'is-starred', 'fork', 'browse',
          \     'disconnect', 'yank', 'yank-gistid', 'yank-url',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--filename',
          \ 'Specify a filename', {
          \   'kind': s:parser.kinds.value,
          \   'subordination_of': [
          \     'open', 'rename', 'remove', 'disconnect', 'browse',
          \     'yank', 'yank-gistid', 'yank-url',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--rename',
          \ 'Rename a filename of a file in the gist', {
          \   'conflict_with': 'command',
          \   'depend_on': ['gistid', 'filename'],
          \})
    call s:parser.add_argument(
          \ '--remove',
          \ 'Remove a file from the gist', {
          \   'conflict_with': 'command',
          \   'depend_on': ['gistid', 'filename'],
          \})
    call s:parser.add_argument(
          \ '--delete',
          \ 'Delete the gist', {
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--star',
          \ 'Star the gist', {
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--unstar',
          \ 'Unstar the gist', {
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--is-starred',
          \ 'Display if the gist is starred', {
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--fork',
          \ 'Fork the gist', {
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--browse',
          \ 'Browse the gist', {
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--disconnect',
          \ 'Disconnect a buffer from the gist', {
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--yank',
          \ 'Yank Gist ID or URL', {
          \   'kind': s:parser.kinds.any,
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \   'choices': ['gistid', 'url'],
          \})
    call s:parser.add_argument(
          \ '--yank-gistid',
          \ 'Yank Gist ID (and filename)', {
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \})
    call s:parser.add_argument(
          \ '--yank-url',
          \ 'Yank Gist ID (and filename)', {
          \   'conflict_with': 'command',
          \   'depend_on': 'gistid',
          \})
    function! s:parser.hooks.pre_completion(args) abort " {{{
      let args = copy(a:args)
      " gistid (GistPost does not require gistid but use)
      let gistid = gista#utils#find_gistid(0, '$')
      if !empty(gistid)
        let args.gistid = 1
      endif
      " filename
      if exists('b:gistinfo') &&
            \ self.has_subordination_of('filename', args)
        let args.filename = 1
      endif
      return args
    endfunction " }}}
    function! s:parser.hooks.pre_validation(args) abort " {{{
      let args = copy(a:args)
      " post (if no conflict options are specified)
      if !self.has_conflict_with('post', args)
        let args.post = self.true
      endif
      " gistid (GistPost does not require gistid but use)
      if self.has_subordination_of('gistid', args)
        let gistid = gista#utils#find_gistid(
              \   a:args.__range__[0],
              \   a:args.__range__[1],
              \)
        if !empty(gistid)
          let args.gistid = gistid
        endif
      endif
      " filename
      if exists('b:gistinfo') &&
            \ self.has_subordination_of('filename', args)
        let args.filename = b:gistinfo.filename
      endif
      " yank
      if has_key(args, 'yank')
        if type(args.yank) != 1 && args.yank == self.true
          unlet args.yank
          let args.yank = g:gista#default_yank_method
        endif
      endif
      return args
    endfunction " }}}
    function! s:parser.hooks.post_transform(args) abort " {{{
      let args = copy(a:args)
      " private => public
      if has_key(args, 'private')
        let args.public = !args.private
        unlet args['private']
      endif
      return args
    endfunction " }}}
  endif
  return s:parser
endfunction " }}}


function! gista#arguments#parse(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.parse, a:000, parser)
endfunction " }}}
function! gista#arguments#complete(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
