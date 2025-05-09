local M = {}

local uv = vim.loop

-- Buscar anotaciones de endpoints en un archivo
local function extract_endpoints(file_path)
	local endpoints = {}
	local file = io.open(file_path, "r")

	if not file then
		return endpoints
	end

	local class_base_path = ""
	local inside_class = false

	-- Función para extraer rutas de anotaciones complejas
	local function extract_mapping_path(line)
		-- Patrones para capturar diferentes formatos
		local patterns = {
			-- Formato: @GetMapping(value = "/path", ...)
			'@%a+Mapping%s*%(%s*value%s*=%s*"([^"]+)"',
			-- Formato: @GetMapping("/path")
			'@%a+Mapping%s*%(%s*"([^"]+)"',
			-- Formato: @GetMapping(path = "/path", ...)
			'@%a+Mapping%s*%(%s*path%s*=%s*"([^"]+)"',
		}

		for _, pattern in ipairs(patterns) do
			local path = line:match(pattern)
			if path then
				return path
			end
		end
		return nil
	end

	for line in file:lines() do
		-- Buscar @RequestMapping en la clase
		local class_path = extract_mapping_path(line)
		if class_path and line:match("@RequestMapping") then
			class_base_path = class_path
			inside_class = true
		end

		-- Buscar métodos con @*Mapping
		local method = line:match("@(%a+)Mapping")
		if method then
			local path = extract_mapping_path(line)
			if path then
				local full_path = class_base_path ~= "" and class_base_path .. "/" .. path or path
				full_path = full_path:gsub("//+", "/")
				table.insert(endpoints, {
					method = method:upper(),
					path = full_path,
					file = file_path,
				})
			end
		end

		-- Detectar si salimos de la clase
		if inside_class and line:match("^}") then
			class_base_path = ""
			inside_class = false
		end
	end

	file:close()
	return endpoints
end

-- Recorrer el proyecto en busca de archivos con controladores
function M.find_endpoints(root_dir)
	local endpoints = {}

	local function scan_dir(dir)
		local handle = uv.fs_scandir(dir)
		if not handle then
			return
		end

		while true do
			local name, type = uv.fs_scandir_next(handle)
			if not name then
				break
			end

			local full_path = dir .. "/" .. name
			if type == "directory" then
				scan_dir(full_path)
			elseif name:match("%.java$") then
				local found = extract_endpoints(full_path)
				for _, ep in ipairs(found) do
					table.insert(endpoints, ep)
				end
			end
		end
	end

	scan_dir(root_dir .. "/src/main/java")
	return endpoints
end

return M
