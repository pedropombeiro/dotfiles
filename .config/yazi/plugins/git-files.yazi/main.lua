--- @since 26.1.22

local cwd = ya.sync(function() return cx.active.current.cwd end)

local function fail(content) return ya.notify { title = "Git Files", content = content, timeout = 5, level = "error" } end

local function run(bin, args, cwd_path)
	local cmd = Command(bin)
	if cwd_path then cmd = cmd:cwd(tostring(cwd_path)) end
	return cmd:arg(args):output()
end

local function detect_vcs(start)
	local out, err = run("git", { "rev-parse", "--show-toplevel" }, start)
	if not err and out.status.success then
		local root = Url(out.stdout:gsub("[\r\n]+$", ""))
		return "git", root, "Git tracked files"
	end

	local out2, err2 = run("yadm", { "ls-files", "--error-unmatch", "." }, start)
	if not err2 and out2.status.success then
		local home = os.getenv("HOME")
		if home then return "yadm", Url(home), "yadm tracked files" end
	end

	return nil, "Not inside a Git or yadm repository"
end

local function entry()
	local start = cwd()
	local bin, root, title = detect_vcs(start)
	if not bin then return fail(root) end

	local output, err = run(bin, { "ls-files", "-z" }, root)
	if err then
		return fail("Failed to run `" .. bin .. " ls-files`, error: " .. err)
	elseif not output.status.success then
		return fail("Failed to run `" .. bin .. " ls-files`, stderr: " .. output.stderr)
	end

	local id = ya.id("ft")
	local search_cwd = root:into_search(title)
	ya.emit("cd", { Url(search_cwd), source = "search" })
	ya.emit("update_files", { op = fs.op("part", { id = id, url = Url(search_cwd), files = {} }) })

	local files = {}
	for line in output.stdout:gmatch("[^%z]+") do
		local url = search_cwd:join(line)
		local cha = fs.cha(url, true)
		if cha then
			files[#files + 1] = File { url = url, cha = cha }
		end
	end
	ya.emit("update_files", { op = fs.op("part", { id = id, url = Url(search_cwd), files = files }) })
	ya.emit("update_files", { op = fs.op("done", { id = id, url = search_cwd, cha = Cha { mode = tonumber("100644", 8) } }) })
end

return { entry = entry }
