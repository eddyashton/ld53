pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
function v2(_x, _y)
 return {x=_x, y=_y}
end

function v2_add(_v1,_v2)
 return v2(_v1.x+_v2.x, _v1.y+_v2.y)
end

function rnd_el(_t)
 local ar = {}
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
end

function _update()
 -- manual control of first truck
 local tr = trucks[1]
 if (btnp(⬆️)) tr.dir_idx = 0
 if (btnp(➡️)) tr.dir_idx = 1
 if (btnp(⬇️)) tr.dir_idx = 2
 if (btnp(⬅️)) tr.dir_idx = 3
 if (btnp(❎)) tr.full = not tr.full _dbg_draw = not _dbg_draw
 if (btnp(🅾️)) tr.blue = not tr.blue
 
 if (btnp(⬆️) or btnp(➡️) or btnp(⬇️) or btnp(⬅️)) then
  try_move(tr)
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

function _init()
 move_delay = 0.1
 update_at = t() + move_delay
 
 _dbg_draw = false

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
 
 roads = {}
 for y=0,15 do
  local row = {}
  for x=0,15 do
   if sget(x+112, y+48) == 6 then
    row[x] = true
   end
  end
  roads[y] = row
 end
 
 paths = {}
 function add_path(px,py)
  if (not paths[py]) paths[py] = {}
  paths[py][px] = true
 end

 for cy, row in pairs(roads) do
  for cx, _ in pairs(row) do
   local x,y = 8*cx,8*cy
   local cl,cr = adjacent_with_wrap(cx)
   local cu,cd = adjacent_with_wrap(cy)
   if row[cl] then
    local py = y+3
    add_path(x,py)
    add_path(x+1,py)
    add_path(x+2,py)
    add_path(x+3,py)
   end
   if roads[cu] and roads[cu][cx] then
    local px = x+3
    add_path(px,y)
    add_path(px,y+1)
    add_path(px,y+2)
    add_path(px,y+3)
   end
   if row[cr] then
    local py = y+3
    add_path(x+3,py)
    add_path(x+4,py)
    add_path(x+5,py)
    add_path(x+6,py)
    add_path(x+7,py)
   end
   if roads[cd] and roads[cd][cx] then
    local px = x+3
    add_path(px,y+3)
    add_path(px,y+4)
    add_path(px,y+5)
    add_path(px,y+6)
    add_path(px,y+7)
   end
  end
 end
 
 
 function mk_truck(b,p,d,f)
  return {
   blue = b,
   pos = p,
   dir_idx = d,
   full = f
  }
 end

 trucks = {
  mk_truck(false, v2(75,83), 1),
 }
 
 --[[
	-- randomly place some trucks on the roads
	for i=1,8 do
	 local cy,row = rnd_el(roads)
	 local cx,_ = rnd_el(row)
	 local d = rnd(dirs)
	 local x,y = cx*8,cy*8
	 -- correct x, y based on dir
	 if (d == down) x+=1
	 if (d == up) x+=5 y+=5
	 if (d == right) x+=4 y+=2
	 if (d == left) x+=4 y+=5
	 add(trucks,
	  mk_truck
	  (
	   i%2==0,
	   v2(x,y),
				d,
	   flr(i/2)==1
	  )
	 )
	end
	]]--
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

function draw_truck(truck)
 pal()
 palt(0, false)
 palt(6, true)
 local pos = truck.pos
 local truck_colour = 8
 if truck.blue then
  -- swap red to blue
  pal(8, 12)
  truck_colour = 12
 end
 if truck.full then
  pal(7, truck_colour)
 end
 sspr(
  unpack(
   sspr_args(pos, dirs[truck.dir_idx])
  )
 )
end

function draw_roads()
 -- border hedges
 for cy, row in pairs(roads) do
  for cx, _ in pairs(row) do
 	 local x,y = 8*cx, 8*cy
	  rect(
    x-1,y-1,
    x+7,y+7,
    3
   )
  end
 end

 for cy,row in pairs(roads) do
  for cx, _ in pairs(row) do
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
   if row[cl] then
    line(x,y+3,x+2,y+3,7)
   end
   --- up
   if roads[cu] and roads[cu][cx] then
    line(x+3,y,x+3,y+2,7)
   end
   --- right
   if row[cr] then
    line(x+4,y+3,x+6,y+3,7)
    --- patch tarmac
    line(x+7,y,x+7,y+6,6)
   end
   -- down
   if roads[cd] and roads[cd][cx] then
    line(x+3,y+4,x+3,y+6,7)
    --- patch tarmac
    line(x,y+7,x+6,y+7,6)
   end
	  
	 end
 end

end

function _draw()
 cls(11)
 pal()
 
 draw_roads()

 if _dbg_draw then
		-- debug draw paths
		for y, row in pairs(paths) do
		 for x, _ in pairs(row) do
		  pset(x,y,10)
		 end
		end
	end
 
 -- draw all trucks
 for truck in all(trucks) do
  draw_truck(truck)
 end
 
 -- debug printing
 color(0)
end
__gfx__
00000000000000006688866633333333666677776666777733333333000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006887886666666666666666666666666766666666000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000008877788666666666666666666666666766666666000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000008787878666666666666666666666666766666666000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000008887888677776777677767776777677777776777000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000006887886666666666666666666666666676666666000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006688866666666666666666666666666676666666000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006666666666666666666666666666666676666666000000000000000000000000000000000000000000000000000000000000000000000000
87786668586878663666766633333333333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
87785868786555663666766636666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
87785568786888663666766636666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88885568886555663666666636666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06606660606060663666766636666777677766660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666663666766636667666666676660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccc6666666666663666766636667666666676660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccc5c66666666663666666636667666666676660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccc5566666666667666766636666666366666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccc5566666666667666766636667666666676660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06606666666666667666766636667666666676660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666667666666636667666666676660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666666666766636666777677766660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666666666766636666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666666666766636666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666636666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007777766600000000000000007666777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007666766600000000000000007666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007666766600000000000000007666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007666666600000000000000007666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006666766600000000000000006666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006666766600000000000000006666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006666766600000000000000006666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006666666600000000000000006666666600000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bbb6bbbbbb6bbbbb
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b666bb666b66666b
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b636666366656b6b
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b6355553656b6b6b
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b63555536565666b
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006666666666666566
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b63633633655656b
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b6666666665c656b
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b56b56555653666b
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b56556b83655636b
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006666666666666666
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b6356b655656bb63
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b6356b6336566663
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b6656b6556555653
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b3666b6666666653
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bbb6bb5555633333
__map__
1303031400000000000003030314000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1200001200000000000013141324000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1200001200000000000012121213000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2303032400000000000023350412000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003320603000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
