-- Justfile support --

local function find_justfile_path(current_dir)
  while current_dir ~= '/' do
    local justfile_path = current_dir .. '/.justfile'
    local alt_justfile_path = current_dir .. '/justfile'

    if vim.fn.filereadable(justfile_path) == 1 then
      return justfile_path
    elseif vim.fn.filereadable(alt_justfile_path) == 1 then
      return alt_justfile_path
    else
      current_dir = vim.fs.dirname(current_dir)
    end
  end

  return nil -- Return nil if no .justfile or justfile is found
end

local function execute_just_recipe(opts)
  local file_dir = vim.fn.expand('%:p:h') -- Get the current directory
  local current_dir = vim.cmd.pwd()

  vim.cmd('cd ' .. file_dir .. ' | !just ' .. table.concat(opts.fargs, ' '))
  vim.cmd('cd ' .. current_dir)
end

vim.api.nvim_create_user_command('Just', execute_just_recipe, {
  nargs = '*',
  desc = 'Execute justfile recipe',
  complete = function(ArgLead, CmdLine, CursorPos)
    local recipes = {}
    local work_dir = vim.fn.expand('%:p:h')
    local justfile_path = find_justfile_path(work_dir)

    while justfile_path ~= nil do
      local parent_recipes = vim.fn.split(
        vim.fn.system('just --working-directory "' .. work_dir .. '" --justfile "' .. justfile_path .. '" --summary')
      )
      for i = 1, #parent_recipes do
        table.insert(recipes, parent_recipes[i])
      end

      justfile_path = find_justfile_path(vim.fs.dirname(vim.fs.dirname(justfile_path)))
    end

    return recipes
  end,
})
