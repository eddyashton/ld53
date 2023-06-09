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

function rnd_range(_a,_b)
 return _a+rnd(_b-_a)
end

function tcopy(_t)
 return {unpack(_t)}
end

function adjacent_with_wrap(c,w)
 w = w or 16
 return (c-1)%w,(c+1)%16
end

_dbg_out = "dbg.out"

function is_adj(_a, _b)
 return
  (_a.y == _b.y and (_a.x == _b.x-1 or _a.x == _b.x+1)) or
  (_a.x == _b.x and (_a.y == _b.y-1 or _a.y == _b.y+1))
end

function adjacent_depot(c, blue)
 for d in all(depots) do
  if d.blue == blue and is_adj(c, d.pos) then
   return d
  end
 end
end

function adjacent_demand(c, blue)
 for d in all(dests) do
  if is_adj(c, d.pos) then
   local deliverable = {}
   for i, b in pairs(d.demand) do
    if b == blue then
     add(deliverable, i)
    end
   end
   if #deliverable > 0 then
    return d, deliverable
   end
  end
 end
end

function interact(tr, c)
 local cs = v_to_s(c)
 local redir = redirections[cs]
 if redir != nil and redir.blue == tr.blue then
  -- got redirected! manually map dirs
  local dir_mapping = {[⬆️]=0, [➡️]=1, [⬇️]=2, [⬅️]=3}
  local redir_idx = dir_mapping[redir.dir]
  -- turn towards the dir, but do a right u-turn to turn around
  -- todo: find a nicer behaviour when redirecting into a wall?
  if redir_idx == (tr.dir_idx-1) % 4 then
   tr.dir_idx = redir_idx
   return true
  elseif redir_idx != tr.dir_idx then
   tr.dir_idx = (tr.dir_idx + 1) % 4
   return true
  end
 end
 if tr.load < tr.max_load then
  -- if you're adjacent to a depot, fill up!
  local adj_depot = adjacent_depot(c, tr.blue)
  if adj_depot != nil and adj_depot.supply > 0 then
   local moved = min(adj_depot.supply, tr.max_load - tr.load)
   tr.load += moved
   adj_depot.supply -= moved
   if (tutorial_state) tutorial_state.collected = true
   return true
  end
 end
 if tr.load > 0 then
  -- if you're adjacent to a building, drop off!
  local dest, deliverable = adjacent_demand(c, tr.blue)
  if dest != nil then
   local delivered = min(#deliverable, tr.load)
   tr.load -= delivered
   for i in all(deliverable) do
    deli(dest.demand, i)
   end
   if (tutorial_state) tutorial_state.delivered = true
   score += delivered
   add(recent_scores, {t(), tr.blue, delivered})
   return true
  end
 end

 -- expire old things from recent scores
 while #recent_scores > 0 do
  local at = unpack(recent_scores[1])
  if t() - at > 1 then
   deli(recent_scores, 1)
  else
   break
  end
 end
 return false
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
end

function next_road(from, dir, escape)
 local v = v2_add(from, dir)
 if (escape and v.x == escape.x and v.y == escape.y) return nil

 v.x %= 16
 v.y %= 16
 if world[v.y][v.x] == road then
  return v
 end
 return next_road(v, dir, escape)
end

function set_game_over()
 game_over = true
 final_score = score
 play_time = t()
end

function create_order(d)
 d.next_order = get_next_order_time(d)
 d.prev_order = t()
 if d.supply < 9 then
  d.supply += 1
 
  -- find an empty house to make this order from
  local candidates = {}
  -- make a list of all candidates with space
  for dest in all(dests) do
   if #dest.demand < dest.max_demand then
    add(candidates, dest)
   end
  end
 
  if #candidates > 0 then
   local dest = rnd(candidates)
   add(dest.demand, d.blue)
  end
 else
  d.damage += 1
  if d.damage == 3 then
   set_game_over()
  end
  d.damage_frames = 25
 end
end

function _update()
 if (game_over) return

 while #events > 0 do
  local trigger,action = unpack(events[1])
  if trigger == nil or trigger() then
   action()
   deli(events, 1)
  else
   break
  end
 end

 if btnp(🅾️) then
  target.blue = not target.blue
  if (tutorial_state) tutorial_state.toggled = true
 end
 
 if btn(❎) then
  target.was_on = true
  if (btn(⬆️)) then target.dir = ⬆️
  elseif (btn(➡️)) then target.dir = ➡️
  elseif (btn(⬇️)) then target.dir = ⬇️
  elseif (btn(⬅️)) then target.dir = ⬅️
  end
 else
  if target.was_on then
   target.was_on = false
   -- x released
   if target.dir != nil then
    -- place a redirection here!
    redirections[v_to_s(target.pos)] = {
      dir = target.dir,
      blue = target.blue
    }
    if (tutorial_state) tutorial_state.placed = true
    if (tutorial_state and target.blue) tutorial_state.placed_blue = true
    target.dir = nil
   else
    -- if there was a redirection here, delete it
    redirections[v_to_s(target.pos)] = nil
    if (tutorial_state) tutorial_state.deleted = true
   end
  end
  
  function mark_tut_move(c)
   if tutorial_state and tutorial_state.moved_cursor then
    tutorial_state.moved_cursor[c] = true
   end
  end
  if (btnp(➡️)) target.pos = next_road(target.pos, right) mark_tut_move(➡️)
  if (btnp(⬅️)) target.pos = next_road(target.pos, left) mark_tut_move(⬅️)
  if (btnp(⬆️)) target.pos = next_road(target.pos, up) mark_tut_move(⬆️)
  if (btnp(⬇️)) target.pos = next_road(target.pos, down) mark_tut_move(⬇️)
 end
 
 -- check if any depots get supplied
 for d in all(depots) do
  if d.next_order and t() >= d.next_order then
   create_order(d)
  end
 end
 
 if t() >= update_at then
  for tr in all(trucks) do
   local c = world_to_cell(v2_add(tr.pos, v2(-3,-3)))
   if not interact(tr, c) then
    try_move(tr)
 
    -- loop off screen edges
    if (tr.dir_idx == 0 and tr.pos.y < 0) tr.pos.y = 131
    if (tr.dir_idx == 1 and tr.pos.x > 128) tr.pos.x = -4
    if (tr.dir_idx == 2 and tr.pos.y > 131) tr.pos.y = 0
    if (tr.dir_idx == 3 and tr.pos.x < -1) tr.pos.x = 131
    update_at = t() + move_delay
   end
  end
 end
end

function build_paths()
 paths = {}
 function add_path(px,py)
  if (not paths[py]) paths[py] = {}
  paths[py][px] = true
 end
 
 local first_road
 for cy, row in pairs(world) do
  for cx, cell in pairs(row) do
   if cell == road then
    if (first_road == nil) first_road = v2(cx,cy)
    local x,y = 8*cx,8*cy
    local cl,cr = adjacent_with_wrap(cx)
    local cu,cd = adjacent_with_wrap(cy)
    if row[cl] == road then
      local py = y+3
      add_path(x,py)
      add_path(x+1,py)
      add_path(x+2,py)
      add_path(x+3,py)
    end
    if world[cu][cx] == road then
      local px = x+3
      add_path(px,y)
      add_path(px,y+1)
      add_path(px,y+2)
      add_path(px,y+3)
    end
    if row[cr] == road then
      local py = y+3
      add_path(x+3,py)
      add_path(x+4,py)
      add_path(x+5,py)
      add_path(x+6,py)
      add_path(x+7,py)
    end
    if world[cd][cx] == road then
      local px = x+3
      add_path(px,y+3)
      add_path(px,y+4)
      add_path(px,y+5)
      add_path(px,y+6)
      add_path(px,y+7)
    end
   end
  end
 end

 local pstart = v2(8,8)
 target = {
  pos = next_road(pstart, up, pstart) or first_road,
  dir = nil,
  was_on = false,
  blue = false,
 }
end

_screen_start = 0x6000
_screen_size = 0x2000
_data_start = 0x8000

function init_new_world()
 local name,offs,e = unpack(_worlds[selected_world])

 events = e or {}
 custom_draws = {}
 game_over = false

 -- restart log file
 --printh("Loading world: "..name, _dbg_out, true)

 if name == "tutorial" then
  tutorial_state = {
    pause_depots = true,
  }
 else
  tutorial_state = nil
 end

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

 trucks = {}
 
 -- place a truck next to each depot
 for d in all(depots) do
  for dir_idx, dir in pairs(dirs) do
   local v = v2_add(d.pos, dir)
   if world[v.y] and world[v.y][v.x] == road then
    add(
     trucks,
     {
      blue = d.blue,
      pos = cell_to_world(v, true),
      dir_idx = 0,
      load = 0,
      max_load = 6,
     }
    )
    break
   end
  end
 end

 redirections = {}
 target.dir = nil

 score = 0
 recent_scores = {}
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

truck_load_offsets = {
  -- when driving up, there's 2 pixels to fill
  [0] = {[3] = v2(-2, 0), [6] = v2(-2,-1)},
  -- when driving down, there's 1 pixel to fill
  [2] = {[6] = v2(2, -4)},

  -- when driving left and right, there's 6 pixels
  -- fill in a consistent order, row-by-row
  [1] = {
   v2(-1,-3),v2(-2,-3),
   v2(-1,-4),v2(-2,-4),
   v2(-1,-5),v2(-2,-5),
  },
  [3] = {
   v2( 1, 1),v2( 2, 1),
   v2( 1, 0),v2( 2, 0),
   v2( 1,-1),v2( 2,-1),
  },
}

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
 sspr(
  unpack(
   sspr_args(pos, dirs[truck.dir_idx])
  )
 )

 local offs = truck_load_offsets[truck.dir_idx]
 for n=1,truck.load do
  local off = offs[n]
  if off != nil then
   pset(
    pos.x + off.x,
    pos.y + off.y,
    8
   )
  end
 end
 pal()
end

function cell_to_world(v, cent)
 local off = cent and 3 or 0
 return v2(v.x*8 + off, v.y*8 + off)
end

function world_to_cell(v)
 return v2(v.x/8,v.y/8)
end

function draw_arrow(c, dir, blue)
  local v = cell_to_world(c)
  local sx = (dir == ⬆️ or dir == ⬇️) and 16 or 23
  local flip_x = dir == ⬅️
  local flip_y = dir == ⬇️
  local w,h = 7,7
  if (blue) swap_red_to_blue()
  sspr(
   sx,0,
   w,h,
   v.x,v.y,
   w,h,
   flip_x,flip_y
  )
  pal()
end

function draw_clock_arm(centre, rad, frac, colour)
 frac += 0.5 -- offset to start from top
 local vend = v2_add(centre, v2(rad*sin(frac), rad*cos(frac)))
 line(
  centre.x, centre.y,
  vend.x, vend.y,
  colour
 )
end

function display_time(n)
  local m = flr(n / 60)
  local s = n % 60
  s = flr(100 * s) / 100
  return (m > 0 and (m .. " m ") or "") .. s .. " s"
end

-- print centered
function printc(str, x, y, colour)
 local w = print(str, 0, -20)
 print(str, x-w/2, y-2, colour)
end

function to_hex(n)
 assert(n<=15)
 return tostr(n, 0x1)[6]
end

function draw_game_over_screen()
 rectfill(0,8,128,16,0)
 printc("yOU GOT fired!", 64, 12, 9)

 rectfill(0,40,128,56,0)
 printc("fINAL sCORE", 64, 44, 9)
 printc(final_score or 0, 64, 52, 9)

 play_time = play_time or 0
 rectfill(0, 72, 128, 88, 0)
 printc("yOUR EMPLOYMENT LASTED", 64, 76, 9)
 printc(display_time(play_time),  64, 84, 9)

 if rank == nil then
  srand(play_time + final_score)
  rank = rnd{"piddly", "pathetic", "proletarian", "poor", "paltry", "pitiful"}
 end
 rectfill(0, 104, 128, 120, 0)
 printc("pOPPYCOCK PROCLAIMS YOU", 64, 108, 9)
 printc(rank, 64, 116, 9)

 if t() - play_time > 3 then
  scan_off = scan_off or 129
  scan_end = print("(RESET AND LEVEL SELECT ON THE PAUSE MENU)", scan_off, 18, 0)
  scan_off -= 1
  if (scan_end < 0) scan_off = 129
 end
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

 if (game_over) draw_game_over_screen() return
 
 -- draw all redirection arrows
 for cs, r in pairs(redirections) do
  local c = s_to_v(cs)
  draw_arrow(c, r.dir, r.blue)
 end
 
 -- draw all trucks
 for truck in all(trucks) do
  draw_truck(truck)
 end
 
 for depot in all(depots) do
 -- draw all depot supplies
  if depot.blue then
   swap_red_to_blue()
  end
  local dp = cell_to_world(depot.pos)
  local bl = v2_add(
   dp,
   v2(2,4)
  )
  for n=1,depot.supply do
   pset(
    bl.x+(n-1)%3,
    bl.y-flr((n-1)/3),
    8
   )
  end

  pal()

  -- draw depot damage
  if (depot.damage < 3) pset(dp.x+5,dp.y, 7)
  if (depot.damage < 2) pset(dp.x+3,dp.y, 7)
  if (depot.damage < 1) pset(dp.x+1,dp.y, 7)

  -- draw a clock to indicate time until next order
  -- only appears for final 3rd of order time
  if depot.next_order then
   local frac = (t() - depot.prev_order) / (depot.next_order - depot.prev_order)
   frac = (frac*3) - 2
   if frac > 0 then
    frac += 0.05 -- offset slightly for nicer rendering
    draw_clock_arm(
     v2_add(cell_to_world(depot.pos, true), v2(0.5, 0.5)),
     2,
     frac,
     0
    )
   end
  end

  if depot.damage_frames > 0 then
   -- draw a cross to indicate this has just taken a strike
   pal(7,0)
   spr(1, dp.x, dp.y)
   depot.damage_frames -= 1
  end
 end
 
 -- draw lights in all of the windows with demand
 for dest in all(dests) do
  local v = cell_to_world(dest.pos)
  local windows = window_offsets[dest.kind]
  for i,blue in pairs(dest.demand) do
   for woff in all(windows[i]) do
    local wv = v2_add(v,woff)
    pset(wv.x,wv.y,blue and 12 or 8)
   end
  end
 end
 
 -- highlight selected cell
 -- flash
 if t() % 1 < 0.6 then
  local targ = cell_to_world(target.pos, true)
  if (target.blue) swap_red_to_blue()
  circ(targ.x, targ.y, 4, 8)
  pal(7,0)
  if target.dir != nil then
   palt(8, true)
   draw_arrow(target.pos, target.dir, target.blue)
  elseif target.was_on then
   local targ = cell_to_world(target.pos)
   spr(1, targ.x,targ.y)
  end
  pal()
 end

 -- print score!
 print("\#5\f0"..score.."\0", 1, 1)
 for _, s in ipairs(recent_scores) do
  local blue = s[2]
  print("\f"..to_hex(blue and 12 or 8).." +"..s[3].."!\0")
 end
 
 for _, drawfn in pairs(custom_draws) do
  drawfn()
 end

 -- debug drawing
 if false then
  -- debug draw paths
  for y, row in pairs(paths) do
   for x, _ in pairs(row) do
    pset(x,y,10)
   end
  end
 end

 -- debug printing
 color(0)
end

-->8
-- world map
function get_next_order_time(d)
 if (tutorial_state and tutorial_state.pause_depots) return nil
 local delay = (rnd() / 10 + 0.9) * d.max_order_time
 if (d.max_order_time > 3) d.max_order_time *= 0.9 -- get harder!
 return t() + delay
end

-- load world from sprite map
function load_world(xoff, yoff)
 srand(bxor(xoff, yoff))
 water = 1
 park = 3
 house = 5
 tower = 9
 road = 6
 red_depot = 8
 blue_depot = 12

 window_offsets = {
  [house] = {{v2(4, 4), v2(4,5)}},
  [tower] = {
   {v2(1,4),v2(1,5)}, -- bottom-left
   {v2(5,1),v2(5,2)}, -- top-right
   {v2(3,1),v2(3,2)}, -- top-mid
   {v2(5,4),v2(5,5)}, -- bottom-right
   {v2(1,1),v2(1,2)}, -- top-left
  },
 }

 world = {}
 depots = {}
 dests = {}
 for y=0,15 do
  local world_row = {}
  for x=0,15 do
   local v = sget(x+xoff, y+yoff)
   world_row[x] = v
   if v == red_depot or v == blue_depot then
    local new_depot = {
     pos = v2(x,y),
     blue = v == blue_depot,
     supply = 0,
     damage = 0,
     damage_frames = 0,
     max_order_time = 15,
    }
    create_order(new_depot)
    add(depots, new_depot)
   elseif v == house or v == tower then
    add(
     dests,
     {
      pos = v2(x,y),
      demand = {},
      max_demand = #window_offsets[v],
      kind = v,
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

  -- build an array-style table of world, so we can ipairs through it
  -- from top-to-bottom, and draw in z-order
  local ar_world = {}
  for cy=0,15 do
   ar_world[cy+1] = {cy, world[cy]}
  end

  function for_each_cell(fn, filter)
    for _, p in ipairs(ar_world) do
     local cy, row = unpack(p)
     for cx, kind in pairs(row) do
      if filter == nil or filter == kind then
       local v = cell_to_world(v2(cx,cy))
       fn(v.x, v.y, kind, cx, cy, row)
      end
     end
    end
  end

  -- draw water
  for_each_cell(
   function(x,y)
    rectfill(x,y,x+8,y+8,12)
   end,
   water
  )

  -- then road edge hedges
  for_each_cell(
   function(x,y)
    rect(
     x-1,y-1,
     x+7,y+7,
     3
    )
   end,
   road
  )

  -- draw parks, buildings, and roads
  for_each_cell(
   function(x,y,cell,cx,cy,row)
    if cell == house then
     spr(9, x, y)
    elseif cell == tower then
     spr(25, x, y)
    elseif cell == park then
     -- draw from back to front, some random plants
     -- todo: z-draw trucks, so they pass behind trees and buildings
     srand(x + 16*y)
     local flip_x = rnd() > 0.5
     for offs in all{{1,1}, {5, 2}, {2,4}, {6,6}} do
      local xoff,yoff = unpack(offs)
      if (flip_x) xoff = 8-xoff
      if rnd() >= 0 then
       -- draw in this row
       local plants = { -- sx,sy,w,h
        {65,1,5,6}, -- tree
        {65,8,4,2}, -- bush
        {65,11,3,2}, -- grass
       }
       -- if there's a building behind, don't draws trees here
       -- (in case they obscure windows!)
       if world[cy-1] then
        local v = world[cy-1][cx]
        if (v==house or v==tower) deli(plants,1)
       end
       local sx,sy,w,h = unpack(rnd(plants))
       sspr(sx,sy,w,h,x+xoff-ceil(w/2),y+yoff-h+1)
      end
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
-- tutorial

function mk_printc(k, ...)
 local args = {...}
 return
  function()
   custom_draws[k] =
    function()
     printc(unpack(args))
    end
  end
end


function checkbox(check, s, x, y, c)
 local done = check()
 print("["..(done and "♥" or "  ").."] ", x-20,y,c)
 print(s,x,y,c)
end

tutorial_events = {
  -- 0th step - welcome message
  {
   nil,
   function()
    custom_draws["tut"] = function()
     printc("WELCOME TO YOUR FIRST DAY AT", 64,56, 0)
     printc("poppycock's", 64,68, 0)
     printc("perfect", 64,75, 0)
     printc("parcels", 64,82, 0)
    end
   end
  },

  {
   function()
    return t() > 4
   end,
   function()
    custom_draws["tut"] = function()
     printc("your job is to", 64,56, 0)
     printc("remote-control the lorries", 64,62, 0)
     printc("to deliver parcels", 64,68, 0)

     if t() > 8 then
      printc("(AND DON'T LET", 64,78, 0)
      printc("ANYONE KNOW THEY'RE", 64,84, 0)
      printc("NOT SELF-DRIVING)", 64,90, 0)
     end
     if t() > 12 then
      printc("let's go through the basics", 64, 104, 0)
     end
    end
   end
  },

  -- 1st step, move cursor
  {
   function()
    tutorial_state.moved_cursor = {}
    return t() > 16
   end,
   function()
    custom_draws["tut"] = function()
     print("move your rc cursor:", 24, 56, 0)
     local mc = tutorial_state.moved_cursor
     checkbox(function() return mc and mc[⬅️] end, "⬅️", 32, 70,0)
     checkbox(function() return mc and mc[➡️] end, "➡️", 32, 76,0)
     checkbox(function() return mc and mc[⬆️] end, "⬆️", 32, 82,0)
     checkbox(function() return mc and mc[⬇️] end, "⬇️", 32, 88,0)

     if mc and mc[⬅️] and mc[➡️] and mc[⬆️] and mc[⬇️] then
      tutorial_state.moved_cursor = nil
     end
    end
   end
  },

  -- 2nd step, place and delete
  {
    function()
     if tutorial_state.moved_cursor == nil then
      tutorial_state.placed = false
      tutorial_state.deleted = false
      return true
     end
    end,
    function()
     custom_draws["tut"] = function()
      printc("this red lorry will", 64, 56)
      printc("follow red arrows", 64, 64)
      checkbox(function() return tutorial_state.placed end, "hold ❎+(dir) to\nplace an arrow", 26,70, 0)
      checkbox(function() return tutorial_state.deleted end, "tap ❎ to delete\nexisting arrow", 26,86, 0)
     end
    end
  },

  -- 3rd step, multiple colours
  {
    function()
     if tutorial_state.placed and tutorial_state.deleted then
      tutorial_state.toggled = false
      tutorial_state.placed_blue = false
      return true
     end
    end,
    function()
     custom_draws["tut"] = function()
      printc("red lorries ignore", 64, 56)
      printc("blue arrows", 64, 64)
      checkbox(function() return tutorial_state.toggled end, "tap 🅾️ to change\ncursor colour", 26,70, 0)
      checkbox(function() return tutorial_state.placed_blue end, "place a blue\narrow", 26,86, 0)
     end
    end
  },

  -- 4th step, collect and deliver
  {
    function()
     if tutorial_state.toggled and tutorial_state.placed_blue then
      tutorial_state.collected = false
      tutorial_state.delivered = false
      tutorial_state.pause_depots = false
      create_order(depots[1])
      return true
     end
    end,
    function()
     custom_draws["tut"] = function()
      printc("orders will now arrive", 64, 56)
      printc("at the depot", 64, 64)
      checkbox(function() return tutorial_state.collected end, "collect an order by\npassing the depot", 24,80, 0)
      checkbox(function() return tutorial_state.delivered end, "deliver an order to\na customer window\nof the same colour", 24,96, 0)
     end
    end
  },

  -- 5th step, rules
  {
    function()
     if tutorial_state.collected and tutorial_state.delivered then
      return true
     end
    end,
    function()
     custom_draws["tut"] = function()
      printc("looking good! now try a real", 64, 56)
      printc("level from the pause menu", 64, 64)

      print("be warned:", 10, 76)
      print(" - depots and lorries will\n   get full", 10, 82)
      print(" - full depots will earn\n   a strike", 10, 94)
      print(" - 3 strikes and you're\n   fired!", 10, 106)
     end
    end
  },
}


-->8
-- level select
_worlds = {
  {"tutorial", v2(48, 48), tutorial_events},
  --{"test", v2(64, 48)},
  {"lake", v2(80, 48)},
  {"town", v2(112, 48)},
  {"city", v2(96,48)},
 }

function add_level_select_menu_item()
 local world_name = _worlds[selected_world][1]
 menuitem(2, "lvl: ⬅️"..world_name.."➡️", level_select)
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
00000000000000000088800008880003666677776666777733333333eeeeeeeeeeeeeee000040000bbbbbbbb0000000000000000000000000000000000000000
00000000070007000887880088788006666666666666666766666666e5555555e00300e000454000bbbbbbbb0000000000000000000000000000000000000000
00700700007070008877788888878806666666666666666766666666e5888885e03330e004555400bbbbbbbb0000000000000000000000000000000000000000
00077000000700008787878877777806666666666666666766666666e5877785e33333e045555540bbbbbbbb0000000000000000000000000000000000000000
00077000007070008887888888878807677767776777677777776777e5877785e03430e005457500bbbbbbbb0000000000000000000000000000000000000000
00700700070007000887880088788006666666666666666676666666e5877785e00400e005457500bbbbbbbb0000000000000000000000000000000000000000
00000000000000000088800008880006666666666666666676666666e5888885e00400e005455500bbbbbbbb0000000000000000000000000000000000000000
00000000000000000000000000000006666666666666666676666666e5555555eeeeeee000000000bbbbbbbb0000000000000000000000000000000000000000
87786668586878663666766633333333333333330000000000000000eeeeeeeee0330e0055555550b33bbbbb0000000000000000000000000000000000000000
8778586878655566366676663666666666666666000000000000000000000000e3333e00575757503333b3bb0000000000000000000000000000000000000000
8778556878688866366676663666666666666666000000000000000000000000eeeeee0057575750bbbb333b0000000000000000000000000000000000000000
8888556888655566366666663666666666666666000000000000000000000000e303e00055555550bbb3333b0000000000000000000000000000000000000000
0660666060606066366676663666677767776666000000000000000000000000e030e00057545750bbb333330000000000000000000000000000000000000000
6666666666666666366676663666766666667666000000000000000000000000eeeee00057545750b3b3343b0000000000000000000000000000000000000000
cccc6666666666663666766636667666666676660000000000000000000000000000000055545550bb3bb4bb0000000000000000000000000000000000000000
cccc5c66666666663666666636667666666676660000000000000000000000000000000000000000bbbbb4bb0000000000000000000000000000000000000000
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
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbb555999bbbbbbbbbbbbbbbbbbbbbbbb6b3633633633633633bbb6bbbbbb6bbbbb
000000000000000000000000000000000000000000000000bbb336119bbbbbbb555999bbbbbbbbbbbb6666bb6666bb6b3633633633633633b666bb666b66666b
000000000000000000000000000000000000000000000000bbb386116bbbbbbb555999bbbbbbbbbbbb6556bb6996bb6b6666666666666666b636666366656b6b
000000000000000000000000000000000000000000000000bbb33666665bbbbb666666bbbbbbbbbbbb6666666666bb6b3633699699699633b6355553656b6b6b
000000000000000000000000000000000000000000000000bbb336116bbbbbbb656696bbbbbbbbbbbbb655555556bb6b3633655655655633b63555536565666b
000000000000000000000000000000000000000000000000bbb336115bbbbbbb666666bcbbbbbbbbbbc653111116bb6b66666666666666666666666666666566
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbb6bbbbbbbb66661111111666663655633655633633b63633633655656b
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbb6bbbbbbbbbb86111111116bbb3655633655633633b66666666653656b
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbb8666665bbbbbbbb6111111116bbb6666666666666666b56b56555553666b
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbb6bbbbbbbbbbb6111116666bbb3699699655655633b56356b83c55636b
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbb6bbbbbbbbbbb6331116556bbb36986c96596956336663666636666666
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbb5bbbbbbbb66666333165566666666666666666666b6356b653356bb63
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb655663316556bbb3655633659695633b6356b6533566663
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb655566666666bbb3655633655655633b6656b6555555653
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb66666bbbbbb666b6666666666666666b3666b6666666653
000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb6b3633633633633633bbb6bb5555633333
__label__
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb3bbbbbbbbb333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbb333333bbbbb366666663cccccccccccccccc5555555bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbb333333333b33b366666663cccccccccccccccc5757575bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbb333343bbbb3333366666663cccccccccccccccc5757575bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb4bb3b3bbbb366666663cccccccccccccccc5555555bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb4bbb3bbbbb366676663cccccccccccccccc5754575bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbb3b3bbbbbbbbb3b3366676663cccccccccccccccc5754575bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbb3bbbbbbbbbbb3b366676663cccccccccccccccc5554555bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb3bbbbbbbbb366666663ccccccccccccccc333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbb33335757575366676663ccccccccccccccc366666663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbb3333335888885366676663ccccccccccccccc366666663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbb333343b5877785366676663ccccccccccccccc366666663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb4bb5877785366666663ccccccccccccccc366666663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb43b5877785366676663ccccccccccccccc366676663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbb3b3bb3335888385366676663ccccccccccccccc366676663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbb3bb33333553335366676663cc8778ccccccccc366676663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb343bb3333336666666333877858333333336666666333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb43b3b343b36667666666877855666666666667666666666663bbb4bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbb33bb4b3bbb4bb36667666666888855666666666667666666666663bb454bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbb3333bbbbbbb4bb36667666666066066666666666667666666666663b45554bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb33b3b3bbbb366667776777677767776777677767776777666634555554bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbb3333b3bbbbb36667666666666666666666666667666666666663b54575bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbb3b3bbbbbbbbb3b336667666666666666666666666667666666666663b54575bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbb3bbbbbbbbb333b36667666666666666666666666667666666666663b54555bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb3333336666666333333333333333336666666333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb3b3b3b343b366676663ccccccccccccccc366676663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbb33bb3b3bbb4bb366676663ccccccccccccccc366676663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbb3333bbbbbbb4bb366676663ccccccccccccccc366676663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbb3b3b3b3bbbb366666663ccccccccccccccc366666663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb3bbb3bbbbb366676663ccccccccccccccc366666663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbb3b3bbbbbbbbbb33366676663ccccccccccccccc366666663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbb3bbbbbbbbbb333366676663ccccccccccccccc366666663bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb366666663ccccccccccccccc333333333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbb3b3bbbbbbbbbbbb3366676663cccccccccccccccccbb4bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbb3bb3b3bbb333b33366676663cccccccccccccccccb454bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbb3bbb33333bb366676663ccccccccccccccccc45554bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbb3b3bbbb333333b3366666663cccccccccccccccc4555554bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbb3bbbbbb343bb3b366666663ccccccccccccccccc54575bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbb33bb4bbbbb366666663ccccccccccccccccc54575bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbb3333b4bbbbb366666663ccccccccccccccccc54555bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb333333333cccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbcccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbb0b0b000b0bbbb00bb00b000b000bbbbb000bb00bbbbb0b0bb00b0b0b00bbbbbb000b000b00bbb00b000bbbbb00bbb00b0b0bbbbbb00b000bbbbbbbbb
bbbbbbbb0b0b00bb0bbb0bbb0b0b000b00bbbbbbb0bb0b0bbbbb000b0b0b0b0b0b0bbbbb00bbb0bb0b0b0bbbb0bbbbbb0b0b0b0b000bbbbb0b0bb0bbbbbbbbbb
bbbbbbbb000b0bbb0bbb0bbb0b0b0b0b0bbbbbbbb0bb0b0bbbbbbb0b0b0b0b0b00bbbbbb0bbbb0bb00bbbb0bb0bbbbbb0b0b000bbb0bbbbb000bb0bbbbbbbbbb
bbbbbbbb000bb00bb00bb00b00bb0b0bb00bbbbbb0bb00bbbbbb00bb00bbb00b0b0bbbbb0bbb000b0b0b00bbb0bbbbbb00bb0b0b00bbbbbb0b0bb0bbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000bb00b000b000b0b0bb00bb00bb00b0b0bb0bbb00bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0b0b0b0b0b0b0b0b0b0b0bbb0b0b0bbb0b0b0bbb0bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000b0b0b000b000b000b0bbb0b0b0bbb00bbbbbb000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0bbb0b0b0bbb0bbbbb0b0bbb0b0b0bbb0b0bbbbbbb0bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0bbb00bb0bbb0bbb000bb00b00bbb00b0b0bbbbb00bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000b000b000b000b000bb00b000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0b0b0bbb0b0b0bbb0bbb0bbbb0bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000b00bb00bb00bb00bb0bbbb0bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0bbb0bbb0b0b0bbb0bbb0bbbb0bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0bbb000b0b0b0bbb000bb00bb0bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000b000b000bb00b000b0bbbb00bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0b0b0b0b0b0b0bbb0bbb0bbb0bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000b000b00bb0bbb00bb0bbb000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0bbb0b0b0b0b0bbb0bbb0bbbbb0bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0bbb0b0b0b0bb00b000b000b00bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

__sfx__
001700001805018050130501805018050180501d050190501d050170501d0501c050190501a0501b0501b0501b050190501805017050160501855015050150501755014050140501405013050120501105011050
