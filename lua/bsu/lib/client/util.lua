-- lib/client/util.lua

local function handleRPC()
	local funcStr = net.ReadString()

	local len = net.ReadUInt(8)
	local args = {}
	for _ = 1, len do
		local arg = net.ReadType()
		table.insert(args, arg)
	end

	local func = BSU.FindVar(funcStr)
	if not func or type(func) ~= "function" then return error("Received bad RPC, invalid function (" .. funcStr .. ")") end

	func(unpack(args))
end

net.Receive("bsu_rpc", handleRPC)

function BSU.LoadModules(dir)
	dir = dir or BSU.DIR_MODULES

	local clDir = dir .. "client/"

	local shFiles, folders = file.Find(dir .. "*", "LUA")
	local clFiles = file.Find(clDir .. "*", "LUA")

	-- run shared modules
	for _, v in ipairs(shFiles) do
		if not string.EndsWith(v, ".lua") then continue end
		include(dir .. v)
	end

	-- run client-side modules
	for _, v in ipairs(clFiles) do
		if not string.EndsWith(v, ".lua") then continue end
		include(clDir .. v)
	end

	for _, v in ipairs(folders) do
		v = string.lower(v)
		if v == "client" then continue end
		BSU.LoadModules(dir .. v .. "/")
	end
end

-- prints a message to console (intended to be called by client RPC)
function BSU.SendConsoleMsg(...)
	MsgC(BSU.FixMsgCArgs(...))
	MsgN()
end