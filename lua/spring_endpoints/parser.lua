local M = {}

local uv = vim.loop

-- Buscar anotaciones de endpoints en un archivo
local function extract_endpoints(file_path)
	local endpoints = {}
	local file = io.open(file_path, "r")

	if not file then
		return endpoints
	end

	local class_base_path = "" -- Para almacenar la ruta base de la clase
	local inside_class = false -- Para saber si estamos dentro de una clase con @RequestMapping

	for line in file:lines() do
		-- Buscar @RequestMapping en la clase y guardar la ruta base
		local class_path = line:match("@RequestMapping%s*%(?[\"']([^\"']+)[\"']?%)")
		if class_path then
			class_base_path = class_path
			inside_class = true
		end

		-- Buscar métodos con @GetMapping, @PostMapping, etc.
		local method, path = line:match("@(%a+)Mapping%s*%(?[\"']([^\"']+)[\"']?%)")
		if method and path then
			local full_path = (class_base_path ~= "" and class_base_path .. "/" .. path) or path
			full_path = full_path:gsub("//", "/") -- Evitar doble slash
			table.insert(endpoints, { method = method:upper(), path = full_path, file = file_path })
		end

		-- Detectar si salimos de la clase
		if inside_class and line:match("^}") then
			class_base_path = "" -- Resetear la ruta base al salir de la clase
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
