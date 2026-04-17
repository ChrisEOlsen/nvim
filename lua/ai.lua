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
        if ok and type(state) == "table" then
            if not state.favorites then
                state.favorites = {}
            end
            return state
        end
    end
    return { model = "anthropic/claude-sonnet-4.6", favorites = {} }
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
If the context is C or C++, follow C89/C99/C++ conventions as shown in the file.
Always use Allman style braces (opening brace on its own line).
Omit braces for single-statement bodies (if, else, for, while, etc.) — put the statement on the next line, indented, with no braces.
The user message includes "Cursor is at line N." — any positional references in the task (e.g. "above", "below", "here") refer to that location in the file.]],
    explain = [[You are a concise code explanation assistant embedded in a text editor.
Respond in plain text only. No markdown, no bullet symbols, no headers, no bold, no code fences.
Respond in two short sections:
SYNTAX: Identify the language constructs and patterns used (2-4 lines max).
PURPOSE: Explain what this code does in the context of the file (3-5 lines max).
Be direct. No preamble, no filler. Fit your entire response within 20 lines.]],
    autoedit = [[You are a code editing assistant embedded in a text editor.
Output the ENTIRE file with your changes applied. No explanations, no markdown fences, no commentary.
Your entire response is the new file contents. Preserve ALL code not related to the task exactly as given.
Match the language, style, and conventions of the file exactly.
If the file is C or C++, use Allman style braces and omit braces for single-statement bodies.
Cursor is at line N refers to where the user is. Focus region lines X-Y is the user's selection.]],
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

local function myers_diff(a, b)
    local n, m = #a, #b
    local dp = {}
    for i = 0, n do
        dp[i] = {}
        for j = 0, m do
            if i == 0 or j == 0 then
                dp[i][j] = 0
            elseif a[i] == b[j] then
                dp[i][j] = dp[i - 1][j - 1] + 1
            else
                dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1])
            end
        end
    end
    local ops = {}
    local i, j = n, m
    while i > 0 or j > 0 do
        if i > 0 and j > 0 and a[i] == b[j] then
            table.insert(ops, 1, { op = "keep",   text = a[i] })
            i, j = i - 1, j - 1
        elseif j > 0 and (i == 0 or dp[i][j - 1] >= dp[i - 1][j]) then
            table.insert(ops, 1, { op = "insert", text = b[j] })
            j = j - 1
        else
            table.insert(ops, 1, { op = "delete", text = a[i] })
            i = i - 1
        end
    end
    return ops
end

local function format_diff_lines(ops)
    local CONTEXT = 3
    local display = { "AutoEdit diff — y to apply, n/q/Esc to cancel", "" }
    local highlights = {}  -- each entry: { 1-based display line index, hl_group }

    local changed = {}
    for idx, op in ipairs(ops) do
        if op.op ~= "keep" then changed[idx] = true end
    end

    local show = {}
    for idx = 1, #ops do
        if changed[idx] then
            for k = math.max(1, idx - CONTEXT), math.min(#ops, idx + CONTEXT) do
                show[k] = true
            end
        end
    end

    local old_n, new_n = 0, 0
    local last_shown = nil

    for idx, op in ipairs(ops) do
        if op.op == "keep" then
            old_n = old_n + 1; new_n = new_n + 1
        elseif op.op == "delete" then
            old_n = old_n + 1
        else
            new_n = new_n + 1
        end

        if show[idx] then
            if last_shown ~= nil and idx > last_shown + 1 then
                table.insert(display, "  ...")
            end
            if op.op == "keep" then
                table.insert(display, string.format("  line %4d   %s", old_n, op.text))
            elseif op.op == "delete" then
                table.insert(display, string.format("- line %4d   %s", old_n, op.text))
                table.insert(highlights, { #display, "DiffDelete" })
            else
                table.insert(display, string.format("+ line %4d   %s", new_n, op.text))
                table.insert(highlights, { #display, "DiffAdd" })
            end
            last_shown = idx
        end
    end

    return display, highlights
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

-- --------------------------------------------------------------------------
-- API CALLER
-- --------------------------------------------------------------------------

local function call_openrouter(system_prompt, user_message)
    local api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key or api_key == "" then
        vim.notify("AI: OPENROUTER_API_KEY is not set", vim.log.levels.ERROR)
        return nil
    end

    local request = {
        model = M.config.model,
        messages = {
            { role = "system", content = system_prompt },
            { role = "user",   content = user_message  },
        },
    }
    -- Always deny providers that use data for training.
    -- If a specific provider is pinned in config, restrict to that one only.
    request.provider = { data_collection = "deny", allow_fallbacks = true }
    if M.config.provider and M.config.provider ~= "" then
        request.provider.only = { M.config.provider }
        request.provider.allow_fallbacks = false
    end
    local payload = vim.fn.json_encode(request)

    local tmpfile = vim.fn.tempname()
    local f = io.open(tmpfile, "w")
    if not f then
        vim.notify("AI: could not create temp file", vim.log.levels.ERROR)
        return nil
    end
    f:write(payload)
    f:close()

    local raw = vim.fn.system({
        "curl", "-s", "-X", "POST",
        "https://openrouter.ai/api/v1/chat/completions",
        "-H", "Authorization: Bearer " .. api_key,
        "-H", "Content-Type: application/json",
        "--data", "@" .. tmpfile,
    })
    local exit_code = vim.v.shell_error
    vim.fn.delete(tmpfile)  -- unconditional: always runs before any branching

    if exit_code ~= 0 then
        vim.notify("AI: curl failed:\n" .. raw, vim.log.levels.ERROR)
        return nil
    end

    local ok, response = pcall(vim.fn.json_decode, raw)
    if not ok then
        vim.notify("AI: failed to parse API response: " .. tostring(response), vim.log.levels.ERROR)
        return nil
    end

    if type(response.choices) ~= "table" or #response.choices == 0 then
        -- Surface whatever OpenRouter sent back (error message, rate limit info, etc.)
        local detail = ""
        if type(response.error) == "table" then
            detail = "\n" .. (response.error.message or vim.fn.json_encode(response.error))
        elseif type(response.error) == "string" then
            detail = "\n" .. response.error
        else
            detail = "\nRaw: " .. raw
        end
        vim.notify("AI: no choices in API response" .. detail, vim.log.levels.ERROR)
        return nil
    end

    if not response.choices[1].message then
        vim.notify("AI: malformed choice in API response", vim.log.levels.ERROR)
        return nil
    end

    return strip_fences(response.choices[1].message.content)
end

local function open_autoedit_diff(old_lines, new_lines, bufnr)
    local ops = myers_diff(old_lines, new_lines)

    local has_changes = false
    for _, op in ipairs(ops) do
        if op.op ~= "keep" then has_changes = true; break end
    end
    if not has_changes then
        vim.notify("AutoEdit: no changes suggested", vim.log.levels.INFO)
        return
    end

    local display, highlights = format_diff_lines(ops)
    local diff_buf = require("panel").open(display, { wrap = false })

    for _, hl in ipairs(highlights) do
        -- hl[1] is 1-based display line index; nvim_buf_add_highlight is 0-based
        vim.api.nvim_buf_add_highlight(diff_buf, -1, hl[2], hl[1] - 1, 0, -1)
    end

    vim.keymap.set("n", "y", function()
        vim.cmd("close")
        vim.schedule(function()
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
        end)
    end, { buffer = diff_buf, noremap = true, silent = true })

    vim.keymap.set("n", "n", "<cmd>close<CR>",
        { buffer = diff_buf, noremap = true, silent = true })
end

-- --------------------------------------------------------------------------
-- DISPLAY LAYER
-- --------------------------------------------------------------------------

local function open_explain_window(text)
    -- Strip trailing blank line that some models append
    local lines = vim.split(text:gsub("\n+$", ""), "\n")

    -- Add one space of left padding to each line for breathing room
    local padded = {}
    for _, line in ipairs(lines) do
        table.insert(padded, " " .. line)
    end

    require("panel").open(padded, { wrap = true })
end

local function insert_at_cursor(text)
    local lines = vim.split(text, "\n")
    -- pos[1] is the 1-based cursor row.
    -- nvim_buf_set_lines is 0-based. To insert AFTER 1-based row N,
    -- pass 0-based index N (== pos[1]) as both start and end.
    -- strict_indexing=false clamps for empty buffers.
    local pos  = vim.api.nvim_win_get_cursor(0)
    local base = pos[1]  -- 0-based insert index after cursor line

    -- Insert all lines at once so the entire block is one undoable action.
    vim.api.nvim_buf_set_lines(0, base, base, false, lines)
    vim.api.nvim_win_set_cursor(0, pos)
end

-- --------------------------------------------------------------------------
-- COMMANDS
-- --------------------------------------------------------------------------

vim.api.nvim_create_user_command("Autogen", function(opts)
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local system_prompt = load_prompt("autogen")
    local context = build_autogen_context(bufnr)
    local user_message =
        "--- CONTEXT START ---\n" .. context .. "\n--- CONTEXT END ---\n\n" ..
        "Cursor is at line " .. cursor_line .. ".\n\nTask: " .. opts.args
    local result = call_openrouter(system_prompt, user_message)
    if result then
        insert_at_cursor(result)
    end
end, { nargs = "+", desc = "Generate code at cursor using AI" })

-- Normal mode shortcut: <leader>ag prompts for input then runs :Autogen
vim.keymap.set("n", "<leader>ag", function()
    vim.ui.input({ prompt = "Autogen: " }, function(input)
        if input and input ~= "" then
            -- Call Lua functions directly — avoids vim.cmd/nvim_exec2 which
            -- converts vim.notify ERROR into a Vim exception that crashes the callback
            local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
            vim.schedule(function()
                vim.api.nvim_echo({{"  AI: thinking ", "Comment"}, {"▓▓▓▓▓▓▓▓▓▓▓▓", "Comment"}}, false, {})
                vim.cmd("redraw")
                local bufnr       = vim.api.nvim_get_current_buf()
                local sys_prompt  = load_prompt("autogen")
                local context     = build_autogen_context(bufnr)
                local user_msg    =
                    "--- CONTEXT START ---\n" .. context .. "\n--- CONTEXT END ---\n\n" ..
                    "Cursor is at line " .. cursor_line .. ".\n\nTask: " .. input
                local result = call_openrouter(sys_prompt, user_msg)
                vim.api.nvim_echo({{"", ""}}, false, {})  -- clear loading bar
                if result then insert_at_cursor(result) end
            end)
        end
    end)
end, { noremap = true, silent = true, desc = "AI generate code at cursor" })

local function run_autoedit(bufnr, cursor_line, visual_range, task)
    vim.api.nvim_echo(
        { { "  AI: thinking ", "Comment" }, { "▓▓▓▓▓▓▓▓▓▓▓▓", "Comment" } },
        false, {}
    )
    vim.cmd("redraw")

    local old_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local sys_prompt = load_prompt("autoedit")

    local focus_hint = ""
    if visual_range then
        focus_hint = "\nFocus region is lines " .. visual_range[1] .. "-" .. visual_range[2] .. "."
    end

    local user_msg =
        "--- FILE START ---\n" .. table.concat(old_lines, "\n") .. "\n--- FILE END ---\n\n" ..
        "Cursor is at line " .. cursor_line .. "." .. focus_hint .. "\n\nTask: " .. task

    local result = call_openrouter(sys_prompt, user_msg)
    vim.api.nvim_echo({ { "", "" } }, false, {})  -- clear loading bar

    if not result then return end

    local new_lines = vim.split(result, "\n", { plain = true })
    -- Strip a spurious trailing empty line that some models append
    if new_lines[#new_lines] == "" then table.remove(new_lines) end

    open_autoedit_diff(old_lines, new_lines, bufnr)
end

vim.api.nvim_create_user_command("AutoEdit", function(opts)
    local bufnr       = vim.api.nvim_get_current_buf()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    run_autoedit(bufnr, cursor_line, nil, opts.args)
end, { nargs = "+", desc = "Edit current file using AI" })

vim.keymap.set("n", "<leader>ae", function()
    vim.ui.input({ prompt = "AutoEdit: " }, function(input)
        if not input or input == "" then return end
        local bufnr       = vim.api.nvim_get_current_buf()
        local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
        vim.schedule(function()
            run_autoedit(bufnr, cursor_line, nil, input)
        end)
    end)
end, { noremap = true, silent = true, desc = "AI edit file" })

vim.keymap.set("v", "<leader>ae", function()
    local line1 = vim.fn.line("'<")
    local line2 = vim.fn.line("'>")
    local bufnr       = vim.api.nvim_get_current_buf()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    vim.schedule(function()
        vim.ui.input(
            { prompt = "AutoEdit (lines " .. line1 .. "-" .. line2 .. "): " },
            function(input)
                if not input or input == "" then return end
                vim.schedule(function()
                    run_autoedit(bufnr, cursor_line, { line1, line2 }, input)
                end)
            end
        )
    end)
end, { noremap = true, silent = true, desc = "AI edit selection" })

-- Visual mode shortcut: select code, press <leader>ai to explain
vim.keymap.set("v", "<leader>ai", function()
    -- Capture range before leaving visual mode
    local line1 = vim.fn.line("'<")
    local line2 = vim.fn.line("'>")
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
    vim.schedule(function()
        vim.ui.input({ prompt = "Ask about selection (Enter for plain explanation): " }, function(user_question)
            if user_question == nil then return end  -- user cancelled with <C-c>
            local question = vim.trim(user_question)
            local sys_prompt
            local user_msg
            local selection    = get_visual_selection(bufnr, line1, line2)
            local file_context = build_explain_context(bufnr)
            if question == "" then
                sys_prompt = load_prompt("explain")
                user_msg =
                    "--- FILE CONTEXT START ---\n" .. file_context ..
                    "\n--- FILE CONTEXT END ---\n\n--- SELECTED CODE ---\n" ..
                    selection .. "\n--- END SELECTED CODE ---"
            else
                sys_prompt = [[You are a concise code assistant embedded in a text editor.
The user highlighted a section of code and asked a specific question about it.
Answer the question directly and concisely. Use the file context to inform your answer.
Respond in plain text only. No markdown, no bullet symbols, no headers, no bold, no code fences.
No preamble, no filler. Keep your response within 30 lines.]]
                user_msg =
                    "--- FILE CONTEXT START ---\n" .. file_context ..
                    "\n--- FILE CONTEXT END ---\n\n--- SELECTED CODE ---\n" ..
                    selection .. "\n--- END SELECTED CODE ---\n\n--- USER QUESTION ---\n" ..
                    question .. "\n--- END USER QUESTION ---"
            end
            vim.api.nvim_echo({{"  AI: thinking ", "Comment"}, {"▓▓▓▓▓▓▓▓▓▓▓▓", "Comment"}}, false, {})
            vim.cmd("redraw")
            local result = call_openrouter(sys_prompt, user_msg)
            vim.api.nvim_echo({{"", ""}}, false, {})  -- clear loading bar
            if result then
                open_explain_window(result)
                require("history").save(bufnr, result)
            end
        end)
    end)
end, { noremap = true, silent = true, desc = "Explain selection" })

vim.api.nvim_create_user_command("Explain", function(opts)
    local bufnr = vim.api.nvim_get_current_buf()
    local system_prompt = load_prompt("explain")
    local selection    = get_visual_selection(bufnr, opts.line1, opts.line2)
    local file_context = build_explain_context(bufnr)
    local user_message =
        "--- FILE CONTEXT START ---\n" .. file_context ..
        "\n--- FILE CONTEXT END ---\n\n--- SELECTED CODE ---\n" ..
        selection .. "\n--- END SELECTED CODE ---"
    local result = call_openrouter(system_prompt, user_message)
    if result then
        open_explain_window(result)
        require("history").save(bufnr, result)
    end
end, { range = 2, desc = "Explain selected code using AI" })

-- Function to update statusline after model changes
local function update_statusline()
    -- Configure model indicator in statusline
    if vim.o.statusline == "" or not vim.o.statusline:match("%%=.*AI:") then
        -- Only add if not already present
        vim.o.statusline = (vim.o.statusline or "") .. "%=%{v:lua.require'ai'.get_model_indicator()}%="
    end
end

-- Expose model info for statusline
function M.get_model_indicator()
    local model = M.config.model
    local short_name = model:match("/([^/]+)$") or model -- Display just the model name after the slash
    return " AI: " .. short_name .. " "
end

-- Set up statusline when module loads
vim.schedule(update_statusline)

vim.api.nvim_create_user_command("Aiconfig", function(opts)
    -- Usage: :Aiconfig <model> [provider]
    -- Provider is everything after the first space. Omit to keep existing provider.
    -- Use "any" as provider to remove the restriction and let OpenRouter choose.
    local space = opts.args:find(" ")
    if space then
        M.config.model    = opts.args:sub(1, space - 1)
        local prov        = opts.args:sub(space + 1)
        M.config.provider = (prov == "any") and nil or prov
    else
        M.config.model = opts.args
    end
    save_ai_config()
    update_statusline() -- Update statusline after model change
    local msg = "AI model: " .. M.config.model
    msg = msg .. " | provider: " .. (M.config.provider or "any (OpenRouter chooses)")
    print(msg)
end, { nargs = "+", desc = "Set AI model and optional provider (e.g. :Aiconfig qwen/qwen3-coder Google Vertex)" })

vim.api.nvim_create_user_command("AddModel", function(opts)
    local id = vim.trim(opts.args)
    if id == "" then
        print("Usage: :AddModel <model-id>")
        return
    end
    for _, existing in ipairs(M.config.favorites) do
        if existing == id then
            print("Already in favorites: " .. id)
            return
        end
    end
    table.insert(M.config.favorites, id)
    save_ai_config()
    print("Added to favorites: " .. id)
end, { nargs = "+", desc = "Add a model ID to the AI favorites list" })

vim.keymap.set("n", "<leader>ah", function()
    local bufnr = vim.api.nvim_get_current_buf()
    require("history").open_panel(bufnr)
end, { noremap = true, silent = true, desc = "AI History for current file" })

vim.keymap.set("n", "<leader>ac", function()
    require("models").open_picker()
end, { noremap = true, silent = true, desc = "AI: pick model from favorites" })

function M.save_config()
    save_ai_config()
end

return M
