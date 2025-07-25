function get_startsel() return math.min(vim.fn.line('.'), vim.fn.line('v')) end
function get_endsel() return math.max(vim.fn.line('.'), vim.fn.line('v')) end

function leave_visualmode()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', false, true, true), 'nx', false)
end

function logme(f, data)
  if f ~= '' then
    local timestamp = os.date('%Y%m%d-%H%M%S')
    log = io.open('/tmp/vimstral.log', 'a')
    if type(data) == 'table' then
      log:write(timestamp ..  ' : \n')
      for d in ipairs(data) do
        log:write(d .. '\n')
      end
    else
      log:write(timestamp .. ' : ' .. data .. '\n')
    end
    log:close()
  end
end

