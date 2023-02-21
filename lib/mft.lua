---@diagnostic disable: undefined-global, lowercase-global

local mft={}

function mft:new(args)
    local self=setmetatable({},{
      __index=mft
    })
    return self
end

function mft:event(data)
    local msg=midi.to_msg(data)
    self:log_msg(msg)

    if msg.cc==12 then
        local d = msg.val==65 and 0.1 or -0.1
        local val = params:get("bdvol")
        params:set("bdvol", val + d)
    end
end

function mft:log_msg(msg)
    print("*********************")
    print("type = "..msg.type)
    print("cc num = "..msg.cc)
    print("channel = "..msg.ch)
    print("value = "..msg.val)
end

return mft