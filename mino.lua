local Utils = require("./utils")

local Tile = {}
Tile.__index = Tile

function Tile.new(texture, mino)
	local self = setmetatable({
		texture = texture,
		mino = mino
	}, Tile)
	
	return self
end


local Mino = {name = '', color = 'grey-200'}
Mino.__index = Mino

function Mino.new(game, base)
	base = base or {
		shape = {
			{0, 0, 0},
			{0, 0, 0},
			{0, 0, 0}
		},
		
		view_xoffset = 0,
		view_yoffset = 0,
		
		srs_table = {
			['01'] = {{0, 0}},
			['10'] = {{0, 0}},
			['12'] = {{0, 0}},
			['21'] = {{0, 0}},
			['23'] = {{0, 0}},
			['32'] = {{0, 0}},
			['30'] = {{0, 0}},
			['03'] = {{0, 0}}
		}
	}
	
	local self = setmetatable(base, Mino)
	self.game = game
	self.x = 4
	self.y = 21
	self.rotation = 1
	
	self.rotation_to_vector = {
		[0] = {0, 1},
		[1] = {1, 0},
		[2] = {0, -1},
		[3] = {-1, 0}
	}
	
	self.shape_cache = {}
	self.shape_cache[1] = self.shape
	
	for i = 3, 1, -1 do
		self.shape_cache[i + 1] = Utils.rotate_cw(self.shape_cache[(i + 1) % 4 + 1])
	end

	self.last_successful_movement = nil
	self.last_rotation_info = nil
	self.phase = 'drop'
	self.locking_start = 0
	self.tick = 0
	self.move_counter = 0
	self.id = Utils.random_id()
	
	return self
end

function Mino.placeable(self, x, y, rotation)
	local shape = self.shape_cache[rotation]
	
	for dy = 0, self:size() - 1 do
		for dx = 0, self:size() - 1 do
			if shape[dy + 1][dx + 1] ~= 0 then
				if x + dx < 1 or x + dx > 10 then
					return false
				end
				
				if y - dy < 1 or y - dy > 40 then
					return false
				end
				
				if self.game.playfield[y - dy][x + dx] ~= nil then
					return false
				end
			end
		end
	end
	
	return true
end

function Mino.rotation_shape(self)
	return self.shape_cache[self.rotation]
end

function Mino.is_placeable(self)
	return self:placeable(self.x, self.y, self.rotation)
end

function Mino.is_locked(self)
	return self.phase == 'locked'
end

function Mino.get_landing_position(self)
	local max_drop = 0
	
	for i = 1, 40 do
		if not self:placeable(self.x, self.y - i, self.rotation) then
			max_drop = i - 1
			break
		end
	end
	
	return self.x, self.y - math.max(0, max_drop), self.rotation
end

function Mino.size(self)
	return #self.shape
end

function Mino.add_move_counter(self)
	if self.phase == 'locking' then
		self.locking_start = self.tick
		self.move_counter  = self.move_counter + 1
	end

	if self.move_counter > 15 then
		return false
	end
	
	return true
end
	
-- /// Begin Rotation ///

function Mino.rotate(self, direction)
	local direction = direction == nil and 1 or direction
	
	local new_rotation = (self.rotation + direction + 3) % 4 + 1
	local rotation_code = tostring(self.rotation) .. tostring(new_rotation)
	local movement_success = false
	local rotation_info = {0, 0}
	
	for key, srs in ipairs(self.srs_table[rotation_code]) do
		x = srs[1]
		y = srs[2]
		
		if self:placeable(self.x + x, self.y + y, new_rotation) then
			movement_success = true
			self.rotation = new_rotation
			self.x = self.x + x
			self.y = self.y + y
			
			rotation_info = {x, y}
			break
		end
	end
	
	if not movement_success then
		return false
	end
	
	self.last_rotation_info = rotation_info
	self.last_successful_movement = 'rotate'
	
	if not self:add_move_counter() then
		self:on_locked()
	end
	
	return true
end

function Mino.rotate_left(self)
	return self:rotate(-1)
end

function Mino.rotate_right(self)
	return self:rotate(1)
end

-- /// End Rotation ///

-- /// Begin Drop ///

function Mino.drop_one(self)
	if self:placeable(self.x, self.y - 1, self.rotation) then
		if self.phase == 'locking' then
			self.phase = 'drop'
		end
		
		if self.phase == 'drop' then
			self.last_successful_movement = 'drop'
			self.y = self.y - 1
		end
	
	else
		if self.phase == 'drop' then
			self.phase = 'locking'
			self.locking_start = self.tick
		end
	end
end

function Mino.drop(self, amount)
	for i = 1, amount do
		self:drop_one()
	end
end

function Mino.harddrop(self)
	x, y, rotation = self:get_landing_position()
	
	self.y = y
	self.last_successful_movement = 'drop'
	
	self:on_locked()
end

-- /// End Drop ///

-- /// Begin Movement ///

function Mino.move(self, x)
	if self:placeable(self.x + x, self.y, self.rotation) then
		self.last_successful_movement = 'move'
		self.x = self.x + x
		
		if not self:add_move_counter() then
			self:on_locked()
		end
	end
end

function Mino.move_left(self)
	return self:move(-1)
end

function Mino.move_right(self)
	return self:move(1)
end

-- /// End Movement ///

function Mino.on_locked(self)
	self.phase = 'locked'
	self.game:on_locked()
end

function Mino.is_position_mino_translate(self, x, y, px, py)
	local dx = x - px
	local dy = py - y
	
	if dx < 0 or dx >= self:size() then
		return false
	end
	
	if dy < 0 or dy >= self:size() then
		return false
	end
	
	return self:rotation_shape()[dy + 1][dx + 1] ~= 0
end

function Mino.is_position_mino(self, x, y)
	return self:is_position_mino_translate(x, y, self.x, self.y)
end

function Mino.get_position_tile(self, x, y)
	return self:get_position_tile_translate(x, y, self.x, self.y)
end

function Mino.get_position_tile_translate(self, x, y, px, py)
	local dx = x - py
	local dy = py - y

	return Tile.new(
		-- self.name .. tostring(self:rotation_shape()[dy + 1][dx + 1]),
		self.name,
		self
	)
end

function Mino.get_tile(self, shape_no)
	return Tile.new(
		-- self.name .. tostring(shape_no),
		self.name,
		self
	)
end

function Mino.update(self)
	self.tick = self.tick + 1
	
	if not self:placeable(self.x, self.y - 1, self.rotation) and
		self.phase == 'locking' and
		self.tick - self.locking_start >= self.game.configuration['lock'] then
		
		self:on_locked()
	end
end


local jlstz_wallkick_table = {
	['12'] = {{ 0,  0}, {-1,  0}, {-1,  1}, { 0, -2}, {-1, -2}},
	['21'] = {{ 0,  0}, { 1,  0}, { 1, -1}, { 0,  2}, { 1,  2}},

	['23'] = {{ 0,  0}, { 1,  0}, { 1, -1}, { 0,  2}, { 1,  2}},
	['32'] = {{ 0,  0}, {-1,  0}, {-1,  1}, { 0, -2}, {-1, -2}},

	['34'] = {{ 0,  0}, { 1,  0}, { 1,  1}, { 0, -2}, { 1, -2}},
	['43'] = {{ 0,  0}, {-1,  0}, {-1, -1}, { 0,  2}, {-1,  2}},

	['41'] = {{ 0,  0}, {-1,  0}, {-1, -1}, { 0,  2}, {-1,  2}},
	['14'] = {{ 0,  0}, { 1,  0}, { 1,  1}, { 0, -2}, { 1, -2}}
}

local MinoL = setmetatable({name = 'l', color = 'orange-400'}, {__index = Mino})
MinoL.__index = MinoL

function MinoL.new(game, base)
	base = base or {
		name = 'l',
		shape = {
			{0, 0, 1},
			{4, 3, 2},
			{0, 0, 0}
		},
		
		view_xoffset = 0,
		view_yoffset = 0.5,
		
		srs_table = jlstz_wallkick_table
	}
	
	return setmetatable(Mino.new(game, base), MinoL)
end

local MinoJ = setmetatable({name = 'j', color = 'blue-400'}, {__index = Mino})
MinoJ.__index = MinoJ

function MinoJ.new(game, base)
	base = base or {
		name = 'j',
		shape = {
			{1, 0, 0},
			{2, 3, 4},
			{0, 0, 0}
		},
		
		view_xoffset = 0,
		view_yoffset = 0.5,
		
		srs_table = jlstz_wallkick_table
	}
	
	return setmetatable(Mino.new(game, base), MinoJ)
end

local MinoS = setmetatable({name = 's', color = 'green-400'}, {__index = Mino})
MinoS.__index = MinoS

function MinoS.new(game, base)
	base = base or {
		name = 's',
		shape = {
			{0, 3, 4},
			{1, 2, 0},
			{0, 0, 0}
		},
		
		view_xoffset = 0,
		view_yoffset = 0.5,
		
		srs_table = jlstz_wallkick_table
	}
	
	return setmetatable(Mino.new(game, base), MinoS)
end

local MinoZ = setmetatable({name = 'z', color = 'red-400'}, {__index = Mino})
MinoZ.__index = MinoZ

function MinoZ.new(game, base)
	base = base or {
		name = 'z',
		shape = {
			{1, 2, 0},
			{0, 3, 4},
			{0, 0, 0}
		},
		
		view_xoffset = 0,
		view_yoffset = 0.5,
		
		srs_table = jlstz_wallkick_table
	}
	
	return setmetatable(Mino.new(game, base), MinoZ)
end

local MinoT = setmetatable({name = 't', color = 'purple-400'}, {__index = Mino})
MinoT.__index = MinoT

function MinoT.new(game, base)
	base = base or {
		name = 't',
		shape = {
			{0, 3, 0},
			{1, 2, 4},
			{0, 0, 0}
		},
		
		view_xoffset = 0,
		view_yoffset = 0.5,
		
		srs_table = jlstz_wallkick_table
	}
	
	return setmetatable(Mino.new(game, base), MinoT)
end


local MinoO = setmetatable({name = 'o', color = 'yellow-400'}, {__index = Mino})
MinoO.__index = MinoO

function MinoO.new(game, base)
	base = base or {
		name = 'o',
		shape = {
			{0, 0, 0, 0},
			{0, 1, 2, 0},
			{0, 4, 3, 0},
			{0, 0, 0, 0}
		},
		
		view_xoffset = 0,
		view_yoffset = 0,
		
		srs_table = jlstz_wallkick_table
	}
	
	return setmetatable(Mino.new(game, base), MinoO)
end


local MinoI = setmetatable({name = 'i', color = 'cyan-400'}, {__index = Mino})
MinoI.__index = MinoI

function MinoI.new(game, base)
	base = base or {
		name = 'i',
		shape = {
			{0, 0, 0, 0},
			{1, 2, 3, 4},
			{0, 0, 0, 0},
			{0, 0, 0, 0}
		},
		
		view_xoffset = 0,
		view_yoffset = 0.5,
		
		srs_table = {
			['12'] = {{ 0,  0}, {-2,  0}, { 1,  0}, {-2, -1}, { 1,  2}},
			['21'] = {{ 0,  0}, { 2,  0}, {-1,  0}, { 2,  1}, {-1, -2}},

			['23'] = {{ 0,  0}, {-1,  0}, { 1,  0}, {-2, -1}, { 1,  2}},
			['32'] = {{ 0,  0}, { 1,  0}, {-1,  0}, { 2,  1}, {-1, -2}},

			['34'] = {{ 0,  0}, { 2,  0}, {-1,  0}, { 2,  1}, {-1, -2}},
			['43'] = {{ 0,  0}, {-2,  0}, { 1,  0}, {-2, -1}, { 1,  2}},

			['41'] = {{ 0,  0}, { 1,  0}, {-2,  0}, { 1, -2}, {-2,  1}},
			['14'] = {{ 0,  0}, {-1,  0}, { 2,  0}, {-1,  2}, { 2, -1}}
		}
	}
	
	return setmetatable(Mino.new(game, base), MinoI)
end


local MinoGarbage = setmetatable({name = 'garbage', color = 'grey-200'}, {__index = Mino})
MinoGarbage.__index = MinoGarbage

function MinoGarbage.new(game, base)
	base = base or {
		name = 'garbage',
		shape = {
			{1}
		},
		
		view_xoffset = 0,
		view_yoffset = 0,
		
		srs_table = {
			['12'] = {{0, 0}},
			['21'] = {{0, 0}},
			['23'] = {{0, 0}},
			['32'] = {{0, 0}},
			['34'] = {{0, 0}},
			['43'] = {{0, 0}},
			['41'] = {{0, 0}},
			['14'] = {{0, 0}}
		}
	}
	
	return setmetatable(Mino.new(game, base), MinoI)
end

local minos = {MinoO, MinoT, MinoJ, MinoL, MinoS, MinoZ, MinoI}
local minos_all = Utils.shallowcopy(minos)
table.insert(minos_all, MinoGarbage)

local mino_by_name = {
	o = MinoO,
	t = MinoT,
	j = MinoJ,
	l = MinoL,
	s = MinoS,
	z = MinoZ,
	i = MinoI,
	garbage = MinoGarbage
}

function get_mino(name)
	return mino_by_name[name]
end

return function() return minos, minos_all, mino_by_name, get_mino end
