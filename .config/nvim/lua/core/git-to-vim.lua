-- Git to Vim --

vim.cmd([[
function OpenBranchCommitedFiles()

  let cmd = 'ruby -r ~/.shellrc/zshrc.d/functions/scripts/git-helpers.rb -e "puts changed_branch_files(format: :vim)"'
  let parent_branch_cmd = 'ruby -r ~/.shellrc/zshrc.d/functions/scripts/git-helpers.rb -e "puts compute_parent_branch()"'
  let files = systemlist(l:cmd)
  let parent_branch = system(l:parent_branch_cmd)
  let cmd = 'git diff --name-only --diff-filter=AMU | grep -v "^bin/"'
  let unstaged_files = systemlist(l:cmd)

  let all_files = uniq(sort(l:files + l:unstaged_files))
  for f in all_files
    execute 'edit ' . l:f
  endfor

  if strlen(l:parent_branch) > 0
    execute 'Gitsigns change_base ' . l:parent_branch . ' true'
  endif
endfunction

:command Branch call OpenBranchCommitedFiles()
]])
