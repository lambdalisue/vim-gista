vim-gista
===============================================================================
[![Travis CI](https://img.shields.io/travis/lambdalisue/vim-gista/master.svg?style=flat-square&label=Travis%20CI)](https://travis-ci.org/lambdalisue/vim-gista) [![AppVeyor](https://img.shields.io/appveyor/ci/lambdalisue/vim-gista/master.svg?style=flat-square&label=AppVeyor)](https://ci.appveyor.com/project/lambdalisue/vim-gista/branch/master) ![Version 2.0.0](https://img.shields.io/badge/version-2.0.0-yellow.svg?style=flat-square) ![Support Vim 7.4 or above](https://img.shields.io/badge/support-Vim%207.4%20or%20above-yellowgreen.svg?style=flat-square) [![MIT License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE) [![Doc](https://img.shields.io/badge/doc-%3Ah%20vim--gista-orange.svg?style=flat-square)](doc/vim-gista.txt)

*vim-gista* is a plugin for manipulating [Gist](https://gist.github.com/) in Vim.
It provide the following features:

- [x] List gists of a particular lookup
- [x] Open a gist as a JSON file
- [x] Open a file of a gist
- [x] Post a content of the current buffer
- [x] Post contents of buffers/files
- [x] Patch a content of the current buffer to a gist
- [ ] Rename files in a gist
- [ ] Remove files in a gist
- [x] Delete a gist
- [x] Star/Unstar a gist
- [x] Folk a gist
- [ ] List folks of a gist
- [ ] List commits of a gist

Requirements
-------------------------------------------------------------------------------
One of the following is required for communicating with Gist API.

- Vim compiled with `python` and/or `python3` (Recommended)
- [cURL](http://curl.haxx.se)
- [wget](https://www.gnu.org/software/wget)

cURL or wget is a minimum requirement.
To enable fast fetching in `:Gista list`, you need a Vim compiled with `python` and/or `python3`.

Install
-------------------------------------------------------------------------------
Use [neobundle.vim](https://github.com/Shougo/neobundle.vim) or [vim-plug](https://github.com/junegunn/vim-plug) as:

```vim
" vim-plug
Plug 'lambdalisue/vim-gista'

" neobundle.vim
NeoBundle 'lambdalisue/vim-gista'

" neobundle.vim (Lazy)
NeoBundleLazy 'lambdalisue/vim-gista', {
    \ 'autoload': {
    \    'commands': ['Gista'],
    \}}
```

Or install the repository into your `runtimepath` manually.


Usage
-------------------------------------------------------------------------------
**While GitHub's Gist API limit the access rate from an anonymous user, login into your API account is strongly recommended.**

### Authorization

To login an API with your account, call `:Gista login` to create a new personal access token of a Gist API as:

```vim
:Gista login YOUR_GITHUB_USER_NAME
```

Then follow the instruction showed after the command execution.
It will create a personal access token of GitHub's Gist API and store it into the local cache.
If you would like to use a different API such as GitHub Enterprise (GHE), call `call gista#api#register({apiname}, {baseurl})` to register a new API and use `--apiname` option to specify the registered API like:

```vim
:call gista#api#register('GHE', 'https://your.ghe.api.url/')
:Gista login YOUR_GHE_USER_NAME --apiname GHE
```

Note that `gista#api#register()` is not permanent so you need to add the line into your `.vimrc` to register the API permanently.

To logout, call `:Gista logout` for temporal logout. If you would like to logout permanently, use `--permanent` option then your personal access token will be removed from local cache.

```vim
" Logout (user does not require to fill password to re-login)
:Gista logout
" Logout permanently (user requires to fill password to re-login)
:Gista logout --permanent
```

### Temporal authorization

All commands except `login` and `logout` allow users to login/logout temporary within the command execution.
To login to an API with your account temporary, specify `--username` option to `:Gista` command like:

```vim
:Gista --username=YOUR_GITHUB_USER_NAME {command} [{options}]
```

Then the specified account is used while the `{command}` execution.
Note that `--username` option is specified before `{command}`.

If you want to logout from an API temporary, specify `--anonymous` option to `:Gista` command like:

```vim
:Gista --anonymous {command} [{options}]
```

In this case as well, note that `--anonymous` option is specified before `{command}`.

Additionally, you can specify an API name with `--apiname` option like:

```vim
:Gista --apiname=GHE --username=YOUR_GHE_USER_NAME {command} [{options}]
```

### List gists of a lookup

To list gists, use `:Gista[!] list` command like:

```vim
:Gista list {lookup}
```

WIP.

### Open a file or JSON of a gist

To open a file content of a gist, use `:Gista open` command like:

```vim
:Gista open {gistid} {filename}
```

WIP

To open a JSON of a gist, use `:Gista json` command like:

```vim
:Gista json {gistid}
```

WIP

### Post a new gist

To post a content of the current buffer, call `:Gista post` like:

```vim
:Gista post
```

WIP

### Modify an existing gist

To patch a content of the current buffer to an existing gist, call `:Gista patch` like:

```vim
:Gista patch {gistid}
```

WIP

### Misc

WIP

Harmonic plugins
-------------------------------------------------------------------------------
The following plugins will be harmonic plugins of vim-gista:

- [ ] vim-gista-unite : Allow users to use unite.vim interface for listing
- [ ] vim-gista-ctrlp : Allow users to use ctrlp.vim interface for listing
- [ ] vim-gista-neocomplete : Complete a gist ID with neocomplete.vim
- [ ] vim-gista-deoplete : Complete a gist ID with deoplete.vim

WIP


For users who use a previous version (v0.1.17)
-------------------------------------------------------------------------------
Most of features, commands, or options are drastically changed from a previous version.
See [Migration from v1 to v2](https://github.com/lambdalisue/vim-gista/wiki/Migration-from-v1-to-v2) or use [`v0.1.17`](https://github.com/lambdalisue/vim-gista/tree/v0.1.17) tag for instance.

License
-------------------------------------------------------------------------------
The MIT License (MIT)

Copyright (c) 2014 Alisue, hashnote.net

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
