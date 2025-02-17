-- lib/commands.lua (SHARED)

local groupChars = {
	'"',
	"'"
}

-- parse a string to command arguments (set inclusive to true to leave the group chars in the result)
local function parseArgs(input, inclusive)
	local index, args = 1, {}

	while true do
		local str = string.sub(input, index)

		-- look for group chars
		local foundGroupChars = {}
		for i = 1, #groupChars do
			local char = groupChars[i]
			local pos = string.find(str, char, 1, true)
			if pos then
				foundGroupChars[#foundGroupChars + 1] = { char, pos }
			end
		end

		local found

		if next(foundGroupChars) ~= nil then
			table.sort(foundGroupChars, function(a, b) return a[2] < b[2] end)

			for i = 1, #foundGroupChars do
				local char, pos1 = unpack(foundGroupChars[i])
				local pos2 = string.find(str, char, pos1 + 1, true)
				if pos2 then
					-- add before args separated by spaces
					local split = string.Split(string.sub(str, 1, pos1 - 1), " ")
					if args[#args] then
						args[#args] = args[#args] .. table.remove(split, 1) -- append first string to last arg
					end
					table.Add(args, split) -- add the rest

					args[#args] = args[#args] .. string.sub(str, pos1 + (inclusive and 0 or 1), pos2 - (inclusive and 0 or 1)) -- append string to last arg
					index = index + pos2
					found = true
					break
				end
			end
		end

		if found then continue end

		-- add args separated by spaces
		local split = string.Split(str, " ")
		if args[#args] then
			args[#args] = args[#args] .. table.remove(split, 1) -- append first string to last arg
		end
		table.Add(args, split) -- add the rest
		break
	end

	-- remove any empty string args
	local newArgs = {}
	for i = 1, #args do
		local arg = args[i]
		if arg ~= "" then
			table.insert(newArgs, arg)
		end
	end

	return newArgs
end

local playerArgPrefixes = {
	["^"] = function(str, pre, caller) -- the caller
		if str == pre then return { caller } end
	end,
	["*"] = function(str, pre) -- all players
		if str == pre then return player.GetAll() end
	end,
	["@"] = function(str, pre, caller) -- the player the caller is looking at
		if str ~= pre then return end
		if not caller:IsValid() then return end
		local ent = caller:GetEyeTrace().Entity
		if IsValid(ent) and ent:IsPlayer() then return { ent } end
	end,
	["$"] = function(str) -- the player with the userid or steamid
		local val = string.sub(str, 2)
		local ply = Player(tonumber(val) or -1)
		if ply:IsValid() then return { ply } end
		if not BSU.IsValidSteamID(val) then return end
		ply = player.GetBySteamID64(BSU.ID64(val))
		if IsValid(ply) and ply:IsPlayer() then return { ply } end
	end,
	["#"] = function(str) -- all players in the group
		local val = string.lower(string.sub(str, 2))
		local found = {}
		for _, ply in player.Iterator() do
			if val == BSU.GetPlayerData(ply).groupid then
				found[#found + 1] = ply
			end
		end
		return found
	end,
	["%"] = function(str) -- all players in the group (with inheritance)
		local val = string.lower(string.sub(str, 2))
		local groups = { [val] = true }
		local found = {}
		for _, ply in player.Iterator() do
			local groupid = BSU.GetPlayerData(ply).groupid
			if groups[groupid] == nil then
				while true do
					local inherit = BSU.GetGroupInherit(groupid)
					if not inherit then
						groups[groupid] = false
						break
					end
					if groups[inherit] then
						groups[groupid] = true
						break
					end
					groupid = inherit
				end
			end
			if groups[groupid] then
				found[#found + 1] = ply
			end
		end
		return found
	end
}

local function parsePlayerArgPrefix(caller, str)
	local pre = string.sub(str, 1, 1)

	-- parse argument but take opposite of result
	if pre == "!" then
		local val = string.sub(str, 2)
		local result = parsePlayerArgPrefix(caller, val)

		-- create lookup table from result
		local tbl = {}
		for _, ply in ipairs(result) do
			tbl[ply] = true
		end

		-- get all players not in the lookup table
		local found = {}
		for _, ply in player.Iterator() do
			if not tbl[ply] then
				found[#found + 1] = ply
			end
		end
		return found
	end

	local func = playerArgPrefixes[pre]
	return func and func(str, pre, caller) or {}
end

-- returns table of players found using a prefixed command argument
local function parsePlayerArg(caller, str)
	str = parseArgs(str)[1]
	if not str then return {} end
	str = string.Trim(str)
	if str == "" then return {} end

	-- if seperated by comma, parse each string and merge results
	do
		local strs = string.Split(str, ",")
		if #strs > 1 then
			local tbl = {} -- lookup table of players so we don't get duplicates
			for _, s in ipairs(strs) do
				local result = parsePlayerArg(caller, s)
				for _, ply in ipairs(result) do
					tbl[ply] = true
				end
			end

			local found = {}
			for ply, _ in pairs(tbl) do
				found[#found + 1] = ply
			end
			return found
		end
	end

	-- check if the argument matches any player names
	do
		local find = string.lower(str)
		local found = {}

		for _, ply in player.Iterator() do
			local name = string.lower(ply:Nick())
			if name == find then -- found exact name
				return { ply }
			elseif #find >= 3 then -- must be a minimum of 3 characters for partial search
				if string.find(name, find, 1, true) then
					found[#found + 1] = ply
				end
			end
		end

		if next(found) ~= nil then
			return found
		end
	end

	-- check if the argument has a special prefix
	return parsePlayerArgPrefix(caller, str)
end

-- holds command objects
BSU._cmds = BSU._cmds or {}
BSU._cmdlist = BSU._cmdlist or {}

-- command object
local objCommand = {}
objCommand.__index = objCommand
objCommand.__tostring = function(self) return "BSU Command[" .. self.name .. "]" end

-- command object setters

function objCommand.SetDescription(self, desc)
	self.desc = desc and tostring(desc) or ""
end

function objCommand.SetCategory(self, category)
	self.category = category and string.lower(category) or "misc"
end

function objCommand.SetAccess(self, access)
	self.access = access or BSU.CMD_ANYONE
end

function objCommand.SetSilent(self, silent)
	self.silent = silent
end

function objCommand.SetValidCaller(self, validcaller)
	self.validcaller = validcaller
end

function objCommand.SetFunction(self, func)
	self.func = func
end

-- command object getters

function objCommand.GetName(self)
	return self.name
end

function objCommand.GetDescription(self)
	return self.desc
end

function objCommand.GetCategory(self)
	return self.category
end

function objCommand.GetAccess(self)
	return self.access
end

function objCommand.GetSilent(self)
	return self.silent
end

function objCommand.GetValidCaller(self)
	return self.validcaller
end

function objCommand.GetFunction(self)
	return self.func
end

function objCommand.GetArgs(self)
	return self.args
end

-- command object add arguments

function objCommand.AddStringArg(self, name, data)
	data = data or {}
	table.insert(self.args, {
		kind = 0,
		name = string.lower(name),
		optional = data.optional or false,
		default = data.default,
		multi = data.multi or false,
		autocomplete = data.autocomplete
	})
end

function objCommand.AddNumberArg(self, name, data)
	data = data or {}
	table.insert(self.args, {
		kind = 1,
		name = string.lower(name),
		optional = data.optional or false,
		default = data.default,
		min = data.min,
		max = data.max,
		allowtime = data.allowtime or false,
		autocomplete = data.autocomplete
	})
end

function objCommand.AddPlayerArg(self, name, data)
	data = data or {}
	table.insert(self.args, {
		kind = 2,
		name = string.lower(name),
		optional = data.optional or false,
		default = data.default,
		check = data.check or false
	})
end

function objCommand.AddPlayersArg(self, name, data)
	data = data or {}
	table.insert(self.args, {
		kind = 3,
		name = string.lower(name),
		optional = data.optional or false,
		default = data.default,
		filter = data.filter or false
	})
end

-- create a command object
function BSU.Command(name, desc, category, access, silent, validcaller, func)
	local cmd = setmetatable({
		name = string.lower(name),
		desc = desc or "",
		category = category or "misc",
		access = access or BSU.CMD_ANYONE,
		silent = silent or false,
		validcaller = validcaller or false,
		func = func or function() end,
		args = {}
	}, objCommand)
	cmd.__index = cmd
	cmd.__tostring = objCommand.__tostring
	return cmd
end

function BSU.RegisterCommand(cmd)
	BSU.RemoveCommand(cmd)
	BSU._cmds[string.lower(cmd:GetName())] = cmd
	local category = string.lower(cmd:GetCategory())
	BSU._cmdlist[category] = BSU._cmdlist[category] or {}
	table.insert(BSU._cmdlist[category], cmd)
end

function BSU.RemoveCommand(cmd)
	local name = string.lower(cmd:GetName())
	if not BSU._cmds[name] then return end
	BSU._cmds[name] = nil
	local category = string.lower(cmd:GetCategory())
	if not BSU._cmdlist[category] then return end
	for k, v in ipairs(BSU._cmdlist[category]) do
		if v == cmd then
			table.remove(BSU._cmdlist[category][k])
			if next(BSU._cmdlist[category]) == nil then BSU._cmdlist[category] = nil end
			break
		end
	end
end

function BSU.SetupCommand(name, setup)
	local cmd = BSU.Command(name)
	if setup then setup(cmd) end
	BSU.RegisterCommand(cmd)
end

function BSU.AliasCommand(alias, name)
	name = string.lower(name)
	local cmd = BSU._cmds[name]
	if getmetatable(cmd) ~= objCommand then error("invalid command, is it already an alias?") end
	BSU.RegisterCommand(setmetatable({
		name = alias,
		desc = "Alias of " .. name,
	}, cmd))
end

function BSU.GetAllCommands()
	return table.ClearKeys(BSU._cmds)
end

function BSU.GetAllCommandNames()
	return table.GetKeys(BSU._cmds)
end

function BSU.GetCommandByName(name)
	return BSU._cmds[string.lower(name)]
end

function BSU.GetCommandsByCategory(category)
	local list = {}
	for _, cmd in ipairs(BSU._cmdlist[string.lower(category)]) do
		table.insert(list, cmd)
	end
	return list
end

function BSU.GetCommandsByAccess(access)  -- only used serverside, is pointless clientside but kept for shared scripts
	local list = {}
	for _, cmd in pairs(BSU._cmds) do
		if cmd.access == access then
			table.insert(list, cmd)
		end
	end
	return list
end

function BSU.GetCommandList()
	local categories = table.GetKeys(BSU._cmdlist)
	table.sort(categories, function(a, b) return a < b end)
	local list = {}
	for _, category in ipairs(categories) do
		for _, cmd in ipairs(BSU._cmdlist[category]) do
			table.insert(list, cmd)
		end
	end
	return list
end

function BSU.GetCommandCategories()
	local categories = table.GetKeys(BSU._cmdlist)
	table.sort(categories, function(a, b) return a < b end)
	return categories
end

-- command handler object
local objCmdHandler = {}
objCmdHandler.__index = objCmdHandler
objCmdHandler.__tostring = function(self) return "BSU Command Handler[" .. self.name .. "]" end

function objCmdHandler.GetCommand(self)
	return self.cmd
end

function objCmdHandler.GetCaller(self, fail)
	if SERVER and fail and not self.caller:IsValid() then
		error("Unable to find player who called the command (was ran from server console?)")
	end
	return self.caller
end

local function errorBadArgument(num, reason)
	error("Bad argument #" .. num .. " (" .. reason .. ")")
end

-- used for getting the original string of the argument
function objCmdHandler.GetRawStringArg(self, n, fail)
	local arg = self.args[n]
	if arg then
		return arg
	elseif fail then
		errorBadArgument(n, "expected string, found nothing")
	end
end

-- used for getting the string of the argument but parsed
function objCmdHandler.GetStringArg(self, n, fail)
	local str = self:GetRawStringArg(n, fail)
	if str then
		return parseArgs(str)[1]
	elseif fail then
		errorBadArgument(n, "expected string, found nothing")
	end
end

-- used for getting multiple original string arguments as a single string
function objCmdHandler.GetRawMultiStringArg(self, n1, n2, fail)
	if n1 < 0 then
		n1 = #self.args + n1 + 1
	end
	if n2 then
		if n2 < 0 then
			n2 = #self.args + n2 + 1
		end
	else
		n2 = #self.args
	end

	if n1 ~= n2 then -- get unparsed arguments from n1 to n2
		local str
		for i = n1, n2 do
			local arg = self.args[i]
			if arg then
				if not str then
					str = arg
				else
					str = str .. " " .. arg
				end
			else
				break
			end
		end
		if str then
			return str
		elseif fail then
			errorBadArgument(n1, "expected string, found nothing")
		end
	end
	local arg = self.args[n1]
	if arg then
		return arg
	elseif fail then
		errorBadArgument(n1, "expected string, found nothing")
	end
end

-- used for getting multiple parsed string arguments as a single string
function objCmdHandler.GetMultiStringArg(self, n1, n2, fail)
	local str = self:GetRawMultiStringArg(n1, n2, fail)
	if str then
		return table.concat(parseArgs(str), " ") -- parse and concat back to string
	elseif fail then
		errorBadArgument(n1, "expected string, found nothing")
	end
end

-- used for getting an argument parsed as a number (will fail if it couldn't be converted to a number)
function objCmdHandler.GetNumberArg(self, n, fail)
	local arg = self.args[n]
	if arg then
		local val = tonumber(arg)
		if val then
			return val
		elseif fail then
			errorBadArgument(n, "failed to interpret '" .. arg .. "' as a number")
		end
	elseif fail then
		errorBadArgument(n, "expected number, got nothing")
	end
end

-- used for getting an argument parsed as a target (will fail if none or more than 1 targets are found)
function objCmdHandler.GetPlayerArg(self, n, fail)
	local arg = self.args[n]
	if arg then
		local plys = parsePlayerArg(self.caller, arg)
		if #plys == 1 then
			local ply = plys[1]
			if ply:IsValid() then
				return ply
			elseif fail then
				errorBadArgument(n, "target was invalid")
			end
		elseif fail then
			if next(plys) == nil then
				errorBadArgument(n, "failed to find a target")
			else
				errorBadArgument(n, "received too many targets")
			end
		end
	elseif fail then
		errorBadArgument(n, "expected target, found nothing")
	end
end

-- used for getting an argument parsed as 1 or more targets (will fail if none are found)
function objCmdHandler.GetPlayersArg(self, n, fail)
	local arg = self.args[n]
	if arg then
		local plys = parsePlayerArg(self.caller, arg)
		if next(plys) ~= nil then
			return plys
		elseif fail then
			errorBadArgument(n, "failed to find any targets")
		end
	elseif fail then
		errorBadArgument(n, "expected targets, found nothing")
	end
end

local function stringTimeToMins(str)
	if str == nil then return end
	str = string.gsub(str, "%s", "")
	if str == "" then return end

	local mins = 0
	local pos = string.find(str, "%a")
	while pos do
		local char = string.sub(str, pos, pos)
		local num = tonumber(string.sub(str, 1, pos - 1))
		if not num then return end

		local multiplier
		if char == "h" then
			multiplier = 60
		elseif char == "d" then
			multiplier = 60 * 24
		elseif char == "w" then
			multiplier = 60 * 24 * 7
		elseif char == "y" then
			multiplier = 60 * 24 * 365
		else
			return
		end

		str = string.sub(str, pos + 1)
		pos = string.find(str, "%a")
		mins = mins + num * multiplier
	end

	if str ~= "" then
		local num = tonumber(str)
		if not num then return end
		mins = mins + num
	end

	return mins
end

local function getStringArg(args, n, multi)
	if multi then
		local str
		for i = n, #args do
			local arg = args[i]
			if arg then
				if str then
					str = str .. " " .. arg
				else
					str = arg
				end
			else
				break
			end
		end
		if str then
			return table.concat(parseArgs(str), " ")
		else
			return nil, "expected string, found nothing"
		end
	else
		local arg = args[n]
		if arg then
			return parseArgs(arg)[1]
		else
			return nil, "expected string, found nothing"
		end
	end
end

local function getNumberArg(arg, allowtime)
	if arg then
		local num = allowtime and stringTimeToMins(arg) or tonumber(arg)
		if num then
			return num
		else
			return nil, "failed to interpret argument as a number"
		end
	else
		return nil, "expected number, got nothing"
	end
end

local function getPlayerArg(arg, caller)
	if arg then
		local plys = parsePlayerArg(caller, arg)
		if #plys == 1 then
			local ply = plys[1]
			if ply:IsValid() then
				return ply
			else
				return nil, "target was invalid"
			end
		else
			if next(plys) == nil then
				return nil, "failed to find a target"
			else
				return nil, "received too many targets"
			end
		end
	else
		return nil, "expected target, found nothing"
	end
end

local function getPlayersArg(arg, caller)
	if arg then
		local plys = parsePlayerArg(caller, arg)
		if next(plys) ~= nil then
			return plys
		else
			return nil, "failed to find any targets"
		end
	else
		return nil, "expected targets, found nothing"
	end
end

function objCmdHandler.GetArgs(self)
	local groupid = SERVER and self.caller:IsPlayer() and BSU.GetPlayerData(self.caller).groupid

	local args = {}

	local n = 1
	for k, v in ipairs(self.cmd.args) do
		if v.kind == 0 then -- string
			local arg, err = getStringArg(self.args[n] and self.args or { [n] = v.default }, n, v.multi)
			if err then
				if not v.optional then errorBadArgument(n, err) end
				n = n - 1
			end
			args[k] = arg
		elseif v.kind == 1 then -- number
			local arg, err = getNumberArg(self.args[n] or v.default, v.allowtime)
			if err then
				if not v.optional then errorBadArgument(n, err) end
				n = n - 1
			end
			if arg then
				local limit = groupid and BSU.GetCommandLimit(groupid, self.cmd.name, v.name) or {}

				if limit.min then arg = math.max(arg, limit.min)
				elseif v.min then arg = math.max(arg, v.min) end

				if limit.max then arg = math.min(arg, limit.max)
				elseif v.max then arg = math.min(arg, v.max) end
			end
			args[k] = arg
		elseif v.kind == 2 then -- player
			local arg, err = getPlayerArg(self.args[n] or v.default, self.caller)
			if err then
				if not v.optional then errorBadArgument(n, err) end
				n = n - 1
			end
			if SERVER and arg and v.check then arg = self:CheckCanTarget(arg, not v.optional) and arg or nil end
			args[k] = arg
		elseif v.kind == 3 then -- players
			local arg, err = getPlayersArg(self.args[n] or v.default, self.caller)
			if err then
				if not v.optional then errorBadArgument(n, err) end
				n = n - 1
			end
			if SERVER and arg and v.filter then arg = self:FilterTargets(arg, not v.optional) end
			args[k] = arg
		end
		n = n + 1
	end

	return unpack(args, 1, #self.cmd.args)
end

function objCmdHandler.GetSilent(self)
	return self.silent
end

if SERVER then
	local targetPrefixes = {
		["^"] = function(str, pre, steamid, targetid) -- if self
			return str == pre and steamid == targetid
		end,
		["*"] = function(str, pre) -- always
			return str == pre
		end,
		["$"] = function(str, _, _, targetid) -- if matches targetid
			local val = string.sub(str, 2)
			return targetid == val
		end,
		["#"] = function(str, _, _, targetid) -- if targetid in group
			local data = BSU.GetPlayerDataBySteamID(targetid)
			if not data then return false end
			local val = string.lower(string.sub(str, 2))
			print(targetid, data.groupid, val)
			return data.groupid == val
		end,
		["%"] = function(str, _, _, targetid) -- if targetid in group (with inheritance)
			local data = BSU.GetPlayerDataBySteamID(targetid)
			if not data then return false end
			local val = string.lower(string.sub(str, 2))
			local groupid = data.groupid
			if groupid == val then return true end
			while true do
				local inherit = BSU.GetGroupInherit(groupid)
				if not inherit then return false end
				if inherit == val then return true end
				groupid = inherit
			end
		end
	}

	local function parseTargetPrefix(steamid, targetid, str)
		local pre = string.sub(str, 1, 1)

		-- parse argument but take opposite of result
		if pre == "!" then
			local val = string.sub(str, 2)
			return not parseTargetPrefix(steamid, targetid, val)
		end

		local func = targetPrefixes[pre]
		return func and func(str, pre, steamid, targetid) or false
	end

	function objCmdHandler.CheckCanTargetSteamID(self, targetid, fail)
		local caller = self.caller
		if not caller:IsValid() or caller:IsSuperAdmin() then return true end

		targetid = BSU.ID64(targetid)

		local target = player.GetBySteamID64(targetid)
		if IsValid(target) then return self:CheckCanTarget(target, fail) end

		if hook.Run("BSU_OnCommandCheckCanTargetSteamID", self, targetid) == false then
			if fail then error("You cannot target this player") end
			return false
		end

		local cantarget = BSU.GetGroupCanTarget(BSU.GetPlayerData(caller).groupid, self.cmd.name)

		local steamid = caller:SteamID64()

		-- parse prefix strings until one of them allows targeting targetid
		local strs = string.Split(cantarget, ",")
		for _, s in ipairs(strs) do
			local result = parseTargetPrefix(steamid, targetid, s)
			if result then return true end
		end

		if fail then error("You cannot target this player") end
		return false
	end

	function objCmdHandler.FilterTargets(self, targets, fail)
		local caller = self.caller

		local num = #targets
		local found = {}

		-- if console or superadmin, return all targets
		if not caller:IsValid() or caller:IsSuperAdmin() then
			for i = 1, num do
				found[#found + 1] = targets[i]
			end
			return found
		end

		local remaining = {}

		for i = 1, num do
			local ply = targets[i]
			-- check if a hook wants to override target filtering
			local allow = hook.Run("BSU_OnCommandCheckCanTarget", self, ply)
			if allow ~= nil then
				if allow then found[#found + 1] = ply end
			else
				remaining[ply] = true
			end
		end

		if next(remaining) == nil then
			if fail and next(found) == nil then
				error("You cannot select " .. (num == 1 and "this target" or "these targets"))
			end
			return found
		end

		local cantarget = BSU.GetGroupCanTarget(BSU.GetPlayerData(caller).groupid, self.cmd.name)

		-- parse prefix strings until the remaining are found
		local strs = string.Split(cantarget, ",")
		for _, s in ipairs(strs) do
			local result = parsePlayerArgPrefix(caller, s)
			for _, ply in ipairs(result) do
				if remaining[ply] then
					remaining[ply] = nil
					found[#found + 1] = ply
					if next(remaining) == nil then
						return found
					end
				end
			end
		end

		if fail and next(found) == nil then
			error("You cannot select " .. (num == 1 and "this target" or "these targets"))
		end
		return found
	end

	function objCmdHandler.CheckCanTarget(self, target, fail)
		return next(self:FilterTargets({ target }, fail)) ~= nil
	end

	local function addColoredText(tbl, clr, str)
		local num = #tbl
		tbl[num + 1] = clr
		tbl[num + 2] = str
	end

	local function addFormattedArg(tbl, ply, target, arg)
		if istable(arg) then
			local num = 0
			for _, v in ipairs(arg) do
				if isentity(v) and v:IsPlayer() then
					num = num + 1
				end
			end
			if num > 1 and num == player.GetCount() then
				addColoredText(tbl, BSU.CLR_EVERYONE, "Everyone")
			else
				for k, v in ipairs(arg) do -- expect table arg to be sequential
					if istable(v) then continue end -- ignore tables in table arg (can cause weird formatting or infinite recursion)
					if k > 1 then
						addColoredText(tbl, BSU.CLR_TEXT, k < #arg and ", " or (#arg > 2 and ", and " or " and "))
					end
					addFormattedArg(tbl, ply, target, v)
				end
			end
		elseif isentity(arg) then
			if arg:IsPlayer() then
				if arg == ply then
					addColoredText(tbl, BSU.CLR_SELF, arg == target and "Yourself" or "Themself")
				else
					addColoredText(tbl, team.GetColor(arg:Team()), arg:Nick())
				end
			else
				addColoredText(tbl, BSU.CLR_MISC, tostring(arg))
			end
		else
			addColoredText(tbl, BSU.CLR_PARAM, tostring(arg))
		end
	end

	function objCmdHandler.FormatMsg(self, ply, target, msg, args)
		local tbl = {}
		local pos = 1

		for pre, name in string.gmatch(msg, "(.-)%%([%w_]+)%%") do
			addColoredText(tbl, BSU.CLR_TEXT, pre)

			local arg = args[name]
			if arg ~= nil then
				addFormattedArg(tbl, ply, target, arg)
			elseif name == "caller" then
				if ply:IsValid() then
					if ply == target then
						addColoredText(tbl, BSU.CLR_SELF, "You")
					else
						addColoredText(tbl, team.GetColor(ply:Team()), ply:Nick())
					end
				else
					addColoredText(tbl, BSU.CLR_CONSOLE, "(Console)")
				end
			end

			pos = pos + #pre + #name + 2
		end

		local last = string.sub(msg, pos)
		if #last > 0 then -- add last part of the msg
			addColoredText(tbl, BSU.CLR_TEXT, last)
		end

		return unpack(tbl)
	end

	-- send a formatted message to players (expects a player or NULL entity, or a table that can include both)
	function objCmdHandler.SendFormattedMsg(self, plys, msg, args)
		if not plys then
			plys = player.GetHumans()
			table.insert(plys, NULL) -- NULL entity = server console
		elseif not istable(plys) then
			plys = { plys }
		end

		for _, v in ipairs(plys) do
			BSU.SendChatMsg(v, self:FormatMsg(self.caller, v, msg, args))
		end
	end

	local function getAdminLevel(ply)
		if not ply:IsValid() then return 3 end -- server console is considered higher than superadmin
		if ply:IsSuperAdmin() then return 2 end
		if ply:IsAdmin() then return 1 end
		return 0
	end

	function objCmdHandler.CanSeeCommandAction(self, target)
		local val = hook.Run("BSU_CanSeeCommandAction", target, self)
		if val ~= nil then return val ~= false end

		if not self.silent then return true end -- allow if not silent

		local caller = self.caller
		if target == caller then return true end -- allow if target is caller

		local tadmin = getAdminLevel(target)
		if tadmin < 1 then return false end -- disallow if not admin

		local cadmin = getAdminLevel(caller)

		return tadmin >= cadmin -- allow if target is equal or higher admin than caller
	end

	-- broadcast a formatted message (intended for command actions)
	function objCmdHandler.BroadcastActionMsg(self, msg, args)
		if not istable(plys) then plys = { plys } end
		local silent = self.silent or BSU._cmds[self.cmd.name].silent
		if silent then msg = "(SILENT) " .. msg end
		args = args or {}

		local caller = self.caller

		for _, target in ipairs(player.GetHumans()) do
			if self:CanSeeCommandAction(target) then
				local val = math.floor(target:GetInfoNum(silent and "bsu_show_silent_actions" or "bsu_show_actions", 2))
				if val == 2 then
					BSU.SendChatMsg(target, self:FormatMsg(caller, target, msg, args))
				elseif val == 1 then
					BSU.SendConsoleMsg(target, self:FormatMsg(caller, target, msg, args))
				end
			end
		end

		BSU.SendConsoleMsg(NULL, self:FormatMsg(caller, NULL, msg, args)) -- also send to server console (SendChatMsg also works for server console)
	end
end

-- print a message to the caller in chat
function objCmdHandler.PrintChatMsg(self, ...)
	if SERVER then
		BSU.SendChatMsg(self.caller, ...)
	else
		chat.AddText(...)
	end
end

-- print a message to the caller in console
function objCmdHandler.PrintConsoleMsg(self, ...)
	if SERVER then
		BSU.SendConsoleMsg(self.caller, ...)
	else
		BSU.SendConsoleMsg(...)
	end
end

-- print an error message to the caller
function objCmdHandler.PrintErrorMsg(self, err)
	self:PrintChatMsg(BSU.CLR_ERROR, err)
end

-- used for a command to check if it should process something on a player
function objCmdHandler.SetExclusive(self, ply, action)
	ply.bsu_exclusive = action
end

function objCmdHandler.CheckExclusive(self, ply, warn)
	if not ply.bsu_exclusive then return true end
	if warn then
		self:PrintErrorMsg((ply == self.caller and "You are " or (ply:Nick() .. " is ")) .. ply.bsu_exclusive .. "!")
	end
	return false
end

function objCmdHandler.ClearExclusive(self, ply)
	ply.bsu_exclusive = nil
end

-- create a command handler object
function BSU.CommandHandler(caller, cmd, argStr, silent)
	return setmetatable({
		caller = caller,
		cmd = cmd,
		args = argStr and parseArgs(argStr, true) or "",
		silent = silent or false
	}, objCmdHandler)
end

