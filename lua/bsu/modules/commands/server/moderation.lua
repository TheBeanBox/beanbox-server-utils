local reasonAutocomplete = {
	"Crashing the server",
	"Prop spam",
	"Voice/Chat spam",
	"Harassment",
	"Hacking/Exploiting",
	"NSFW content",
	"Racism",
}

BSU.SetupCommand("ban", function(cmd)
	cmd:SetDescription("Ban a player")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, caller, target, duration, reason)
		if caller:IsValid() then
			local ban = BSU.GetBanStatus(target:SteamID64())
			if ban and (not ban.admin or not self:CheckCanTargetSteamID(ban.admin)) then
				error("You don't have permission to overwrite this player's ban")
			end
		end

		BSU.BanPlayer(target, reason, duration, caller)

		self:BroadcastActionMsg("%caller% banned %target%<%steamid%>" .. (duration ~= 0 and " for %duration%" or " permanently") .. (reason and " (%reason%)" or ""), {
			target = target,
			steamid = target:SteamID(),
			duration = duration ~= 0 and BSU.StringTime(duration, 10000) or nil,
			reason = reason
		})
	end)
	cmd:AddPlayerArg("target", { check = true })
	cmd:AddNumberArg("duration", { default = 0, min = 0, allowtime = true })
	cmd:AddStringArg("reason", { optional = true, multi = true, autocomplete = reasonAutocomplete })
end)

BSU.SetupCommand("banid", function(cmd)
	cmd:SetDescription("Ban a player by steamid")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, caller, steamid, duration, reason)
		steamid = BSU.ID64(steamid)

		if caller:IsValid() then
			self:CheckCanTargetSteamID(steamid, true) -- make sure caller is allowed to target this person
			local ban = BSU.GetBanStatus(steamid)
			if ban and (not ban.admin or not self:CheckCanTargetSteamID(ban.admin)) then
				error("You don't have permission to overwrite this player's ban")
			end
		end

		BSU.BanSteamID(steamid, reason, duration, caller:IsValid() and caller:SteamID64() or nil)

		local data = BSU.GetPlayerDataBySteamID(steamid)
		local name = data and data.name or nil

		self:BroadcastActionMsg("%caller% banned steamid %steamid%" .. (name and " (%name%)" or "") .. (duration ~= 0 and " for %duration%" or " permanently") .. (reason and " (%reason%)" or ""), {
			steamid = util.SteamIDFrom64(steamid),
			name = name,
			duration = duration ~= 0 and BSU.StringTime(duration, 10000) or nil,
			reason = reason
		})
	end)
	cmd:AddStringArg("steamid")
	cmd:AddNumberArg("duration", { default = 0, min = 0, allowtime = true })
	cmd:AddStringArg("reason", { optional = true, multi = true, autocomplete = reasonAutocomplete })
end)

BSU.SetupCommand("ipban", function(cmd)
	cmd:SetDescription("IP ban a player")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, caller, target, duration, reason)
		BSU.IPBanPlayer(target, reason, duration, caller)

		self:BroadcastActionMsg("%caller% ip banned %target%" .. (duration ~= 0 and " for %duration%" or " permanently") .. (reason and " (%reason%)" or ""), {
			target = target,
			duration = duration ~= 0 and BSU.StringTime(duration, 10000) or nil,
			reason = reason
		})
	end)
	cmd:AddPlayerArg("target", { check = true })
	cmd:AddNumberArg("duration", { default = 0, min = 0, allowtime = true })
	cmd:AddStringArg("reason", { optional = true, multi = true, autocomplete = reasonAutocomplete })
end)

BSU.SetupCommand("banip", function(cmd)
	cmd:SetDescription("Ban a player by ip")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetSilent(true)
	cmd:SetFunction(function(self, caller, ip, duration, reason)
		local data = BSU.GetPlayerDataByIPAddress(ip) -- find any players associated with this ip

		if caller:IsValid() then
			for i = 1, #data do -- make sure caller is allowed to target all of these players
				self:CheckCanTargetSteamID(data[i].steamid, true)
			end
		end

		BSU.BanIP(ip, reason, duration, caller:IsValid() and caller:SteamID64() or nil)

		local names = {}
		for i = 1, #data do
			table.insert(names, data[i].name)
		end

		self:BroadcastActionMsg("%caller% banned an ip" .. (next(names) ~= nil and " (%names%)" or "") .. (duration ~= 0 and " for %duration%" or " permanently") .. (reason and " (%reason%)" or ""), {
			names = next(names) ~= nil and names or nil,
			duration = duration ~= 0 and BSU.StringTime(duration, 10000) or nil,
			reason = reason
		})
	end)
	cmd:AddStringArg("ip")
	cmd:AddNumberArg("duration", { default = 0, min = 0, allowtime = true })
	cmd:AddStringArg("reason", { optional = true, multi = true, autocomplete = reasonAutocomplete })
end)

BSU.SetupCommand("unban", function(cmd)
	cmd:SetDescription("Unban a player by steamid")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, caller, steamid)
		steamid = BSU.ID64(steamid)

		if caller:IsValid() then
			local ban = BSU.GetBanStatus(steamid)
			if ban and (not ban.admin or not self:CheckCanTargetSteamID(ban.admin)) then
				error("You don't have permission to unban this steamid")
			end
		end

		BSU.RevokeSteamIDBan(steamid, caller) -- this also checks if the steam id is actually banned

		local data = BSU.GetPlayerDataBySteamID(steamid)
		local name = data and data.name or nil

		self:BroadcastActionMsg("%caller% unbanned %steamid%" .. (name and " (%name%)" or ""), {
			steamid = util.SteamIDFrom64(steamid),
			name = name
		})
	end)
	cmd:AddStringArg("steamid")
end)

BSU.SetupCommand("unbanip", function(cmd)
	cmd:SetDescription("Unban a player by ip")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetSilent(true)
	cmd:SetFunction(function(self, caller, ip)
		ip = BSU.Address(ip)

		if caller:IsValid() then
			local ban = BSU.GetBanStatus(ip)
			if ban and (not ban.admin or not self:CheckCanTargetSteamID(ban.admin)) then
				error("You don't have permission to unban this ip")
			end
		end

		BSU.RevokeIPBan(ip, caller) -- this also checks if the steam id is actually banned

		local data = BSU.GetPlayerDataByIPAddress(ip)
		local names = {}
		for i = 1, #data do -- get all the names of players associated with this ip
			table.insert(names, data[i].name)
		end

		self:BroadcastActionMsg("%caller% unbanned an ip" .. (next(names) ~= nil and " (%names%)" or ""), {
			names = next(names) ~= nil and names or nil
		})
	end)
	cmd:AddStringArg("ip")
end)

BSU.SetupCommand("superban", function(cmd)
	cmd:SetDescription("Equivalent to the ban command, except it will also ban the account that owns the game license if the player is using Steam Family Sharing")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, caller, target, duration, reason)
		BSU.BanPlayer(target, reason, duration, caller)

		local ownerID = target:OwnerSteamID64()
		if ownerID ~= target:SteamID64() then
			BSU.BanSteamID(ownerID, reason, duration, caller:IsValid() and caller:SteamID64() or nil)
		end

		self:BroadcastActionMsg("%caller% superbanned %target%<%steamid%>" .. (duration ~= 0 and " for %duration%" or " permanently") .. (reason and " (%reason%)" or ""), {
			target = target,
			steamid = target:SteamID(),
			duration = duration ~= 0 and BSU.StringTime(duration, 10000) or nil,
			reason = reason
		})
	end)
	cmd:AddPlayerArg("target", { check = true })
	cmd:AddNumberArg("duration", { default = 0, min = 0, allowtime = true })
	cmd:AddStringArg("reason", { optional = true, multi = true, autocomplete = reasonAutocomplete })
end)

BSU.SetupCommand("superduperban", function(cmd)
	cmd:SetDescription("Equivalent to the superban command, except it will also ip ban the player")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, caller, target, duration, reason)
		BSU.BanPlayer(target, reason, duration, caller)

		local ownerID = target:OwnerSteamID64()
		if ownerID ~= target:SteamID64() then
			BSU.BanSteamID(ownerID, reason, duration, caller:IsValid() and caller:SteamID64() or nil)
		end

		BSU.IPBanPlayer(target, reason, duration, caller)

		self:BroadcastActionMsg("%caller% superduperbanned %target%<%steamid%>" .. (duration ~= 0 and " for %duration%" or " permanently") .. (reason and " (%reason%)" or ""), {
			target = target,
			steamid = target:SteamID(),
			duration = duration ~= 0 and BSU.StringTime(duration, 10000) or nil,
			reason = reason
		})
	end)
	cmd:AddPlayerArg("target", { check = true })
	cmd:AddNumberArg("duration", { default = 0, min = 0, allowtime = true })
	cmd:AddStringArg("reason", { optional = true, multi = true, autocomplete = reasonAutocomplete })
end)

BSU.SetupCommand("voteban", function(cmd)
	cmd:SetDescription("Start a vote to ban a player")
	cmd:SetCategory("utility")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, caller, target, duration, reason)
		if BSU.HasActiveVote(caller) then
			error("You already have a vote active!")
		end

		local title = string.format("Vote To Ban %s %s (%s)", target:Nick(), duration ~= 0 and "for " .. BSU.StringTime(duration, 10000) or "permanently", reason and reason or "No reason given")
		local options = {"Yes", "No"}

		local callerID = caller:SteamID64()
		local targetID = target:SteamID64()

		BSU.StartVote(title, 30, caller, options, function(winner)
			if not winner then
				BSU.SendChatMsg(nil, BSU.CLR_TEXT, "No one voted! (", BSU.CLR_PARAM, title, BSU.CLR_TEXT, ")")
				return
			end

			if winner == "Yes" then
				BSU.SendChatMsg(nil, BSU.CLR_TEXT, "Vote ban passed, ", target, " will now be banned!")
				BSU.BanSteamID(targetID, reason, duration, callerID)
			else
				BSU.SendChatMsg(nil, BSU.CLR_TEXT, "Vote ban failed, ", target, " will NOT be banned!")
			end
		end)

		self:BroadcastActionMsg("%caller% started a vote to ban %target% for %duration% (%title%)", {
			target = target,
			duration = duration ~= 0 and BSU.StringTime(duration, 10000) or nil,
			title = title
		})
	end)
	cmd:AddPlayerArg("target", { check = true })
	cmd:AddNumberArg("duration", { default = 0, min = 0, allowtime = true })
	cmd:AddStringArg("reason", { optional = true, multi = true, autocomplete = reasonAutocomplete })
end)

BSU.SetupCommand("bancheck", function(cmd)
	cmd:SetDescription("Check if a player is banned")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, _, steamid)
		steamid = BSU.ID64(steamid)

		local ban = BSU.GetBanStatus(steamid)
		if not ban then error("This player is not banned!") end

		local admin = ban.admin and string.format("%s<%s>", BSU.GetPlayerDataBySteamID(ban.admin).name, util.SteamIDFrom64(ban.admin)) or "Console"
		local reason = ban.reason or "N/A"
		local banDate = os.date("%c", ban.time)
		local duration = ban.duration or 0
		local unbanDate = duration > 0 and os.date("%c", ban.time + duration * 60) or "Never"

		self:PrintChatMsg(string.format(
			"Admin: %s\nReason: %s\nBan Date: %s\nDuration: %s\nUnban Date: %s",
			admin,
			reason,
			banDate,
			duration > 0 and BSU.StringTime(duration) or "Permanent",
			unbanDate
		))
	end)
	cmd:AddStringArg("steamid")
end)

BSU.SetupCommand("kick", function(cmd)
	cmd:SetDescription("Kick a player")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, caller, target, reason)
		BSU.KickPlayer(target, reason, caller)

		self:BroadcastActionMsg("%caller% kicked %target%<%steamid%>" .. (reason and " (%reason%)" or ""), {
			target = target,
			steamid = target:SteamID(),
			reason = reason
		})
	end)
	cmd:AddPlayerArg("target", { check = true })
	cmd:AddStringArg("reason", { optional = true, multi = true, autocomplete = reasonAutocomplete })
end)

BSU.SetupCommand("votekick", function(cmd)
	cmd:SetDescription("Start a vote to ban a player")
	cmd:SetCategory("utility")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, caller, target, reason)
		if BSU.HasActiveVote(caller) then
			error("You already have a vote active!")
		end

		local title = string.format("Vote To Kick %s (%s)", target:Nick(), reason and reason or "No reason given")
		local options = {"Yes", "No"}

		BSU.StartVote(title, 30, caller, options, function(winner)
			if not winner then
				BSU.SendChatMsg(nil, BSU.CLR_TEXT, "No one voted! (", BSU.CLR_PARAM, title, BSU.CLR_TEXT, ")")
				return
			end

			if winner == "Yes" then
				BSU.SendChatMsg(nil, BSU.CLR_TEXT, "Vote kick passed, ", target, " will now be kicked!")
				if target:IsValid() then BSU.KickPlayer(target, reason, caller) end
			else
				BSU.SendChatMsg(nil, BSU.CLR_TEXT, "Vote kick failed, ", target, " will NOT be kicked!")
			end
		end)

		self:BroadcastActionMsg("%caller% started a vote to kick %target% (%title%)", {target = target, title = title})
	end)
	cmd:AddPlayerArg("target", { check = true })
	cmd:AddStringArg("reason", { optional = true, multi = true, autocomplete = reasonAutocomplete })
end)

local groupAutocomplete = {}
for _, group in ipairs(BSU.GetAllGroups()) do
	table.insert(groupAutocomplete, group.id)
end

BSU.SetupCommand("setgroup", function(cmd)
	cmd:SetDescription("Set the group of a player")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, target, groupid)
		if not BSU.GetGroupByID(groupid) then error("Group does not exist") end
		if BSU.GetPlayerData(target).groupid == groupid then error("Target is already in that group") end

		self:BroadcastActionMsg("%caller% set the group of %target% to %groupid%", {
			target = target,
			groupid = groupid
		})

		BSU.SetPlayerGroup(target, groupid)
	end)
	cmd:AddPlayerArg("target", { check = true })
	cmd:AddStringArg("group", { multi = true, autocomplete = groupAutocomplete })
end)

BSU.SetupCommand("setteam", function(cmd)
	cmd:SetDescription("Set the team of a player")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, target, team)
		local data = BSU.GetTeamByName(team)
		if not data then
			team = tonumber(team)
			if team then data = BSU.GetTeamByID(team) end
		end

		if not data then error("Team does not exist") end
		if BSU.GetPlayerData(target).team == data.id then error("Target is already in that team") end

		self:BroadcastActionMsg("%caller% set the team of %target% to %name%", {
			target = target,
			name = data.name
		})

		BSU.SetPlayerTeam(target, data.id)
	end)
	cmd:AddPlayerArg("target", { check = true })
	cmd:AddStringArg("team", { multi = true })
end)

BSU.SetupCommand("resetteam", function(cmd)
	cmd:SetDescription("Reset the team of a player to use their group's team instead")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, target)
		self:BroadcastActionMsg("%caller% reset the team of %target%", {
			target = target
		})

		BSU.ResetPlayerTeam(target)
	end)
	cmd:AddPlayerArg("target", { check = true })
end)

local privs = {
	misc    = BSU.PRIV_MISC,
	model   = BSU.PRIV_MODEL,
	mdl     = BSU.PRIV_MODEL,
	npc     = BSU.PRIV_NPC,
	sent    = BSU.PRIV_SENT,
	swep    = BSU.PRIV_SWEP,
	tool    = BSU.PRIV_TOOL,
	command = BSU.PRIV_CMD,
	cmd     = BSU.PRIV_CMD
}

local function getPrivFromName(name)
	return privs[string.lower(name)]
end

local names = {
	[BSU.PRIV_MISC]   = "misc",
	[BSU.PRIV_MODEL]  = "model",
	[BSU.PRIV_NPC]    = "npc",
	[BSU.PRIV_SENT]   = "sent",
	[BSU.PRIV_SWEP]   = "swep",
	[BSU.PRIV_TOOL]   = "tool",
	[BSU.PRIV_CMD]    = "command"
}

local function getNameFromPriv(priv)
	return names[priv]
end

local groupprivAutocomplete = {
	"model",
	"mdl",
	"npc",
	"entity",
	"sent",
	"weapon",
	"swep",
	"tool",
	"command",
	"cmd",
	"target",
	"misc",
}

local function checkGroupisValid(groupid)
	local group = BSU.GetGroupByID(groupid)
	if not group then error("Group does not exist") end
	if group.usergroup == "superadmin" then error("This command cannot be used on groups with the 'superadmin' usergroup") end
	return group
end

BSU.SetupCommand("grantgrouppriv", function(cmd)
	cmd:SetDescription("Set a group to have access to a privilege")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, name, value)
		checkGroupisValid(groupid)

		local type = getPrivFromName(name)
		if not type then error("Unknown privilege type") end

		-- command names should be lowercase
		if type == BSU.PRIV_CMD then
			value = string.lower(value)
		end

		local priv = BSU.SQLSelectByValues(BSU.SQL_GROUP_PRIVS, { groupid = groupid, type = type, value = value }, 1)[1]
		if priv and priv.granted then error("Privilege is already granted to this group") end

		BSU.RegisterGroupPrivilege(groupid, type, value, true)

		self:BroadcastActionMsg("%caller% granted the group %groupid% access to %value% (%name%)", {
			groupid = groupid,
			value = value,
			name = getNameFromPriv(type)
		})
	end)
	cmd:AddStringArg("group", { autocomplete = groupAutocomplete })
	cmd:AddStringArg("name", { autocomplete = groupprivAutocomplete })
	cmd:AddStringArg("value", { multi = true })
end)

BSU.SetupCommand("revokegrouppriv", function(cmd)
	cmd:SetDescription("Set a group to not have access to a privilege")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, name, value)
		checkGroupisValid(groupid)

		local type = getPrivFromName(name)
		if not type then error("Unknown privilege type") end

		-- command names should be lowercase
		if type == BSU.PRIV_CMD then
			value = string.lower(value)
		end

		local priv = BSU.SQLSelectByValues(BSU.SQL_GROUP_PRIVS, { groupid = groupid, type = type, value = value }, 1)[1]
		if priv and not priv.granted then error("Privilege is already revoked from this group") end

		BSU.RegisterGroupPrivilege(groupid, type, value, false)

		self:BroadcastActionMsg("%caller% revoked the group %groupid% access from %value% (%name%)", {
			groupid = groupid,
			value = value,
			name = getNameFromPriv(type)
		})
	end)
	cmd:AddStringArg("group", { autocomplete = groupAutocomplete })
	cmd:AddStringArg("name", { autocomplete = groupprivAutocomplete })
	cmd:AddStringArg("value", { multi = true })
end)

BSU.SetupCommand("cleargrouppriv", function(cmd)
	cmd:SetDescription("Clear an existing access override on a group (will use the default access settings)")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, name, value)
		checkGroupisValid(groupid)

		local type = getPrivFromName(name)
		if not type then error("Unknown privilege type") end

		-- command names should be lowercase
		if type == BSU.PRIV_CMD then
			value = string.lower(value)
		end

		local priv = BSU.SQLSelectByValues(BSU.SQL_GROUP_PRIVS, { groupid = groupid, type = type, value = value }, 1)[1]
		if not priv then error("Privilege is not set on this group") end

		BSU.RemoveGroupPrivilege(groupid, type, value)

		self:BroadcastActionMsg("%caller% cleared an access override for the group %groupid% that %kind% access to %value% (%name%)", {
			kind = priv.granted and "granted" or "revoked",
			groupid = groupid,
			value = value,
			name = getNameFromPriv(type),
		})
	end)
	cmd:AddStringArg("group", { autocomplete = groupAutocomplete })
	cmd:AddStringArg("name")
	cmd:AddStringArg("value", { multi = true })
end)

BSU.SetupCommand("setgrouplimit", function(cmd)
	cmd:SetDescription("Set a limit on a group")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, name, amount)
		checkGroupisValid(groupid)

		local limit = BSU.SQLSelectByValues(BSU.SQL_GROUP_LIMITS, { groupid = groupid, name = name }, 1)[1]
		if limit == amount then error("Limit is already set to this amount on this group") end

		BSU.RegisterGroupLimit(groupid, name, amount)

		self:BroadcastActionMsg("%caller% set the limit of %name% to %amount% on the group %groupid%", {
			groupid = groupid,
			amount = amount,
			name = name
		})
	end)
	cmd:AddStringArg("group", { autocomplete = groupAutocomplete })
	cmd:AddStringArg("name")
	cmd:AddNumberArg("amount")
end)

BSU.SetupCommand("cleargrouplimit", function(cmd)
	cmd:SetDescription("Clear an existing limit override on a group (will use the default limit settings)")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, name)
		checkGroupisValid(groupid)

		local limit = BSU.SQLSelectByValues(BSU.SQL_GROUP_LIMITS, { groupid = groupid, name = name }, 1)[1]
		if not limit then error("Limit is not set on this group") end

		BSU.RemoveGroupLimit(groupid, name)

		self:BroadcastActionMsg("%caller% cleared the limit override of %name% on the group %groupid%", {
			groupid = groupid,
			name = name
		})
	end)
	cmd:AddStringArg("group", { autocomplete = groupAutocomplete })
	cmd:AddStringArg("name")
end)

BSU.SetupCommand("setgroupcmdtarget", function(cmd)
	cmd:SetDescription("Set a command target filter for a group")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, command, filter)
		checkGroupisValid(groupid)

		BSU.RegisterCommandTarget(groupid, command, filter)

		self:BroadcastActionMsg("%caller% set a command target filter on the group %groupid% (%command% %filter%)", {
			groupid = groupid,
			command = command,
			filter = filter
		})
	end)
	cmd:AddStringArg("group", { autocomplete = groupAutocomplete })
	cmd:AddStringArg("command")
	cmd:AddStringArg("filter")
end)

BSU.SetupCommand("cleargroupcmdtarget", function(cmd)
	cmd:SetDescription("Clear an existing command target filter for a group")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, command)
		checkGroupisValid(groupid)

		if not BSU.GetCommandTarget(groupid, command) then error("Command target filter is not set on this group") end

		BSU.RemoveCommandTarget(groupid, command)

		self:BroadcastActionMsg("%caller% cleared a command target filter on the group %groupid% (%command%)", {
			groupid = groupid,
			command = command
		})
	end)
	cmd:AddStringArg("group", { autocomplete = groupAutocomplete })
	cmd:AddStringArg("command")
end)

BSU.SetupCommand("setgroupcmdlimit", function(cmd)
	cmd:SetDescription("Set a command limit on a group")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, command, arg, min, max)
		checkGroupisValid(groupid)

		if max < min then error("The min cannot be less than max") end

		BSU.RegisterCommandLimit(groupid, command, arg, min, max)

		self:BroadcastActionMsg("%caller% set a command limit on the group %groupid% (%max% >= %command%.%arg% >= %min%)", {
			groupid = groupid,
			command = command,
			max = max,
			arg = arg,
			min = min,
		})
	end)
	cmd:AddStringArg("group", { autocomplete = groupAutocomplete })
	cmd:AddStringArg("command")
	cmd:AddStringArg("arg")
	cmd:AddNumberArg("min")
	cmd:AddNumberArg("max")
end)

BSU.SetupCommand("cleargroupcmdlimit", function(cmd)
	cmd:SetDescription("Clear an existing command limit on a group")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, command, arg)
		checkGroupisValid(groupid)

		if not BSU.GetCommandLimit(groupid, command, arg) then error("Command limit is not set on this group") end

		BSU.RemoveCommandLimit(groupid, command, arg)

		self:BroadcastActionMsg("%caller% cleared a command limit on the group %groupid% (%command%.%arg%)", {
			groupid = groupid,
			command = command,
			arg = arg,
		})
	end)
	cmd:AddStringArg("group", { autocomplete = groupAutocomplete })
	cmd:AddStringArg("command")
	cmd:AddStringArg("arg")
end)

BSU.SetupCommand("mute", function(cmd)
	cmd:SetDescription("Prevent a player from speaking in text chat")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, _, targets)
		local muted = {}

		for _, v in ipairs(targets) do
			if not v.bsu_muted then
				v.bsu_muted = true
				table.insert(muted, v)
			end
		end

		if next(muted) ~= nil then
			self:BroadcastActionMsg("%caller% muted %muted%", {
				muted = muted
			})
		end
	end)
	cmd:AddPlayersArg("targets", { default = "^", filter = true })
end)

BSU.SetupCommand("unmute", function(cmd)
	cmd:SetDescription("Unmute a player, allowing them to speak in text chat")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, _, targets)
		local unmuted = {}

		for _, v in ipairs(targets) do
			if v.bsu_muted then
				v.bsu_muted = nil
				table.insert(unmuted, v)
			end
		end

		if next(unmuted) ~= nil then
			self:BroadcastActionMsg("%caller% unmuted %unmuted%", {
				unmuted = unmuted
			})
		end
	end)
	cmd:AddPlayersArg("targets", { default = "^", filter = true })
end)

hook.Add("BSU_ChatCommand", "BSU_PlayerMute", function(ply)
	if ply.bsu_muted then return "" end
end)

BSU.SetupCommand("gag", function(cmd)
	cmd:SetDescription("Prevent a player from speaking in voice chat")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, _, targets)
		local gagged = {}

		for _, v in ipairs(targets) do
			if not v.bsu_gagged then
				v.bsu_gagged = true
				table.insert(gagged, v)
			end
		end

		if next(gagged) ~= nil then
			self:BroadcastActionMsg("%caller% gagged %gagged%", {
				gagged = gagged
			})
		end
	end)
	cmd:AddPlayersArg("targets", { default = "^", filter = true })
end)

BSU.SetupCommand("ungag", function(cmd)
	cmd:SetDescription("Ungag a player, allowing them to speak in voice chat again")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, _, targets)
		local ungagged = {}

		for _, v in ipairs(targets) do
			if v.bsu_gagged then
				v.bsu_gagged = nil
				table.insert(ungagged, v)
			end
		end

		if next(ungagged) ~= nil then
			self:BroadcastActionMsg("%caller% ungagged %ungagged%", {
				ungagged = ungagged
			})
		end
	end)
	cmd:AddPlayersArg("targets", { default = "^", filter = true })
end)

hook.Add("PlayerCanHearPlayersVoice", "BSU_PlayerGag", function(_, speaker)
	if speaker.bsu_gagged then return false end
end)
