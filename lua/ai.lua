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

-- --------------------------------------------------------------------------
-- CONSTANTS: hardcoded fallback prompts (used when prompt files are missing)
-- --------------------------------------------------------------------------

local FALLBACK_PROMPTS = {
    autogen = [[You are a code generation assistant embedded in a text editor.
Output ONLY valid code. No explanations, no markdown fences, no commentary.
Match the language, style, and conventions of the surrounding code exactly.
If the context is C or C++, follow C89/C99/C++ conventions as shown in the file.]],
    explain = [[You are a concise code explanation assistant embedded in a text editor.
Respond in two short sections:
1. SYNTAX: Identify the language constructs and patterns used (2-4 lines max).
2. PURPOSE: Explain what this code does in the context of the file (3-5 lines max).
Be direct. No preamble, no filler. Fit your entire response within 20 lines.]],
}

-- --------------------------------------------------------------------------
-- UTILITIES
-- --------------------------------------------------------------------------

local function strip_fences(text)
    text = text:gsub("^```[^\n]*\n", "")
    text = text:gsub("\n```%s*$", "")
    text = text:gsub("^```%s*$", "")
    return text
end

local function load_prompt(name)
    local path = vim.fn.stdpath("config") .. "/ai_prompts/" .. name .. ".txt"
    local f = io.open(path, "r")
    if f then
        local content = f:read("*a")
        f:close()
        return content
    end
    return FALLBACK_PROMPTS[name] or ""
end

return M
