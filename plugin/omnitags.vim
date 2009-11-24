""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" File:
"   omnitags.vim
"
" Author:
"   fwlei <fwlei@live.com>
"
" Version:
"   0.1
"
" Description:
"   This plugin can help you to maintenance tags file.
"
"   There are 3 commands:
"
"     :OmniTagsLoad /path/to/tags-file
"
"     Load the tags-file and generate a list of source files indexed by
"     tags-file.
"
"     If tags-file doesn't exist, it can create a null file automaticlly.
"
"     Once tags loaded, buffer-write event will trigger a re-index operation
"     of current file if current file is existed in tags.
"
"     :OmniTagsUpdate {file1} {file2} ...
"
"     Update the tags-file loaded before, you can specify many files and use
"     wildcards(see ":h wildcards"), "wildignore" option(see "h: wildignore")
"     also influences the result of parse wildcards.
"
"     If files not in tags yet, the plugin will add those file to tags, if
"     files are already exists, the plugin will update them.
"
"     You can specify no files, for re-index all files that already indexed.
"
"     :OmniTagsUnload
"
"     Just a oppsite of :OmniTagsLoad, usually need not call by human.
"
" Installation:
"   Just drop the script to ~/.vim/plugin.
"
"   The plugin depends on ctags, install it at first.
"
" Options:
"   g:OmniTagsCtagsPrg = 'ctags'
"     The execute path of ctags command.
"
"   g:OmniTagsCtagsDeletePrg = 'sed'
"     There are two ways to delete tags from tags-file, default is use sed
"     command. But if you are in linux, I suggest you compile ctags_delete.c
"     and drop it into $PATH, it is more faster.
"
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if exists("loaded_OmniTags")
	finish
endif
let loaded_OmniTags = 1

let s:savedCpo = &cpo
set cpo&vim

if !exists("g:OmniTagsCtagsPrg")
	let g:OmniTagsCtagsPrg = "ctags"
endif

if !exists("g:OmniTagsCtagsDeletePrg")
	let g:OmniTagsCtagsDeletePrg = "sed"
endif

if !executable(g:OmniTagsCtagsPrg)
    echoe "can not execute ctags command, OmniTags disabled."
	finish
endif

if !executable(g:OmniTagsCtagsDeletePrg)
    echoe "can not execute ctags delete command, OmniTags disabled."
	finish
endif

"the utility functions

function! s:error(msg)
    echohl Error
    redraw
    echon a:msg
    redraw
    echohl None
endfunction

function! s:binaryInsert(list, item, beginPos, endPos)
    if len(a:list) == 0
        call add(a:list, a:item)
        return
    endif

    let size = a:endPos - a:beginPos
    if size > 1
        let middlePos = a:beginPos + ( size + 1 ) / 2
        if a:list[middlePos] > a:item
            call s:binaryInsert(a:list, a:item, a:beginPos, middlePos - 1)
        elseif a:list[middlePos] < a:item
            call s:binaryInsert(a:list, a:item, middlePos + 1, a:endPos)
        else
            return
        endif
    elseif size == 1
        if a:list[a:beginPos] > a:item
            call insert(a:list, a:item, a:beginPos)
        elseif a:list[a:endPos] < a:item
            call insert(a:list, a:item, a:endPos + 1)
        elseif a:list[a:beginPos] != a:item && a:list[a:endPos] != a:item
            call insert(a:list, a:item, a:endPos)
        else
            return
        endif
    elseif size == 0
        if a:list[a:beginPos] > a:item
            call insert(a:list, a:item, a:beginPos)
        elseif a:list[a:beginPos] < a:item
            call insert(a:list, a:item, a:beginPos + 1)
        else
            return
        endif
    endif
endfunction
            
function! s:genFileList(tagsFile)
    let lines = readfile(a:tagsFile)

    let fileList = []
    for line in lines
        let filename = matchstr(line, '^[^!\t][^\t]*\t\zs[^\t]\+')
        if len(filename) > 0
            let filename = fnamemodify(filename, ":p")
            if has('win32')
                let filename = tr(filename, "\\", "/")
            endif

            call s:binaryInsert(fileList, filename, 0, len(fileList) - 1)
        endif
    endfor

    return fileList
endfunction

function! s:createTagsFile(tagsFile)
	let ctagsCmd = g:OmniTagsCtagsPrg
    let ctagsCmd .= " -f \"".a:tagsFile."\" -L -"

	call system(ctagsCmd, 'I\ am\ sure\,\ no\ file\ in\ this\ position\!')
endfunction

function! s:addTags(tagsFile, fileList)
	let ctagsCmd = g:OmniTagsCtagsPrg
    let ctagsCmd .= " -a --c++-kinds=+p --fields=+iaS --extra=+q"
    let ctagsCmd .= " -f \"".a:tagsFile."\" -L -"

	call system(ctagsCmd, join(a:fileList, "\n"))
endfunction

function! s:deleteTags(tagsFile, fileList)
    if fnamemodify(g:OmniTagsCtagsDeletePrg, ":t:r") == "ctags_delete"
        call system("ctags_delete \"".a:tagsFile."\"", join(a:fileList, "\n"))
    elseif fnamemodify(g:OmniTagsCtagsDeletePrg, ":t:r") == "sed"
        let sedCmd = g:OmniTagsCtagsDeletePrg." -i -f - \"".a:tagsFile."\""

        let sedScript = ""
        for filename in a:fileList
            let sedScript .= "/".escape(filename, ' /')."/d\n"
        endfor

        call system(sedCmd, sedScript)
    endif
endfunction

"the user-interface functions

function! s:updateCurrentFile()
	if !exists("s:tagsFile") || !exists("s:fileList")
        call s:error("Please load tags file first!")
		return
	endif

	let filename = expand("%:p")
	if has("win32")
		let filename = tr(filename, "\\", "/")
	endif

    if index(s:fileList, filename) < 0
        return
    endif

	call s:deleteTags(s:tagsFile, [filename])
	call s:addTags(s:tagsFile, [filename])
endfunction

function! s:updateTags(...)
	if !exists("s:tagsFile") || !exists("s:fileList")
        call s:error("Please load tags file first!")
		return
	endif

    echon "Updating tags..."
    redraw

    if a:0 <= 0
        let choice = confirm("Update all files?", "&Yes\n&No")
        if choice == 1
            call s:createTagsFile(s:tagsFile)
            call s:addTags(s:tagsFile, s:fileList)
        endif

        return 
    endif

    let newFiles = []
    let oldFiles = []
    for filePat in a:000
        for filename in split(glob(filePat), "\n")
            let filename = fnamemodify(filename, ":p")
            if has("win32")
                let filename = tr(filename, "\\", "/")
            endif

            if !isdirectory(filename)
                if index(s:fileList, filename) >= 0
                    call add(oldFiles, filename)
                else
                    call add(newFiles, filename)
                endif
            endif
        endfor
    endfor

    let fileList = []

    if len(oldFiles) > 0
        call s:deleteTags(s:tagsFile, oldFiles)
        let fileList += oldFiles
    endif

    if len(newFiles) > 0
        call extend(s:fileList, newFiles)
        call sort(s:fileList)
        let fileList += newFiles
    endif

    if len(fileList) > 0
        call s:addTags(s:tagsFile, fileList)
    endif

    echon "Updating tags... Done!"
    redraw
endfunction

function! s:loadTags(path)
	if !filewritable(a:path)
        let choice = confirm("The tags file not exists, create it?", "&Yes\n&No")
        if choice == 1
            call s:createTagsFile(a:path)
        else
		    return
        endif
	endif

	if exists("s:fileList") || exists("s:tagsFile")
		call s:unloadTags()
	endif

    echon "Parsing tags file..."
    redraw

    let s:tagsFile = fnamemodify(a:path, ':p')
    if has("win32")
        let filename = tr(filename, "\\", "/")
    endif

    let s:fileList = s:genFileList(a:path)

   	let s:savedTags = &tags
    let &tags = s:tagsFile . ',' . &tags

    aug OmniTags
        au BufWritePost * call s:updateCurrentFile()
        au VimLeavePre * call s:unloadTags()
    aug END

    echon "Parsing tags file... Totally ".string(len(s:fileList))." file(s)."
    redraw
endfunction

function! s:unloadTags()
	if !exists("s:tagsFile") && !exists("s:fileList")
		return
	endif

	let &tags = s:savedTags
    au! OmniTags
    aug! OmniTags

	unlet s:savedTags
	unlet s:tagsFile
	unlet s:fileList
endfunction

" register commands

if !exists(":OmniTagsLoad")
	command -nargs=1 -complete=file OmniTagsLoad :call s:loadTags(<f-args>)
endif

if !exists(":OmniTagsUnload")
	command -nargs=0 OmniTagsUnload :call s:unloadTags()
endif
 
if !exists(":OmniTagsUpdate")
	command -nargs=* -complete=file OmniTagsUpdate :call s:updateTags(<f-args>)
endif

let &cpo = s:savedCpo
unlet s:savedCpo

