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
local timer = require("timer")

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
		if out[i] ~= nil then
			return out[i], list[out[i]]
		end
	end
end

require("Content/functions")

--[[ System ]]--
local owners = {
	["285878295759814656"] = true, -- Bolo
	["162919786358112256"] = true, -- Jordy
}

math.randomseed(os.time())
local forumClient

local commands = { }
local boundaries = { }
local account = {
	username = os.readFile("Info/Forum/username", "*l"),
	password = os.readFile("Info/Forum/password", "*l")
}
local messages = {
	terms = os.readFile("Info/Others/terms", "*a"),
	rejected = os.readFile("Info/Others/reject", "*a")
}
local locales = {
	section = os.readFile("Info/Forum/section", "*l"),
	ajaxList = os.readFile("Info/Forum/members", "*l"),
	roomList = os.readFile("Info/Forum/modules", "*l")
} 
local imageHost = {
	link = os.readFile("Info/Forum/image-ajax", "*l"),
	host = os.readFile("Info/Forum/image", "*l")
}

local prefix = '!'

local channels = {
	guild = os.readFile("Info/Channel/guild", "*l"),
	announcements = os.readFile("Info/Channel/announcements", "*l"),
	modules = os.readFile("Info/Channel/modules", "*l"),
	applications = os.readFile("Info/Channel/applications", "*l"),
	flood = os.readFile("Info/Channel/flood", "*l"),
	notifications = os.readFile("Info/Channel/notifications", "*l"),
	logs = os.readFile("Info/Channel/logs", "*l"),
	sharpie = os.readFile("Info/Channel/sharpie", "*l"),
	bot_logs = "490515118820687884", -- Another guild
	bridge = "499635964503785533"
}
local roles = {
	dev = os.readFile("Info/Role/dev", "*l"),
	helper = os.readFile("Info/Role/helper", "*l"),
}

local botNames = { "Jerry", "ModuleAPI", "MoonAPI", "Moon", "FroggyJerry", "MoonForMice", "MoonduleAPI", "MoonBot", "ModuleBot", "JerryForMice", "JerryForMoon", "MoonPie" }
local botAvatars = { }
local botStatus = {
	{ "online", { "I'm ready to be used!", "Yoohoo", "LUA or Phyton, that's the question", ":jerry:", "Ping @Pikashu", "Atelier801 Forums" } },
	{ "idle", { "Waiting Pikashu to update the API", "Waiting my Java application to compile", "Pong @Streaxx", "AAAAA i don't work the way i should", "Editing TFM API", "Checking the moon" } },
	{ "dnd", { "Taking shower BRB", "I am stressed, do /moon", "My disk is almost full", "Reading applications", "Marriage proposal to Sharpiebot" } }
}

local greetings = {
	"Hello, sunshine!",
	"Howdy, partner!",
	"What's kickin', little chicken?",
	"Howdy-doody!",
	"Hey there, freshman!",
	"Hi, mister!",
	"I come in peace!",
	"Ahoy, matey!",
	"Hiya!",
	"I'm Batman.",
	"Ghostbusters, whatya want?",
	"Yo!",
	"Whaddup.",
	"Greetings and salutations!",
	"I like your face.",
	"What's cookin', good lookin'?",
	"Hey hot stuff",
	"OMG it's you!! kan i get your autografph?!",
	"Well hello, I didn't see you there..",
	"I've been expecting you, Mr Bond..."
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

local communities = {
	["br"] = "\xF0\x9F\x87\xA7\xF0\x9F\x87\xB7",
	["es"] = "\xF0\x9F\x87\xAA\xF0\x9F\x87\xB8",
	["fr"] = "\xF0\x9F\x87\xAB\xF0\x9F\x87\xB7",
	["gb"] = "\xF0\x9F\x87\xAC\xF0\x9F\x87\xA7",
	["nl"] = "\xF0\x9F\x87\xB3\xF0\x9F\x87\xB1",
	["ro"] = "\xF0\x9F\x87\xB7\xF0\x9F\x87\xB4",
	["ru"] = "\xF0\x9F\x87\xB7\xF0\x9F\x87\xBA",
	["sa"] = "\xF0\x9F\x87\xB8\xF0\x9F\x87\xA6",
	["tr"] = "\xF0\x9F\x87\xB9\xF0\x9F\x87\xB7",
	["pt"] = "br",
	["en"] = "gb",
	["ar"] = "sa",
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
	if owners[member.id] then -- test purpose
		return true
	end

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

	return bit.band(daysElapsed, 7) + 1
end

local updateLayout = function(skip)
	if skip or os.date("%H") == "00" then
		client:getGuild(channels.guild):getMember(client.user.id):setNickname(table.random(botNames))
		client:setAvatar(botAvatars[moonPhase()])
	end
end

local envTfm
do
	local trim = function(n)
		return bit.band(n, 0xFFFFFFFF)
	end

	local mask = function(width)
		return bit.bnot(bit.lshift(0xFFFFFFFF, width))
	end

	local fieldArgs = function(field, width)
		width = width or 1
		assert(field >= 0, "field cannot be negative")
		assert(width > 0, "width must be positive")
		assert(field + width <= 32, "trying to access non-existent bits")
		return field, width
	end

	local emptyFunction = function() end
	envTfm = {
		-- API
		assert = assert,
		bit32 = {
			arshift = function(x, disp)
				return math.floor(x / (2 ^ disp))
			end,
			band = bit.band,
			bnot = bit.bnot,
			bor = bit.bor,
			btest = function(...)
				return bit.band(...) ~= 0
			end,
			bxor = bit.bxor,
			extract = function(n, field, width)
				field, width = fieldArgs(field, width)
				return bit.band(bit.rshift(n, field), mask(width))
			end,
			lshift = bit.lsfhit,
			replace = function(n, v, field, width)
				field, width = fieldArgs(field, width)
				width = mask(width)
				return bit.bor(bit.band(n, bit.bnot(bit.lshift(m, f))), bit.lshift(bit.band(v, m), f))
			end,
			rshift = bit.rshift
		},
		coroutine = table.copy(coroutine),
		debug = {
			disableEventLog = emptyFunction,
			disableTimerLog = emptyFunction
		},
		error = emptyFunction,
		getmetatable = getmetatable,
		ipairs = ipairs,
		math = {
			abs = math.abs,
			acos = math.acos,
			asin = math.asin,
			atan = math.atan,
			atan2 = math.atan2,
			ceil = math.ceil,
			cos = math.cos,
			cosh = math.cosh,
			deg = math.deg,
			exp = math.exp,
			floor = math.floor,
			fmod = math.fmod,
			frexp = math.frexp,
			huge = math.huge,
			ldexp = math.ldexp,
			log = math.log,
			max = math.max,
			min = math.min,
			modf = math.modf,
			pi = math.pi,
			pow = math.pow,
			rad = math.rad,
			random = math.random,
			randomseed = math.randomseed,
			sin = math.sin,
			sinh = math.sinh,
			sqrt = math.sqrt,
			tan = math.tan,
			tanh = math.tanh
		},
		next = next,
		os = {
			date = os.date,
			difftime = os.difftime,
			time = os.time
		},
		pairs = pairs,
		pcall = pcall,
		print = print,
		rawequal = rawequal,
		rawget = rawget,
		rawlen = rawlen,
		rawset = rawset,
		select = select,
		setmetatable = setmetatable,
		string = {
			byte = string.byte,
			char = string.char,
			dump = string.dump,
			find = string.find,
			format = string.format,
			gmatch = string.gmatch,
			gsub = string.gsub,
			len = string.len,
			lower = string.lower,
			match = string.match,
			rep = string.rep,
			reverse = string.reverse,
			sub = string.sub,
			upper = string.upper
		},
		system = {
			bindKeyboard = emptyFunction,
			bindMouse = emptyFunction,
			disableChatCommandDisplay = emptyFunction,
			exit = emptyFunction,
			giveEventGift = emptyFunction,
			loadFile = emptyFunction,
			loadPlayerData = emptyFunction,
			newTimer = emptyFunction,
			removeTimer = emptyFunction,
			saveFile = emptyFunction,
			savePlayerData = emptyFunction
		},
		table = {
			concat = table.concat,
			foreach = table.foreach,
			foreachi = table.foreachi,
			insert = table.insert,
			pack = table.pack,
			remove = table.remove,
			sort = table.sort,
			unpack = table.unpack
		},
		tfm = {
			enum = {
				emote = {
					dance = 0,
					laugh = 1,
					cry = 2,
					kiss = 3,
					angry = 4,
					clap = 5,
					sleep = 6,
					facepaw = 7,
					sit = 8,
					confetti = 9,
					flag = 10,
					marshmallow = 11,
					selfie = 12,
					highfive = 13,
					highfive_1 = 14,
					highfive_2 = 15,
					partyhorn = 16,
					hug = 17,
					hug_1 = 18,
					hug_2 = 19,
					jigglypuff = 20,
					kissing = 21,
					kissing_1 = 22,
					kissing_2 = 23,
					carnaval = 24,
					rockpaperscissors = 25,
					rockpaperscissors_1 = 26,
					rockpaperscissor_2 = 27
				},
				ground = {
					wood = 0,
					ice = 1,
					trampoline = 2,
					lava = 3,
					chocolate = 4,
					earth = 5,
					grass = 6,
					sand = 7,
					cloud = 8,
					water = 9,
					stone = 10,
					snow = 11,
					rectangle = 12,
					circle = 13,
					invisible = 14,
					web = 15,
				},
				particle = {
					whiteGlitter = 0,
					blueGlitter = 1,
					orangeGlitter = 2,
					cloud = 3,
					dullWhiteGlitter = 4,
					heart = 5,
					bubble = 6,
					tealGlitter = 9,
					spirit = 10,
					yellowGlitter = 11,
					ghostSpirit = 12,
					redGlitter = 13,
					waterBubble = 14,
					plus1 = 15,
					plus10 = 16,
					plus12 = 17,
					plus14 = 18,
					plus16 = 19,
					meep = 20,
					redConfetti = 21,
					greenConfetti = 22,
					blueConfetti = 23,
					yellowConfetti = 24,
					diagonalRain = 25,
					curlyWind = 26,
					wind = 27,
					rain = 28,
					star = 29,
					littleRedHeart = 30,
					littlePinkHeart = 31,
					daisy = 32,
					bell = 33,
					egg = 34,
					projection = 35,
					mouseTeleportation = 36,
					shamanTeleportation = 37,
					lollipopConfetti = 38,
					yellowCandyConfetti = 39,
					pinkCandyConfetti = 40
				},
				shamanObject = {
					arrow = 0,
					littleBox = 1,
					box = 2,
					littleBoard = 3,
					board = 4,
					ball = 6,
					trampoline = 7,
					anvil = 10,
					cannon = 17,
					bomb = 23,
					orangePortal = 26,
					bluePortal = 26,
					balloon = 28,
					blueBalloon = 28,
					redBalloon = 29,
					greenBalloon = 30,
					yellowBalloon = 31,
					rune = 32,
					chicken = 33,
					snowBall = 34,
					cupidonArrow = 35,
					apple = 39,
					sheep = 40,
					littleBoardIce = 45,
					littleBoardChocolate = 46,
					iceCube = 54,
					cloud = 57,
					bubble = 59,
					tinyBoard = 60,
					companionCube = 61,
					stableRune = 62,
					balloonFish = 65,
					longBoard = 67,
					triangle = 68,
					sBoard = 69,
					paperPlane = 80,
					rock = 85,
					pumpkinBall = 89,
					tombstone = 90,
					paperBall = 95
				}
			},
			exec = {
				addConjuration = emptyFunction,
				addImage = emptyFunction,
				addJoint = emptyFunction,
				addPhysicObject = emptyFunction,
				addShamanObject = emptyFunction,
				bindKeyboard = emptyFunction,
				changePlayerSize = emptyFunction,
				chatMessage = emptyFunction,
				disableAfkDeath = emptyFunction,
				disableAllShamanSkills = emptyFunction,
				disableAutoNewGame = emptyFunction,
				disableAutoScore = emptyFunction,
				disableAutoShaman = emptyFunction,
				disableAutoTimeLeft = emptyFunction,
				disableDebugCommand = emptyFunction,
				disableMinimalistMode = emptyFunction,
				disableMortCommand = emptyFunction,
				disablePhysicalConsumables = emptyFunction,
				disablePrespawnPreview = emptyFunction,
				disableWatchCommand = emptyFunction,
				displayParticle = emptyFunction,
				explosion = emptyFunction,
				giveCheese = emptyFunction,
				giveConsumables = emptyFunction,
				giveMeep = emptyFunction,
				giveTransformations = emptyFunction,
				killPlayer = emptyFunction,
				linkMice = emptyFunction,
				lowerSyncDelay = emptyFunction,
				moveObject = emptyFunction,
				movePlayer = emptyFunction,
				newGame = emptyFunction,
				playEmote = emptyFunction,
				playerVictory = emptyFunction,
				removeCheese = emptyFunction,
				removeImage = emptyFunction,
				removeJoint = emptyFunction,
				removeObject = emptyFunction,
				removePhysicObject = emptyFunction,
				respawnPlayer = emptyFunction,
				setAutoMapFlipMode = emptyFunction,
				setGameTime = emptyFunction,
				setNameColor = emptyFunction,
				setPlayerScore = emptyFunction,
				setRoomMaxPlayers = emptyFunction,
				setRoomPassword = emptyFunction,
				setShaman = emptyFunction,
				setShamanMode = emptyFunction,
				setUIMapName = emptyFunction,
				setUIShamanName = emptyFunction,
				setVampirePlayer = emptyFunction,
				snow = emptyFunction
			},
			get = {
				misc = {
					apiVersion = 0.27,
					transformiceVersion = 5.86
				},
				room = {
					community = "en",
					currentMap = 0,
					maxPlayers = 50,
					mirroredMap = false,
					name = "en-#lua",
					objectList = {
						[1] = {
							angle = 0,
							baseType = 2,
							colors = {
								0xFF0000,
								0xFF00,
								0xFF
							},
							ghost = false,
							id = 1,
							type = 203,
							vx = 0,
							vy = 0,
							x = 400,
							y = 200
						}
					},
					passwordProtected = false,
					playerList = {
						["Tigrounette#0001"] = {
							community = "en",
							gender = 0,
							hasCheese = false,
							id = 0,
							inHardMode = 0,
							isDead = true,
							isFacingRight = true,
							isInvoking = false,
							isJumping = false,
							isShaman = false,
							isVampire = false,
							look = "1;0,0,0,0,0,0,0,0,0",
							movingLeft = false,
							movingRight = false,
							playerName = "Tigrounette#0001",
							registrationDate = 0,
							score = 0,
							shamanMode = 0,
							spouseId = 0,
							spouseName = "Melibelulle#0001",
							title = 0,
							tribeId = 0,
							tribeName = "Les Populaires",
							vx = 0,
							vy = 0,
							x = 0,
							y = 0
						}
					},
					uniquePlayers = 2,
					xmlMapInfo = {
						author = "Tigrounette#0001",
						mapCode = 184924,
						permCode = 1,
						xml = "<C><P /><Z><S /><D /><O /></Z></C>"
					}
				}
			}
		},
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		ui = {
			addPopup = emptyFunction,
			addTextArea = emptyFunction,
			removeTextArea = emptyFunction,
			setMapName = emptyFunction,
			setShamanName = emptyFunction,
			showColorPicker = emptyFunction,
			updateTextArea = emptyFunction
		},
		xpcall = xpcall,

		-- Events
		eventChatCommand = emptyFunction,
		eventChatMessage = emptyFunction,
		eventEmotePlayed = emptyFunction,
		eventFileLoaded = emptyFunction,
		eventFileSaved = emptyFunction,
		eventKeyboard = emptyFunction,
		eventMouse = emptyFunction,
		eventLoop = emptyFunction,
		eventNewGame = emptyFunction,
		eventNewPlayer = emptyFunction,
		eventPlayerDataLoaded = emptyFunction,
		eventPlayerDied = emptyFunction,
		eventPlayerGetCheese = emptyFunction,
		eventPlayerLeft = emptyFunction,
		eventPlayerMeep = emptyFunction,
		eventPlayerVampire = emptyFunction,
		eventPlayerWon = emptyFunction,
		eventPlayerRespawn = emptyFunction,
		eventPopupAnswer = emptyFunction,
		eventSummoningStart = emptyFunction,
		eventSummoningCancel = emptyFunction,
		eventSummoningEnd = emptyFunction,
		eventTextAreaCallback = emptyFunction,
		eventColorPicked = emptyFunction
	}

	envTfm.bit32.lrotate = function(x, disp)
		if disp == 0 then
			return x
		elseif disp < 0 then
			return bit.rrotate(x, -disp)
		else
			disp = bit.band(disp, 31)
			x = trim(x)
			return trim(bit.bor(bit.lshift(x, disp), bit.rshift(x, (32 - disp))))
		end
	end
	envTfm.bit32.rrotate = function(x, disp)
		if disp == 0 then
			return x
		elseif disp < 0 then
			return bit.lrotate(x, -disp)
		else
			disp = bit.band(disp, 31)
			x = trim(x)
			return trim(bit.bor(bit.rshift(x, disp), bit.lshift(x, (32 - disp))))
		end
	end
	envTfm.tfm.get.room.playerList["Pikashu#0001"] = envTfm.tfm.get.room.playerList["Tigrounette#0001"]
	envTfm._G = envTfm
end

do
	boundaries[1] = "MoonBot_" .. os.time()
	boundaries[2] = "--" .. boundaries[1]
	boundaries[3] = boundaries[2] .. "--"
end

--[[ Forum ]]--
local normalizePlayerName = function(playerName)
	if not string.find(playerName, '#') then
		playerName = playerName .. "#0000"
	end

	return (string.gsub(string.lower(playerName), "%a", string.upper, 1))
end

local normalizeDiscriminator
normalizeDiscriminator = function(discriminator)
	return #discriminator > 5 and (string.gsub(discriminator, "#%d%d%d%d", normalizeDiscriminator, 1)) or (discriminator == "#0000" and "" or "`" .. discriminator .. "`")
end

local playerExists = function(playerName)
	playerName = normalizePlayerName(playerName)

	local header, body = http.request("GET", "https://atelier801.com/profile?pr=" .. encodeUrl(playerName))
	return not string.find(body, "La requête contient un ou plusieurs paramètres invalides."), playerName
end

local applicationExists = function(playerName)
	return not not string.find(forumClient:getPage(locales.section), "%[MODULE%] " .. playerName)
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
			markdown = "~~"
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
	str = string.gsub(str, '<blockquote .-><small>(%S+).-</small><div>(.-)</div></blockquote>', function(from, content)
		return from .. ": [" .. (#content > 10 and string.sub(content, 1, 10) .. "..." or content) .. "]"
	end)
	str = string.gsub(str, '<div class="cadre cadre%-code"><div class="indication%-langage%-code">(.-)</div><hr/>.-<pre .-</pre></div></div>', function(lang)
		return "'" .. lang .. "' => ..."
	end)
	str = string.gsub(str, '<div class="cadre cadre%-code">.-<pre .-</pre></div></div>', function()
		return "'Lua code' detected => ..."
	end)
	str = string.gsub(str, '<a href="(.-)".->(.-)</a>', "[%2](%1)")
	str = string.gsub(str, "<br />", "\n")
	str = string.gsub(str, "<hr />", '')
	str = string.gsub(str, "&gt;", '>')
	str = string.gsub(str, "&lt;", '<')
	str = string.gsub(str, "&quot;", "\"")
	str = string.gsub(str, "&laquo;", '«')
	str = string.gsub(str, "&raquo;", '»')
	str = string.gsub(str, '`', '´') -- Avoid breaking blocks on discord
	return str
end

local cachedApplications

local userTimers = { }

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

		self.attachFile = function(self, fileName, fileData, fileExtension)
			return table.concat({
				boundaries[2],
				'Content-Disposition: form-data;name="/KEY1/"',
				"\r\n/KEY2/",
				boundaries[2],
				'Content-Disposition: form-data; name="fichier"; filename="[BOT] ' .. fileName .. '.' .. fileExtension .. '"',
				"Content-Type: image/" .. (fileExtension == "jpg" and "jpeg" or fileExtension) .. "\r\n",
				fileData,
				boundaries[3]
			}, "\r\n")
		end

		self.getKeys = function(self, where)
			local header, body = http.request("GET", "https://atelier801.com/" .. (where or "index"), self.headers(self))

			self.setCookies(self, header)
			return { string.match(body, '<input type="hidden" name="(.-)" value="(.-)">') }
		end

		self.getPage = function(self, pageName)
			-- Note that :page is in english and :getPage is in french because of the headers.
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

		self.getToken_Date = function(self)
			return this.cookies.token_date / 1000
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

		self.hostImage = function(self, link, fileName, image, extension)
			return self.page(self, imageHost.host, { }, link, nil, self.attachFile(self, fileName, image, extension))
		end

		self.isConnected = function(self)
			return self.getUsername(self) ~= ""
		end

		self.login = function(self, username, password, reconnect)
			if reconnect then
				this.username = ""
			end

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

		self.page = function(self, pageName, postData, ajax, keyLocation, fileBody)
			local keys = self.getKeys(self, keyLocation or ajax)
			if #keys == 0 then
				return commands["refresh"].fn()
			end

			local headers = self.headers(self)
			if ajax then
				headers[3] = { "Accept", "application/json, text/javascript, */*; q=0.01" }
				headers[4] = { "Accept-Language", "en-US,en;q=0.9" }
				headers[5] = { "X-Requested-With", "XMLHttpRequest" }
				headers[6] = { "Content-Type", (fileBody and "multipart/form-data; boundary=" .. boundaries[1] or "application/x-www-form-urlencoded; charset=UTF-8") }
				headers[7] = { "Referer", "https://atelier801.com/" .. ajax }
				headers[8] = { "Connection", "keep-alive" }
			end

			postData = postData or { }
			postData[#postData + 1] = keys

			local header, body = http.request("POST", "https://atelier801.com/" .. pageName, headers, (fileBody and string.gsub(fileBody, "/KEY(%d)/", function(id)
				return keys[tonumber(id)]
			end, 2) or table.fconcat(postData, '&', function(index, value)
				return value[1] .. "=" .. encodeUrl(value[2])
			end)))

			self.setCookies(self, header)

			return body
		end

		self.sendPrivateMessage = function(self, to, subject, message)
			return self.page(self, "create-discussion", {
				{ "destinataires", to .. "§#§Shamousey#0015" },
				{ "objet", subject },
				{ "message", message }
			}, "new-discussion")
		end

		self.answerPrivateMessage = function(self, conversationId, answer)
			return self.page(self, "answer-conversation", {
				{ "co", conversationId },
				{ "message_reponse", answer }
			}, "conversation?co=" .. conversationId)
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

--[[ Commands ]]--
local hasParam = function(message, parameters)
	if not parameters or #parameters == 0 then
		toDelete[message.id] = message:reply({
			content = "<@!" .. message.author.id .. ">",
			embed = {
				color = color.fail,
				title = "<:wheel:456198795768889344> Missing or invalid parameters.",
				description = "Type **!help command** to read its description and syntax."
			}
		})
		return false
	end
	return true
end

local validPattern = function(message, src, pattern)
	local success, err = pcall(string.find, src, pattern)
	if not success then
		toDelete[message.id] = message:reply({
			content = "<@!" .. message.author.id .. ">",
			embed = {
				color = color.fail,
				title = "<:atelier:458403092417740824> Invalid pattern.",
				description = "```\n" .. tostring(err) .. "```"
			}
		})
		return false
	end
	return true
end

local alias = {
	-- alias, cmd
	["accept"] = "terms",
	["answer"] = "reply",
	["applications"] = "apps",
	["bulb"] = "remind",
	["deny"] = "reject",
	['i'] = "upload",
	["img"] = "upload",
	["info"] = "help",
	["lua"] = "tree",
	['m'] = "members",
	["message"] = "mobile",
	["pm"] = "mobile",
	["reminder"] = "remind",
	["rooms"] = "modules",
	["say"] = "remind",
	["server"] = "serverinfo"
}

-- description => Description of the command, appears in !help
-- syntax => Command syntax
-- connection => Whether the command uses the forum client connection or not, do not execute until the client is connected
-- highlevel => Whether the command works only for helpers or not
-- sys => Whether the command is invisible or not. Usually for debug commands or commands in test.
-- fn(msg, param) => The function
commands["adoc"] = {
	description = "Gets information about a specific tfm api function.",
	syntax = prefix .. "adoc function_name",
	fn = function(message, parameters)
		if not hasParam(message, parameters) then return end

		local header, body = http.request("GET", "https://atelier801.com/topic?f=826122&t=924910")

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
				description = string.gsub(description, "&amp;", "&")
				description = string.gsub(description, "&pi;", "π")
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
								local params, counter = { }, 0
								for name, type in string.gmatch(list, "(%w+) %((.-)%)") do
									counter = counter + 1
									params[counter] = "`" .. type .. "` **" .. name .. "**"
								end

								if counter > 0 and desc then
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
}
commands["apps"] = {
	description = "Counts the current number of applications and gives an approximate counter of votes.",
	connection = true,
	fn = function(message)
		if cachedApplications then
			local lines = splitByLine(table.fconcat(cachedApplications.data, "\n", function(index, value)
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

				return ((value.isNew or (value.difftime and value.difftime < 4)) and "`NEW` " or ((value.difftime and ((value.difftime > 30 and ":warning: " or "") .. value.difftime .. "d ") or ""))) .. ":envelope: [**" .. value.playerName .. "**](https://atelier801.com/" .. value.url .. ") " .. (#res > 0 and ("≈ " .. table.concat(res, " | ") .. (value.n > 2 and " - :x:" or ((value.y > 5 and value.n == 0) or value.y > 6) and " - :white_check_mark:" or "")) or "")
			end))

			local msgs = { }
			for line = 1, #lines do
				local data = {
					embed = {
						color = color.info,
						description = lines[line]
					}
				}

				if line == 1 then
					data.content = "__Yes and No votes are approximated!\nDo not judge before checking the application.__"
					data.embed.title = "<:atelier:458403092417740824> Applications [" .. #cachedApplications.data .. "]"
				end

				if line == #lines then
					data.embed.footer = { text = "Last update" }
					data.embed.timestamp = cachedApplications.timestamp
				end

				msgs[line] = message:reply(data)
			end

			toDelete[message.id] = msgs
		else
			toDelete[message.id] = message:reply({
				embed = {
					color = color.fail,
					title = "<:atelier:458403092417740824> Applications",
					description = "There are no applications. :("
				}
			})
		end
	end
}
commands["del"] = {
	sys = true,
	fn = function(message, parameters)
		local msg = message.channel:getMessage(parameters)
		if msg and msg.author.id == client.user.id then
			msg:delete()
		end
		message:delete()
	end
}
commands["doc"] = {
	description = "Gets information about a specific lua function.",
	syntax = prefix .. "doc function_name",
	fn = function(message, parameters)
		if not hasParam(message, parameters) then return end

		local header, body = http.request("GET", "http://www.lua.org/work/doc/manual.html")

		if body then
			local syntax, description = string.match(body, "<a name=\"pdf%-" .. parameters .. "\"><code>(.-)</code></a></h3>[\n<p>]*(.-)<h[r2]>")

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
}
commands["eval"] = {
	description = "Checks if the provided code would run in Transformice or not.",
	syntax = prefix .. "eval link / \\`\\`\\`Code\\`\\`\\`",
	fn = function(message, parameters)
		if not hasParam(message, parameters) then return end

		if string.find(parameters, '`') then
			local _
			_, parameters = string.match(parameters, "`(`?`?)(.*)%1`")

			if parameters then
				local hasLuaTag, final = string.find(string.lower(parameters), "^lua\n+")
				if hasLuaTag then
					parameters = string.sub(parameters, final + 1)
				end
			end
		elseif string.find(parameters, "^http") then
			local header, body = http.request("GET", parameters)
			parameters = body
		else
			parameters = nil
		end

		if not parameters or #parameters == 0 then
			toDelete[message.id] = message:reply({
				content = "<@!" .. message.author.id .. ">",
				embed = {
					color = color.fail,
					title = "<:wheel:456198795768889344> Invalid parameters.",
					description = "The parameter is not a link or \\`\\`\\`Code\\`\\`\\`."
				}
			})
			return
		end

		local kb = #parameters / 1000

		local fn, err = load(parameters, '', 't', envTfm)
		if not fn then
			toDelete[message.id] = message:reply({
				content = "<@!" .. message.author.id .. ">",
				embed = {
					color = color.error,
					title = "<:wheel:456198795768889344> Syntax failed.",
					description = "**Script length** : " .. kb .. "kb\n\n<:dnd:456197711251636235> Script syntax failed\n\n```\n" .. err .. "```"
				}
			})
			return
		end

		toDelete[message.id] = message:reply({
			content = "<@!" .. message.author.id .. ">",
			embed = {
				color = color.success,
				title = "<:wheel:456198795768889344> Syntax checked sucessfully.",
				description = "**Script length** : " .. kb .. "kb\n\n<:online:456197711356755980> Script syntax checked sucessfully"
			}
		})
	end
}
commands["form"] = {
	description = "Displays the application form link.",
	fn = function(message)
		toDelete[message.id] = message:reply({
			content = "<@!" .. message.author.id .. ">",
			embed = {
				color = color.info,
				title = "<:atelier:458403092417740824> Application Form",
				description = "**Application state** : <:online:456197711356755980>\n\n**URL** : https://goo.gl/ZJcnhZ",
				timestamp = message.timestamp
			}
		})
	end
}
commands["help"] = {
	description = "Displays the help message.",
	syntax = prefix .. "help [command]",
	fn = function(message, parameters)
		if parameters and #parameters > 0 then
			parameters = string.lower(parameters)

			parameters = alias[parameters] or parameters
			if commands[parameters] and not commands[parameters].sys then
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
						title = ":loudspeaker: Help ~> '" .. prefix .. parameters .. "'",
						description = "**Must be connected on forums:** " .. string.upper(tostring(not not commands[parameters].connection)) .. "\n**Helper command:** " .. string.upper(tostring(not not commands[parameters].highlevel)) .. "\n\n**Description:** " .. commands[parameters].description .. (commands[parameters].syntax and ("\n\n**Syntax:** " .. commands[parameters].syntax) or "") .. (#aliases > 0 and ("\n\n**Aliases:** _" .. prefix .. table.concat(aliases, "_ , _" .. prefix) .. "_") or "")
					}
				})
			else
				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.fail,
						title = ":loudspeaker: Help",
						description = "The command **" .. prefix .. parameters .. "** doesn't exist!"
					}
				})
			end
		else
			toDelete[message.id] = message:reply({
				content = "<@!" .. message.author.id .. ">",
				embed = {
					color = color.info,
					title = ":loudspeaker: General help",
					description = table.fconcat(commands, "", function(index, value)
						return value.sys and "" or (":small_" .. (value.highlevel and "orange" or "blue") .. "_diamond: **" .. prefix .. index .. "** - " .. value.description .. "\n")
					end, nil, nil, pairsByIndexes)
				}
			})
		end
	end
}
commands["members"] = {
	description = "Lists the module team members.",
	syntax = prefix .. "members [pattern]",
	connection = true,
	fn = function(message, parameters)
		local body = forumClient:getPage(locales.ajaxList)

		if parameters and not validPattern(message, body, parameters) then return end

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
					description = "there are no members with that pattern. :("
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
commands["mobile"] = {
	description = "Sends a private message with the embed in a text format.",
	syntax = prefix .. "mobile message\\_id",
	fn = function(message, parameters)
		parameters = parameters and string.match(parameters, "%d+")

		if parameters then
			local msg = message.channel:getMessage(parameters)

			if msg then
				if msg.embed then
					local content = { }

					if msg.content then
						content[#content + 1] = "`" .. msg.content .. "`"
					end

					if msg.embed.title then
						content[#content + 1] = "**" .. msg.embed.title .. "**"
					end
					if msg.embed.description then
						content[#content + 1] = msg.embed.description
					end

					local footerText = msg.embed.footer and msg.embed.footer.text
					if footerText then
						content[#content + 1] = "`" .. footerText .. "`"
					end

					local len = #content
					content[len + (footerText and 0 or 1)] = (footerText and (content[len] .. " | ") or "") .. "`" .. os.date("%c", os.time(discordia.Date().fromISO(msg.timestamp):toTableUTC())) .. "`"

					local img = (msg.attachment and msg.attachment.url) or (msg.embed and msg.embed.image and msg.embed.image.url)
					message.author:send({
						content = string.sub(table.concat(content, "\n"), 1, 2000),
						embed = {
							image = (img and { url = img } or nil)
						}
					})
				else
					message.author:send(msg.content)
				end
				message:delete()
			end
		end
	end
}
commands["modules"] = {
	description = "Lists the current modules available in Transformice.",
	syntax = prefix .. "modules [[from Community / by Player] [level ModuleLevel(0=semi / 1=official)] [#pattern]]",
	connection = true,
	fn = function(message, parameters)
		local body = forumClient:getPage(locales.roomList)

		local search = {
			commu = false,
			player = false,
			type = false,
			pattern = false
		}
		if parameters then
			if not validPattern(message, body, parameters) then return end

			string.gsub(string.lower(parameters), "(%S+)[\n ]+(%S+)", function(keyword, value)
				if keyword then
					if keyword == "from" and not search.player then
						search.commu = tonumber(value)
						if #value == 2 then
							search.commu = #tostring(communities[value]) == 2 and communities[value] or value
						else
							search.commu = table.search(communities, value) or value
						end
					elseif keyword == "by" and not search.commu then
						if not validPattern(message, body, value) then return end
						search.player = value
					elseif keyword == "level" then
						search.type = tonumber(value)
					end
				end
			end)

			local filter = search.commu or search.player or search.type

			search.pattern = string.match(" " .. parameters, "[\n ]+#(.+)$")

			if not search.pattern and not filter then
				search.pattern = parameters
			end
			if search.pattern and not validPattern(message, body, search.pattern) then return end
		end

		local list, counter = { }, 0

		string.gsub(body, '<tr><td><img src="https://atelier801%.com/img/pays/(..)%.png" alt="https://atelier801%.com/img/pays/%1%.png" class="inline%-block img%-ext" style="float:;" /></td><td>     </td><td><span .->(#%S+)</span>.-</td><td>     </td><td><span .->(%S+)</span></td><td>     </td><td><span .->(%S+)</span></td> 	</tr>', function(community, module, level, hoster)
			local check = (not parameters or parameters == "")
			if not check then
				check = true

				if search.commu then
					check = community == search.commu
				end
				if search.type then
					check = check and ((search.type == 0 and level == "semi-official") or (search.type == 1 and level == "official"))
				end
				if search.player then
					check = check and not not string.find(string.lower(hoster), search.player)
				end
				if search.pattern then
					check = check and not not string.find(module, search.pattern)
				end
			end

			if check then
				counter = counter + 1
				list[counter] = { community, module, level, normalizeDiscriminator(hoster) }
			end
		end)

		if #list == 0 then
			toDelete[message.id] = message:reply({
				content = "<@!" .. message.author.id .. ">",
				embed = {
					color = color.fail,
					title = "<:wheel:456198795768889344> Modules",
					description = "There are no modules " .. (search.commu and ("made by a(n) [:flag_" .. search.commu .. ":] **" .. string.upper(search.commu) .. "** ") or "") .. (search.player and ("made by **" .. search.player .. "** ") or "") .. (search.type and ("that are [" .. (search.type == 0 and "semi-official" or "official") .. "]") or "") .. (search.pattern and (" with the pattern **`" .. tostring(search.pattern) .. "`**.") or ".")
				}
			})
		else
			local out = table.fconcat(list, "\n", function(index, value)
				return communities[value[1]] .. " `" .. value[3] .. "` **" .. value[2] .. "** ~> **" .. value[4] .. "**"
			end)

			local lines, msgs = splitByLine(out), { }
			for line = 1, #lines do
				msgs[line] =  message:reply({
					content = (line == 1 and "<@!" .. message.author.id .. ">" or nil),
					embed = {
						color = color.info,
						title = (line == 1 and "<:wheel:456198795768889344> [" .. #list .. "] Modules found" or nil),
						description = lines[line]
					}
				})
			end

			toDelete[message.id] = msgs
		end
	end
}
commands["quote"] = {
	description = "Quotes a message.",
	syntax = prefix .. "quote [channel_id-]message_id",
	fn = function(message, parameters)
		if not hasParam(message, parameters) then return end

		local quotedChannel, quotedMessage = string.match(parameters, "(%d+)%-(%d+)")
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

						fields = {
							{
								name = "Link",
								value = "[Click here](" .. msg.link .. ")"
							}
						},

						footer = {
							text = "In " .. (msg.channel.category and (msg.channel.category.name .. ".#") or "#") .. msg.channel.name,
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
commands["refresh"] = {
	sys = true,
	fn = function(message)
		if message then
			message:delete()
		end

		os.execute("luvit bot.lua")
		os.exit()
	end
}
commands["reject"] = {
	description = "Messages a player to inform their application got rejected.",
	syntax = prefix .. "reject PlayerName#0000",
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
	end
}
commands["remind"] = {
	description = "Sets a reminder. Bot will remind you.",
	syntax = prefix .. "remind time\\_and\\_order text",
	fn = function(message, parameters)
		if not hasParam(message, parameters) then return end

		local time, order, text = string.match(parameters, "^(%d+%.?%d*)(%a+)[\n ]+(.-)$")
		if time and order and text and #text > 0 then
			time = tonumber(time)
			if order == "ms" then
				time = math.clamp(time, 6e4, 216e5)
			elseif order == 's' then
				time = math.clamp(time, 60, 21600) * 1000
			elseif order == 'm' then
				time = math.clamp(time, 1, 360) * 6e4
			elseif order == 'h' then
				time = math.clamp(time, .017, 6) * 3.6e6
			else
				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.fail,
						title = ":timer: Invalid time magnitude order '" .. order .. "'",
						description = "The available time magnitude orders are **ms**, **s**, **m**, **h**."
					}
				})
				return
			end

			timer.setTimeout(time, coroutine.wrap(function(channel, text, userId, cTime)
				cTime = os.time() - cTime
				local h, m, s = math.floor(cTime / 3600), math.floor(cTime % 3600 / 60), math.floor(cTime % 3600 % 60)
				local info = (((h > 0 and (h .. " hour") .. (h > 1 and "s" or "") .. (((s > 0 and m > 0) and ", ") or (m > 0 and " and ") or "")) or "") .. ((m > 0 and (m .. " minute") .. (m > 1 and "s" or "")) or "") .. ((s > 0 and (" and " .. s .. " second" .. (s > 1 and "s" or ""))) or ""))

				channel:send({
					content = "<@" .. userId .. ">",
					embed = {
						color = color.info,
						title = ":bulb: Reminder",
						description = info .. " ago you asked to be reminded about ```\n" .. text .. "```"
					}
				})
			end), message.channel, text, message.author.id, os.time())

			local ok = message:reply(":thumbsup:")
			timer.setTimeout(1e4, coroutine.wrap(function(ok)
				ok:delete()
			end), ok)
			message:delete()
		end
	end
}
commands["reply"] = {
	description = "Answers a private message.",
	syntax = prefix .. "reply conversation\\_id \\`\\`\\` BBCODE answer \\`\\`\\`",
	connection = true,
	highlevel = true,
	fn = function(message, parameters)
		if not hasParam(message, parameters) then return end

		local co, _, answer = string.match(parameters, "^(%d+)[\n ]+`(`?`?)%s*(.-)%s*%2`$")
		if co then
			local body = forumClient:getPage("conversation?co=" .. co)

			if string.find(body, '<div class="modal%-body"> <p>  Interdit') then
				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.fail,
						title = "<:atelier:458403092417740824> Invalid conversation id.",
						description = "The conversation **" .. tostring(co) .. "** doesn't exist."
					}
				})
				return
			end

			if #answer == 0 then
				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.fail,
						title = "<:atelier:458403092417740824> Empty reply content.",
						description = "You must insert a text within \\`."
					}
				})
				return
			end

			local body = forumClient:answerPrivateMessage(co, answer)

			if string.sub(body, 2, 11) == '"supprime"' then
				message:reply({
					embed = {
						color = color.success,
						title = "<:atelier:458403092417740824> Message Reply ( " .. co .. " )",
						description = "<@!" .. message.author.id .. "> [" .. message.member.name .. "] replied the conversation **" .. co .. "** with the following content:\n```\n" .. answer .. "```"
					}
				})
				message:delete()
			else
				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.fail,
						title = "<:atelier:458403092417740824> Private Message Error",
						description = "Failure trying to send a reply for **co_" .. tostring(co) .. "**\n```\n" .. tostring(body) .. "```"
					}
				})
			end
		end
	end
}
commands["serverinfo"] = {
	description = "Displays cool informations about the server.",
	syntax = prefix .. "serverinfo",
	fn = function(message)
		local members = message.guild.members

		local bots = members:count(function(member) return member.bot end)

		toDelete[message.id] = message:reply({
			content = "<@" .. message.author.id .. ">",
			embed = {
				color = color.info,

				author = {
					name = message.guild.name,
					icon_url = message.guild.iconURL
				},

				thumbnail = { url = "https://i.imgur.com/Lvlrhot.png" },

				fields = {
					[1] = {
						name = ":computer: ID",
						value = message.guild.id,
						inline = true
					},
					[2] = {
						name = ":crown: Owner",
						value = "<@" .. message.guild.ownerId .. ">",
						inline = true
					},
					[3] = {
						name = ":speech_balloon: Channels",
						value = ":pencil2: Text: " .. #message.guild.textChannels .. "\n:speaker: Voice: " .. #message.guild.voiceChannels .. "\n:card_box: Category: " .. #message.guild.categories,
						inline = true
					},
					[4] = {
						name = ":calendar: Created at",
						value = os.date("%Y-%m-%d %I:%M%p", message.guild.createdAt),
						inline = true
					},
					[5] = {
						name = ":family_mmgb: Members",
						value = string.format("<:online:456197711356755980> Online: %s | <:idle:456197711830581249> Away: %s | <:dnd:456197711251636235> Busy: %s | <:offline:456197711457419276> Offline: %s\n\n:raising_hand: **Total:** %s\n\n<:lua:483421987499147292> **Devs Lua**: %s\n<:akinator:456196251743027200> **Helpers**: %s\n<:jerry:484137634483142667> **Funcorps**: %s\n<:atelier:458403092417740824> **Admins**: %s\n\n:robot: **Bots**: %s", members:count(function(member)
							return member.status == "online"
						end), members:count(function(member)
							return member.status == "idle"
						end), members:count(function(member)
							return member.status == "dnd"
						end), members:count(function(member)
							return member.status == "offline"
						end), message.guild.totalMemberCount - bots, members:count(function(member)
							return member:hasRole("190845564940845056") -- devlua
						end), members:count(function(member)
							return member:hasRole("203570211205414912") or member:hasRole("228169003678433280") -- helper / ahelper
						end), members:count(function(member)
							return member:hasRole("279752481620099073") -- funcorp
						end), members:count(function(member)
							return member:hasRole("197765650398183424") -- admin
						end), bots),
						inline = false
					},
				},
			}
		})
	end
}
commands["terms"] = {
	description = "Messages a player to inform their application got accepted.",
	syntax = prefix .. "terms PlayerName#0000",
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
	end
}
commands["tree"] = {
	description = "Displays the Lua tree.",
	syntax = prefix .. "tree [path]",
	fn = function(message, parameters)
		local src, pathExists = envTfm, true
		local indexName

		if parameters and #parameters > 0 then
			for p in string.gmatch(parameters, "[^%.]+") do
				if type(src) ~= "table" then
					pathExists = false
					break
				end

				p = tonumber(p) or p
				src = src[p]

				if not src then
					pathExists = false
					break
				elseif type(src) ~= "table" then
					indexName = p
				end
			end

			if not pathExists then
				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.fail,
						title = "<:wheel:456198795768889344> Invalid path",
						description = "The path **`" .. parameters .. "`** doesn't exist"
					}
				})
				return
			end
		end

		local sortedSrc = { }

		if type(src) == "table" then
			local counter = 0
			for k, v in next, src do
				counter = counter + 1
				sortedSrc[counter] = { k, tostring(v), type(v) }
			end
		else
			sortedSrc[1] = { tostring(indexName), tostring(src), type(src) }
		end
		table.sort(sortedSrc, function(value1, value2)
			if value1[3] == "number" and value2[3] == "number" then
				value1 = tonumber(value1[2])
				value2 = tonumber(value2[2])
			else
				value1 = value1[1]
				value2 = value2[1]
			end

			return value1 < value2
		end)

		local lines = splitByLine(table.fconcat(sortedSrc, "\n", function(index, value)
			return "`" .. value[3] .. "` **" .. value[1] .. "** : `" .. value[2] .. "`" 
		end))

		local msgs = { }
		for line = 1, #lines do
			msgs[line] = message:reply({
				content = (line == 1 and "<@!" .. message.author.id .. ">" or nil),
				embed = {
					color = color.info,
					title = (line == 1 and "<:wheel:456198795768889344> " .. (parameters and ("'" .. parameters .. "' ") or "") .. "Tree" or nil),
					description = lines[line]
				}
			})
		end

		toDelete[message.id] = msgs
	end
}
commands["update"] = {
	sys = true,
	fn = function(message)
		updateLayout(true)

		message:delete()
	end
}
commands["upload"] = {
	description = "Uploads an image in module-images.",
	syntax = prefix .. "upload link / imgur album / image",
	connection = true,
	fn = function(message, parameters, get)
		local mt_member, shades_requester -- shades_requester when someone from 50shades get approval to have the image hosted.
		if message.channel.id == channels.bridge and not get then
			local _, final, mt, my = string.find(parameters, "`(%d+)|(%d+)`")
			mt_member = mt
			shades_requester = my
			parameters = string.sub(parameters, final + 2)
		else
			mt_member = message.author.id
		end
	
		local img = message.attachment and message.attachment.url
		if not img then
			if not hasParam(message, parameters) then return end
		end

		local channel = client:getChannel(channels.flood)

		parameters = img or parameters

		if string.sub(parameters, 1, 20) == "https://imgur.com/a/" then -- imgur album
			local header, body = http.request("GET", parameters)
        
			local images, counter = { }, 0
			string.gsub(tostring(body), '<div id="(%S+)" class="post%-image%-container', function(image)
				counter = counter + 1
				images[counter] = image .. ".png"
			end)
        
			if counter > 0 then
				local len, refMessage = (counter <= 13 and 0 or counter <= 23 and 1 or 2)
				for image = 1, math.min(counter, 50) do
					local code, failed = commands["upload"].fn(message, "https://i.imgur.com/" .. images[image], true)
        
					local imgurMarkdown, atelierMarkdown = "**" .. images[image] .. "**", "**" .. code .. "**"
					imgurMarkdown = (len == 2 and imgurMarkdown or ("[" .. imgurMarkdown .. "](https://i.imgur.com/" .. images[image] .. ")"))
					atelierMarkdown = (len == 2 and atelierMarkdown or ("[" .. atelierMarkdown .. "](http://images.atelier801.com/" .. code .. ")"))
        
					local result = (failed and ((len == 0 and "<:dnd:456197711251636235>" or ":x:") .. imgurMarkdown) or ((len == 0 and "<:online:456197711356755980> " or "") .. imgurMarkdown .. " ~> " .. atelierMarkdown))
        
					if image == 1 then
						refMessage = channel:send({
							content = "<@!" .. mt_member .. ">",
							embed = {
								color = color.success,
								title = (len > 0 and ":warning: " or "") .. "<:atelier:458403092417740824> Image album upload [ 1 / " .. counter .. " ]",
								description = result
							}
						})
					else
						refMessage.embed.title = string.gsub(refMessage.embed.title, "%[ (%d+) /", "[ " .. image .. " /", 1)
						refMessage.embed.description = refMessage.embed.description .. "\n" .. result
						refMessage:setEmbed(refMessage.embed)
					end
				end
        
				client:getUser(mt_member):send({ embed = refMessage.embed })
				if shades_requester then
					client:getChannel(channels.bridge):send({
						content = shades_requester,
						embed = refMessage.embed
					})
				end
				message:delete()
			else
				local embed = {
					color = color.fail,
					title = "<:imgur:485536726794764299> Invalid imgur album",
					description = "The link provided is not a valid imgur album.\n```\n" .. parameters .. "```"
				}

				toDelete[message.id] = channel:send({
					content = "<@!" .. mt_member .. ">",
					embed = embed
				})
				if shades_requester then
					client:getChannel(channels.bridge):send({
						content = shades_requester,
						embed = embed
					})
				end
			end
			return
		end

		local extension, formats = false, { ".jpg", ".png" }
		for f = 1, #formats do
			if string.find(parameters, formats[f]) then
				extension = string.sub(formats[f], 2)
				break
			end
		end

		if not img and extension and not string.find(parameters, "^https?://") then
			extension = false
		end

		if not extension then
			local embed = {
				color = color.fail,
				title = "<:atelier:458403092417740824> Invalid link",
				description = "The link provided is not a valid image.\n```\n" .. parameters .. "```"
			}

			toDelete[message.id] = channel:send({
				content = "<@!" .. mt_member .. ">",
				embed = embed
			})
			if shades_requester then
				client:getChannel(channels.bridge):send({
					content = shades_requester,
					embed = embed
				})
			end
			return
		end

		if string.sub(parameters, 1, 13) == "https://imgur" then -- imgur doesn't redirect to i.imgur in the request
			parameters = string.gsub(parameters, "/imgur", "/i.imgur", 1)
		end

		local foo, image = http.request("GET", parameters)
		if not image then
			local embed = {
				color = color.fail,
				title = "<:atelier:458403092417740824> Invalid image",
				description = "The link provided could not be uploaded.\n```\n" .. tostring(foo) .. "```\n```\n" .. parameters .. "```"
			}

			toDelete[message.id] = channel:send({
				content = "<@!" .. mt_member .. ">",
				embed = embed
			})
			if shades_requester then
				client:getChannel(channels.bridge):send({
					content = shades_requester,
					embed = embed
				})
			end
			return
		end

		local link = imageHost.link .. encodeUrl(account.username)
		local body = forumClient:hostImage(link, mt_member, image, extension)
		if string.sub(body, 3, 13) == "redirection" then
			local list = forumClient:getPage(link)

			local imageLink, imageId = string.match(list, '"(http://images%.atelier801%.com/(.-))"')

			if get then
				return imageId
			else
				local embed = {
					color = color.info,
					title = "<:atelier:458403092417740824> Image upload",
					description = "Your image code is [**" .. imageId .. "**](" .. imageLink .. ")\nFrom: ```\n" .. parameters .. "```",
					image = { url = imageLink }
				}

				channel:send({
					content = "<@!" .. mt_member .. ">",
					embed = embed
				})
				client:getUser(mt_member):send({ embed = embed })
				if shades_requester then
					client:getChannel(channels.bridge):send({
						content = shades_requester,
						embed = embed
					})
				end
			end
		else
			if get then
				return parameters, true
			else
				local embed = {
					color = color.fail,
					title = "<:atelier:458403092417740824> Image upload",
					description = "Failure trying to upload the image **" .. parameters .. "**\n```\n" .. tostring(body) .. "```"
				}

				toDelete[message.id] = channel:send({
					content = "<@!" .. mt_member .. ">",
					embed = embed
				})
				if shades_requester then
					client:getChannel(channels.bridge):send({
						content = shades_requester,
						embed = embed
					})
				end
				return
			end
		end

		message:delete()
	end
}

--[[ Events ]]--
local ini_time
client:on("ready", function()
	forumClient = forum()

	forumClient:login(account.username, account.password)
	ini_time = os.time() + 3600 * 10

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
	-- Ignore its own messages
	if message.author.id == client.user.id then return end

	if message.author.id == "185432774314819584" then
		return message:delete()
	end

	-- Bridge
	if message.channel.id == channels.bridge then
		if string.sub(message.content, 1, 2) == "%p" then
			client:getChannel(channels.sharpie):send(message.content)
			message:delete()
		elseif string.sub(message.content, 1, 7) == "!upload" then
			commands["upload"].fn(message, string.sub(message.content, 9))
			message:delete()
		end
		return
	end

	-- Skips bot messages
	if message.author.bot then return end

	-- Doesn't allow private messages
	if message.channel.type == 1 then return end

	-- Doesn't allow to speak in #announcements
	if message.channel.id == channels.announcements then return end

	-- Doesn't allow to speak in another guild (except the one that hosts the bot emojis and stuff)
	if message.guild.id ~= channels.guild and message.guild.id ~= "399730169000230923" then
		return client:leave()
	end

	-- Checks if the message pinged the bot
	if string.find(message.content, "<@!?" .. client.user.id .. ">") then
		toDelete[message.id] = message:reply("<@!" .. message.author.id .. ">\n" .. table.random(greetings) .. "\n\nMy prefix is `" .. prefix .. "`. Type `" .. prefix .. "help` to learn more!")
		return
	end

	-- Check if the user is allowed to use a command
	if userTimers[message.author.id] then
		if os.time() < userTimers[message.author.id] then
			return
		end
	else
		userTimers[message.author.id] = 0
	end

	-- Detect command and parameters
	local command, parameters = string.match(message.content, "^" .. prefix .. "(.-)[\n ]+(.*)")
	command = command or string.match(message.content, "^" .. prefix .. "(.+)")

	if not command then return end

	command = string.lower(command)
	parameters = (parameters and parameters ~= "") and string.trim(parameters) or nil

	-- Function call
	command = alias[command] or command
	if commands[command] then
		message.channel:broadcastTyping()

		if not hasPermission(message.member, (commands[command].highlevel and roles.helper or roles.dev)) then
			if not commands[command].sys then
				toDelete[message.id] = message:reply({
					content = "<@!" .. message.author.id .. ">",
					embed = {
						color = color.fail,
						title = "Authorization denied.",
						description = "You do not have access to the command **" .. prefix .. command .. "**!"
					}
				})
			end
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
			return
		end
		userTimers[message.author.id] = os.time() + 1.2
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
		client:getChannel(channels.bot_logs):send({
			embed = {
				color = color.error,
				title = "evt@ReactionAddU => Fatal Error!",
				description = "Message: " .. tostring(messageId) .. "\n```\n" .. err .. "```"
			}
		})
	end
end)
client:on("reactionAdd", function(reaction, userId)
	-- Parameters are normalized to both Uncached and Cached messages trigger reactionAdd correctly
	local success, err = pcall(reactionAdd, false, reaction.message.channel, reaction.message.id, reaction.emojiName, userId)
	if not success then
		client:getChannel(channels.bot_logs):send({
			embed = {
				color = color.error,
				title = "evt@ReactionAdd => Fatal Error!",
				description = "Message: " .. tostring(reaction.message.id) .. "\n```\n" .. err .. "```"
			}
		})
	end
end)

local memberJoin = function(member)
	if member.guild.id == channels.guild then
		client:getChannel(channels.logs):send({
			embed = {
				color = color.info,
				description = "<@!" .. member.id .. "> [" .. member.name .. "] just joined the server!"
			}
		})
	end
end
local memberLeave = function(member)
	if member.guild.id == channels.guild then
		client:getChannel(channels.logs):send({
			embed = {
				color = color.info,
				description = "<@" .. member.id .. "> [" .. member.name .. "] just left the server!"
			}
		})
	end
end

client:on("memberJoin", function(member)
	local success, err = pcall(memberJoin, member)
	if not success then
		client:getChannel(channels.bot_logs):send({
			embed = {
				color = color.error,
				title = "evt@MemberJoin => Fatal Error!",
				description = "```\n" .. err .. "```"
			}
		})
	end
end)
client:on("memberLeave", function(member)
	local success, err = pcall(memberLeave, member)
	if not success then
		client:getChannel(channels.bot_logs):send({
			embed = {
				color = color.error,
				title = "evt@MemberLeave => Fatal Error!",
				description = "```\n" .. err .. "```"
			}
		})
	end
end)

local checkApplications = function()
	if not forumClient:isConnected() then return end

	local body = forumClient:getPage(locales.section)

	-- Checks new topics and new messages (counter only)
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
		client:getChannel(channels.applications):send({ -- #applications
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
		local announcements = client:getChannel(channels.applications) -- #applications
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

	-- Caches the output for !apps
	counter = 0
	local applications = { }
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

		local difftime = tonumber(string.match(topic, 'data%-afficher%-secondes="false">(%d+)</span>', 1))

		counter = counter + 1
		list[counter] = {
			url = applications[application][2],
			playerName = applications[application][3],
			y = yeses,
			n = nos,
			unkn = unknowns,
			isNew = new,
			difftime = difftime and math.ceil((os.time() - (difftime / 1000)) / 60 / 60 / 24) or nil
		}
	end

	cachedApplications = (#list > 0 and ({
		timestamp = string.gsub(discordia.Date():toISO(), " ", ""), -- gsub avoid Discordia glitches
		data = list
	}) or nil)
end
local checkPrivateMessages = function()
	if not forumClient:isConnected() then return end

	local body = forumClient:getPage("conversations")
	if not body then return end

	local toCheck, counter = { }, 0
	string.gsub(body, 'img18 espace%-2%-2" />  (.-) </a>.-nombre%-messages%-(.-)" href="(.-)">(%d+)<', function(title, messageState, url, totalReplies)
		if messageState == "reponses" or messageState == "nouveau" then
			local final = string.find(url, "&p")
			local link = string.sub(url, 1, (final or 0) - 1)
			local conversationId = string.match(link, "%d+$")

			if not topicState == "nouveau" then -- new msg must be #1
				link = link .. "&p=1#m" .. totalReplies
			end

			local checkedReplies = final and tonumber(string.sub(url, final + 6)) or 0
			counter = counter + 1

			toCheck[counter] = { title, messageState == "nouveau", link, totalReplies - (totalReplies - checkedReplies) + 1, totalReplies, conversationId }
		end
	end)

	if #toCheck > 0 then
		local channel = client:getChannel(channels.notifications) -- #notifications
		for topic = 1, #toCheck do
			local message = forumClient:getPage(toCheck[topic][3])

			counter = 0
			local replies = { }
			for reply = toCheck[topic][4], toCheck[topic][5] do
				-- Conversation
				local author, discriminator = string.match(message, '<div id="m' .. reply ..'".-alt="">%s+(%S+)<br/>.-(#%d+)</span>')

				if author then -- Sometimes it does not find the author. (???)
					author = author .. discriminator

					if author ~= account.username then -- Won't notify bot messages
						local text = string.match(message, '>    #' .. reply .. '   </a>    </td> </tr> <tr> .- <div id="message_%d+">(.-)</div> </div>  </div> </td>')

						counter = counter + 1
						replies[counter + 1] = { string.sub(removeHtmlFormat(text), 1, 200), normalizeDiscriminator(normalizePlayerName(author)) }
					end
				end
			end

			if #replies > 0 then -- there must be replies, otherwise the PM was created by the bot
				channel:send({
					embed = {
						color = color.info,
						title = (toCheck[topic][2] and ":envelope_with_arrow:" or ":mailbox_with_mail:") .. " " .. toCheck[topic][1],
						description = "[View conversation](https://atelier801.com/" .. toCheck[topic][3] .. ") - **" .. tostring(toCheck[topic][6]) .. "**\n" .. string.sub(table.fconcat(replies, "\n", function(index, value)
							return "> " .. value[2] .. " ```\n" .. value[1] .. "```"
						end), 1, 1900),
						timestamp = discordia.Date():toISO()
					}
				})
			end
		end
	end
end

local minutes, hours = 0, 0
local clockMin = function()
	minutes = minutes + 1

	if not forumClient:isConnected() or (os.time() > forumClient:getToken_Date()) or (os.time() > ini_time) then -- reconnection
		-- Unsolved error, I guess this if spammed the error logs. Probably the reconnection thing is broken.
		forumClient:login(account.username, account.password, true)
		ini_time = os.time() + 3600 * 10 -- updates every 10h
	elseif minutes == 1 then
		updateLayout()
	end

	if not forumClient:isConnected() then return end

	if minutes == 1 or minutes % 15 == 0 then
		checkPrivateMessages()
	end
	if minutes == 1 or minutes % 20 == 0 then
		local newStatus = table.random(botStatus)
		client:setGame(table.random(newStatus[2]))
		client:setStatus(newStatus[1])
	end
	if minutes == 1 or minutes % 30 == 0 then
		checkApplications()
	end
end
local clockHour = function()
	hours = hours + 1

	-- Change name once per day
	updateLayout()
end

local handleError = {
	min = false,
	hour = false
}
clock:on("min", function()
	local success, err = pcall(clockMin)
	if not success then
		if handleError.min then
			return commands["refresh"].fn()
		else
			handleError.min = true
		end

		client:getChannel(channels.bot_logs):send({ -- #flood channel
			embed = {
				color = color.error,
				title = "clock@Minute => Fatal Error!",
				description = "```\n" .. err .. "```"
			}
		})
	else
		handleError.min = false
	end
end)
clock:on("hour", function()
	local success, err = pcall(clockHour)
	if not success then
		if handleError.hour then
			return commands["refresh"].fn()
		else
			handleError.hour = true
		end

		client:getChannel(channels.bot_logs):send({ -- #flood channel
			embed = {
				color = color.error,
				title = "clock@Hour => Fatal Error!",
				description = "```\n" .. err .. "```"
			}
		})
	else
		handleError.hour = false
	end
end)

client:run(os.readFile("Info/Settings/token", "*l"))