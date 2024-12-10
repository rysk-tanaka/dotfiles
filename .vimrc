set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim

filetype plugin indent on    " required

set number
set title
set autoindent
"set smartindent
set expandtab
set tabstop=4
set shiftwidth=4
set ambiwidth=double
set nrformats-=octal
set history=50
set hlsearch

syntax on

filetype plugin on
filetype indent on
"sw=softtabstop, sts=shiftwidth, ts=tabstop, et=expandtab
autocmd FileType ruby        setlocal sw=2 sts=2 ts=2 et
autocmd FileType html        setlocal sw=2 sts=2 ts=2 et
autocmd FileType css         setlocal sw=2 sts=2 ts=2 et
autocmd FileType javascript  setlocal sw=2 sts=2 ts=2 et
autocmd FileType js          setlocal sw=2 sts=2 ts=2 et
autocmd FileType htmldjango  setlocal sw=2 sts=2 ts=2 et
autocmd FileType vue         setlocal sw=2 sts=2 ts=2 et
autocmd FileType ts          setlocal sw=2 sts=2 ts=2 et
autocmd FileType sh          setlocal sw=2 sts=2 ts=2 et
"autocmd FileType cpp         setlocal sw=2 sts=2 ts=2 et
autocmd FileType arduino     setlocal sw=2 sts=2 ts=2 et
autocmd FileType typescript  setlocal sw=2 sts=2 ts=2 et
autocmd FileType json        setlocal sw=2 sts=2 ts=2 et
autocmd FileType jsonc       setlocal sw=2 sts=2 ts=2 et

" for ts
" https://qiita.com/kazuyaseo/items/4a5a41ef0cb824bc94fd
set re=0
