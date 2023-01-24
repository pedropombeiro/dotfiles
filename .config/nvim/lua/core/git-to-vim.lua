-- Git to Vim --

vim.cmd([[
function OpenBranchCommitedFiles()

  let cmd = 'ruby -r ~/.shellrc/zshrc.d/functions/scripts/git-helpers.rb -e "puts changed_branch_files(format: :vim)"'
  let files = systemlist(l:cmd)
  let cmd = 'git diff --name-only --diff-filter=AMU'
  let unstaged_files = systemlist(l:cmd)

  let all_files = uniq(sort(l:files + l:unstaged_files))
  for f in all_files
    execute 'edit ' . l:f
  endfor
endfunction

:command Branch call OpenBranchCommitedFiles()
]])
