---@diagnostic disable: undefined-global, lowercase-global

local GGrid={}

local MODE_INCREASE=1
local MODE_DECREASE=2
local MODE_ERASE=3
local MODE_LENGTH=4

local MAIN_KIT = 0
local AUX_KIT = 4

function GGrid:new(args)
  local m=setmetatable({},{
    __index=GGrid
  })
  local args=args==nil and {} or args

  m.grid_on=args.grid_on==nil and true or args.grid_on

  -- initiate the grid
  --local grid=util.file_exists(_path.code.."midigrid") and include "midigrid/lib/mg_128" or grid
  local grid= grid

  m.g=grid.connect()
  m.g.key=function(x,y,z)
    if m.grid_on then
      m:grid_key(x,y,z)
    end
  end
  print("grid columns: "..m.g.cols)

  -- setup visual
  m.visual={}
  m.grid_width=16
  for i=1,8 do
    m.visual[i]={}
    for j=1,m.grid_width do
      m.visual[i][j]=0
    end
  end

  m.mode=MODE_ERASE
  m.mode_prev=MODE_ERASE
  m.kit_mod = MAIN_KIT
  m.seq_view = 1 -- current view
  m.seq_mod = 1 -- total seq

  m.seq_mod_visual = {0,0,0,0,0,0}

  -- keep track of pressed buttons
  m.pressed_buttons={}
  m.gesture_mode={false,false}

  -- grid refreshing
  m.grid_refresh=metro.init()
  m.grid_refresh.time=0.03
  m.grid_refresh.event=function()
    if m.grid_on then
      m:get_seq_mod_visuals()
      m:grid_redraw()
    end
  end
  m.grid_refresh:start()

  return m
end

function GGrid:instrument_seq()
  return params:get("instrument_pattern") == 1
end

function GGrid:get_seq_mod_visuals()
  for i=1,6 do
    if self.seq_mod_visual[i]>0 then
        self.seq_mod_visual[i]=self.seq_mod_visual[i]-1
        self:grid_redraw()
    end
    if self.seq_mod_visual[i]<0 then
        self.seq_mod_visual[i]=0
        self:grid_redraw()
    end
  end
end

function GGrid:get_seq_view_offset()
  return (self.seq_view-1)*16
end

function GGrid:grid_key(x,y,z)
  self:key_press(y,x,z==1)
  self:grid_redraw()
end

function GGrid:key_press(row,col,on)
  if on then
    self.pressed_buttons[row..","..col]=true
    if row==7 then
      self.pressed_buttons[row..","..col]=clock.run(function()
        clock.sleep(0.6)
        drm[g_sel_drm]:bank_save(col)
        self.just_saved=true
        msg("saved bank "..col)
      end)
    end
  else
    if row==7 then
      local saved=self.just_saved
      clock.cancel(self.pressed_buttons[row..","..col])
      self.just_saved=false
      self.pressed_buttons[row..","..col]=nil
      if saved then
        do return end
      end
    end
    self.pressed_buttons[row..","..col]=nil
  end
  if not on then
    if row==7 then
      if self.just_saved==nil or self.just_saved==false then
        -- make sure bank exists
        if not drm[g_sel_drm]:bank_exists(col) then
          msg("no saved bank "..col)
          do return end
        end
        drm[g_sel_drm]:bankseq_add(col) -- set it to queue
        if self.mode~=MODE_ERASE and params:get("record")==0 then
          -- just load bank immediately
          drm[g_sel_drm]:bank_load(col)
          msg("loaded bank "..col)
        end
      end
    end
    do
      return
    end
  end
  if row==8 and col<=9 then
    self:set_drm(col)
  elseif row==8 and col<15 then -- TODO allow prob/reverse
    self:change_ptn(col)
  elseif row==8 and col>=15 then
    self:change_mode(col)
  elseif not self:instrument_seq() then
    if row<=5 then
      self:adj_ptn(row,col)
    elseif row==6 then
      self:adj_view(col)
    end
  else
    if row<7 then
      self:adj_ptn(row,col)
    end
  end
end

function GGrid:change_mode(col)
  params:set("record",0)
  self.gesture_mode[col-14]=not self.gesture_mode[col-14]
  if self.gesture_mode[1]==true and self.gesture_mode[2]==true then
    self.mode=MODE_INCREASE
  elseif self.gesture_mode[1]==true and self.gesture_mode[2]==false then
    self.mode=MODE_DECREASE
  elseif self.gesture_mode[1]==false and self.gesture_mode[2]==false then
    self.mode=MODE_ERASE
    params:set("record",1)
  else
    self.mode=MODE_LENGTH
  end
end

function GGrid:change_ptn(col)
  if col==10 then
    g_sel_ptn=1
    do
      return
    end
  end
  local i=2*(col-10)
  if math.floor(i/2)==math.floor(g_sel_ptn/2) then
    -- toggle between increase/decrease of current pattern
    g_sel_ptn=g_sel_ptn+(g_sel_ptn%2==0 and 1 or-1)
  else
    g_sel_ptn=i
  end
end

function GGrid:get_pressed()
  local pressed={}
  for k,_ in pairs(self.pressed_buttons) do
    local row,col=k:match("(%d+),(%d+)")
    table.insert(pressed,{tonumber(row),tonumber(col)})
  end
  return pressed
end

function GGrid:get_pressed_m()
  local pressed={}
  for k,_ in pairs(self.pressed_buttons) do
    local row,col=k:match("(%d+),(%d+)")
    if self:instrument_seq() then
      local m=(tonumber(row)-1)*16+tonumber(col)
      if m<128 then
        table.insert(pressed,m)
      end
    else
      local step = tonumber(col)
      if step<=16 then
        table.insert(pressed,step)
      end
    end
  end
  return pressed
end

function GGrid:adj_ptn(row,col)
  local target = self:instrument_seq() and g_sel_drm or row + self.kit_mod
  local offset = self:instrument_seq() and 0 or self:get_seq_view_offset()
  local step = self:instrument_seq() and self:get_step_num(row,col) or col + offset
  if self.mode==MODE_LENGTH then
    print("adjusting length")
    local pressed=self:get_pressed_m()
    if #pressed==1 then
      drm[target].ptn[g_sel_ptn]:set_finish(pressed[1]+offset)
    -- elseif #pressed==2 then
    --   drm[target].ptn[g_sel_ptn]:set_start_finish(pressed[1],pressed[2])
    end
  elseif self.mode==MODE_ERASE then
    if drm[target].ptn[g_sel_ptn].data[step] > 0 then -- check if step has a value
      drm[target].ptn[g_sel_ptn]:gerase(step) -- erase if step data exists
    else
      drm[target].ptn[g_sel_ptn]:gdelta(step,5) -- set step to mid value if currently empty
    end
  elseif self.mode==MODE_INCREASE then
    drm[target].ptn[g_sel_ptn]:gdelta(step,1)
  elseif self.mode==MODE_DECREASE then
    drm[target].ptn[g_sel_ptn]:gdelta(step,-1)
  end
end

function GGrid:adj_view(col)
  if col <=2 then
    self.kit_mod = self.kit_mod~=MAIN_KIT and MAIN_KIT or AUX_KIT
  elseif col>=11 then
    local new_mod = col-10
    if self.mode==MODE_LENGTH then
      local prev_mod = self.seq_mod
      self.seq_mod = new_mod
      for drum=1,9 do 
        drm[drum].ptn[g_sel_ptn]:set_finish(self.seq_mod*16)
        if self.seq_mod-prev_mod==1 then --if extending seq by one window then copy values over
          for step=1,16 do
            local prev_step = step + ((prev_mod-1)*16)
            local new_step = step + ((new_mod-1)*16)
            drm[drum].ptn[g_sel_ptn].data[new_step] = drm[drum].ptn[g_sel_ptn].data[prev_step]
          end
        end
      end
    end
    self.seq_view = new_mod
  end
end

function GGrid:get_step_num(row,col)
  return (row-1)*16+col
end

function GGrid:set_drm(i)
  if self.mode==MODE_DECREASE and
    i==g_sel_drm and lattice.enabled then
    -- toggle mute
    drm[i].muted=not drm[i].muted
  end
  if self.mode==MODE_INCREASE or self.mode==MODE_LENGTH or self.mode==MODE_ERASE or (not lattice.enabled) then
    trigger_ins(i)
  end
  g_sel_drm=i
end

function GGrid:get_visual()
  -- clear visual
  for row=1,8 do
    for col=1,self.grid_width do
      self.visual[row][col]=self.visual[row][col]-2
      if self.visual[row][col]<0 then
        self.visual[row][col]=0
      end
    end
  end

  -- show drum selectors
  for col,d in ipairs(drm) do
    local row=8
    if d.muted then
      self.visual[row][col]=1
    else
      if self:instrument_seq() then
        self.visual[row][col]=(g_sel_drm==col and 8 or 3)+(d.playing and 7 or 0)
      else
        if col<5 then
          self.visual[row][col]=(self.kit_mod==MAIN_KIT and 6 or 3)+(d.playing and 7 or 0)
        elseif col==5 then
          self.visual[row][col]=6+(d.playing and 7 or 0)
        elseif col>5 then
          self.visual[row][col]=(self.kit_mod==AUX_KIT and 6 or 3)+(d.playing and 7 or 0)
        end
      end
    end
  end

  -- show pattern selectors
  if g_sel_ptn==1 then
    self.visual[8][10]=10
  else
    self.visual[8][math.floor(g_sel_ptn/2)+10]=g_sel_ptn%2==0 and 10 or 5
  end

  -- show saved banks
  for i=1,16 do
    if drm[g_sel_drm].banks[i]~=nil then
      self.visual[7][i]=4
      if drm[g_sel_drm].bankseq_current==i then
        self.visual[7][i]=12
      end
    end
  end

  -- show mode
  self.visual[8][15]=self.gesture_mode[1] and 10 or 3
  self.visual[8][16]=self.gesture_mode[2] and 10 or 3

  -- show pattern
  if not self:instrument_seq() then
    -- show kit view
    self.visual[6][1]=self.kit_mod==MAIN_KIT and 10 or 3
    self.visual[6][2]=self.kit_mod==AUX_KIT and 10 or 3

    local step_mod = {false,false,false,false,false,false}
    for drum=1,5 do
      local i=self:get_seq_view_offset()
      local d=drm[drum+self.kit_mod].ptn[g_sel_ptn]
      for col=1,16 do
        i=i+1
        if i>=d.start and i<=d.finish then
          self.visual[drum][col]=d.data[i] + 1
        elseif d.data[i]>0 then
          self.visual[drum][col]=2
        else
          self.visual[drum][col]=0
        end
        if d.cur==i and lattice.enabled then
          self.visual[drum][col]=10
        elseif lattice.enabled then
          --self.seq_mod_visual[self:get_current_step_mod(d.cur)] = 16-(d.cur%16)
          local mod = self:get_current_step_mod(d.cur)
          self.seq_mod_visual[mod] = 16*mod-d.cur
        end
      end
    end
    self.visual[6][11] = self.seq_view == 1 and 12 or (self.seq_mod_visual[1]>0 and self.seq_mod_visual[1] or (self.seq_mod >= 1 and 6 or 3))
    self.visual[6][12] = self.seq_view == 2 and 12 or (self.seq_mod_visual[2]>0 and self.seq_mod_visual[2] or (self.seq_mod >= 2 and 6 or 3))
    self.visual[6][13] = self.seq_view == 3 and 12 or (self.seq_mod_visual[3]>0 and self.seq_mod_visual[3] or (self.seq_mod >= 3 and 6 or 3))
    self.visual[6][14] = self.seq_view == 4 and 12 or (self.seq_mod_visual[4]>0 and self.seq_mod_visual[4] or (self.seq_mod >= 4 and 6 or 3))
    self.visual[6][15] = self.seq_view == 5 and 12 or (self.seq_mod_visual[5]>0 and self.seq_mod_visual[5] or (self.seq_mod >= 5 and 6 or 3))
    self.visual[6][16] = self.seq_view == 6 and 12 or (self.seq_mod_visual[6]>0 and self.seq_mod_visual[6] or (self.seq_mod >= 6 and 6 or 3))
  else
    local i=0
    local d=drm[g_sel_drm].ptn[g_sel_ptn]
    for row=1,6 do
      for col=1,16 do
        i=i+1
        self.visual[row][col]=((i>=d.start and i<=d.finish) and 1 or 0)+d.data[i]
        if d.cur==i and lattice.enabled then
          --self.visual[row][col]=self.visual[row][col]+1
          self.visual[row][col]=10
        end
      end
    end
  end

  -- illuminate currently pressed button
  for k,_ in pairs(self.pressed_buttons) do
    local row,col=k:match("(%d+),(%d+)")
    self.visual[tonumber(row)][tonumber(col)]=15
  end

  return self.visual
end

-- 1-16
-- 17-32
-- 33-48
-- 49-64
-- 65-80
-- 81-96
function GGrid:get_current_step_mod(step)
  for mod=6,1,-1 do
    if step>((mod-1)*16) then
      return mod
    end
  end
end

function GGrid:grid_redraw()
  local gd=self:get_visual()
  if self.g.rows==0 then
    do return end
  end
  self.g:all(0)
  local s=1
  local e=self.grid_width
  local adj=0
  for row=1,8 do
    for col=s,e do
      if gd[row][col]~=0 then
        self.g:led(col+adj,row,gd[row][col])
      end
    end
  end
  self.g:refresh()
end

return GGrid
