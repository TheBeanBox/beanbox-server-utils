-- lib/server/pdata.lua

util.AddNetworkString("bsu_pdata")

function BSU.RegisterPData(steamid, key, value, network)
	steamid = BSU.ID64(steamid)

	BSU.SQLReplace(BSU.SQL_PDATA, {
		steamid = steamid,
		key = key,
		value = value,
		network = network
	})
end

function BSU.RemovePData(steamid, key)
	BSU.SQLDeleteByValues(BSU.SQL_PDATA, { steamid = BSU.ID64(steamid), key = key })
end

function BSU.GetPDataBySteamID(steamid, key, default)
	local query = BSU.SQLSelectByValues(BSU.SQL_PDATA, { steamid = BSU.ID64(steamid), key = key }, 1)[1]
	if query then return query.value end
	return default
end

function BSU.GetAllPDataBySteamID(steamid, network)
	local query = BSU.SQLSelectByValues(BSU.SQL_PDATA, { steamid = BSU.ID64(steamid) })
	network = network or false

	local data = {}

	for i = 1, #query do
		local entry = query[i]
		if network ~= nil and entry.network ~= network then continue end
		data[entry.key] = entry.value
	end

	return data
end

local pdataNetworkCache = {}

hook.Add("BSU_ClientReady", "BSU_NetworkPData", function(ply)
	for i, data in pairs(pdataNetworkCache) do
		for k, v in pairs(data) do
			net.Start("bsu_pdata")
			net.WriteUInt(i, 8)
			net.WriteString(k)
			net.WriteBool(true)
			net.WriteString(v)
			net.Send(ply)
		end
	end

	local ind = ply:EntIndex()
	local data = pdataNetworkCache[ind]
	if not data then
		data = {}
		pdataNetworkCache[ind] = data
	end

	for k, v in pairs(BSU.GetAllPData(ply, true)) do -- get only networked data
		data[k] = v

		net.Start("bsu_pdata")
		net.WriteUInt(ply:EntIndex(), 8)
		net.WriteString(k)
		net.WriteBool(true)
		net.WriteString(v)
		net.Broadcast()
	end
end)

hook.Add("EntityRemoved", "BSU_CleanPData", function(ent, fullUpdate)
	if fullUpdate then return end
	local ind = ent:EntIndex()
	if pdataNetworkCache[ind] then
		pdataNetworkCache[ind] = nil
	end
end)

-- adds pdata key to a player (or overwrites an existing pdata key with a new value)
function BSU.SetPData(ply, key, value, network)
	key = tostring(key)
	value = tostring(value)

	BSU.RegisterPData(ply:SteamID64(), key, value, network)

	if network then
		local ind = ply:EntIndex()
		local data = pdataNetworkCache[ind]
		if not data then
			data = {}
			pdataNetworkCache[ind] = data
		end
		data[key] = value

		net.Start("bsu_pdata")
		net.WriteUInt(ind, 8)
		net.WriteString(key)
		net.WriteBool(true)
		net.WriteString(value)
		net.Broadcast()
	end
end

-- clears pdata key on a player (or does nothing if it's not set)
function BSU.ClearPData(ply, key)
	key = tostring(key)

	if not BSU.GetPData(ply, key) then return end

	BSU.RemovePData(ply:SteamID64(), key)

	local ind = ply:EntIndex()
	local data = pdataNetworkCache[ind]
	if data then
		data[key] = nil

		net.Start("bsu_pdata")
		net.WriteUInt(ply:EntIndex(), 8)
		net.WriteString(key)
		net.WriteBool(false)
		net.Broadcast()
	end
end

-- gets a pdata value on a player (or default if it's not set)
function BSU.GetPData(ply, key, default)
	return BSU.GetPDataBySteamID(ply:SteamID64(), key, default)
end

-- gets a pdata value on a player and attempts to convert it to a number (or default if it fails to convert)
function BSU.GetPDataNumber(ply, key, default)
	return tonumber(BSU.GetPData(ply, key, default)) or default
end

-- gets a table of all the pdata on a player
-- optionally get only networked data (network = true)
-- optionally get only non-networked data (network = false)
-- (leave network unset to get all data)
function BSU.GetAllPData(ply, network)
	return BSU.GetAllPDataBySteamID(ply:SteamID64(), network)
end

