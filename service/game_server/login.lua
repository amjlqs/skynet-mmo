local require = require
local string = string
local assert = assert
local tostring = tostring

local skynet = require "skynet"
local log = require "log"
local errors = require "common.errors"
local util = require "util.util"
local uuid = require "uuid"
local snowflake = require "snowflake"

-- 加载 proto
local pb = require "pb"
local protoc = require "protoc"
local pc = protoc.new()
pc:addpath("proto/")
pc.include_imports = true
pc:loadfile("db/login_log.proto")
pc:loadfile("db/user.proto")
pc:loadfile("db/user_bind.proto")

-- 正在登录中的用户
local loggin_in_user = {}

local CMD = {}

function CMD.login(req)
    local openid = req.openid
    local where_clause = string.format("`platform`=1 and `openid`='%s'", openid)
    local ok, rs = util.pcall(util.call, "db", ".dbproxy", "query", 0, "user_bind", {"actorid"}, where_clause)
    if not ok then
        --assert(false, "系统错误")
    end
    local uid = 0
    if not rs[1] then
        uid = 0
    else
        uid = rs[1].actorid
    end
    if uid == 0 then --创建账号
        local row = {
            password = "123456",
            created_at = os.time(),
            account = openid
        }
        local msg = pb.encode("db.user", row)
        ok, rs,actor_id = util.pcall(util.call, "db", ".dbproxy", "createrole", 0, "user", "db.user", msg)
        if not ok then
            assert(false, "系统错误")
        end
        uid = actor_id--rs.insert_id
        
        local sql = string.format("call updateuserbind(%d,%s)", uid,openid)
        ok = util.pcall(util.call,"db", ".dbproxy", "execute", uid, sql)
        if not ok then
            assert(false, "系统错误")
        end
    else
        if loggin_in_user[uid] then
            return nil, errors.PLAYER_LOGGING_IN
        end
        loggin_in_user[uid] = true
        -- TODO: 踢掉该帐号其它登录的终端
        -- 这里简单地从本地服务器的gate服务获取在线玩家，并调用 gate 服务器的 kick方法
        local player = skynet.call(".wsgate", "lua", "get_online", uid)
        if player ~= nil then
            LOGF("玩家 %d 在另一处登录", uid)
            skynet.call(player.agent, "lua", "kick", "Player logged in elsewhere")
        end
    end
        --登录返回
    local rsp = {
        uid=uid,
        server = req.server
    }
    local row = {
        id = snowflake.next(),
        actorid= uid,
        type = 0;--req.type,
        platform = "",--req.platform,
        app_version = "",--req.app_version,
        res_version = "",--req.res_version,
        device_id = "",--req.device_id,
        device_name = "",--req.device_name,
        device_model = "",--req.device_model,
        login_time = os.time(),
        logout_time = 0,
        duration = 0,
    }
    local msg = pb.encode("db.login_log", row)
    local ok = util.pcall(util.call, "db", ".dbproxy", "insert", uid, "login_log", "db.login_log", msg)
    if not ok then
        loggin_in_user[uid] = nil
        return nil, errors.SYSTEM
    end

    loggin_in_user[uid] = nil

    return rsp, nil
end

skynet.start(function ()
    skynet.dispatch("lua", function (_, _, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
end)
