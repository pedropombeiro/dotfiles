autocmd BufNewFile,BufRead,BufWritePost crontab.txt set filetype=crontab " Overwrite text filetype
autocmd BufNewFile,BufRead,BufWritePost *.crontab setfiletype crontab
