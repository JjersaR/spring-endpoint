local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local parser = require("spring_endpoints.parser")

local function open_file(entry)
	vim.cmd("edit " .. entry.file)

	-- Función para buscar texto exacto ignorando mayúsculas/minúsculas y espacios
	local function search_mapping(method_pattern, path)
		vim.fn.cursor(1, 1)
		while true do
			-- Buscar la anotación del método primero
			local found = vim.fn.search(method_pattern, "W")
			if found == 0 then
				break
			end

			-- Verificar si la línea contiene la ruta
			local line = vim.fn.getline(found):lower()
			if line:find(path:lower(), 1, true) then
				return found
			end
		end
		return 0
	end

	-- Construir patrones de búsqueda flexibles
	local method_pattern = "@" .. entry.method:lower() .. "mapping"
	local capitalized_method = entry.method:sub(1, 1):upper() .. entry.method:sub(2):lower()

	-- 1. Primero buscar la ruta completa
	local found_line = search_mapping(method_pattern, entry.path)

	-- 2. Si no se encuentra, buscar ruta relativa
	if found_line == 0 then
		-- Buscar RequestMapping en la clase
		vim.fn.cursor(1, 1)
		local class_mapping = vim.fn.search("@RequestMapping", "w")
		if class_mapping > 0 then
			local line = vim.fn.getline(class_mapping):lower()
			local base_path = line:match("[\"']([^\"']+)[\"']")
			if base_path then
				base_path = base_path:gsub("^/+", ""):gsub("/+$", "")

				-- Verificar si el endpoint comienza con la ruta base
				if entry.path:lower():find(base_path, 1, true) == 1 then
					local method_path = entry.path:sub(#base_path + 1):gsub("^/+", "")
					found_line = search_mapping(method_pattern, method_path)
				end
			end
		end
	end

	-- 3. Último intento: búsqueda menos estricta
	if found_line == 0 then
		vim.fn.cursor(1, 1)
		found_line = vim.fn.search(entry.path:gsub("{[^}]+}", ".*"), "w")
	end

	-- Mover cursor si se encontró
	if found_line > 0 then
		vim.fn.cursor(found_line, 1)
		vim.api.nvim_command("normal! zz")
	else
		print("⚠️ The end point not Found.")
	end
end

local function search_endpoints()
	local endpoints = parser.find_endpoints(vim.fn.getcwd())

	local seen_paths = {} -- Para evitar duplicados
	-- Filtrar los endpoints que NO contengan "[REQUEST]" y que NO tengan entry.method == "REQUEST"
	local filtered_endpoints = {}
	for _, ep in ipairs(endpoints) do
		if not ep.path:match("^REQUEST") and ep.method ~= "REQUEST" and not seen_paths[ep.path] then
			table.insert(filtered_endpoints, ep)
			seen_paths[ep.path] = true
		end
	end

	pickers
		.new({}, {
			prompt_title = "Spring Boot Endpoints",
			prompt_prefix = " ",
			finder = finders.new_table({
				results = filtered_endpoints,
				entry_maker = function(entry)
					return {
						value = entry,
						display = string.format("[%s] %s", entry.method, entry.path),
						ordinal = entry.method .. " " .. entry.path,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry().value
					actions.close(prompt_bufnr)
					open_file(selection)
				end)
				return true
			end,
		})
		:find()
end

return {
	search_endpoints = search_endpoints,
}
