do
	local toHex = function(c)
		return string.format("%%%02X", string.byte(c))
	end

	encodeUrl = function(url)
		if not url then return "" end -- assert(url, "[Encode] Invalid url.")

		url = string.gsub(url, "([^%w ])", toHex)
		url = string.gsub(url, " ", "+")
		return url
	end
end

os.readFile = function(file, format)
	file = io.open(file, "r")
	
	format = format or "*a"
	local out = file:read(format)
	file:close()		
	
	return out
end

table.fconcat = function(tbl, sep, f, i, j, iter)
	local out = {}

	sep = sep or ""

	i, j = (i or 1), (j or #tbl)

	local counter = 1
	for k, v in (iter or pairs)(tbl) do
		if type(k) ~= "number" or (k >= i and k <= j) then
			if f then
				out[counter] = f(k, v)
			else
				out[counter] = tostring(v)
			end
			counter = counter + 1
		end
	end

	return table.concat(out, sep)
end

table.map = function(list, f)
	local out = {}
	
	for k, v in next, list do
		out[k] = f(v)
	end
	
	return out
end

table.random = function(list)
	return list[math.random(#list)]
end
