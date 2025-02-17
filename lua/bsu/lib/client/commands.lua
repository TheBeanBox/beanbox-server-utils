-- lib/client/commands.lua

local function run(cmd, handler)
	cmd:GetFunction()(handler, handler:GetCaller(), handler:GetArgs())
end

function BSU.RunCommand(name, argStr, silent)
	name = string.lower(name)

	local cmd = BSU._cmds[name]
	if not cmd then error("Command '" .. name .. "' does not exist") end

	if cmd._serverside then
		BSU.SendRunCommand(name, argStr, silent)
		return
	end

	local ply = LocalPlayer()

	if hook.Run("BSU_PreRunCommand", ply, cmd, argStr, silent) == false then return end

	local handler = BSU.CommandHandler(ply, cmd, argStr, silent)

	xpcall(run, function(err) handler:PrintErrorMsg("Command errored with: " .. string.Split(err, ": ")[2]) end, cmd, handler)

	hook.Run("BSU_PostRunCommand", ply, cmd, argStr, silent)
end

function BSU.SafeRunCommand(name, argStr, silent)
	if not BSU.GetCommandByName(name) then BSU.SendConsoleMsg(color_white, "Unknown BSU command: '" .. name .. "'") return end
	BSU.RunCommand(name, string.sub(argStr or "", 1, 255), silent) -- limit arg string length
end

function BSU.SendRunCommand(name, argStr, silent)
	net.Start("bsu_command_run")
		net.WriteString(name)
		net.WriteString(argStr)
		net.WriteBool(silent)
	net.SendToServer()
end

net.Receive("bsu_command_run", function()
	local name = net.ReadString()
	local argStr = net.ReadString()
	local silent = net.ReadBool()
	BSU.SafeRunCommand(name, argStr, silent)
end)

local function func()
	error("Cannot run this command on the client")
end

function BSU.RegisterServerCommand(name, desc, category, args)
	name = string.lower(name)
	local cmd = BSU._cmds[name]
	if cmd and not cmd._serverside then return end -- clientside command already exists

	cmd = BSU.Command(name, desc, category)
	cmd.args = args
	cmd.func = func
	cmd._serverside = true

	BSU.RegisterCommand(cmd)
end