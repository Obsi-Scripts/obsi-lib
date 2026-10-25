-- Text UI (client): a docked key hint.
--   ObsiLib.ui.showText(data)   data = 'text' or { key = 'E', label = 'Open', description = 'Storage locker' }
--   ObsiLib.ui.hideText()
--   ObsiLib.ui.textOpen() -> boolean, data

local current

function ObsiLib.ui.showText(data)
    if type(data) == 'string' then data = { label = data } end
    if type(data) ~= 'table' then return end

    local payload = {
        key = data.key and tostring(data.key):upper() or nil,
        label = data.label or data.title or data.text or '',
        description = data.description or data.desc,
    }

    if current and current.key == payload.key and current.label == payload.label and current.description == payload.description then
        return
    end

    current = payload
    Core.nui('obsi-lib:textui', { op = 'show', key = payload.key, label = payload.label, description = payload.description })
end

function ObsiLib.ui.hideText()
    if not current then return end
    current = nil
    Core.nui('obsi-lib:textui', { op = 'hide' })
end

---@return boolean open, table|nil data
function ObsiLib.ui.textOpen()
    return current ~= nil, current
end

exports('showText', ObsiLib.ui.showText)
exports('hideText', ObsiLib.ui.hideText)
exports('textOpen', ObsiLib.ui.textOpen)
