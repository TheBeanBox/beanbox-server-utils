-- bsu/defines.lua
-- defines some values on both the server and client

-- privilege types
BSU.PRIV_MISC  = 0
BSU.PRIV_MODEL = 1
BSU.PRIV_NPC   = 2
BSU.PRIV_SENT  = 3
BSU.PRIV_SWEP  = 4
BSU.PRIV_TOOL  = 5
BSU.PRIV_CMD   = 6

-- prop protection enums
BSU.PP_PHYSGUN = 1
BSU.PP_GRAVGUN = 2
BSU.PP_TOOLGUN = 4
BSU.PP_USE     = 8
BSU.PP_DAMAGE  = 16

-- logging enums
BSU.LOG_SPAWN_EFFECT  = 1
BSU.LOG_SPAWN_NPC     = 2
BSU.LOG_SPAWN_PROP    = 3
BSU.LOG_SPAWN_RAGDOLL = 4
BSU.LOG_SPAWN_SENT    = 5
BSU.LOG_SPAWN_SWEP    = 6
BSU.LOG_SPAWN_VEHICLE = 7

-- color values (mainly used for command messages)
BSU.CLR_ERROR    = Color(255, 127, 0)   -- error messages                        (orange)
BSU.CLR_TEXT     = Color(150, 210, 255) -- normal text                           (light blue)
BSU.CLR_PARAM    = Color(0, 255, 0)     -- when a parameter isn't an entity      (green)
BSU.CLR_SELF     = Color(75, 0, 130)    -- when target is client                 (dark purple)
BSU.CLR_EVERYONE = Color(0, 130, 130)   -- when targeting all plys on the server (cyan)
BSU.CLR_CONSOLE  = Color(0, 0, 0)       -- server console name                   (black)
BSU.CLR_MISC     = Color(255, 255, 255) -- other (just used for non-player ents) (white)

-- color values (logging)
BSU.LOG_CLR_SPAWN    = Color(0, 200, 255)
BSU.LOG_CLR_ADVDUPE2 = Color(50, 225, 50)
BSU.LOG_CLR_TEXT     = Color(200, 200, 200)
BSU.LOG_CLR_PARAM    = Color(255, 255, 255)

BSU.CMD_PREFIX        = "!"
BSU.CMD_PREFIX_SILENT = "/"

if SERVER then
	-- server SQL database table names
	BSU.SQL_TEAMS        = "bsu_teams"
	BSU.SQL_GROUPS       = "bsu_groups"
	BSU.SQL_PLAYERS      = "bsu_players"
	BSU.SQL_PDATA        = "bsu_pdata"
	BSU.SQL_BANS         = "bsu_bans"
	BSU.SQL_GROUP_PRIVS  = "bsu_grp_privs"
	BSU.SQL_GROUP_LIMITS = "bsu_grp_limits"
	BSU.SQL_CMD_TARGETS  = "bsu_cmd_targets"
	BSU.SQL_CMD_LIMITS   = "bsu_cmd_limits"

	-- command access values
	BSU.CMD_CONSOLE    = 0 -- access only via the server console (command is also not networked to client)
	BSU.CMD_NONE       = 1 -- access only via the server console and privileges
	BSU.CMD_ADMIN      = 2 -- access only for admins, superadmins and via the server console
	BSU.CMD_SUPERADMIN = 3 -- access only for superadmins and via the server console
	BSU.CMD_ANYONE     = 4 -- access to all

	BSU.BAN_MSG = [[============ You've Been Banned! ===========

Ban Reason:
%reason%

Time Length:
%duration%

Time Remaining:
%remaining%

Ban Date:
%time%

=====================================]]
else
	-- client SQL database table names
	BSU.SQL_PP = "bsu_pp"
end
