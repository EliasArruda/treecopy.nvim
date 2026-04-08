--- @class TreecopyConfig
--- @field ignore string[] Patterns of files/directories to ignore
--- @field title string Title used in the Markdown header
--- @field keymap string|false Keyboard shortcut to open the format selector
--- @field max_depth number|nil Maximum recursion depth for the tree
--- @field output_format "markdown" | "yaml" | "plain" | "json" Default output format
--- @field show_hidden boolean Whether to include hidden files (starting with dot)
--- @field icons table Dictionary of glyphs for UI and visual tree
--- @field which_key table Integration settings for which-key.nvim

local M = {}

-- =============================================================================
-- [ CONFIGURATION AND STATE ]
-- =============================================================================

local default_opts = {
	ignore = { ".git", "node_modules", "__pycache__", ".next", "dist", ".DS_Store" },
	title = "📁 Project File Tree",
	keymap = "<leader>fq",
	max_depth = nil,
	output_format = "markdown",
	show_hidden = false,
	icons = {
		success = "✅",
		error = "❌",
		warning = "⚠️",
		info = "ℹ️",
		tree = "🌳",
		copy = "📋",
	},
	which_key = {
		icon = "🌲",
		description = "Copy File Tree (Select Format)",
		group = "Project",
	},
}

local config = {}

-- =============================================================================
-- [ DATA SERIALIZERS ]
-- =============================================================================

--- Recursive YAML serializer with proper indentation
--- @param data table The node structure
--- @param indent_level number Current depth level
--- @return string
local function to_yaml(data, indent_level)
	indent_level = indent_level or 0
	local indent = string.rep("  ", indent_level)
	local lines = {
		string.format("%s- name: %q", indent, data.name),
		string.format("%s  type: %s", indent, data.type),
	}

	if data.contents and #data.contents > 0 then
		table.insert(lines, string.format("%s  contents:", indent))
		for _, item in ipairs(data.contents) do
			table.insert(lines, to_yaml(item, indent_level + 2))
		end
	end
	return table.concat(lines, "\n")
end

--- Pure Lua Pretty-Print JSON Serializer
--- @param obj table Table to convert
--- @param indent string Indentation prefix
--- @return string
local function pretty_json(obj, indent)
	indent = indent or ""
	local next_indent = indent .. "  "
	local str = ""

	if type(obj) == "table" then
		local is_array = #obj > 0
		str = is_array and "[\n" or "{\n"
		local parts = {}
		for k, v in pairs(obj) do
			local key = is_array and "" or string.format("%q: ", k)
			table.insert(parts, string.format("%s%s%s", next_indent, key, pretty_json(v, next_indent)))
		end
		str = str .. table.concat(parts, ",\n") .. "\n" .. indent .. (is_array and "]" or "}")
	elseif type(obj) == "string" then
		str = string.format("%q", obj)
	else
		str = tostring(obj)
	end
	return str
end

-- =============================================================================
-- [ DATA EXTRACTION ]
-- =============================================================================

--- Extract tree data using the system 'tree' binary (Performance-optimized)
--- @param root string Root directory
--- @param format string Requested format
--- @return string|nil
local function fetch_native(root, format)
	local cmd_parts = { "tree" }
	-- Force JSON output if structured data is needed
	if format == "json" or format == "yaml" then
		table.insert(cmd_parts, "-J")
	end
	if config.show_hidden then
		table.insert(cmd_parts, "-a")
	end

	table.insert(cmd_parts, "--dirsfirst --noreport")
	if config.max_depth then
		table.insert(cmd_parts, "-L " .. tostring(config.max_depth))
	end

	local ignores = table.concat(config.ignore, "|")
	if ignores ~= "" then
		table.insert(cmd_parts, "-I " .. vim.fn.shellescape(ignores))
	end
	table.insert(cmd_parts, vim.fn.shellescape(root))

	local output = vim.fn.system(table.concat(cmd_parts, " "))
	return vim.v.shell_error == 0 and output or nil
end

--- Extract data using Lua's libuv bindings (Fallback mechanism)
--- @param root string Current path
--- @param depth number|nil Max depth
--- @param current_depth number|nil Current recursion depth
--- @return table
local function fetch_lua_structure(root, depth, current_depth)
	current_depth = current_depth or 0
	local node = { name = vim.fn.fnamemodify(root, ":t"), type = "directory", contents = {} }
	local handle = vim.loop.fs_scandir(root)
	if not handle then
		return node
	end

	while true do
		local name, ftype = vim.loop.fs_scandir_next(handle)
		if not name then
			break
		end
		if not config.show_hidden and name:sub(1, 1) == "." then
			goto continue
		end

		local ignored = false
		for _, p in ipairs(config.ignore) do
			if name:match(p) then
				ignored = true
				break
			end
		end
		if ignored then
			goto continue
		end

		if ftype == "directory" then
			if not depth or (current_depth + 1 < depth) then
				table.insert(node.contents, fetch_lua_structure(root .. "/" .. name, depth, current_depth + 1))
			else
				table.insert(node.contents, { name = name, type = "directory", contents = {} })
			end
		else
			table.insert(node.contents, { name = name, type = "file" })
		end
		::continue::
	end
	return node
end

--- Generate ASCII visual tree using Lua
local function fetch_lua_visual(root, depth, current_depth)
	current_depth = current_depth or 0
	local result = {}
	local handle = vim.loop.fs_scandir(root)
	if not handle then
		return result
	end

	while true do
		local name, ftype = vim.loop.fs_scandir_next(handle)
		if not name then
			break
		end
		if not config.show_hidden and name:sub(1, 1) == "." then
			goto continue
		end

		local ignored = false
		for _, p in ipairs(config.ignore) do
			if name:match(p) then
				ignored = true
				break
			end
		end
		if ignored then
			goto continue
		end

		local icon = ftype == "directory" and "📁" or "📄"
		table.insert(result, string.format("%s├── %s %s", string.rep("│   ", current_depth), icon, name))

		if ftype == "directory" and (not depth or current_depth + 1 < depth) then
			vim.list_extend(result, fetch_lua_visual(root .. "/" .. name, depth, current_depth + 1))
		end
		::continue::
	end
	return result
end

-- =============================================================================
-- [ CORE LOGIC ]
-- =============================================================================

--- Core function to copy the tree to the system clipboard
--- @param opts TreecopyConfig|nil Overrides for this specific call
function M.copy_tree(opts)
	local run_conf = vim.tbl_deep_extend("force", config, opts or {})
	local root = run_conf.root or vim.fn.getcwd()
	local fmt = run_conf.output_format
	local data

	-- Try native binary first
	if vim.fn.executable("tree") == 1 then
		data = fetch_native(root, fmt)
	end

	-- Fallback to Lua implementation if native fails or is missing
	if not data or data == "" then
		data = (fmt == "json" or fmt == "yaml") and fetch_lua_structure(root, run_conf.max_depth)
			or fetch_lua_visual(root, run_conf.max_depth)
	end

	local final_output = ""
	if fmt == "json" then
		local obj = type(data) == "string" and vim.json.decode(data) or data
		final_output = pretty_json(obj)
	elseif fmt == "yaml" then
		local obj = type(data) == "string" and vim.json.decode(data) or data
		-- 'tree -J' returns an array; we target the root object
		local target = type(obj) == "table" and (obj[1] or obj) or obj
		final_output = to_yaml(target)
	elseif fmt == "plain" then
		final_output = type(data) == "table" and table.concat(data, "\n") or data
	else -- Markdown (Default)
		local tree_str = type(data) == "table" and table.concat(data, "\n") or data
		final_output = string.format(
			"# %s\n\n**Root:** `%s`\n\n```text\n%s\n```\n\n_Generated by treecopy.nvim_ 🌲",
			run_conf.title,
			root,
			tree_str
		)
	end

	-- Copy to system clipboard
	vim.fn.setreg("+", final_output)
	if vim.fn.has("unix") == 1 then
		vim.fn.setreg("*", final_output)
	end

	vim.notify(
		"Copied as " .. fmt:upper() .. "!",
		vim.log.levels.INFO,
		{ title = "treecopy.nvim", icon = config.icons.success }
	)
end

--- Open an interactive UI selector to choose the output format
function M.select_format_and_copy()
	local formats = { "markdown", "json", "yaml", "plain" }
	vim.ui.select(formats, {
		prompt = "🌲 Select output format for the file tree:",
		format_item = function(item)
			return "Copy as " .. item:upper()
		end,
	}, function(choice)
		if choice then
			M.copy_tree({ output_format = choice })
		end
	end)
end

-- =============================================================================
-- [ PLUGIN SETUP ]
-- =============================================================================

function M.setup(opts)
	config = vim.tbl_deep_extend("force", default_opts, opts or {})

	-- Register User Commands
	vim.api.nvim_create_user_command("TreeCopy", function(args)
		local f = (args.args ~= "") and args.args or config.output_format
		M.copy_tree({ output_format = f })
	end, {
		nargs = "?",
		complete = function()
			return { "markdown", "json", "yaml", "plain" }
		end,
		desc = "Copy project tree to clipboard",
	})

	-- Integration with Which-Key (V3+)
	local has_wk, wk = pcall(require, "which-key")
	if has_wk and config.keymap then
		wk.add({
			{
				config.keymap,
				M.select_format_and_copy,
				desc = config.which_key.description,
				icon = config.which_key.icon,
				mode = "n",
			},
		})
	elseif config.keymap then
		vim.keymap.set("n", config.keymap, M.select_format_and_copy, { desc = config.which_key.description })
	end
end

return M
