---@diagnostic disable: undefined-global, lowercase-global

local mft={}

function mft:new(args)
    local self=setmetatable({},{
      __index=mft
    })
    self.connected = false
    self.param_map = {{},{},{},{},{}}
    self.delta_map = {}
    return self
end

function mft:init()
    -- tab.print(self.param_map[1])
    -- tab.print(self.param_map[5])
    -- tab.print(self.delta_map)
end

function mft:event(data)
    if not self.connected then return end
    local msg=midi.to_msg(data)
    --self:log_msg(msg)

    if msg.ch==4 and msg.cc==13 then params:set("instrument_pattern", 1-params:get("instrument_pattern")) return end

    self:control(self.param_map[msg.ch][msg.cc], msg)
end

function mft:control(param, msg)
    if param == nil then return end
    mft_param = param
    show_dials = 15
    local d = msg.val==65 and self.delta_map[param] or -self.delta_map[param]
    local val = params:get(param)
    params:set(param, val + d)
    self:set(param, msg.ch, msg.cc)
end

function mft:set(param, channel, cc_num)
    if not self.connected then return end
    local min = params:get_range(param)[1]
    min = min==-96 and -36 or min --for vol params the encoders will 0 at noon
    local max = params:get_range(param)[2]
    local param_to_cc = util.round(util.linlin(min,max,0,127,params:get(param)))
    midi_devices["Midi Fighter Twister"]:cc(cc_num, param_to_cc, channel)
end

function mft:init_param(param, ch, cc, d)
    if not self.connected then return end
    self:set(param, ch, cc)
    self.param_map[ch][cc] = param
    self.delta_map[param] = d
end

function mft:log_msg(msg)
    print("*********************")
    print("type = "..msg.type)
    print("cc num = "..msg.cc)
    print("channel = "..msg.ch)
    print("value = "..msg.val)
end

return mft