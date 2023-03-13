---@diagnostic disable: undefined-global, lowercase-global

local mft={}

function mft:new(args)
    local self=setmetatable({},{
      __index=mft
    })
    self.connected = false
    return self
end

function mft:init()
    -- bd mic 3 (kick mic)
    local param_to_cc = util.round(util.linlin(-36,36,0,127,params:get("bdmic3")))
    midi_devices["Midi Fighter Twister"]:cc(10,param_to_cc,1)
end

function mft:event(data)
    local msg=midi.to_msg(data)
    self:log_msg(msg)

    if msg.cc==8 then
        local d = msg.val==65 and 0.1 or -0.1
        local val = params:get("bdvol")
        params:set("bdvol", val + d)
        local param_to_cc = util.round(util.linlin(-36,36,0,127,params:get("bdvol")))
        midi_devices["Midi Fighter Twister"]:cc(msg.cc,param_to_cc,1)
    end

    if msg.cc==10 then
        local d = msg.val==65 and 0.1 or -0.1
        local val = params:get("bdmic3")
        params:set("bdmic3", val + d)
        local param_to_cc = util.round(util.linlin(-36,36,0,127,params:get("bdmic3")))
        midi_devices["Midi Fighter Twister"]:cc(msg.cc,param_to_cc,1)
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