math.randomseed(os.time())

local Utils = {}
function Utils.transpose(matrix)
	local rotated = {}
	for y, first_col_x in ipairs(matrix[1]) do
		local col = {first_col_x}
		
		for x = 2, #matrix do
			col[x] = matrix[x][y]
		end
		
		table.insert(rotated, col)
	end
	
	return rotated
end

function Utils.reverse_row(matrix)
	local reversed = {}
	
	for y = #matrix, 1, -1 do
		reversed[#matrix - y + 1] = matrix[y]
	end
	
	return reversed
end

function Utils.rotate_cw(matrix)
	return Utils.reverse_row(Utils.transpose(matrix))
end

function Utils.random_id()
	return math.random()
end

function Utils.includes(tab, val)
	for index, value in ipairs(tab) do
		if value == val then
			return true
		end
	end

	return false
end

function Utils.shuffle(tab)
	for i = #tab, 2, -1 do
		local j = math.random(i)
		tab[i], tab[j] = tab[j], tab[i]
	end
	return tab
end

function Utils.dump(o)
	if type(o) ~= 'table' then
		return tostring(o)
	end
	
	local s = '{ '
	for k,v in pairs(o) do
		if type(k) ~= 'number' then k = '"'..k..'"' end
		s = s .. '['..k..'] = ' .. Utils.dump(v) .. ','
	end
	return s .. '} '
end


function Utils.shallowcopy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end

return Utils
