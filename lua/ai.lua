-- ==========================================================================
-- AI INTEGRATION (OpenRouter)
-- ==========================================================================

local M = {}

-- Register orange border highlight once at load time
vim.api.nvim_set_hl(0, "AIFloatBorder", { fg = "#FFA500" })

-- --------------------------------------------------------------------------
-- CONFIG LAYER
-- --------------------------------------------------------------------------

local ai_config_file = vim.fn.stdpath("data") .. "/ai_config.json"

local function load_ai_config()
    local f = io.open(ai_config_file, "r")
    if f then
        local content = f:read("*a")
        f:close()
        local ok, state = pcall(vim.fn.json_decode, content)
        if ok and state then
            return state
        end
    end
    return { model = "qwen/qwen3-coder" }
end

local function save_ai_config()
    local json = vim.fn.json_encode(M.config)
    local f = io.open(ai_config_file, "w")
    if f then
        f:write(json)
        f:close()
    end
end

M.config = load_ai_config()

return M
