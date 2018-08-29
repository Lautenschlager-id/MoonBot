--[[ Discordia ]]--
local discordia = require("discordia")
discordia.extensions()

local client = discordia.Client({
	cacheAllMembers = true
})
client._options.routeDelay = 0

local clock = discordia.Clock()

--[[ Lib ]]--
local http = require("coro-http")
local base64 = require("Content/base64")
local json = require("json")

local splitByChar = function(content, int)
	int = int or 1900

	local data = {}

	if content == "" or content == "\n" then return end

	local current = 0
	while #content > current do
		current = current + (int + 1)
		data[#data + 1] = string.sub(content, current - int, current)
	end

	return data
end
local splitByLine = function(content)
	local data = {}

	if content == "" or content == "\n" then return data end

	local current, tmp = 1, ""
	for line in string.gmatch(content, "([^\n]*)[\n]?") do
		tmp = tmp .. line .. "\n"

		if #tmp > 1850 then
			data[current] = tmp
			tmp = ""
			current = current + 1
		end
	end
	if #tmp > 0 then data[current] = tmp end

	return data
end
local pairsByIndexes = function(list,f)
	local out = {}
	for index in next, list do
		out[#out + 1] = index
	end
	table.sort(out, f)
	
	local i = 0
	return function()
		i = i + 1
		if out[i] == nil then
			return nil
		else
			return out[i], list[out[i]]
		end
	end
end

require("Content/functions")

local forum
do
	local _, openssl = pcall(require, "openssl")
	local sha256 = openssl.digest.get("sha256")
	local toSha256 = function(str)
		local hash = openssl.digest.new(sha256)
		hash:update(str)
		return hash:final()
	end

	local saltBytes = {
		247,	026,	166,	222,	143,	023,	118,
		168,	003,	157,	050,	184,	161,	086,
		178,	169,	062,	221,	067,	157,	197,
		221,	206,	086,	211,	183,	164,	005,
		074,	013,	008,	176
	}

	forum = function()
		local self = { }
		local this = {
			username = "",
			cookies = { },
			getInfo = 0 -- 0 | 1 | 2 = get all cookies, get all cookies after login, do not get JSESSIONID, token, token_date
		}

		self.getKeys = function(self, where)
			local header, body = http.request("GET", "https://atelier801.com/" .. (where or "index"), self.headers(self))

			self.setCookies(self, header)
			return { string.match(body, '<input type="hidden" name="(.-)" value="(.-)">') }
		end

		self.getPage = function(self, pageName)
			local header, body = http.request("GET", "https://atelier801.com/" .. pageName, self.headers(self))
			return body
		end

		self.getPasswordHash = function(self, password)
			local hash = toSha256(password)

			local chars = { }
			for i = 1, #saltBytes do
				chars[i] = string.char(saltBytes[i])
			end

			hash = toSha256(hash .. table.concat(chars))
			local len = #hash

			local out, counter = { }, 0
			for i = 1, len, 2 do
				counter = counter + 1
				out[counter] = string.char(tonumber(string.sub(hash, i, i + 1), 16))
			end

			return base64.encode(table.concat(out))
		end

		self.getUsername = function(self)
			return this.username
		end

		self.headers = function(self)
			return {
				{ "User-Agent", "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36" },
				{ "Cookie", table.fconcat(this.cookies, "; ", function(index, value)
					return index .. "=" .. value
				end) }
			}
		end

		self.isConnected = function(self)
			return self.getUsername(self) ~= ""
		end
		
		self.login = function(self, username, password)
			if self.isConnected(self) then
				print("[ERROR] You are already logged in the account [" .. this.username .. "].")
				return false
			end

			print("[CONNECTION] Connecting to [" .. username .. "]")

			local body = self.page(self, "identification", {
				{ "rester_connecte", "on" },
				{ "id", username },
				{ "pass", self.getPasswordHash(self, password) },
				{ "redirect", "https://atelier801.com" }
			}, "login")

			if string.sub(body, 2, 15) == '"supprime":"*"' then
				this.username = username
				print("[CONNECTION] Connected to [" .. username .. "]")
				this.getInfo = 1
				return true, body
			else
				print("[CONNECTION] Error trying to log in [" .. username .. "]")
				return false, body
			end
		end

		self.logout = function(self)
			if not self.isConnected(self) then
				print("[ERROR] You are not logged.")
				return false
			end

			print("[CONNECTION] Disconnecting from [" .. this.username .. "]")

			local body = self.page(self, "deconnexion")

			if string.sub(body, 3, 13) == 'redirection' then
				print("[CONNECTION] Disconnected from [" .. this.username .. "]")
				this.username = ""
				this.cookies = { }
				this.getInfo = 0
				return true, body
			else
				print("[CONNECTION] Error trying to disconnect from [" .. this.username .. "]")
				return false, body
			end
		end

		self.page = function(self, pageName, postData, ajax, keyLocation)
			local keys = self.getKeys(self, keyLocation or ajax)

			local headers = self.headers(self)
			if ajax then
				headers[3] = { "Accept", "application/json, text/javascript, */*; q=0.01" }
				headers[4] = { "Accept-Language", "en-US,en;q=0.9" }
				headers[5] = { "X-Requested-With", "XMLHttpRequest" }
				headers[6] = { "Content-Type", "application/x-www-form-urlencoded; charset=UTF-8" }
				headers[7] = { "Referer", "https://atelier801.com/" .. ajax }
				headers[8] = { "Connection", "keep-alive" }
			end

			postData = postData or { }
			postData[#postData + 1] = keys

			local header, body = http.request("POST", "https://atelier801.com/" .. pageName, headers, table.fconcat(postData, '&', function(index, value)
				return value[1] .. "=" .. encodeUrl(value[2])
			end))

			self.setCookies(self, header)

			return body
		end

		self.sendPrivateMessage = function(self, to, subject, message)
			local body = self.page(self, "create-dialog", {
				{ "destinataire", to },
				{ "objet", subject },
				{ "message", message }
			}, "new-dialog")

			return body
		end
		
		self.setCookies = function(self, header)
			for i = 1, #header do
				if header[i][1] == "Set-Cookie" then
					local cookie = header[i][2]
					cookie = string.sub(cookie, 1, string.find(cookie, ';') - 1)

					local eq = string.find(cookie, '=')
					local cookieName = string.sub(cookie, 1, eq - 1)

					
					if this.getInfo < 2 or (cookieName ~= "JSESSIONID" and cookieName ~= "token" and cookieName ~= "token_date") then
						this.cookies[cookieName] = string.sub(cookie, eq + 1)
					end
				end
			end
			if this.getInfo == 1 then
				this.getInfo = 2
			end
		end

		return self
	end
end

--[[ System ]]--
math.randomseed(os.time())
local forumClient

local commands = { }
local account = {
	username = os.readFile("Info/Forum/username", "*l"),
	password = os.readFile("Info/Forum/password", "*l")
}
local messages = {
	terms = os.readFile("Info/Others/terms", "*a"),
	rejected = os.readFile("Info/Others/reject", "*a")
}
local section = os.readFile("Info/Forum/section", "*l")
local ajaxList = os.readFile("Info/Forum/members", "*l")

local channels = {
	guild = os.readFile("Info/Channel/guild", "*l"),
	modules = os.readFile("Info/Channel/modules", "*l"),
	apps = os.readFile("Info/Channel/applications", "*l"),
	flood = os.readFile("Info/Channel/flood", "*l"),
}
local roles = {
	dev = os.readFile("Info/Role/dev", "*l"),
	helper = os.readFile("Info/Role/helper", "*l"),	
}

local botNames = { "Jerry", "ModuleAPI", "MoonAPI", "Moon", "FroggyJerry", "MoonForMice", "MoonduleAPI", "MoonBot", "ModuleBot", "JerryForMice", "JerryForMoon", "MoonPie" }
local botAvatars = { }
local botStatus = {
	{ "online", { "I'm ready!", "Yoohoo", "LUA or Phyton, that's the question", ":jerry:", "Ping @Pikashu", "Atelier801 Forums" } },
	{ "idle", { "Waiting Pikashu to update the API", "Waiting my Java application to compile", "Pong @Streaxx", "Editing TFM API", "Checking the moon" } },
	{ "dnd", { "Taking shower BRB", "I am stressed, do /moon", "My disk is almost full", "Reading applications", "Marriage proposal to Sharpiebot" } }
}

local reactions = {
	Y = "\xE2\x9C\x85",
	N = "\xE2\x9D\x8C"
}

local color = {
	error = 0x488372,
	fail = 0x9C3AAF,
	success = 0xCC0000,
	info = 0x3391B1
}

local toDelete = setmetatable({}, {
	__newindex = function(list, index, value)
		if value then
			if value.channel then value = { value } end

			value = table.map(value, function(l) return l.id end)
			rawset(list, index, value)
		end
	end
})

local hasPermission = function(member, roleId)
	return not not member.roles:find(function(role)
		return role.id == roleId
	end)
end

local moonPhase = function()
	-- http://jivebay.com/calculating-the-moon-phase/
	local day, month, year = tonumber(os.date("%d")), tonumber(os.date("%m")), tonumber(os.date("%Y"))

	if month < 3 then
		year = year - 1
		month = month + 12
	end
	month = month + 1

	local Y = 365.25 * year
	local M = 30.6 * month
	local daysElapsed = (Y + M + day - 694039.09) / 29.5305882
	daysElapsed = math.floor(((daysElapsed % 1) * 8) + .5)

	if daysElapsed >= 8 then daysElapsed = 0 end
	return daysElapsed + 1 -- [ 1 : 8 ]
end

--[[ Forum ]]--
local normalizePlayerName = function(playerName)
	if not string.find(playerName, '#') then
		playerName = playerName .. "#0000"
	end

	return (string.gsub(string.lower(playerName), "%a", string.upper, 1))
end

local normalizeDiscriminator = function(discriminator)
	return discriminator == "#0000" and "" or "`" .. discriminator .. "`"
end

local playerExists = function(playerName)
	playerName = normalizePlayerName(playerName)

	local header, body = http.request("GET", "https://atelier801.com/profile?pr=" .. encodeUrl(playerName))
	return not string.find(body, 'La requête contient un ou plusieurs paramètres invalides.'), playerName
end

local applicationExists = function(playerName)
	return not not string.find(forumClient:getPage(section), "%[MODULE%] " .. playerName)
end

local htmlToMarkdown = function(str)
	str = string.gsub(str, "&#(%d+)", function(dec) return string.char(dec) end)
	str = string.gsub(str, '<span style="(.-);">(.-)</span>', function(x, content)
		local markdown = ""
		if x == "font-weight:bold" then
			markdown = "**"
		elseif x == "font-style:italic" then
			markdown = '_'
		elseif x == "text-decoration:underline" then
			markdown = "__"
		elseif x == "text-decoration:line-through" then
			markdown = '~'
		end
		return markdown .. content .. markdown
	end)
	str = string.gsub(str, '<p style="text-align:.-;">(.-)</p>', "%1")
	str = string.gsub(str, '<blockquote.-><div>(.-)</div></blockquote>', function(content)
		return "`" .. (#content > 50 and string.sub(content, 1, 50) .. "..." or content) .. "`"
	end)
	str = string.gsub(str, '<a href="(.-)".->(.-)</a>', "[%2](%1)")
	str = string.gsub(str, "<br />", "\n")
	str = string.gsub(str, "&gt;", '>')
	str = string.gsub(str, "&lt;", '<')
	str = string.gsub(str, "&quot;", "\"")
	str = string.gsub(str, "&laquo;", '«')
	str = string.gsub(str, "&raquo;", '»')
	return str
end

local removeHtmlFormat = function(str)
	str = string.gsub(str, "&#(%d+)", function(dec) return string.char(dec) end)
	str = string.gsub(str, '<span style=".-;">(.-)</span>', "%1")
	str = string.gsub(str, '<p style="text-align:.-;">(.-)</p>', "%1")
	str = string.gsub(str, '<blockquote.-><small>(.-)</small></blockquote>', function(content)
		return "[" .. (#content > 10 and string.sub(content, 1, 10) .. "..." or content) .. "]"
	end)
	str = string.gsub(str, '<div class="cadre cadre%-code"><div class="indication%-langage%-code">(.-)</div><hr/>.-<pre .-</pre></div></div>', function(lang)
		return "'" .. lang .. "' => ..."
	end)
	str = string.gsub(str, '<div class="cadre cadre%-code">.-<pre .-</pre></div></div>', function()
		return "'Lua code' detected => ..."
	end)
	str = string.gsub(str, '<a href="(.-)".->(.-)</a>', "[%2](%1)")
	str = string.gsub(str, "<br />", "\n")
	str = string.gsub(str, "&gt;", '>')
	str = string.gsub(str, "&lt;", '<')
	str = string.gsub(str, "&quot;", "\"")
	str = string.gsub(str, "&laquo;", '«')
	str = string.gsub(str, "&raquo;", '»')
	str = string.gsub(str, '`', '´') -- Avoid breaking blocks on discord
	return str
end

--[[ Commands ]]--
local hasParam = function(message, parameters)
	if not parameters or #parameters == 0 then
		toDelete[message.id] = message:reply({
			content = "<@!" .. message.author.id .. ">",
			embed = {
				color = color.fail,
				title = "<:wheel:456198795768889344> Missing parameters.",
				description = "Type **!help command** to read its description and syntax."
			}
		})
		return false
	end
	return true
end

local alias = {
	-- alias, cmd
	["accept"] = "terms",
	["applications"] = "apps",
	["deny"] = "reject",
	['m'] = "members"	
}

-- description => Description of the command, appears in !help
-- syntax => Command syntax
-- connection => Whether the command uses the forum client connection or not, do not execute until the client is connected
-- highlevel => Whether the command works only for helpers or not
-- fn(msg, param) => The function
commands["adoc"] = {
	description = "Gets information about a specific tfm api function.",
	syntax = "!adoc function_name",
	fn = function(message, parameters)
		if parameters and #parameters > 0 then
			local head, body = http.request("GET", "https://atelier801.com/topic?f=826122&t=924910")

			if body then
				body = string.gsub(string.gsub(body, "<br />", "\n"), " ", "")
				local _, init = string.find(body, "id=\"message_19463601\">•")
				body = string.sub(body, init)

				local syntax, description = string.match(body, "•  (" .. parameters .. " .-)\n(.-)\n\n\n\n")

				if syntax then
					description = string.gsub(description, "&sect;", "§")
					description = string.gsub(description, "&middot;", ".")
					description = string.gsub(description, "&gt;", ">")
					description = string.gsub(description, "&lt;", "<")
					description = string.gsub(description, "&quot;", "\"")
					description = string.gsub(description, "&#(%d+)", function(dec) return string.char(dec) end)

					local info = {
						desc = { },
						param = { },
						ret = nil
					}

					for line in string.gmatch(description, "[^\n]+") do
						if not string.find(line, "^Parameters") and not string.find(line, "^Arguments") then
							local i, e = string.find(line, "^[%-~] ")
							if i then
								local param = string.sub(line, e + 1)

								local list, desc = string.match(param, "(.-) ?: (.+)")

								if list then
									local params = { }
									for name, type in string.gmatch(list, "(%w+) %((.-)%)") do
										params[#params + 1] = "`" .. type .. "` **" .. name .. "**"
									end

									if #params > 0 and desc then
										param = table.concat(params, ", ") .. " ~> " .. desc
									end
								end

								info.param[#info.param + 1] = (string.sub(line, 1, 1) == "~" and "- " or "") .. param
							else
								i, e = string.find(line, "^Returns: ")
								if i then
									local param = string.sub(line, e + 1)
									local type, desc = string.match(param, "^%((.-)%) (.+)")

									if type then
										param = "`" .. type .. "` : " .. desc
									end

									info.ret = param
								else
									info.desc[#info.desc + 1] = line
								end
							end
						end
					end

					toDelete[message.id] = message:reply({
						content = "<@!" .. message.author.id .. ">",
						embed = {
							color = color.info,
							title = "<:atelier:458403092417740824> " .. syntax,
							description = table.concat(info.desc, "\n") .. (#info.param > 0 and ("\n\n**Arguments / Parameters**\n" .. table.concat(info.param, "\n")) or "") .. (info.ret and ("\n\n**Returns**\n" .. info.ret) or ""),
							footer = { text = "TFM API Documentation" },
						}
					})
				else
					toDelete[message.id] = message:reply({
						content = "<@!" .. message.author.id .. ">",
						embed = {
							color = color.info,
							title = "<:atelier:458403092417740824> TFM API Documentation",
							description = "The function **" .. parameters .. "** was not found in the documentation."
						}
					})
				end
			end
		end
	end
}
commands["apps"] = {
	description = "Counts the current number of applications and gives an approximate counter of votes.",
	connection = true,
	fn = function(message)
		local body = forumClient:getPage(section)

		local applications, counter = { }, 0
		string.gsub(body, 'href="((topic%?f=6&t=%d+)&p=1#m%d+)"> +%[MODULE%] +(.-) +</a>', function(current_url, init_url, playerName)
			counter = counter + 1
			applications[counter] = { current_url, init_url, playerName }
		end)
		
		counter = 0
		local list = { }
		local new, yeses, nos, unknowns

		for application = 1, #applications do
			local topic = forumClient:getPage(applications[application][2])

			new, yeses, nos, unknowns = false, 0, 0, 0
			if topic then
				if string.find(applications[application][1], "m1$") then new = true end -- 1 comment

				local first = true
				string.gsub(topic, '<div id="message_%d+">(.-)</div>', function(comment)
					if first then
						first = false
					else
						comment = " " .. string.lower(comment) .. " "
						local yes = string.find(comment, "[%W]yes[%W]")
						local no = string.find(comment, "[%W]no[%W]")

						if yes and not no then
							yeses = yeses + 1
						elseif no and not yes then
							nos = nos + 1
						else
							unknowns = unknowns + 1
						end
					end
				end)
			end

			counter = counter + 1
			list[counter] = {
				url = applications[application][2],
				playerName = applications[application][3],
				y = yeses,
				n = nos,
				unkn = unknowns,
				isNew = new
			}
		end

		if #list == 0 then
			toDelete[message.id] = message:reply({
				embed = {
					color = color.info,
					title = "<:atelier:458403092417740824>  Applications",
					description = "There are not applications. :("
				}
			})
		else
			-- Split list by line because it may be bigger than 2000 characters
			local lines = splitByLine(table.fconcat(list, "\n", function(index, value)
				local votes = {
					value.y > 0 and ("**" .. value.y .. "** Yes" .. (value.y > 1 and "es" or "")) or nil,
					value.n > 0 and ("**" .. value.n .. "** No" .. (value.n > 1 and "s" or "")) or nil,
					value.unkn > 0 and ("**" .. value.unkn .. "** Unknown" .. (value.unkn > 1 and "s" or "")) or nil
				}

				local res, counter = { }, 0
				for i = 1, 3 do
					if votes[i] then
						counter = counter + 1
						res[counter] = votes[i]
					end
				end

				return (value.isNew and "`NEW` " or "") .. ":envelope: [**" .. value.playerName .. "**](https://atelier801.com/" .. value.url .. ") " .. (#res > 0 and ("≈ " .. table.concat(res, " | ") .. (value.n > 2 and " - :x:" or value.y > 6 and " - :white_check_mark:" or "")) or "")
			end))

			local msgs = { }
			for line = 1, #lines do
				msgs[line] = message:reply({
					content = "__Yes and No votes are approximated!\nDo not judge before checking the application.__",
					embed = {
						color = color.info,
						title = (line == 1 and "<:atelier:458403092417740824> Applications [" .. #list .. "]" or nil),
						description = lines[line],
						timestamp = string.gsub(message.timestamp, " ", "") -- gsub avoid Discordia glitches
					}
				})
			end

			toDelete[message.id] = msgs
		end
	end
}
commands["doc"] = {
	description = "Gets information about a specific lua function.",
	syntax = "!doc function_name",
	fn = function(message, parameters)
		if parameters and #parameters > 0 then
			local head, body = http.request("GET", "http://www.lua.org/work/doc/manual.html")

			if body then
				local syntax, description = string.match(body, "<a name=\"pdf%-" .. parameters .. "\"><code>(.-)</code></a></h3>[\n<p>]*(.-)<hr>")

				if syntax then
					-- Normalizing tags
					syntax = string.gsub(syntax, "&middot;", ".")

					description = string.gsub(description, "<b>(.-)</b>", "**%1**")
					description = string.gsub(description, "<em>(.-)</em>", "_%1_")
					description = string.gsub(description, "<li>(.-)</li>", "\n- %1")

					description = string.gsub(description, "<code>(.-)</code>", "`%1`")
					description = string.gsub(description, "<pre>(.-)</pre>", function(code)
						return "```LUA¨" .. (string.gsub(string.gsub(code, "\n", "¨"), "¨     ", "¨")) .. "```"
					end)

					description = string.gsub(description, "&sect;", "§")
					description = string.gsub(description, "&middot;", ".")
					description = string.gsub(description, "&nbsp;", " ")
					description = string.gsub(description, "&gt;", ">")
					description = string.gsub(description, "&lt;", "<")

					description = string.gsub(description, "<a href=\"(#.-)\">(.-)</a>", "[%2](https://www.lua.org/manual/5.2/manual.html%1)")

					description = string.gsub(description, "\n", " ")
					description = string.gsub(description, "¨", "\n")
					description = string.gsub(description, "<p>", "\n\n")

					description = string.gsub(description, "<(.-)>(.-)</%1>", "%2")

					local lines = splitByChar(description)

					local toRem = { }
					for i = 1, #lines do
						toRem[i] = message:reply({
							content = (i == 1 and "<@!" .. message.author.id .. ">" or nil),
							embed = {
								color = color.info,
								title = (i == 1 and ("<:lua:483421987499147292> " .. syntax) or nil),
								description = lines[i],
								footer = { text = "Lua Documentation" }
							}
						})
					end
					toDelete[message.id] = toRem
				else
					toDelete[message.id] = message:reply({
						content = "<@!" .. message.author.id .. ">",
						embed = {
							color = color.info,
							title = "<:lua:483421987499147292> Lua Documentation",
							description = "The function **" .. parameters .. "** was not found in the documentation."
						}
					})
				end
			end
		end
	end
}
commands["help"] = {
	description = "Displays the help message.",
	syntax = "!help or !help command",
	fn = function(message, parameters)
		if parameters and #parameters > 0 then
			parameters = string.lower(parameters)
			
			parameters = alias[parameters] or parameters
			if commands[parameters] then
				local aliases, counter = { }, 0
				for ali, cmd in next, alias do
					if cmd == parameters then
						counter = counter + 1
						aliases[counter] = ali
					end
				end

				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.info,
						title = ":loudspeaker: Help ~> '!" .. parameters .. "'",
						description = "**Must be connected on forums:** " .. string.upper(tostring(not not commands[parameters].connection)) .. "\n**Helper command:** " .. string.upper(tostring(not not commands[parameters].highlevel)) .. "\n\n**Description:** " .. commands[parameters].description .. (commands[parameters].syntax and ("\n\n**Syntax:** " .. commands[parameters].syntax) or "") .. (#aliases > 0 and ("\n\n**Aliases:** _!" .. table.concat(aliases, "_ , _!") .. "_") or "")
					}
				})
			else
				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.fail,
						title = ":loudspeaker: Help",
						description = "The command **!" .. parameters .. "** doesn't exist!"
					}
				})
			end
		else
			toDelete[message.id] = message:reply({
				content = "<@!" .. message.author.id .. ">",
				embed = {
					color = color.info,
					title = ":loudspeaker: General help",
					description = table.fconcat(commands, "\n", function(index, value)
						return ":small_" .. (value.highlevel and "orange" or "blue") .. "_diamond: **!" .. index .. "** - " .. value.description
					end, nil, nil, pairsByIndexes)
				}
			})
		end
	end
}
commands["members"] = {
	description = "Lists the module team members.",
	syntax = "!members [pattern]",
	connection = true,
	fn = function(message, parameters)
		local body = forumClient:getPage(ajaxList)

		if parameters then
			local _, err = pcall(string.find, body, parameters)
			if err then
				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.fail,
						title = "<:atelier:458403092417740824> Invalid pattern in '!members'.",
						description = "```\n" .. err .. "```"
					}
				})
				return
			end
		end
		
		local list, counter = { }, 0
		string.gsub(body, '(%S+)<span class="font%-s couleur%-hashtag%-pseudo"> (#%d+)</span>', function(nickname, discriminator)
			nickname = nickname .. discriminator

			if (not parameters or parameters == "") or string.find(nickname .. discriminator, parameters) then
				counter = counter + 1
				list[counter] = (string.gsub(nickname, discriminator, normalizeDiscriminator))
			end
		end)

		if #list == 0 then
			toDelete[message.id] = message:reply({
				content = "<@!" .. message.author.id .. ">",
				embed = {
					color = color.info,
					title = "<:lua:483421987499147292> Module Team Members",
					description = "There are not members with that pattern. :("
				}
			})
		else
			table.sort(list, function(m1, m2)
				return m1 < m2
			end)
			toDelete[message.id] = message:reply({
				content = "<@!" .. message.author.id .. ">",
				embed = {
					color = color.info,
					title = "<:lua:483421987499147292> Module Team Members [" .. #list .. "]",
					description = ":small_blue_diamond:" .. table.concat(list, "\n:small_blue_diamond:")
				}
			})
		end
	end
}
commands["quote"] = {
	description = "Quotes a message.",
	syntax = "!quote [channel_id-]message_id",
	fn = function(message, parameters)
		if not hasParam(message, parameters) then return end

		local quotedMessage, quotedChannel = string.match(parameters, "(%d+)%-(%d+)")
		quotedMessage = quotedMessage or string.match(parameters, "%d+")

		if quotedMessage then
			local msg = client:getChannel(quotedChannel or message.channel)
			if msg then
				msg = msg:getMessage(quotedMessage)

				if msg then
					message:delete()

					local memberName = message.guild:getMember(msg.author.id)
					memberName = memberName and memberName.name or msg.author.fullname

					local embed = {
						author = {
							name = memberName,
							icon_url = msg.author.avatarURL
						},
						description = (msg.embed and msg.embed.description) or msg.content,

						footer = {
							text = "In #" .. msg.channel.name
						},
						timestamp = string.gsub(msg.timestamp, " ", ""),
					}

					local img = (msg.attachment and msg.attachment.url) or (msg.embed and msg.embed.image and msg.embed.image.url)
					if img then embed.image = { url = img } end

					message:reply({ content = "_Quote from **" .. (message.member or message.author).name .. "**_", embed = embed })
				end
			end
		end
	end
}
commands["reject"] = {
	description = "Messages a player to inform their application got rejected.",
	syntax = "!reject PlayerName#0000",
	connection = true,
	highlevel = true,
	fn = function(message, parameters)
		if not hasParam(message, parameters) then return end

		local exists, playerName = playerExists(parameters)
		if not exists then
			toDelete[message.id] = message:reply({
				content = "<@!" .. message.author.id .. ">",
				embed = {
					color = color.fail,
					title = "<:atelier:458403092417740824> Invalid user.",
					description = "The player **" .. playerName .. "** doesn't exist."
				}
			})
			return
		end

		local hasApplication = applicationExists(playerName)
		local msg = message:reply({
			content = "<@!" .. message.author.id .. "> | 0",
			embed = {
				color = color.info,
				title = "<:atelier:458403092417740824> Confirmation",
				description = "You are about to send the rejection message to the player **" .. playerName .. "**.\n" .. (hasApplication and "" or ":warning: | There is not an application for this player\n") .. "\nContinue?"
			}
		})

		msg:addReaction(reactions.Y)
		msg:addReaction(reactions.N)

		toDelete[message.id] = msg
	end
}
commands["terms"] = {
	description = "Messages a player to inform their application got accepted.",
	syntax = "!terms PlayerName#0000",
	connection = true,
	highlevel = true,
	fn = function(message, parameters)
		if not hasParam(message, parameters) then return end

		local exists, playerName = playerExists(parameters)
		if not exists then
			toDelete[message.id] = message:reply({
				content = "<@!" .. message.author.id .. ">",
				embed = {
					color = color.fail,
					title = "<:atelier:458403092417740824> Invalid user.",
					description = "The player **" .. playerName .. "** doesn't exist."
				}
			})
			return
		end

		local hasApplication = applicationExists(playerName)
		local msg = message:reply({
			content = "<@!" .. message.author.id .. "> | 1",
			embed = {
				color = color.info,
				title = "<:atelier:458403092417740824> Confirmation",
				description = "You are about to send the terms to the player **" .. playerName .. "**.\n" .. (hasApplication and "" or ":warning: | There is not an application for this player\n") .. "\nContinue?"
			}
		})

		msg:addReaction(reactions.Y)
		msg:addReaction(reactions.N)

		toDelete[message.id] = msg
	end
}

--[[ Events ]]--
client:on("ready", function()
	forumClient = forum()

	forumClient:login(account.username, account.password)

	local moons = io.open("Info/Others/avatar", 'r')
	local counter = 0
	for avatar in moons:lines() do
		counter = counter + 1
		botAvatars[counter] = avatar
	end
	moons:close()

	clock:start()
end)

local messageCreate = function(message)
	-- Skips bot messages
	if message.author.bot then return end

	-- Doesn't allow private messages
	if message.channel.type == 1 then return end

	-- Doesn't allow to speak in #announcements
	if message.channel.id == "190849892158013440" then return end

	-- Doesn't allow to speak in another guild (except the one that hosts the bot emojis and stuff)
	if message.guild.id ~= "190844663660412928" and message.guild.id ~= "399730169000230923" then
		return client:leave()
	end

	-- Detect command and parameters
	local command, parameters = string.match(message.content, "^!(.-)[\n ]+(.*)")
	command = command or string.match(message.content, "^!(.+)")

	if not command then return end

	command = string.lower(command)
	parameters = (parameters and parameters ~= "") and string.trim(parameters) or nil

	-- Function call
	command = alias[command] or command
	if commands[command] then
		if not hasPermission(message.member, (commands[command].highlevel and roles.helper or roles.dev)) then
			toDelete[message.id] = message:reply({
				content = "<@!" .. message.author.id .. ">",
				embed = {
					color = color.fail,
					title = "Authorization denied.",
					description = "You do not have access to the command **!" .. command .. "**!"
				}
			})
			return
		end
		
		if commands[command].connection then
			if not forumClient or not forumClient:isConnected() then
				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.error,
						title = "Forum account not connected yet. Try again later."
					}
				})
				return
			end
		end

		local success, err = pcall(commands[command].fn, message, parameters)

		if not success then
			toDelete[message.id] = message:reply({
				embed = {
					color = color.error,
					title = "Command [" .. string.upper(command) .. "] => Fatal Error!",
					description = "```\n" .. err .. "```"
				}
			})
		end
	end
end
local messageDelete = function(message)
	if toDelete[message.id] then
		local msg
		for id = 1, #toDelete[message.id] do
			msg = message.channel:getMessage(toDelete[message.id][id])
			if msg then
				msg:delete()
			end
		end

		toDelete[message.id] = nil
	end
end

local reactionAdd = function(cached, channel, messageId, emojiName, userId)
	if userId == client.user.id then return end

	local message = channel:getMessage(messageId)
	if message.author.id == client.user.id then
		if not forumClient:isConnected() then
			message:removeReaction(emojiName, userId)
			return
		end
	
		if message.embed then
			local confirmation = string.find(message.embed.title or "", "Confirmation")
			if confirmation then
				local user, state = string.match(message.content, "^<@!?(%d+)> | ([01])$")
				if user ~= userId then return end
				
				local member = message.guild:getMember(user)
				if member then
					if emojiName == reactions.Y then
						toDelete[messageId] = nil -- So it doesn't delete the confirmation message if the member deletes his message

						local playerName = string.match(message.embed.description, "%*%*(.-)%*%*")

						local desc = "<:atelier:458403092417740824> <@!" .. user .. "> (`" .. member.name .. "`) "

						message:clearReactions()
						message:setContent("")

						local timestamp = discordia.Date():toISO()

						local msg = "rejected"
						if state == '0' then
							message:setEmbed({
								color = color.success,
								description = desc .. "rejected the player **" .. playerName .. "**.",
								timestamp = timestamp
							})
						elseif state == '1' then
							msg = "terms"
							message:setEmbed({
								color = color.success,
								description = desc .. "sent the terms to the player **" .. playerName .. "**.",
								timestamp = timestamp
							})
						end

						forumClient:sendPrivateMessage(playerName, "Module Team Application", string.format(messages[msg], playerName))
					elseif emojiName == reactions.N then
						message:delete()
					end
				end
			end
		end
	end
end

client:on("messageCreate", function(message)
	local success, err = pcall(messageCreate, message)
	if not success then
		toDelete[message.id] = message:reply({
			embed = {
				color = color.error,
				title = "evt@MessageCreate => Fatal Error!",
				description = "```\n" .. err .. "```"
			}
		})
	end
end)
client:on("messageDelete", function(message)
	local success, err = pcall(messageDelete, message)
	if not success then
		message:reply({
			embed = {
				color = color.error,
				title = "evt@MessageDelete => Fatal Error!",
				description = "```\n" .. err .. "```"
			}
		})
	end
end)

client:on("reactionAddUncached", function(channel, messageId, emojiName, userId)
	local success, err = pcall(reactionAdd, true, channel, messageId, emojiName, userId)
	if not success then
		toDelete[messageId] = channel:send({
			embed = {
				color = color.error,
				title = "evt@ReactionAddU => Fatal Error!",
				description = "```\n" .. err .. "```"
			}
		})
	end
end)
client:on("reactionAdd", function(reaction, userId)
	-- Parameters are normalized to both Uncached and Cached messages trigger reactionAdd correctly
	local success, err = pcall(reactionAdd, false, reaction.message.channel, reaction.message.id, reaction.emojiName, userId)
	if not success then
		toDelete[reaction.message.id] = reaction.message:reply({
			embed = {
				color = color.error,
				title = "evt@ReactionAdd => Fatal Error!",
				description = "```\n" .. err .. "```"
			}
		})
	end
end)

local minutes = 0
local clockMin = function()
	minutes = minutes + 1

	if not forumClient:isConnected() then -- reconnection
		forumClient:login(account.username, account.password)
	end

	if minutes % 30 == 0 then
		local newStatus = table.random(botStatus)
		client:setStatus(newStatus[1])
		client:setGame(table.random(newStatus[2]))

		 -- check new pms and answers
		local body = forumClient:getPage("conversations")

		local toCheck, counter = { }, 0
		string.gsub(body, 'img18 espace%-2%-2" />  (.-) </a>.-nombre%-messages%-(.-)" href="(.-)">(%d+)<', function(title, messageState, url, totalReplies)
			if messageState == "reponses" or messageState == "nouveau" then
				local final = string.find(url, "&p")
				local link = string.sub(url, 1, (final or 0) - 1)

				if not topicState == "nouveau" then -- new msg must be #1
					link = link .. "&p=1#m" .. totalReplies
				end

				local checkedReplies = final and tonumber(string.sub(url, final + 6)) or 0
				counter = counter + 1

				toCheck[counter] = { title, messageState == "nouveau", link, totalReplies - (totalReplies - checkedReplies) + 1, totalReplies }
			end
		end)

		if #toCheck > 0 then
			local channel = client:getChannel(channels.modules) -- #modules
			for topic = 1, #toCheck do
				local message = forumClient:getPage(toCheck[topic][3])

				counter = 0
				local replies = { }
				for reply = toCheck[topic][4], toCheck[topic][5] do
					local author, discriminator = string.match(message, '<div id="m' .. reply ..'".-alt="">   (%S+)<br/>.-(#%d+)</span>')
					author = author .. discriminator

					if author ~= account.username then -- Won't notify bot messages
						local text = string.match(message, '>    #' .. reply .. '   </a>    </td> </tr> <tr> .- <div id="message_%d+">(.-)</div> </div>  </div> </td>')

						counter = counter + 1
						replies[counter + 1] = { string.sub(removeHtmlFormat(text), 1, 100), normalizeDiscriminator(normalizePlayerName(author)) }
					end
				end

				channel:send({
					embed = {
						color = color.info,
						title = (toCheck[topic][2] and ":envelope_with_arrow:" or ":mailbox_with_mail:") .. " " .. toCheck[topic][1],
						description = "[View conversation](https://atelier801.com/" .. toCheck[topic][3] .. ")\n" .. string.sub(table.fconcat(replies, "\n", function(index, value)
							return "> " .. value[2] .. " ```\n" .. value[1] .. "```"
						end), 1, 1900),
						timestamp = discordia.Date():toISO()
					}
				})
			end
		end
	end
end
local clockHour = function()
	-- Change name once per day
	if os.date("%H") == "00" then
		client:getGuild(channels.guild):getMember(client.user.id):setNickname(table.random(botNames))
		client:setAvatar(botAvatars[moonPhase()])
	end

	if forumClient:isConnected() then -- new apps and comments
		local body = forumClient:getPage(section)

		local newApplications, topics, counter, toCheck = { }, { }, 0, { }
		string.gsub(body, 'href="(%S+)"> +%[MODULE%] +(.-) +</a>.-messages%-(.-)".->(%d+)</a>', function(url, playerName, topicState, totalComments)
			if topicState == "reponses" or topicState == "nouveau" then
				local final = string.find(url, "&p")
				local link = string.sub(url, 1, (final or 0) - 1)

				if not topicState == "nouveau" then -- new app must be #1
					link = link .. "&p=1#m" .. totalComments
				end

				counter = counter + 1
				toCheck[counter] = link

				local bar = {
					[1] = "https://atelier801.com/" .. link,
					[2] = playerName
				}
				if topicState == "reponses" then
					local checkedComments = final and tonumber(string.sub(url, final + 6)) or 0
					bar[3] = totalComments - checkedComments
					topics[#topics + 1] = bar
				elseif topicState == "nouveau" then
					newApplications[#newApplications + 1] = bar
				end
			end
		end)

		if #topics > 0 then
			client:getChannel(channels.modules):send({ -- #modules
				embed = {
					color = color.info,
					title = "<:atelier:458403092417740824> New comments in applications!",
					description = table.fconcat(topics, "\n", function(index, value)
						return ":eye: [**" .. value[2] .. "**](" .. value[1] .. ") - **" .. value[3] .. "** new comment" .. (value[3] > 1 and "s" or "") .. "."
					end),
					timestamp = discordia.Date():toISO()
				}
			})
		end
		if #newApplications > 0 then
				local announcements = client:getChannel(channels.apps) -- #applications
				for application = 1, #newApplications do
					announcements:send({
						embed = {
							color = color.info,
							title = "<:atelier:458403092417740824> New application",
							description = ":eye: [**" .. newApplications[application][2] .. "**](" .. newApplications[application][1] .. ")",
							timestamp = discordia.Date():toISO()
						}
					})
				end
			end
		if #toCheck > 0 then
			for page = 1, #toCheck do
				forumClient:getPage(toCheck[page])
			end
		end
	end
end

clock:on("min", function()
	local success, err = pcall(clockMin)
	if not success then
		client:getChannel(channels.flood):send({ -- #flood channel
			embed = {
				color = color.error,
				title = "clock@Minute => Fatal Error!",
				description = "```\n" .. err .. "```"
			}
		})
	end
end)
clock:on("hour", function()
	local success, err = pcall(clockHour)
	if not success then
		client:getChannel(channels.flood):send({ -- #flood channel
			embed = {
				color = color.error,
				title = "clock@Hour => Fatal Error!",
				description = "```\n" .. err .. "```"
			}
		})
	end
end)

client:run(os.readFile("Info/Settings/token", "*l"))