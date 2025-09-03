local M = {}

local namespace = vim.api.nvim_create_namespace('default')
local group = 'default'
local insertmark_id = nil
local ctxsign_name = "context"

-- local function get_startsel() return math.min(vim.fn.line('.'), vim.fn.line('v')) end
-- local function get_endsel() return math.max(vim.fn.line('.'), vim.fn.line('v')) end

function M.set_insertmark(row, col)
  insertmark_id = vim.api.nvim_buf_set_extmark(0, namespace, row, col, {}) -- 0 indexed
end

function M.get_insertmark()
  local row, col, other = nil, nil, nil
  local insertmark = vim.api.nvim_buf_get_extmark_by_id(0, namespace, insertmark_id, {})
  if insertmark ~= {} then
    row, col, other = unpack(insertmark)
  end
  return row, col
end

function M.del_insertmark()
  vim.api.nvim_buf_del_extmark(0, namespace, insertmark_id)
end


function M.toggle_usercontext()
  local startsel, endsel = get_startsel(), get_endsel()
  M.toggle_sign("user", startsel, endsel)
end

function M.force_assistantcontext()
  local startsel, endsel = get_startsel(), get_endsel()
  M.toggle_sign("assistant", startsel, endsel, 'add')
end

function M.clean_context()
  local startsel, endsel = get_startsel(), get_endsel()
  M.toggle_sign("user", startsel, endsel, 'del')
  M.toggle_sign("assistant", startsel, endsel, 'del')
end

function M.toggle_sign(sign_type, lstart, lend, force)
  -- set a "context" sign on defined lines
  -- local buf = vim.fn.bufname() -- current buffer
  local buf = vim.fn.bufname()
  logme(logfile, 'toggle sign type : ' .. sign_type .. 'start/end : ' .. lstart ..'/'..lend)
  if force then logme(logfile, 'force : ' .. force) end
  -- toggle context sign based on the one on the 1st line of the selection
  local lstart_signs = vim.fn.sign_getplaced(buf, {group = group, lnum = lstart})[1].signs
  for l = lstart, lend do
    -- clean the existing signs on the line
    local line_signs = vim.fn.sign_getplaced(buf, {group = group, lnum = l})[1].signs
    for _, s in ipairs(line_signs) do
      if (s.name == sign_type and force ~= 'add') or force == 'del' then
        vim.fn.sign_unplace(group, {buffer = buf, id = s.id})
      end
    end
    if (#lstart_signs == 0 and force ~= 'del') or force == 'add' then
      vim.fn.sign_place(0, group, sign_type, buf, {lnum = l})
    end
  end
  -- leave visualmode if needed
  leave_visualmode()
end


function M.get_signinfo(sign_types)
  local buf = vim.fn.bufname()
  local signs = vim.fn.sign_getplaced(buf, {group = group})[1].signs

  local signinfo = {}
  local signdetails = {}

  if signs ~= {} then
    for i, s in ipairs(signs) do
      table.insert(signdetails, vim.fn.getline(s.lnum))
      if not signs[i + 1] or s.name ~= signs[i + 1].name then
        table.insert(signinfo, { role = s.name, content = table.concat(signdetails, "\n") })
      end
    end
    return signinfo
  else
    return nil
  end
end


function M.setup(name, signs)
  namespace = vim.api.nvim_create_namespace(name)
  group = name
  vim.fn.sign_define("user", { text = signs.user, texthl = "DiagnosticOK" })
  vim.fn.sign_define("assistant", { text = signs.assistant, texthl = "DiagnosticHint" })
end

return M
