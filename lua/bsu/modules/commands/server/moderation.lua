BSU.SetupCommand("ban", function(cmd)
	cmd:SetDescription("Ban a player")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, caller, target, duration, reason)
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
	cmd:AddStringArg("reason", { optional = true, multi = true })
end)

BSU.SetupCommand("banid", function(cmd)
	cmd:SetDescription("Ban a player by steamid")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, caller, steamid, duration, reason)
		steamid = BSU.ID64(steamid)

		self:CheckCanTargetSteamID(steamid, true) -- make sure caller is allowed to target this person

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
	cmd:AddStringArg("reason", { optional = true, multi = true })
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
	cmd:AddStringArg("reason", { optional = true, multi = true })
end)

BSU.SetupCommand("banip", function(cmd)
	cmd:SetDescription("Ban a player by ip")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetSilent(true)
	cmd:SetFunction(function(self, caller, ip, duration, reason)
		local data = BSU.GetPlayerDataByIPAddress(ip) -- find any players associated with this ip
		for i = 1, #data do -- make sure caller is allowed to target all of these players
			self:CheckCanTargetSteamID(data[i].steamid, true)
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
	cmd:AddStringArg("reason", { optional = true, multi = true })
end)

BSU.SetupCommand("unban", function(cmd)
	cmd:SetDescription("Unban a player")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, caller, steamid)
		steamid = BSU.ID64(steamid)

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

		BSU.RevokeIPBan(ip, caller) -- this also checks if the steam id is actually banned

		local data, names = BSU.GetPlayerDataByIPAddress(ip), {}
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
	cmd:AddStringArg("reason", { optional = true, multi = true })
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
	cmd:AddStringArg("reason", { optional = true, multi = true })
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
	cmd:AddStringArg("reason", { optional = true, multi = true })
end)

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
	cmd:AddStringArg("group", { multi = true })
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
	model   = BSU.PRIV_MODEL,
	mdl     = BSU.PRIV_MODEL,
	npc     = BSU.PRIV_NPC,
	sent    = BSU.PRIV_SENT,
	entity  = BSU.PRIV_SENT,
	swep    = BSU.PRIV_SWEP,
	weapon  = BSU.PRIV_SWEP,
	tool    = BSU.PRIV_TOOL,
	command = BSU.PRIV_CMD,
	cmd     = BSU.PRIV_CMD,
	target  = BSU.PRIV_TARGET,
	misc    = BSU.PRIV_MISC,
}

local function getPrivFromName(name)
	return privs[string.lower(name)]
end

local names = {
	[BSU.PRIV_MODEL]  = "model",
	[BSU.PRIV_NPC]    = "npc",
	[BSU.PRIV_SENT]   = "entity",
	[BSU.PRIV_SWEP]   = "weapon",
	[BSU.PRIV_TOOL]   = "tool",
	[BSU.PRIV_CMD]    = "command",
	[BSU.PRIV_TARGET] = "target",
	[BSU.PRIV_MISC]   = "misc",
}

local function getNameFromPriv(priv)
	return names[priv]
end

BSU.SetupCommand("grantgrouppriv", function(cmd)
	cmd:SetDescription("Set a group to have access to a privilege")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, name, value)
		local group = BSU.GetGroupByID(groupid)
		if not group then error("Group does not exist") end
		if group.usergroup == "superadmin" then error("Group is in the 'superadmin' usergroup and thus already has access to everything") end

		local type = getPrivFromName(name)
		if not type then error("Unknown privilege type") end

		-- command names should be lowercase
		if type == BSU.PRIV_CMD or type == BSU.PRIV_TARGET then
			value = string.lower(value)
		end

		local priv = BSU.SQLSelectByValues(BSU.SQL_GROUP_PRIVS, { groupid = groupid, type = type, value = value })[1]
		if priv and priv.granted ~= 0 then error("Privilege is already granted to this group") end

		BSU.RegisterGroupPrivilege(groupid, type, value, true)

		self:BroadcastActionMsg("%caller% granted the group %groupid% access to %value% (%name%)", {
			groupid = groupid,
			value = value,
			name = getNameFromPriv(type)
		})
	end)
	cmd:AddStringArg("group")
	cmd:AddStringArg("name")
	cmd:AddStringArg("value", { multi = true })
end)

BSU.SetupCommand("revokegrouppriv", function(cmd)
	cmd:SetDescription("Set a group to not have access to a privilege")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, name, value)
		local group = BSU.GetGroupByID(groupid)
		if not group then error("Group does not exist") end
		if group.usergroup == "superadmin" then error("Group is in the 'superadmin' usergroup and thus cannot be restricted from anything") end

		local type = getPrivFromName(name)
		if not type then error("Unknown privilege type") end

		-- command names should be lowercase
		if type == BSU.PRIV_CMD or type == BSU.PRIV_TARGET then
			value = string.lower(value)
		end

		local priv = BSU.SQLSelectByValues(BSU.SQL_GROUP_PRIVS, { groupid = groupid, type = type, value = value })[1]
		if priv and priv.granted == 0 then error("Privilege is already revoked from this group") end

		BSU.RegisterGroupPrivilege(groupid, type, value, false)

		self:BroadcastActionMsg("%caller% revoked the group %groupid% access from %value% (%name%)", {
			groupid = groupid,
			value = value,
			name = getNameFromPriv(type)
		})
	end)
	cmd:AddStringArg("group")
	cmd:AddStringArg("name")
	cmd:AddStringArg("value", { multi = true })
end)

BSU.SetupCommand("cleargrouppriv", function(cmd)
	cmd:SetDescription("Remove an existing group privilege (will use whatever the default access settings are)")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, name, value)
		local group = BSU.GetGroupByID(groupid)
		if not group then error("Group does not exist") end

		local type = getPrivFromName(name)
		if not type then error("Unknown privilege type") end

		-- command names should be lowercase
		if type == BSU.PRIV_CMD or type == BSU.PRIV_TARGET then
			value = string.lower(value)
		end

		local priv = BSU.SQLSelectByValues(BSU.SQL_GROUP_PRIVS, { groupid = groupid, type = type, value = value })[1]
		if not priv then error("Privilege is not set on this group") end

		BSU.RemoveGroupPrivilege(groupid, type, value)

		self:BroadcastActionMsg("%caller% cleared a %kind% privilege on the group %groupid% for %value% (%name%)", {
			kind = priv.granted ~= 0 and "granting" or "revoking",
			groupid = groupid,
			value = value,
			name = getNameFromPriv(type),
		})
	end)
	cmd:AddStringArg("group")
	cmd:AddStringArg("name")
	cmd:AddStringArg("value", { multi = true })
end)

BSU.SetupCommand("setgrouplimit", function(cmd)
	cmd:SetDescription("Set a group limit")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, name, amount)
		local group = BSU.GetGroupByID(groupid)
		if not group then error("Group does not exist") end

		local limit = BSU.SQLSelectByValues(BSU.SQL_GROUP_LIMITS, { groupid = groupid, name = name })[1]
		if limit == amount then error("Limit is already set to this amount on this group") end

		BSU.RegisterGroupLimit(groupid, name, amount)

		self:BroadcastActionMsg("%caller% set a limit on the group %groupid% to %amount% (%name%)", {
			groupid = groupid,
			amount = amount,
			name = name
		})
	end)
	cmd:AddStringArg("group")
	cmd:AddStringArg("name")
	cmd:AddNumberArg("amount")
end)

BSU.SetupCommand("cleargrouplimit", function(cmd)
	cmd:SetDescription("Set a group limit")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_SUPERADMIN)
	cmd:SetFunction(function(self, _, groupid, name)
		local group = BSU.GetGroupByID(groupid)
		if not group then error("Group does not exist") end

		local limit = BSU.SQLSelectByValues(BSU.SQL_GROUP_LIMITS, { groupid = groupid, name = name })[1]
		if not limit then error("Limit is not set on this group") end

		BSU.RemoveGroupLimit(groupid, name)

		self:BroadcastActionMsg("%caller% cleared a limit on the group %groupid% (%name%)", {
			groupid = groupid,
			name = name
		})
	end)
	cmd:AddStringArg("group")
	cmd:AddStringArg("name")
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

BSU.SetupCommand("cleanprops", function(cmd)
	cmd:SetDescription("Cleans up a player's props")
	cmd:SetCategory("moderation")
	cmd:SetAccess(BSU.CMD_ADMIN)
	cmd:SetFunction(function(self, _, target)

		BSU.CleanupProps(target:UserID())

		self:BroadcastActionMsg("%caller% cleaned up %target%'s props", {
			target = target
		})
	end)
	cmd:AddPlayerArg("target", { check = true })
end)