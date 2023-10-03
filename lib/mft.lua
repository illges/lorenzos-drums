---@diagnostic disable: undefined-global, lowercase-global

local mft={}

local mftconf
if util.file_exists("/home/we/dust/code/mftconf/lib/mftconf.lua") then
    mftconf=include("mftconf/lib/mftconf")
end

function mft:new(args)
    local self=setmetatable({},{
      __index=mft
    })
    self.connected = false
    self.device = nil
    self.param_map = {{},{},{},{},{}}
    self.delta_map = {}
    self.main_ch = 1
    self.shift_ch = 5
    self.show_update_count = 0
    self.updated_param = ""
    return self
end

function mft:init(device, file)
    self.device = device
    if file ~= nil and mftconf ~= nil then mftconf.load_conf(self.device.midi,file) end
    self.connected = true
end

function mft:event(data)
    if not self.connected then return end
    local msg=midi.to_msg(data)
    --self:log_msg(msg)
    if msg.ch == nil or msg.cc == nil then return end
    self:control(self.param_map[msg.ch][msg.cc], msg)
end

function mft:control(param, msg)
    if param == nil then return end
    self.updated_param = param
    self.show_update_count = 15
    local d = msg.val==65 and self.delta_map[param] or -self.delta_map[param]
    local val = params:get(param)
    params:set(param, val + d)
    self:set(param, msg.ch, msg.cc)
end

function mft:set(param, channel, cc_num)
    if not self.connected then return end
    local min = params:get_range(param)[1]
    local max = params:get_range(param)[2]
    local param_to_cc = util.round(util.linlin(min,max,0,127,params:get(param)))
    self.device.midi:cc(cc_num, param_to_cc, channel)
end

function mft:init_param(param, ch, cc, d)
    if not self.connected then return end
    self:set(param, ch, cc)
    self.param_map[ch][cc] = param
    self.delta_map[param] = d
end

function mft:log_param()
    tab.print(self.param_map[1])
    tab.print(self.param_map[5])
    tab.print(self.delta_map)
end

function mft:log_msg(msg)
    print("*********************")
    print("type = "..msg.type)
    print("cc num = "..msg.cc)
    print("channel = "..msg.ch)
    print("value = "..msg.val)
end

return mft