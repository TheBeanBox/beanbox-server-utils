-- base/server/players.lua
-- handles player data stuff

gameevent.Listen("OnRequestFullUpdate")
hook.Add("OnRequestFullUpdate", "BSU_ClientReady", function(data)
	local ply = Player(data.userid)
	if ply.bsu_client_ready then return end
	ply.bsu_client_ready = true
	hook.Run("BSU_ClientReady", ply)
end)

-- initialize player data
hook.Add("OnGamemodeLoaded", "BSU_InitializePlayer", function()
	BSU._oldPlayerInitialSpawn = BSU._oldPlayerInitialSpawn or GAMEMODE.PlayerInitialSpawn

	local defaultGroup = GetConVar("bsu_default_group")
	local botGroup = GetConVar("bsu_bot_group")

	function GAMEMODE.PlayerInitialSpawn(self, ply, transition)
		BSU._oldPlayerInitialSpawn(self, ply, transition)

		local id64 = ply:SteamID64()
		local plyData = BSU.GetPlayerData(ply)
		local isPlayer = not ply:IsBot()

		if not plyData then -- this is the first time this player has joined
			BSU.RegisterPlayer(id64, isPlayer and defaultGroup:GetString() or botGroup:GetString())
			plyData = BSU.GetPlayerData(ply)
			BSU.SetPData(ply, "first_visit", BSU.UTCTime(), true)
		end

		-- update some sql data
		BSU.SetPlayerDataBySteamID(id64, {
			name = ply:Nick(),
			ip = isPlayer and BSU.Address(ply:IPAddress()) or nil
		})

		local lastvisit = BSU.GetPDataNumber(ply, "last_visit")

		-- update some pdata
		if not BSU.GetPDataNumber(ply, "total_time") then BSU.SetPData(ply, "total_time", 0, true) end
		BSU.SetPData(ply, "last_visit", BSU.UTCTime(), true)
		BSU.SetPData(ply, "connect_time", BSU.UTCTime(), true)

		local groupData = BSU.GetGroupByID(plyData.groupid)
		ply:SetTeam(plyData.team and plyData.team or groupData.team)
		ply:SetUserGroup(groupData.usergroup or "user")

		ply.bsu_ready = true

		hook.Run("BSU_PlayerReady", ply, lastvisit)
	end
end)

-- update total_time and last_visit pdata values for all connected players
local function updatePlayerTime()
	for _, v in ipairs(player.GetAll()) do
		if not v.bsu_ready then continue end

		local totalTime = BSU.GetPDataNumber(v, "total_time", 0)
		if hook.Run("BSU_PlayerTotalTime", v, totalTime) ~= false then
			BSU.SetPData(v, "total_time", totalTime + 1, true) -- increment by 1 sec
		end
	end
end

timer.Create("BSU_UpdatePlayerTime", 1, 0, updatePlayerTime) -- update player time every second

-- updates the name value of sql player data whenever a player's steam name is changed
gameevent.Listen("player_changename")
hook.Add("player_changename", "BSU_UpdatePlayerDataName", function(data)
	BSU.SetPlayerData(Player(data.userid), { name = data.newname })
end)

util.AddNetworkString("bsu_client_info")

-- update pdata with client data
local function updateClientInfo(_, ply)
	local os = net.ReadUInt(2)
	local country = net.ReadString()
	local timezone = net.ReadFloat()

	BSU.SetPData(ply, "os", os == 0 and "Windows" or os == 1 and "Linux" or os == 2 and "macOS" or "N/A", true)
	BSU.SetPData(ply, "country", string.sub(country, 1, 2), true) -- incase if spoofed, remove everything after the first two characters
	BSU.SetPData(ply, "timezone", math.Clamp(timezone, -12, 14), true) -- incase if spoofed, clamp the value
end

net.Receive("bsu_client_info", updateClientInfo)

-- send request for some client data
hook.Add("BSU_ClientReady", "BSU_RequestClientInfo", function(ply)
	BSU.RequestClientInfo(ply)
end)

-- allow players picking up other players
hook.Add("PhysgunPickup", "BSU_AllowPlayerPhysgunPickup", function(ply, ent)
	if not ent:IsPlayer() then return end
	return BSU.PlayerHasPermission(ply, ent, BSU.PP_PHYSGUN) ~= false
end)

local grabbed = {}

-- fix glitchy player movement on physgun pickup
hook.Add("OnPhysgunPickup", "BSU_PlayerPhysgunPickup", function(ply, ent)
	if not ent:IsPlayer() then return end

	hook.Run("BSU_PlayerPhysgunPickup", ply, ent)

	ent:SetMoveType(MOVETYPE_NONE)
	ent:SetVelocity(-ent:GetVelocity())
	grabbed[ent] = true
end)

-- allow throwing players across the map on physgun drop
hook.Add("PhysgunDrop", "BSU_PlayerPhysgunDrop", function(ply, ent)
	if not ent:IsPlayer() then return end

	ent:SetMoveType(MOVETYPE_WALK)
	grabbed[ent] = nil
	if ent.bsu_grabbedVel then
		-- SetVelocity actually ADDS velocity to a player, so the original velocity is also subtracted to reset velocity
		ent:SetVelocity(ent.bsu_grabbedVel - ent:GetVelocity())
	end
	ent.bsu_grabbedOldPos = nil
	ent.bsu_grabbedPos = nil
	ent.bsu_grabbedVel = nil

	hook.Run("BSU_PlayerPhysgunDrop", ply, ent)
end)

-- calculate velocity of grabbed players
hook.Add("Think", "BSU_PlayerGrabbed", function()
	for ply, _ in pairs(grabbed) do
		if not ply:IsValid() then
			grabbed[ply] = nil
			return
		end
		ply.bsu_grabbedOldPos = ply.bsu_grabbedPos
		ply.bsu_grabbedPos = ply:GetPos()
		if ply.bsu_grabbedOldPos then
			local vel = (ply.bsu_grabbedPos - ply.bsu_grabbedOldPos) / engine.TickInterval()
			if ply.bsu_grabbedVel then
				ply.bsu_grabbedVel = (ply.bsu_grabbedVel + vel) / 2 -- probably not accurate but it works
			else
				ply.bsu_grabbedVel = vel
			end
		end
	end
end)
