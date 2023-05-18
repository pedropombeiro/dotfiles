autocmd BufNewFile,BufRead,BufWritePost crontab.txt setfiletype crontab " Overwrite text filetype
autocmd BufNewFile,BufRead,BufWritePost *.crontab setfiletype crontab
