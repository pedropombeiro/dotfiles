-- Git to Vim --

vim.cmd([[
function! TabIsEmpty()
  return winnr('$') == 1 && len(expand('%')) == 0 && line2byte(line('$') + 1) <= 2
endfunction

function OpenBranchCommitedFiles()

  let cmd = 'ruby -r ~/.shellrc/zshrc.d/functions/scripts/git-helpers.rb -e "puts changed_branch_files(format: :vim)"'
  let files = systemlist(l:cmd)
  let cmd = 'git diff --name-only --diff-filter=AMU'
  let unstaged_files = systemlist(l:cmd)
  let started_empty = TabIsEmpty()

  if started_empty == 0
    " Ensure that we close all tabs not related to current branch
    0tabnew
    2,$tabdo :Bclose
    let started_empty = 1
  endif

  let all_files = uniq(sort(l:files + l:unstaged_files))
  for f in all_files
    execute 'edit ' . l:f
  endfor
  if started_empty == 1
    execute 'buffer 1 | Bclose'
  endif
endfunction

:command Branch call OpenBranchCommitedFiles()
]])
