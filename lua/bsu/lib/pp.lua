-- lib/pp.lua (SHARED)

BSU._owners = BSU._owners or {} -- owner data
BSU._entowners = BSU._entowners or {} -- [entindex] = steamid64
BSU._ownerents = BSU._ownerents or {} -- [steamid64] = entindex

local infoUpdates, entsUpdates = {}, {}

local WORLD_ID = "18446744073709551615" -- owner id for the world

-- used for determining amount of bits needed to network owner info and ents (these do not limit anything serverside)

local OWNER_INFO_MAX = 2 -- max keys in owner info, currently only storing name and userid (update this if more are added)
local OWNER_ENTS_MAX = 2 ^ 13 - 1 -- max ents per owner

if SERVER then
	util.AddNetworkString("bsu_init_owners")
	util.AddNetworkString("bsu_owner_info")
	util.AddNetworkString("bsu_set_owner")
	util.AddNetworkString("bsu_clear_owner")
end

local function sendOwnerUpdates()
	if next(infoUpdates) ~= nil then
		for id, info in pairs(infoUpdates) do
			for k, v in pairs(info) do
				net.Start("bsu_owner_info")
					net.WriteUInt64(id)
					net.WriteString(k)
					net.WriteType(v)
				net.Broadcast()
			end
		end

		infoUpdates = {}
	end

	if next(entsUpdates) ~= nil then
		local owners, ownerless = {}, {}

		for entindex, id in pairs(entsUpdates) do
			if id then
				if not owners[id] then owners[id] = {} end
				table.insert(owners[id], entindex)
			else
				table.insert(ownerless, entindex)
			end
		end

		if next(owners) ~= nil then
			for id, ents in pairs(owners) do
				for _, entindex in ipairs(ents) do
					net.Start("bsu_set_owner")
						net.WriteUInt64(id)
						net.WriteUInt(entindex, 13)
					net.Broadcast()
				end
			end
		end

		if next(ownerless) ~= nil then
			for _, entindex in ipairs(ownerless) do
				net.Start("bsu_clear_owner")
					net.WriteUInt(entindex, 13)
				net.Broadcast()
			end
		end

		entsUpdates = {}
	end
end

local function signalOwnerUpdates()
	-- use a 0 second timer to send updates next tick
	-- if ownership changes multiple times in the same tick, only the last update will matter (this makes sure only the last is sent)
	timer.Create("BSU_SendOwnerUpdates", 0, 1, sendOwnerUpdates)
end

-- periodically send owner updates
-- if ownership updates keep happening every tick, the above timer will keep resetting and never finish (this makes sure updates get sent atleast every so often)
if SERVER then timer.Create("BSU_ForceSendOwnerUpdates", 1, 0, sendOwnerUpdates) end

local function updateOwnerInfo(id, key, value)
	if not isstring(key) or value == nil then return end

	key = string.lower(key)

	if BSU._owners[id] then
		if BSU._owners[id][key] == value then return end -- value didn't change
	else
		BSU._owners[id] = {}
	end
	BSU._owners[id][key] = value

	if SERVER then
		if not infoUpdates[id] then infoUpdates[id] = {} end
		infoUpdates[id][key] = value
		signalOwnerUpdates()
	end
end

local function clearEntityOwner(entindex)
	local id = BSU._entowners[entindex]
	if not id then return end -- already ownerless

	BSU._entowners[entindex] = nil
	-- clear all owner data for disconnected players who own no entities
	if id ~= WORLD_ID and next(BSU._ownerents[id]) == nil and not Player(BSU._owners[id].userid):IsValid() then
		BSU._owners[id] = nil
		BSU._ownerents[id] = nil
	else
		BSU._ownerents[id][entindex] = nil
	end

	if SERVER then
		entsUpdates[entindex] = false
		signalOwnerUpdates()
	end
end

local function setEntityOwner(entindex, id)
	if BSU._entowners[entindex] == id then return end -- already owned by this id
	clearEntityOwner(entindex)

	BSU._entowners[entindex] = id
	BSU._ownerents[id] = BSU._ownerents[id] or {}
	BSU._ownerents[id][entindex] = true

	if SERVER then
		entsUpdates[entindex] = id
		signalOwnerUpdates()
	end
end

function BSU.SetOwnerInfo(owner, key, value)
	if not IsValid(owner) or (not owner:IsPlayer() and not owner:IsWorld()) then return end
	local id = owner:IsPlayer() and owner:SteamID64() or WORLD_ID
	updateOwnerInfo(id, key, value)
end

function BSU.SetOwnerless(ent)
	if not IsValid(ent) or ent:IsPlayer() then return end
	clearEntityOwner(ent:EntIndex())
	ent:RemoveCallOnRemove("BSU_SetOwnerless")
end

function BSU.SetOwner(ent, owner)
	if not IsValid(ent) or ent:IsPlayer() then return end
	if not IsValid(owner) or not owner:IsPlayer() then return end
	local id = owner:SteamID64()
	updateOwnerInfo(id, "name", owner:Nick()) -- used for HUD display
	updateOwnerInfo(id, "userid", owner:UserID()) -- used for getting the owner entity
	setEntityOwner(ent:EntIndex(), id)
	ent:CallOnRemove("BSU_SetOwnerless", BSU.SetOwnerless)
end

function BSU.SetOwnerWorld(ent)
	if not IsValid(ent) or ent:IsPlayer() then return end
	updateOwnerInfo(WORLD_ID, "name", "World") -- used for HUD display
	updateOwnerInfo(WORLD_ID, "userid", -1) -- used for getting the owner entity
	setEntityOwner(ent:EntIndex(), WORLD_ID)
end

function BSU.CopyOwner(from, to)
	if not IsValid(from) or from:IsPlayer() then return end
	if not IsValid(to) or to:IsPlayer() then return end

	local id = BSU._entowners[from:EntIndex()]
	if not id then return end -- is ownerless

	setEntityOwner(to:EntIndex(), id)
	to:CallOnRemove("BSU_SetOwnerless", BSU.SetOwnerless)
end

function BSU.ReplaceOwner(from, to)
	if not IsValid(from) or from:IsPlayer() then return end
	if not IsValid(to) or to:IsPlayer() then return end

	local id = BSU._entowners[from:EntIndex()]
	if not id then return end -- is ownerless

	clearEntityOwner(from:EntIndex())
	from:RemoveCallOnRemove("BSU_SetOwnerless")

	setEntityOwner(to:EntIndex(), id)
	to:CallOnRemove("BSU_SetOwnerless", BSU.SetOwnerless)
end

-- returns table of entities this owner owns
function BSU.GetOwnerEntities(id)
	local ents = {}
	for entindex, _ in pairs(BSU._ownerents[id] or {}) do
		table.insert(ents, Entity(entindex))
	end
	return ents
end

-- returns steamid64 of the entity owner (WORLD_ID if owner is the world, nil if entity is ownerless)
function BSU.GetOwnerID(ent)
	if not IsValid(ent) then return end
	return BSU._entowners[ent:EntIndex()]
end

-- returns string of the entity owner ("Name<STEAM_X:Y:Z>" if owner is a player, "World" if owner is the world, "N/A" if entity is ownerless)
function BSU.GetOwnerString(ent)
	if not IsValid(ent) then return "N/A" end
	local id = BSU._entowners[ent:EntIndex()]
	if not id then return "N/A" end
	local name = BSU._owners[id].name or ""
	if id == WORLD_ID then return name end
	return string.format("%s<%s>", name, util.SteamIDFrom64(id))
end

-- returns info about the entity owner (nil if entity is ownerless or there's no info with the key)
function BSU.GetOwnerInfo(ent, key)
	if not IsValid(ent) then return end
	local id = BSU._entowners[ent:EntIndex()]
	if not id or not BSU._owners[id] then return end
	return BSU._owners[id][string.lower(key)]
end

-- returns owner of the entity (can be a player or the world, NULL entity if player is disconnected, nil if entity is ownerless)
function BSU.GetOwner(ent)
	local userid = BSU.GetOwnerInfo(ent, "userid")
	if not userid then return end
	if userid == -1 then return game.GetWorld() end
	return Player(userid)
end

-- owner info util functions

-- returns name of the entity owner (will be "World" if entity is the world, nil if entity is ownerless)
function BSU.GetOwnerName(ent)
	return BSU.GetOwnerInfo(ent, "name")
end

-- returns userid of the entity owner (will be -1 if entity is the world, nil if entity is ownerless)
function BSU.GetOwnerUserID(ent)
	return BSU.GetOwnerInfo(ent, "userid")
end

local infoBits = math.floor(math.log(OWNER_INFO_MAX, 2)) + 1
local entsBits = math.floor(math.log(OWNER_ENTS_MAX, 2)) + 1

if SERVER then
	function BSU.SendOwnerData(ply)
		net.Start("bsu_init_owners")
			net.WriteUInt(table.Count(BSU._owners), 7)
		for id, info in pairs(BSU._owners) do
			net.WriteUInt64(id)

			local infoTotal = math.min(table.Count(info), OWNER_INFO_MAX)
			net.WriteUInt(infoTotal, infoBits)
			for k, v in pairs(info) do
				net.WriteString(k)
				net.WriteType(v)
				infoTotal = infoTotal - 1
				if infoTotal == 0 then break end
			end

			local ents = BSU._ownerents[id]
			local entsTotal = math.min(table.Count(ents), OWNER_ENTS_MAX)
			net.WriteUInt(entsTotal, entsBits)
			for entindex, _ in pairs(ents) do
				net.WriteUInt(entindex, 13)
				entsTotal = entsTotal - 1
				if entsTotal == 0 then break end
			end
		end
		net.Send(ply)
	end

	return
end

net.Receive("bsu_init_owners", function()
	local owners = net.ReadUInt(7)
	for _ = 1, owners do
		local id = net.ReadUInt64()

		local info = net.ReadUInt(infoBits)
		for _ = 1, info do
			local key, value = net.ReadString(), net.ReadType()
			updateOwnerInfo(id, key, value)
		end

		local ents = net.ReadUInt(entsBits)
		for _ = 1, ents do
			local entindex = net.ReadUInt(13)
			setEntityOwner(entindex, id)
		end
	end
end)

net.Receive("bsu_owner_info", function()
	local id, key, value = net.ReadUInt64(), net.ReadString(), net.ReadType()
	updateOwnerInfo(id, key, value)
end)

net.Receive("bsu_set_owner", function()
	local id, entindex = net.ReadUInt64(), net.ReadUInt(13)
	setEntityOwner(entindex, id)
end)

net.Receive("bsu_clear_owner", function()
	local entindex = net.ReadUInt(13)
	clearEntityOwner(entindex)
end)