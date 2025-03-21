local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local parser = require("spring_endpoints.parser")

local function open_file(entry)
	-- Abrir el archivo
	vim.cmd("edit " .. entry.file)

	-- Función para buscar texto plano en el archivo
	local function search_plain_text(text)
		vim.fn.cursor(1, 1) -- Empezar la búsqueda desde el inicio del archivo
		local found_line = vim.fn.search(text, "w")
		return found_line
	end

	-- Función para extraer el valor de la anotación @RequestMapping
	local function extract_request_mapping_value(line)
		local line_content = vim.fn.getline(line)
		local value = line_content:match('@RequestMapping%("([^"]+)"')
			or line_content:match('@RequestMapping%([^"]*"([^"]+)"')
		return value
	end

	-- Buscar la anotación @RequestMapping en la clase
	local class_pattern = "@RequestMapping"
	local found_class = search_plain_text(class_pattern)

	if found_class ~= 0 then
		local base_path = extract_request_mapping_value(found_class)
		if base_path then
			-- Normalizar rutas quitando "/" final de @RequestMapping si existe
			base_path = base_path:gsub("/$", "")

			-- Comparar la ruta base con el endpoint seleccionado
			if entry.path:find(base_path, 1, true) == 1 then
				-- Extraer la ruta del método
				local method_path = entry.path:sub(#base_path + 1)
				method_path = method_path:gsub("^/*", "/") -- Asegurar que comience con una barra

				-- Capitalizar correctamente el método (por ejemplo, "get" -> "Get")
				local capitalized_method = entry.method:sub(1, 1):upper() .. entry.method:sub(2):lower()

				-- Construir el texto de búsqueda para el método
				local method_text = "@" .. capitalized_method .. 'Mapping("' .. method_path .. '")'
				local found_method = search_plain_text(method_text)

				if found_method ~= 0 then
					vim.fn.cursor(vim.fn.line("."), 1) -- Mover cursor al inicio de la línea
					vim.api.nvim_command("normal! zz") -- Centrar la ventana en el cursor
					return
				end
			end
		end
	end

	-- Si no se encuentra la anotación de la clase o no coincide la ruta base, buscar la ruta completa
	local capitalized_method = entry.method:sub(1, 1):upper() .. entry.method:sub(2):lower()
	local full_method_text = "@" .. capitalized_method .. 'Mapping("' .. entry.path .. '")'
	local found_full_method = search_plain_text(full_method_text)

	if found_full_method ~= 0 then
		vim.fn.cursor(vim.fn.line("."), 1) -- Mover cursor al inicio de la línea
		vim.api.nvim_command("normal! zz") -- Centrar la ventana en el cursor
		return
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
