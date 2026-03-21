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

-- --------------------------------------------------------------------------
-- CONTEXT BUILDERS
-- --------------------------------------------------------------------------

local function build_autogen_context(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local buf_path = vim.api.nvim_buf_get_name(bufnr)
    local dir = vim.fn.fnamemodify(buf_path, ":h")

    local headers = {}
    for _, line in ipairs(lines) do
        local header_name = line:match('^#include%s*"([^"]+)"')
        if header_name then
            local header_path = dir .. "/" .. header_name
            local f = io.open(header_path, "r")
            if f then
                local content = f:read("*a")
                f:close()
                table.insert(headers, "// --- " .. header_name .. " ---\n" .. content)
            end
            -- silently skip if file not found
        end
    end

    local file_content = table.concat(lines, "\n")
    if #headers > 0 then
        return table.concat(headers, "\n") .. "\n// --- current file ---\n" .. file_content
    end
    return file_content
end

local function get_visual_selection(bufnr, line1, line2)
    -- line1/line2 are 1-based (from opts.line1/opts.line2)
    -- nvim_buf_get_lines is 0-based: subtract 1 from start, end is exclusive so line2 is correct
    local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
    return table.concat(lines, "\n")
end

local function build_explain_context(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    return table.concat(lines, "\n")
end

return M
