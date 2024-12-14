local require = require
local tonumber = tonumber

local skynet = require "skynet"

-- 以单进程模式运行所有服务
skynet.start(function ()
	skynet.newservice("debug_console", tonumber(skynet.getenv("debug_port")))

	-- 数据库服务器相关服务
	skynet.uniqueservice("mysqlpool")
	skynet.uniqueservice("redispool")
	skynet.uniqueservice("dbproxy")

	-- 游戏服务器相关服务
    local gate = skynet.uniqueservice "wsgate"
    skynet.call(gate, "lua", "start", {
        port = tonumber(skynet.getenv("ws_port")) or 9001,
		maxclient = tonumber(skynet.getenv("maxclient")) or 1024,
    })

    skynet.exit()
end)
