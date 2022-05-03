"-- Git to Vim --

function! TabIsEmpty()
    return winnr('$') == 1 && len(expand('%')) == 0 && line2byte(line('$') + 1) <= 2
endfunction

function OpenBranchCommitedFiles()

  let parent_branch = trim(system("git show-branch --current | grep '\*' | grep -v `git rev-parse --abbrev-ref HEAD` | head -n1 | sed 's/[^[]*\\[\\([^]^]*\\).*\\].*/\\1/'"))
  let cmd = 'git diff --name-only ' . l:parent_branch . '...'
  let files = systemlist(l:cmd)
  let started_empty = TabIsEmpty()

  if started_empty == 0
    " Ensure that we close all tabs not related to current branch
    0tabnew
    2,$tabdo :q
    let started_empty = 1
  endif

  for f in l:files
    execute 'tabedit ' . l:f
  endfor
  if started_empty == 1
    execute '1tabclose'
  endif
endfunction

:command Branch call OpenBranchCommitedFiles()

:nnoremap <leader>ob :Branch<ESC>

