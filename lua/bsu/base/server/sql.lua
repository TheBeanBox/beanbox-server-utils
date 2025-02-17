-- base/server/sql.lua

--[[
	Teams

	id    - (int)  id of the team
	name  - (text) display name of the team
	color - (text) display color of the team
]]

BSU.SQLCreateTable(BSU.SQL_TEAMS, string.format(
	[[
		id INTEGER PRIMARY KEY,
		name TEXT NOT NULL UNIQUE,
		color TEXT NOT NULL
	]]
))

--[[
	Groups

	id        - (text)         id of the group
	team      - (int)          id of the team this group should use
	usergroup - (text)         usergroup this group should use (ex: "user", "admin", "superadmin") (default: "user")
	cantarget - (text or NULL) filter for who this group can target with commands (default: "*" for everyone)
	inherit   - (text or NULL) id of the group this group should inherit the properties of
]]

BSU.SQLCreateTable(BSU.SQL_GROUPS, string.format(
	[[
		id TEXT PRIMARY KEY,
		team INTEGER NOT NULL REFERENCES %s(id),
		usergroup TEXT NOT NULL,
		cantarget TEXT NOT NULL,
		inherit TEXT REFERENCES %s(id)
	]],
		BSU.SQLEscIdent(BSU.SQL_TEAMS),
		BSU.SQLEscIdent(BSU.SQL_GROUPS)
))

--[[
	Players

	steamid   - (text)         steam 64 bit id of the player
	name      - (text or NULL) steam name of the player (can be NULL but is set whenever the player joins or updates their name)
	team      - (int or NULL)  id of the team the player is currently in (overrides the team the player's group uses if not NULL)
	groupid   - (text)         id of the group the player is currently in
	ip        - (text or NULL) ip address of the player (NULL if it's a bot)
]]

BSU.SQLCreateTable(BSU.SQL_PLAYERS, string.format(
	[[
		steamid TEXT PRIMARY KEY,
		name TEXT,
		team INTEGER REFERENCES %s(id),
		groupid TEXT NOT NULL REFERENCES %s(id),
		ip TEXT
	]],
		BSU.SQLEscIdent(BSU.SQL_TEAMS),
		BSU.SQLEscIdent(BSU.SQL_GROUPS)
))

--[[
	PData

	steamid - (text) steam 64 bit id of the player
	key     - (text) key of the data
	value   - (text) value of the data
	network - (bool) should network this value to clients or not
]]

BSU.SQLCreateTable(BSU.SQL_PDATA, string.format(
	[[
		steamid TEXT NOT NULL REFERENCES %s(steamid),
		key TEXT NOT NULL,
		value TEXT NOT NULL,
		network BOOLEAN NOT NULL CHECK (network in (0, 1)),
		UNIQUE (steamid, key)
	]],
		BSU.SQLEscIdent(BSU.SQL_PLAYERS)
))

--[[
	Bans

	identity   - (text)         steam 64 bit id or ip address of the banned/kicked player (does not use a reference so players not registered on the server may be banned)
	reason     - (text or NULL) reason for the ban/kick (NULL if no reason given)
	duration   - (int or NULL)  (in minutes) how long the ban will last (0 for perma, NULL for kick)
	time       - (int)          utc unix timestamp when the ban/kick was done
	admin      - (text or NULL) steam 64 bit id of the admin who did the ban (NULL if done through rcon)
	unbanTime  - (int or NULL)  utc unix timestamp when the ban was manually resolved
	unbanAdmin - (text or NULL) steam 64 bit id of the admin who resolved the ban (NULL if done through rcon)

	(use the latest entry of a steamid or ip when checking ban status)
]]

BSU.SQLCreateTable(BSU.SQL_BANS, string.format(
	[[
		identity TEXT NOT NULL,
		reason TEXT,
		duration INTEGER,
		time INTEGER NOT NULL,
		admin TEXT REFERENCES %s(steamid),
		unbanTime INTEGER,
		unbanAdmin TEXT REFERENCES %s(steamid)
	]],
		BSU.SQLEscIdent(BSU.SQL_PLAYERS),
		BSU.SQLEscIdent(BSU.SQL_PLAYERS)
))

--[[
	Group Privileges

	groupid - (text) id of the group
	type    - (text) privilege type
	value   - (text) privilege value
	granted - (bool) grant or restrict the privilege
]]

BSU.SQLCreateTable(BSU.SQL_GROUP_PRIVS, string.format(
	[[
		groupid TEXT NOT NULL REFERENCES %s(id),
		type INTEGER NOT NULL,
		value TEXT NOT NULL,
		granted BOOLEAN NOT NULL CHECK (granted in (0, 1)),
		UNIQUE (groupid, type, value)
	]],
		BSU.SQLEscIdent(BSU.SQL_GROUPS)
))

--[[
	Group Limits

	groupid - (text) id of the group
	name    - (text) name of the limit
	amount  - (int)  max spawn amount
]]

BSU.SQLCreateTable(BSU.SQL_GROUP_LIMITS, string.format(
	[[
		groupid TEXT NOT NULL REFERENCES %s(id),
		name TEXT NOT NULL,
		amount INTEGER NOT NULL,
		UNIQUE (groupid, name)
	]],
		BSU.SQLEscIdent(BSU.SQL_GROUPS)
))

--[[
	Command Targets

	groupid - (text) id of the group
	cmd     - (text) name of the command
	filter  - (text) filter for who can be targeted with this command
]]

BSU.SQLCreateTable(BSU.SQL_CMD_TARGETS, string.format(
	[[
		groupid TEXT NOT NULL REFERENCES %s(id),
		cmd TEXT NOT NULL,
		filter TEXT NOT NULL,
		UNIQUE (groupid, cmd)
	]],
		BSU.SQLEscIdent(BSU.SQL_GROUPS)
))

--[[
	Command Limits

	groupid - (text) id of the group
	cmd     - (text) name of the command
	arg     - (text) name of the arg
	min     - (int)  min number
	max     - (int)  max number
]]

BSU.SQLCreateTable(BSU.SQL_CMD_LIMITS, string.format(
	[[
		groupid TEXT NOT NULL REFERENCES %s(id),
		cmd TEXT NOT NULL,
		arg TEXT NOT NULL,
		min INTEGER,
		max INTEGER,
		UNIQUE (groupid, cmd, arg)
	]],
		BSU.SQLEscIdent(BSU.SQL_GROUPS)
))
