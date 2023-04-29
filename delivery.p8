pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
function v2(_x, _y)
 return {x=_x, y=_y}
end

function v2_add(_v1,_v2)
 return v2(_v1.x+_v2.x, _v1.y+_v2.y)
end

function v_to_s(_v)
 return _v.x..",".._v.y
end

function s_to_v(_s)
 return v2(unpack(split(_s,",")))
end

function rnd_el(_t)
 local ar = {}
 print(_t)
 for k, v in pairs(_t) do
  add(ar, {k,v})
 end
 return unpack(rnd(ar))
end

function adjacent_with_wrap(c,w)
 w = w or 16
 return (c-1)%w,(c+1)%16
end

function try_move(tr)
 local v = v2_add(tr.pos, dirs[tr.dir_idx])
 v.x = v.x%128
 v.y = v.y%128
 if paths[v.y] and paths[v.y][v.x] then
  tr.pos = v
 else
  -- can't go forward
  -- turn left if there's a path there
  local left_idx = (tr.dir_idx-1) % 4
  v = v2_add(tr.pos, dirs[left_idx])
  if paths[v.y] and paths[v.y][v.x] then
   tr.dir_idx = left_idx
  else
   -- turn right
   tr.dir_idx = (tr.dir_idx+1)%4
  end
 end
 
 -- todo: remove this weird -3 offset
 -- todo: do u-turns around reverse arrows
 local cs = v_to_s(world_to_cell(v2_add(tr.pos, v2(-3,-3))))
 local redir = redirections[cs]
 if redir != nil and redir.blue == tr.blue then
  -- got redirected! manually map dirs
  if (redir.dir == ⬆️) tr.dir_idx=0
  if (redir.dir == ➡️) tr.dir_idx=1
  if (redir.dir == ⬇️) tr.dir_idx=2
  if (redir.dir == ⬅️) tr.dir_idx=3
 end
end

function _update()
 --[[
 -- manual control of first truck
 local tr = trucks[1]
 if (btnp(⬆️)) tr.dir_idx = 0
 if (btnp(➡️)) tr.dir_idx = 1
 if (btnp(⬇️)) tr.dir_idx = 2
 if (btnp(⬅️)) tr.dir_idx = 3
 if (btnp(❎)) tr.full = not tr.full
 if (btnp(🅾️)) tr.blue = not tr.blue
 
 if (btnp(⬆️) or btnp(➡️) or btnp(⬇️) or btnp(⬅️)) then
  try_move(tr)
 end
 ]]--
 
 if btnp(🅾️) then
  target.blue = not target.blue
 end
 
 if btn(❎) then
  if (btn(⬆️)) target.dir = ⬆️
  if (btn(➡️)) target.dir = ➡️
  if (btn(⬇️)) target.dir = ⬇️
  if (btn(⬅️)) target.dir = ⬅️
 else
  if target.dir != nil then
   -- x released, place a redirection here!
   redirections[v_to_s(target.pos)] = {
    dir = target.dir,
    blue = target.blue
   }
   target.dir = nil
  end
  
  local from_here = crossings_graph[v_to_s(target.pos)]
  if (btnp(➡️)) target.pos = from_here.➡️
  if (btnp(⬅️)) target.pos = from_here.⬅️
  if (btnp(⬆️)) target.pos = from_here.⬆️
  if (btnp(⬇️)) target.pos = from_here.⬇️
 end
 
 -- check if any depots get supplied
 for d in all(depots) do
  if t() >= d.next_supply then
   d.next_supply = get_next_supply_time()
   if d.supply < 9 then
    d.supply += 1
   end
  end
 end
 
 if t() >= update_at then
  for tr in all(trucks) do
   try_move(tr)
   --tr.pos = v2_add(tr.pos, tr.dir)
   -- loop off screen edges
   if (tr.dir_idx == 0 and tr.pos.y < 0) tr.pos.y = 131
   if (tr.dir_idx == 1 and tr.pos.x > 128) tr.pos.x = -4
   if (tr.dir_idx == 2 and tr.pos.y > 131) tr.pos.y = 0
   if (tr.dir_idx == 3 and tr.pos.x < -1) tr.pos.x = 131
   update_at = t() + move_delay
  end
 end
end

function build_paths()
 crossings = {}
 paths = {}
 function add_path(px,py)
  if (not paths[py]) paths[py] = {}
  paths[py][px] = true
 end
 
 for cy, row in pairs(world) do
  for cx, cell in pairs(row) do
   if cell == road then
    local x,y = 8*cx,8*cy
    local cl,cr = adjacent_with_wrap(cx)
    local cu,cd = adjacent_with_wrap(cy)
    local neighbours = 0
    if row[cl] == road then
      local py = y+3
      add_path(x,py)
      add_path(x+1,py)
      add_path(x+2,py)
      add_path(x+3,py)
      neighbours += 1
    end
    if world[cu][cx] == road then
      local px = x+3
      add_path(px,y)
      add_path(px,y+1)
      add_path(px,y+2)
      add_path(px,y+3)
      neighbours += 1
    end
    if row[cr] == road then
      local py = y+3
      add_path(x+3,py)
      add_path(x+4,py)
      add_path(x+5,py)
      add_path(x+6,py)
      add_path(x+7,py)
      neighbours += 1
    end
    if world[cd][cx] == road then
      local px = x+3
      add_path(px,y+3)
      add_path(px,y+4)
      add_path(px,y+5)
      add_path(px,y+6)
      add_path(px,y+7)
      neighbours += 1
    end

    if neighbours > 2 then
     add(crossings, v2(cx, cy))
    end
   end
  end
 end

 target = {
  pos = crossings[next(crossings, nil)],
  dir = nil,
  blue = false,
 }
end

function build_crossings_graph()
 crossings_graph = {}
 
 function follow_road(from, adj)
  local cx,cy = adj.x, adj.y
  local cl,cr = adjacent_with_wrap(cx)
  local cu,cd = adjacent_with_wrap(cy)
  local row = world[cy]
  local neighbours = {}
  if row[cl] == road then
   add(neighbours, v_to_s(v2(cl, cy)))
  end
  if world[cu][cx] == road then
   add(neighbours, v_to_s(v2(cx, cu)))
  end
  if row[cr] == road then
   add(neighbours, v_to_s(v2(cr, cy)))
  end
  if world[cd][cx] == road then
   add(neighbours, v_to_s(v2(cx, cd)))
  end
  del(neighbours, v_to_s(from))
  
  if #neighbours == 1 then
   return follow_road(
    adj,
    s_to_v(neighbours[1])
   )
  elseif #neighbours == 0 then
   return nil
  else
   return adj
  end
 end
 
 -- todo: should also try straight
 -- line raytrace
 function find_next(from, dir)
  local adj = v2_add(from, dir)
  if world[adj.y][adj.x] == road then
   local cross = follow_road(from, adj)
   if cross != nil then
    return cross
   end
  end
  return from
 end

 for i, crossing in ipairs(crossings) do
  crossings_graph[v_to_s(crossing)] = {
   ➡️ = find_next(crossing, right),
   ⬅️ = find_next(crossing, left),
   ⬆️ = find_next(crossing, up),
   ⬇️ = find_next(crossing, down),
  }
 end
end

_screen_start = 0x6000
_screen_size = 0x2000
_data_start = 0x8000

function init_new_world()
 local offs = _worlds[selected_world][2]
 world = load_world(offs.x,offs.y)
 
 -- draw the background map
 draw_world()

 -- move back buffer to screen
 flip()

 -- copy screen to memory, to blit later
 memcpy(
  _data_start,
  _screen_start,
  _screen_size
 )

 build_paths()
 build_crossings_graph()
 
 function mk_truck(b,p,d,f)
  return {
   blue = b,
   pos = p,
   dir_idx = d,
   full = f
  }
 end

 trucks = {}
 
 -- randomly place some trucks on the paths
 for i=1,2 do
  local y,row = rnd_el(paths)
  local x,_ = rnd_el(row)
  local dir_idx = flr(rnd(4))
  add(trucks,
   mk_truck
   (
    i%2==0,
    v2(x,y),
    dir_idx,
    flr(i/2)==1
   )
  )
 end

 redirections = {}
 target.dir = nil
end

function _init()
 move_delay = 0.1
 update_at = t() + move_delay

 up = v2(0, -1)
 right = v2(1, 0)
 down = v2(0, 1)
 left = v2(-1, 0)
 
 dirs = {
  [0] = up,
  [1] = right,
  [2] = down,
  [3] = left
 }
 
 selected_world = 1
 init_new_world()

 menuitem(1, "reset", init_new_world)
 add_level_select_menu_item()
end

function sspr_args(pos,dir)
 local x,sx,xoff,yoff
 -- common to all or most sprites
 local y,sy = 8,5
 if dir == left or dir == right then
  x = 0
  sx = 6
  if dir == right then
   xoff = -3
   yoff = -5
  else
   xoff = -2
   yoff = -1
  end
 elseif dir == up then
  x = 7
  sx = 3
  xoff = -3
  yoff = -2
 elseif dir == down then
  x = 11
  sx = 3
  xoff = 1
  yoff = -4
 else
  assert(false, "unexpected dir:"..dir)
 end

 return {
  x,y,
  sx,sy,
  pos.x+xoff,pos.y+yoff,
  sx,sy,
  dir==left, -- flip_x when facing left
 }
end

function swap_red_to_blue()
 pal(8, 12)
 return 12
end

function draw_truck(truck)
 pal()
 palt(0, false)
 palt(6, true)
 local pos = truck.pos
 local truck_colour = 8
 if truck.blue then
  -- swap red to blue
  truck_colour = swap_red_to_blue()
 end
 if truck.full then
  pal(7, truck_colour)
 end
 sspr(
  unpack(
   sspr_args(pos, dirs[truck.dir_idx])
  )
 )
 pal()
end

function cell_to_world(v, cent)
 local off = cent and 3 or 0
 return v2(v.x*8 + off, v.y*8 + off)
end

function world_to_cell(v)
 return v2(v.x/8,v.y/8)
end

function _draw()
 cls()
 pal()
 
 -- copy pre-rendered background map
 memcpy(
  _screen_start,
  _data_start,
  _screen_size
 )
 
 -- draw all redirection arrows
 for cs, r in pairs(redirections) do
  local c = s_to_v(cs)
  local v = cell_to_world(c)
  local sx = (r.dir == ⬆️ or r.dir == ⬇️) and 16 or 23
  local flip_x = r.dir == ⬅️
  local flip_y = r.dir == ⬇️
  local w,h = 7,7
  if (r.blue) swap_red_to_blue()
  sspr(
   sx,0,
   w,h,
   v.x,v.y,
   w,h,
   flip_x,flip_y
  )
  pal()
 end
 
 -- draw all trucks
 for truck in all(trucks) do
  draw_truck(truck)
 end
 
 -- draw all depot supplies
 for depot in all(depots) do
  if depot.blue then
   swap_red_to_blue()
  end
  local bl = v2_add(
   cell_to_world(depot.pos),
   v2(2,4)
  )
  local yoff=0
  for n=1,depot.supply do
   pset(
    bl.x+(n-1)%3,
    bl.y-flr((n-1)/3),
    8
   )
  end
  pal()
 end
 
 -- debug drawing
 if false then
  -- debug draw paths
  for y, row in pairs(paths) do
   for x, _ in pairs(row) do
    pset(x,y,10)
   end
  end
  
  for c in all(crossings) do
   local v = cell_to_world(c, true)
   circ(v.x,v.y, 3, 15)
  end
 end
 
 -- highlight selected crossing
 -- flash
 if t() % 1 < 0.6 then
  local targ = cell_to_world(target.pos, true)
  local c = target.blue and 12 or 8
  circ(targ.x, targ.y, 4, c)
 end
 
 -- debug printing
 color(0)
 local d = depots[1]
 print(d.supply)
 print(d.next_supply - t())
end

-->8
-- world map
function get_next_supply_time()
 return t() + 5 + rnd(10)
end

-- load world from sprite map
function load_world(xoff, yoff)
 srand(bxor(xoff, yoff))
 water = 1
 park = 3
 building = 5
 road = 6
 red_depot = 8
 blue_depot = 12
 world = {}
 depots = {}
 for y=0,15 do
  local world_row = {}
  for x=0,15 do
   local v = sget(x+xoff, y+yoff)
   world_row[x] = v
   if v == red_depot or v == blue_depot then
    add(
     depots,
     {
      pos = v2(x,y),
      blue = v == blue_depot,
      next_supply = get_next_supply_time(),
      supply = 1,
     }
    )
   end
  end
  world[y] = world_row
 end
 return world
end

function draw_world()
  -- grassy background
  pal()
  cls(11)

  function for_each_cell(fn, kind)
    for cy, row in pairs(world) do
     for cx, cell in pairs(row) do
      if kind == nil or cell == kind then
       fn(cx, cy, cell, row)
      end
     end
    end
  end

  -- draw water
  for_each_cell(
   function(cx,cy,cell)
    local v = cell_to_world(v2(cx,cy))
    local x,y = v.x,v.y
    rectfill(x,y,x+8,y+8,12)
   end,
   water
  )

  -- then road edge hedges
  for_each_cell(
   function(cx,cy,cell)
    local v = cell_to_world(v2(cx,cy))
    rect(
     v.x-1,v.y-1,
     v.x+7,v.y+7,
     3
    )
   end,
   road
  )

  -- draw parks, buildings, and roads
  for_each_cell(
   function(cx,cy,cell,row)
    local v = cell_to_world(v2(cx,cy))
    local x,y = v.x,v.y
    if cell == building then
     spr(9, x, y, 1,1,(x + y*3)%2 == 1)
    elseif cell == park then
     srand(x + 16*y)
     local n = rnd() > 0.8 and 2 or 1
     for i=1,n do
       local xoff = flr(rnd(6)) - 2
       local yoff = flr(rnd(6)) - 5
       sspr(65,1,5,6,x+xoff,y+yoff)
     end
    elseif cell == red_depot then
     sspr(57,1,7,7, x, y)
    elseif cell == blue_depot then
     swap_red_to_blue()
     sspr(57,1,7,7, x, y)
     pal()
    end

    if cell == road then
      -- tarmac
      local x,y = 8*cx, 8*cy
      rectfill(
        x,y,
        x+6,y+6,
        6
      )
   
      -- white lines
     --- left
     local cl,cr = adjacent_with_wrap(cx)
     local cu,cd = adjacent_with_wrap(cy)
     if row[cl] == road then
      line(x,y+3,x+2,y+3,7)
     end
     --- up
     if world[cu][cx] == road then
      line(x+3,y,x+3,y+2,7)
     end
     --- right
     if row[cr] == road then
      line(x+4,y+3,x+6,y+3,7)
      --- patch tarmac
      line(x+7,y,x+7,y+6,6)
     end
     -- down
     if world[cd][cx] == road then
      line(x+3,y+4,x+3,y+6,7)
      --- patch tarmac
      line(x,y+7,x+6,y+7,6)
     end
    end
   end
  )
 end

-->8
-- level select
_worlds = {
  --{"test", v2(64, 48)},
  {"town", v2(112, 48)},
  {"lake", v2(80, 48)},
  {"grid", v2(96,48)},
 }

function add_level_select_menu_item()
  local world_name = _worlds[selected_world][1]
  menuitem(2, "⬅️ "..world_name.." ➡️", level_select)
 end
 
 function level_select(b)
  if b&1 > 0 then
   selected_world -= 1
   if selected_world < 1 then
    selected_world = #_worlds
   end
   add_level_select_menu_item()
   return true
  end
  
  if b&2 > 0 then
   selected_world += 1
   if selected_world > #_worlds then
    selected_world = 1
   end
   add_level_select_menu_item()
   return true
  end
 
  if b&32 > 0 then
   init_new_world()
   return false
  end
 end

__gfx__
00000000000000000088800008880003666677776666777733333333eeeeeeeeeeeeeee000000000000000000000000000000000000000000000000000000000
00000000000000000887880088788006666666666666666766666666e5555555e00300e000004000000000000000000000000000000000000000000000000000
00700700000000008877788888878806666666666666666766666666e5888885e03330e000045400000000000000000000000000000000000000000000000000
00077000000000008787878877777806666666666666666766666666e5877785e33333e000455540000000000000000000000000000000000000000000000000
00077000000000008887888888878807677767776777677777776777e5877785e03430e004555554000000000000000000000000000000000000000000000000
00700700000000000887880088788006666666666666666676666666e5877785e00400e000545750000000000000000000000000000000000000000000000000
00000000000000000088800008880006666666666666666676666666e5888885e00400e000545550000000000000000000000000000000000000000000000000
00000000000000000000000000000006666666666666666676666666e5555555eeeeeee000000000000000000000000000000000000000000000000000000000
87786668586878663666766633333333333333330000000000000000eeeeeeeee0330e0000555500000000000000000000000000000000000000000000000000
8778586878655566366676663666666666666666000000000000000000000000e3333e0000588500000000000000000000000000000000000000000000000000
8778556878688866366676663666666666666666000000000000000000000000eeeeee0000555500000000000000000000000000000000000000000000000000
8888556888655566366666663666666666666666000000000000000000000000e303e00000588500000000000000000000000000000000000000000000000000
0660666060606066366676663666677767776666000000000000000000000000e030e00000555500000000000000000000000000000000000000000000000000
6666666666666666366676663666766666667666000000000000000000000000eeeee00000554500000000000000000000000000000000000000000000000000
cccc6666666666663666766636667666666676660000000000000000000000000000000000554500000000000000000000000000000000000000000000000000
cccc5c66666666663666666636667666666676660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccc5566666666667666766636666666366666660000000037777666355555550000000000000000000000000000000000000000000000000000000000000000
cccc5566666666667666766636667666666676660000000036667666355555550000000000000000000000000000000000000000000000000000000000000000
06606666666666667666766636667666666676660000000036667666358888850000000000000000000000000000000000000000000000000000000000000000
66666666666666667666666636667666666676660000000036666666358777850000000000000000000000000000000000000000000000000000000000000000
66666666666666666666766636666777677766660000000036667666358777850000000000000000000000000000000000000000000000000000000000000000
66666666666666666666766636666666666666660000000036667666358777850000000000000000000000000000000000000000000000000000000000000000
66666666666666666666766636666666666666660000000036667666358888850000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666636666666666666660000000036666666355555550000000000000000000000000000000000000000000000000000000000000000
00000000000000007777766600000000000000007666777736666666333333330000000000000000000000000000000000000000000000000000000000000000
00000000000000007666766600000000000000007666666636667666666666660000000000000000000000000000000000000000000000000000000000000000
00000000000000007666766600000000000000007666666636667666666666660000000000000000000000000000000000000000000000000000000000000000
00000000000000007666666600000000000000007666666636667666666666660000000000000000000000000000000000000000000000000000000000000000
00000000000000006666766600000000000000006666666636666777677767770000000000000000000000000000000000000000000000000000000000000000
00000000000000006666766600000000000000006666666636666666666666660000000000000000000000000000000000000000000000000000000000000000
00000000000000006666766600000000000000006666666636666666666666660000000000000000000000000000000000000000000000000000000000000000
00000000000000006666666600000000000000006666666636666666666666660000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb6bb6336bb6bb6bb633bbb6bbbbbb6bbbbb
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbb666bb6666bb6bb6336bb6bb6bb633b666bb666b66666b
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbb656bb6556bb6b6666666666666666b636666366656b6b
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbb666666666bb6bb633655655655633b6355553656b6b6b
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbb655555556bb6bb633655655655633b63555536565666b
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbcbbbbbbbbbbc653111116bb6b66666666666666666666666666666566
0000000000000000000000000000000000000000000000000000000000000000bbbbbbb6bbbbbbbb6666111111166666b6556336556336bbb63633633655656b
0000000000000000000000000000000000000000000000000000000000000000bbbbbbb6bbbbbbbbbb86111111116bbbb65563365c6336bbb66666666653656b
0000000000000000000000000000000000000000000000000000000000000000bbbb8666665bbbbbbbb6111111116bbb6666666666666666b56b56555553666b
0000000000000000000000000000000000000000000000000000000000000000bbbbbbb6bbbbbbbbbbb6111111116bbb3655655633633633b56556b83c55636b
0000000000000000000000000000000000000000000000000000000000000000bbbbbbb6bbbbbbbbbb66331111556bbb36586556336336336663666636666666
0000000000000000000000000000000000000000000000000000000000000000bbbbbbb5bbbbbbbbb6666333115566666666666666666666b6356b655356bb63
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbb655663311556bbbb6556336556556bbb6356b6333566663
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbb655566666666bbbb6556336556556bbb6656b6555555653
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbb66666bbbbbb666b6666666666666666b3666b6666666653
0000000000000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb6bb6bb6bb6bb6bb633bbb6bb5555633333
