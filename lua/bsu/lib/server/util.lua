-- lib/server/util.lua

util.AddNetworkString("bsu_rpc")

function BSU.ClientRPC(plys, func, ...)
	net.Start("bsu_rpc")
	net.WriteString(func)

	local args = { ... }
	local len = math.min(#args, 2 ^ 8 - 1)
	net.WriteUInt(len, 8) -- only 255 args
	for i = 1, len do
		net.WriteType(args[i])
	end

	if plys then
		net.Send(plys)
	else
		net.Broadcast()
	end
end

function BSU.LoadModules(dir)
	dir = dir or BSU.DIR_MODULES

	local svDir = dir .. "server/"
	local clDir = dir .. "client/"

	local shFiles, folders = file.Find(dir .. "*", "LUA")
	local svFiles = file.Find(svDir .. "*", "LUA")
	local clFiles = file.Find(clDir .. "*", "LUA")

	-- run server-side modules
	for _, v in ipairs(svFiles) do
		if not string.EndsWith(v, ".lua") then continue end
		include(svDir .. v)
	end

	-- run/include shared modules
	for _, v in ipairs(shFiles) do
		if not string.EndsWith(v, ".lua") then continue end
		include(dir .. v)
		AddCSLuaFile(dir .. v)
	end

	-- include client-side modules
	for _, v in ipairs(clFiles) do
		if not string.EndsWith(v, ".lua") then continue end
		AddCSLuaFile(clDir .. v)
	end

	for _, v in ipairs(folders) do
		v = string.lower(v)
		if v == "server" or v == "client" then continue end
		BSU.LoadModules(dir .. v .. "/")
	end
end

-- send a chat message to players (expects a player or NULL entity, or a table that can include both)
function BSU.SendChatMsg(plys, ...)
	if not plys then
		plys = player.GetHumans()
		table.insert(plys, NULL) -- NULL entity = server console
	elseif not istable(plys) then
		plys = { plys }
	end

	for _, v in ipairs(plys) do
		if v:IsValid() then
			BSU.ClientRPC(v, "chat.AddText", ...)
		else
			MsgC(BSU.FixMsgCArgs(...))
			MsgN()
		end
	end
end

-- send a console message to players (expects a player or NULL entity, or a table that can include both)
function BSU.SendConsoleMsg(plys, ...)
	if not plys then
		plys = player.GetHumans()
		table.insert(plys, NULL) -- NULL entity = server console
	elseif not istable(plys) then
		plys = { plys }
	end

	for _, v in ipairs(plys) do
		if v:IsValid() then
			BSU.ClientRPC(v, "BSU.SendConsoleMsg", ...)
		else
			MsgC(BSU.FixMsgCArgs(...))
			MsgN()
		end
	end
end

function BSU.GetSpawnInfo(ply)
	local data = {}
	data.health = ply:Health()
	data.armor = ply:Armor()

	local weps = {}
	for _, wep in ipairs(ply:GetWeapons()) do
		weps[wep:GetClass()] = {
			clip1 = wep:Clip1(),
			clip2 = wep:Clip2(),
			ammo1 = ply:GetAmmoCount(wep:GetPrimaryAmmoType()),
			ammo2 = ply:GetAmmoCount(wep:GetSecondaryAmmoType())
		}
	end

	data.weps = weps

	local active = ply:GetActiveWeapon()
	if IsValid(active) then data.activewep = active:GetClass() end

	return data
end

local function setWeapons(ply, weps, active)
	ply:StripAmmo()
	ply:StripWeapons()

	local weapons = list.Get("Weapon")

	for class, data in pairs(weps) do
		if not weapons[class] then continue end
		local wep = ply:Give(class)
		if not wep:IsValid() then continue end
		wep:SetClip1(data.clip1)
		wep:SetClip2(data.clip2)
		ply:SetAmmo(data.ammo1, wep:GetPrimaryAmmoType())
		ply:SetAmmo(data.ammo2, wep:GetSecondaryAmmoType())
	end

	if active then ply:SelectWeapon(active) end
end

function BSU.SpawnWithInfo(ply, spawninfo)
	ply:Spawn()
	if not spawninfo then return end
	ply:SetHealth(spawninfo.health)
	ply:SetArmor(spawninfo.armor)
	timer.Simple(0, function()
		if ply:IsValid() and ply:Alive() and ply:GetObserverMode() == OBS_MODE_NONE then
			setWeapons(ply, spawninfo.weps, spawninfo.activewep)
		end
	end)
end
