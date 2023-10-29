-- lib/server/pp.lua

-- holds prop protection perms
BSU._perms = BSU._perms or {}

function BSU.SetPermission(plyID, tarID, perm)
	plyID = BSU.ID64(plyID)
	tarID = BSU.ID64(tarID)
	if perm and perm > 0 then
		if not BSU._perms[plyID] then BSU._perms[plyID] = {} end
		BSU._perms[plyID][tarID] = perm
	elseif BSU._perms[plyID] then
		BSU._perms[plyID][tarID] = nil
		if next(BSU._perms[plyID]) == nil then BSU._perms[plyID] = nil end
	end
end

function BSU.GetPermission(plyID, tarID)
	plyID = BSU.ID64(plyID)
	tarID = BSU.ID64(tarID)
	local permission = BSU._perms[plyID] and BSU._perms[plyID][tarID] and BSU._perms[plyID][tarID]
	return permission or 0
end

function BSU.CheckPermission(plyID, tarID, perm)
	local permission = BSU.GetPermission(plyID, tarID)
	return bit.band(permission, perm) == perm
end

function BSU.SetPlayerPermission(ply, target, perm)
	if not ply:IsPlayer() then return end
	if not target:IsPlayer() then return end
	return BSU.SetPermission(ply:SteamID64(), target:SteamID64(), perm)
end

function BSU.GetPlayerPermission(ply, target)
	if not ply:IsPlayer() then return end
	if not target:IsPlayer() then return end
	return BSU.GetPermission(ply:SteamID64(), target:SteamID64())
end

-- returns bool if player has granted permission to the target player
function BSU.CheckPlayerPermission(ply, target, perm)
	if not ply:IsPlayer() then return end
	if not target:IsPlayer() then return end
	return BSU.CheckPermission(ply:SteamID64(), target:SteamID64(), perm)
end

-- returns a table of current players on the server who are friends with the player, including admins (uses the toolgun permission)
function BSU.GetPlayerFriends(ply)
	if not ply:IsPlayer() then return {} end
	local friends = {}
	for _, v in ipairs(player.GetHumans()) do
		if v:IsAdmin() or BSU.CheckPlayerPermission(ply, v, BSU.PP_TOOLGUN) then
			table.insert(friends, v)
		end
	end
	return friends
end

-- clear permissions granted from the steamid
function BSU.ClearPermissionFrom(steamid)
	BSU._perms[BSU.ID64(steamid)] = nil
end

-- clear permissions granted to the steamid
function BSU.ClearPermissionTo(steamid)
	steamid = BSU.ID64(steamid)
	for _, v in pairs(BSU._perms) do
		v[steamid] = nil
	end
end

local worldPermission = BSU.PP_GRAVGUN + BSU.PP_USE + BSU.PP_DAMAGE

-- returns bool if players have permission on the world
function BSU.CheckWorldPermission(perm)
	return bit.band(worldPermission, perm) == perm
end

-- utility function for hooks to know if a player has permission over an entity
-- can return the following:
--  true  - player has permission (player is superadmin and must have permission)
--  nil   - player has permission (nil so the hook lets another addon can decide if the player should have permission)
--  false - player doesn't have permission
function BSU.PlayerHasPermission(ply, ent, perm)
	if ply:IsSuperAdmin() then return true end

	local owner = BSU.GetOwner(ent)
	if owner then ent = owner end

	if ply == ent then return end

	if ent:IsPlayer() then
		if BSU.CheckPlayerPermission(ent, ply, perm) ~= false then return end
	elseif ent:IsWorld() then
		if BSU.CheckWorldPermission(perm) ~= false then return end
	end

	return false
end

function BSU.RequestPermissions(plys, target)
	net.Start("bsu_perms")
		net.WriteUInt(target:UserID(), 15)
	if plys then
		net.Send(plys)
	else
		net.Broadcast()
	end
end

net.Receive("bsu_perms", function(_, ply)
	local total = net.ReadUInt(7)
	for _ = 1, total do
		local target = Player(net.ReadUInt(15))
		local perm = net.ReadUInt(5)
		if ply ~= target and target:IsPlayer() and not target:IsBot() then
			BSU.SetPlayerPermission(ply, target, perm)
		end
	end
end)

function BSU.CleanupProps(id)
	for _, ent in ipairs(BSU.GetOwnerEntities(id)) do
		ent:Remove()
	end
end
