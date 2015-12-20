let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()
let s:J = s:V.import('Web.JSON')
let s:G = s:V.import('Web.API.GitHub')

function! s:find_page(res, rel) abort " {{{
  let link = s:G.parse_response_link(a:res)
  let page = matchstr(get(link, a:rel, ''), '.*[&?]page=\zs\d\+\ze')
  return empty(page) ? 1 : str2nr(page)
endfunction " }}}
function! s:fetch_vim(client, url, params, indicator) abort " {{{
  redraw
  call gista#util#prompt#echo(printf(a:indicator, a:params.page))
  let res = a:client.get(a:url, a:params)
  let res.content = get(res, 'content', '')
  let res.content = empty(res.content) ? [] : s:J.decode(res.content)
  if res.status != 200
    call gista#api#throw_api_exception(res)
  endif
  return res.content
endfunction " }}}

function! gista#util#fetcher#vim(url, indicator, ...) abort " {{{
  let client = gista#api#get_current_client()
  let params = extend({
        \ 'since': '',
        \ 'per_page': g:gista#util#fetcher#default_per_page,
        \}, get(a:000, 0, {})
        \)
  redraw
  call gista#util#prompt#echo('Requesting the total number of pages ...')
  let res = client.head(a:url, params)
  let page_count = s:find_page(res, 'last')
  let indicator = printf(a:indicator, page_count)
  let entries = []
  for page in range(1, page_count)
    let params = extend(params, {
          \ 'page': page,
          \})
    call extend(entries, s:fetch_vim(client, a:url, params, indicator))
  endfor
  return entries
endfunction " }}}
function! gista#util#fetcher#python(url, indicator, ...) abort " {{{
  let client = gista#api#get_current_client()
  let params = extend({
        \ 'since': '',
        \ 'per_page': g:gista#util#fetcher#default_per_page,
        \}, get(a:000, 0, {})
        \)
  let g:gista#util#fetcher#_temporary_kwargs = extend(copy(params), {
        \ 'url': client.get_absolute_url(a:url),
        \ 'token': client.get_token(),
        \ 'indicator': a:indicator,
        \ 'nprocess': g:gista#util#fetcher#python_nprocess,
        \})
  call gista#util#python#exec_code([
        \ 'from gista import request, echo_status_vim',
        \ 'kwargs = vim.eval("g:gista#util#fetcher#_temporary_kwargs")',
        \ 'result = request(callback=echo_status_vim, **kwargs)',
        \])
  let [entries, exceptions] = gista#util#python#eval_code('result')
  if !empty(exceptions)
    let errormsg = join(exceptions, "\n")
    call gista#util#prompt#throw(printf('python: %s', errormsg))
  endif
  unlet g:gista#util#fetcher#_temporary_kwargs
  return entries
endfunction " }}}

" Configure variables
call gista#define_variables('util#fetcher', {
      \ 'default_per_page': 100,
      \ 'python_nprocess': 50,
      \})


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
