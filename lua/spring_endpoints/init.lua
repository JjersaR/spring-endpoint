local M = {}

-- Verificar si el usuario tiene instalado Telescope, fzf-lua o snacks.picker
local has_telescope, telescope = pcall(require, "spring_endpoints.telescope")
local has_fzf, fzf = pcall(require, "spring_endpoints.fzf")

-- Función principal de búsqueda
function M.search()
	if has_telescope then
		telescope.search_endpoints()
	elseif has_fzf then
		fzf.search_endpoints()
	end
end

return M
