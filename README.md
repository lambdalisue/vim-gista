vim-gista
===============================================================================
**This is under construction**

*vim-gista* is a plugin which helps users to manipulate GitHub gists.
This plugin provides basic manipulation features listing below:

1.  List gists
    -	Own gists
    -	Own starred gists
    -	All public gists of a specific user
    -	All public gists in GitHub gist
2.  Post gists
    -	Create a new gist from the current buffer
    -	Create a new gist which contains all opened buffers
3.  Open gists
    -	Open files in the user owned gist with |modifiable|
    -	Open files in a specific user's gist with |nomodifiable|
4.  Edit gists (owned gists)
    -	Update file content changes in the current opened gist buffer
    -	Update a description or a publish status of a gist (a gist under the
    	cursor in the gist list window)
    -	Update a description or a publish status of a gist which is linked to
    	the current opened gist buffer
    -	Rename a file name of a gist file (a gist file under the cursor in the
    	gist list window)
    -	Rename a file name of a gist file which is linked to the current
    	opened gist buffer
    -	Remove a file form a gist (a gist file under the cursor in the gist
    	list window)
    -	Remove a file from a gist which is linked to the current opened gist
    	buffer
5.  Delete gists (owned gists)
    -	Delete a gist (a gist under the cursor in the gist list window)
    -	Delete a gist which is linked to the current opened gist buffer
6.  Star/Unstar gist
    -	Star/Unstar a gist (a gist under the cursor in the gist list window)
6.  Fork gist
    -	Fork a gist (a gist under the cursor in the gist list window)

The original concepts and source codes are taken from mattn/gist.vim but most
of codes are dramatically refactered to establish new implementations.

Reference: mattn/gist.vim - https://github.com/mattn/gist-vim

