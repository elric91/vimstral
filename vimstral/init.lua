require('vimstral.common')
local sm = require('vimstral.signsandmarks')

local M = {}


M.config = {
  api_key = os.getenv("MISTRAL_API_KEY"),
  query_model = "mistral-medium-2505",
  query_api = "https://api.mistral.ai/v1/chat/completions",
  fim_model = "codestral-latest",
  fim_api =  "https://api.mistral.ai/v1/fim/completions",
  system = "Be concise and direct in your responses. Respond without unnecessary explanation.",

  signs = {
    user = '󰙊',
    assistant  = '󰄛',
  },

  keymaps = {
    user_context        = '<C-j>', -- toggle user context on line
    fim                 = '<leader>jf', -- fim
    query               = '<leader>jr', -- ask visually selected question ('R'equest), append response
    assistant_context   = '<leader>ja', -- force the selected lines to be considered as responses
    clean_context       = '<leader>jc', -- force the context to be removes
  }
}


function M.fill_in_the_middle()

  local buf = vim.api.nvim_get_current_buf()
  local prompt = ''
  local suffix = ''
  local mode = 'newline'

  if vim.fn.mode() == 'i' then
  -- if insert mode, try to fill where the cursor is taking into account what's before and after
    local startsel = {buf, vim.fn.line('.'), 1, 0}
    local cursorpos = vim.fn.getpos('.')
    local lines = vim.fn.getregion(startsel, cursorpos, {exclusive = true})
    prompt = lines[1]
    suffix = vim.fn.getline('.'):sub(#prompt + 1)
    sm.set_insertmark(cursorpos[2] - 1, cursorpos[3] - 1) -- 0 indexed
    mode = 'mark'

  elseif vim.fn.mode() == 'n' then
    -- if normal mode, consider the current line the input and try to fill starting from the end
    prompt = vim.fn.getline('.')
    sm.set_insertmark(vim.fn.line('.') - 1, #prompt) -- end of the line
    mode = 'mark'

  elseif vim.fn.mode() == 'v' then
    -- if visual (character mode), only consider what's selected
    local startsel = vim.fn.getpos('.')
    local endsel = vim.fn.getpos('v')
    local line = vim.fn.getregion(startsel, endsel, {exclusive = true})
    prompt = line[1]
    insert_mark = vim.api.nvim_buf_set_insertmark(buf, namespace, vim.fn.line('.') - 1, #prompt, {}) -- end of the line
    mode = 'mark'

  elseif vim.fn.mode() == 'V' then
    -- if visual (line mode), try to fill the first blank line within the selection, and if there is none, append to the end
    local lines = vim.fn.getline(get_startsel(), get_endsel())
    vim.notify('TYPE ' .. type(lines) .. ' len ' .. #lines)
    local emptyline = nil
    -- grab the last empty line (if any)
    for i, l in ipairs(lines) do
      if l:gsub('%s', '') == '' then emptyline = i end
    end
    prompt = table.concat(lines, '\n', 1, emptyline) -- if emptyline is nil, takes all the table
    if emptyline then
      suffix = table.concat(lines, '\n', emptyline, #lines)
      sm.set_insertmark(get_startsel() + emptyline - 2, 0) -- 0 indexed, before the empty line
    else
      sm.set_insertmark(get_endsel() - 1, 0) -- 0 indexed
    end
    mode = 'newline'

  end

  local data = vim.json.encode({
    model = M.config.fim_model,
    temperature = 0,
    max_tokens = 1024,
    stream = false,
    prompt = prompt,
    suffix = suffix,
  })

  leave_visualmode()
  api_do(M.config.fim_api, data, mode)

end


function M.query()

  -- Combine visual selection with context blocks
  local startsel, endsel = get_startsel(), get_endsel()
  local lines = vim.fn.getline(startsel, endsel)
  local selection = table.concat(lines, "\n")
  --  Add the selection to context (forced)
  sm.toggle_sign('user', startsel, endsel, 'add')

  sm.set_insertmark(endsel - 1, 0) -- 0 indexed


  local full_context = sm.get_signinfo({"user", "assistant"})
  local messages = {}
  -- system message
  table.insert(messages, { role = "system", content = M.config.system })
  -- previous inputs
  for i, ctx in ipairs(full_context) do
    table.insert(messages, {role = ctx.role, content = ctx.content})
  end
  
  local data = vim.json.encode({
    model = M.config.query_model,
    temperature = 0,
    max_tokens = 1024,
    messages = messages,
    response_format = { type = "text" }
  })

  leave_visualmode()
  api_do(M.config.query_api, data, 'newline')

end


function api_do(url, data_in, mode)

  if not M.config.api_key then
    vim.notify("MISTRAL_API_KEY missing", vim.log.levels.ERROR)
    return
  end

  logme(logfile, 'API REQUEST : ' .. data_in)
  local api_cmd = {
    "curl", "-s", "-X", "POST",
    url,
    "-H", "Content-Type: application/json",
    "-H", "Accept: application/json",
    "-H", "Authorization: Bearer " .. M.config.api_key,
    "-d", data_in
  }

  vim.notify('vimstral : Querying the model ... please wait')
  vim.fn.jobstart(api_cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        local response = table.concat(data, "")
        logme(logfile, 'API RESPONSE : ' .. response)
        local ok, parsed = pcall(vim.json.decode, response)

        if ok and parsed.choices and parsed.choices[1] then
          local lines = vim.split(parsed.choices[1].message.content, "\n")
          logme(logfile, 'PARSED LINES : ' .. response)
          M.write_in_buffer(lines, mode)
          vim.notify('vimstral : Usage ' .. parsed.usage.total_tokens .. ' tokens (' .. 
                      parsed.usage.prompt_tokens .. ' prompt / ' ..
                      parsed.usage.completion_tokens .. ' completion)')
        else
          logme(logfile, "Error with mistral: " .. response)
          vim.notify('vimstral : Error with api request' .. response)
        end

      end
    end
  })
end


function M.write_in_buffer(lines, mode)
  -- mark : insert at mark
  -- newline : add a new line and start from here (default mode)
  logme(logfile, 'ENTERING insert_in_buffer (' .. mode .. ')')

  row, col = sm.get_insertmark()
  logme(logfile, 'ROW ' .. row .. ' COL ' .. col)
  if row ~= nil and col ~= nil then 

    if mode == 'mark' then
      vim.api.nvim_buf_set_text(0, row, col, row, col, lines) -- O indexed values
    elseif mode == 'patch' then

    else -- default : newline
      vim.fn.append(row + 1, {''}) -- Spacer. fn.append is 1 indexed 
      vim.fn.append(row + 2, lines)
      logme(logfile, "sm : " .. row+2 .. " : " .. #lines)
      sm.toggle_sign("assistant", row + 3, row + #lines + 3)
    end

    sm.del_insertmark()
  end
  logme(logfile, 'ENDING insert_in_buffer')
end



function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  local signs = M.config.signs
  sm.setup('vimstral', M.config.signs)

  local keymaps = M.config.keymaps
  vim.keymap.set({'v', 'n'}, keymaps.user_context, sm.toggle_usercontext)
  vim.keymap.set({'v', 'n'}, keymaps.assistant_context, sm.force_assistantcontext)
  vim.keymap.set({'v', 'n'}, keymaps.clean_context, sm.clean_context)
  vim.keymap.set({'n', 'i', 'v'}, keymaps.query, M.query)
  vim.keymap.set({'n', 'i', 'v'}, keymaps.fim, M.fill_in_the_middle)

  logfile = '/tmp/vimstral.log' -- empty string to avoid debugging logs
end

return M
