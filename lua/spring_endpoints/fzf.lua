local fzf_lua = require("fzf-lua")
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
	-- Filtrar los endpoints que NO contengan "[REQUEST]"
	local filtered_endpoints = {}
	for _, ep in ipairs(endpoints) do
		if not ep.path:match("^REQUEST") and ep.method ~= "REQUEST" and not seen_paths[ep.path] then
			table.insert(filtered_endpoints, ep)
			seen_paths[ep.path] = true
		end
	end

	-- Configurar fzf-lua para mostrar los endpoints
	fzf_lua.fzf_exec(function(cb)
		for _, ep in ipairs(filtered_endpoints) do
			cb(string.format("[%s] %s", ep.method, ep.path))
		end
		cb(nil) -- Finalizar la lista
	end, {
		actions = {
			["default"] = function(selected)
				local selected_entry = selected[1]
				if selected_entry then
					local method, path = selected_entry:match("%[([^%]]+)%]%s+(.+)")
					if method and path then
						for _, ep in ipairs(filtered_endpoints) do
							if ep.method == method and ep.path == path then
								open_file(ep)
								break
							end
						end
					end
				end
			end,
		},
		prompt = "Spring Boot Endpoints> ",
	})
end

return {
	search_endpoints = search_endpoints,
}
