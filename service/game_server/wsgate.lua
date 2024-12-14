local require = require
local string = string
local assert = assert
local tostring = tostring
local table = table
local error = error

local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local log = require "log"
local errors = require "common.errors"
local constant = require "common.constant"
local util = require "util.util"

local pb = require "pb"
local protoc = require "protoc"
local pc = protoc.new()
pc:addpath("proto/")
pc.include_imports = true
pc:loadfile("proto.proto")
pc:loadfile("login.proto")

local randnamesdict = {}

function read_text_to_table(file_path)
    local file = io.open(file_path, "r")
 
    for line in file:lines() do
        local key, value = line:match("(%S+)%s+(.-)")
        --data_table[key] = value
        table.insert(randnamesdict,key)
    end
 
    file:close()
end

-- 尝试打开文件
local file_path = "randname.txt"
read_text_to_table(file_path)
local maxnamecnt = #randnamesdict

local CMD = {}
local connections = {}   -- fd -> uid
local players = {}       -- uid -> {uid=uid, fd=fd, agent=agent,expiration=0,fuben=fuben,fubenstate=0}
local cache_players = {} -- 用户短暂离线，缓存用户信息
local agent_pool = {}
local max_client = 0
local cur_client = 0

local function init(conf)
    local n = 2
	LOGF("precreate %d agents", n)
	for i = 1, n do
		local agent = assert(skynet.newservice("agent"), string.format("precreate agent %d of %d error", i, n))
		table.insert(agent_pool, agent)
	end
    max_client = conf.maxclient
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local function close_internal(fd)
    local uid = connections[fd]
    if not uid then
        return
    end
    local player = players[uid]
    if player then
        local ok, err = util.pcall(skynet.call, player.agent, "lua", "afk")
        if not ok then
            log.error(err)
        end
        player.fd = 0
        player.expiration = skynet.now() + 100*3600 -- 缓存一个小时
        cache_players[uid] = player
    end
    connections[fd] = nil
    players[uid] = nil
    cur_client = cur_client - 1

    websocket.close(fd)
end

local handle = {}

function handle.connect(fd)
    LOGF("新的连接建立: fd=%d", fd)
end

function handle.handshake(fd, header, url)
    local addr = websocket.addrinfo(fd)
    LOG("websocket握手成功", addr)
    connections[fd] = 0

    if cur_client > max_client then
        local payload = assert(pb.encode("proto.Error", errors.CONNECTION_LIMIT))
        local msg = assert(pb.encode("proto.Msg", {
            seq = 0,
            cmd = "proto.Error",
            payload = payload
        }))
        CMD.write(fd, msg)
        websocket.close(fd, 1000, "too many clients")
        connections[fd] = nil
        return
    end

    cur_client = cur_client + 1

    -- 连接成功后10秒内, 没有收到LOGIN消息, 断开连接
    skynet.timeout(100*10, function ()
        local uid = connections[fd]
        if uid == 0 then
            close_internal(fd)
        end
    end)
end

function handle.message(fd, msg, msg_type)
    assert(msg_type == "binary" or msg_type == "text")

    --LOG("msg_type=", msg_type)
    local uid = connections[fd]
    local player = players[uid]
    if player then
        -- 已认证, 消息转发给
		skynet.redirect(player.agent, 0, "client", fd,  msg)
    else
        local ok, m, req
        ok, m = util.pcall(pb.decode, "proto.Msg", msg)
        if not ok then
            log.error("pb decode error", m)
            close_internal(fd)
            return
        end
        LOG(" proto.Msg  m: ",m)
        local cmd = "proto."..m.cmd
        ok, req = util.pcall(pb.decode, cmd, m.payload)
        if not ok then
            log.error("pb decode error", req)
            close_internal(fd)
            return
        end

        LOG("req =", req)
        local login = skynet.uniqueservice "login"
        local rsp, err
        ok, rsp, err = util.pcall(skynet.call, login, "lua", "login", req)
        if not ok then
            log.error("登录失败:", rsp)
            close_internal(fd)
            return
        end

        if rsp then
            uid = rsp.uid
            local agent
            if cache_players[uid] then
                -- 缓存中有玩家对象，直接关联
                player = cache_players[uid]
                player.fd = fd
                player.expiration = nil
                cache_players[uid] = nil
                agent = player.agent
            else
                agent = table.remove(agent_pool)
                if not agent then
                    agent = skynet.newservice "agent"
                end
                player = {uid=uid, fd=fd, device_id= "", agent=agent}
                local createname = ""
                local randidx = math.random(1,maxnamecnt)
                createname = randnamesdict[randidx]

                ok, err = util.pcall(skynet.call, agent, "lua", "load", uid, createname)
                if not ok then
                    log.error("加载玩家数据失败", err)
                    skynet.send(agent, "lua", "exit")
                    close_internal(fd)
                    return
                end
            end

            ok, err = util.pcall(skynet.call, agent, "lua", "login", uid, fd, "")
            if not ok then
                log.error("登录到agent失败", err)
                close_internal(fd)
                return
            end
            players[uid] = player
            -- TODO: 登录全局的用户中心
            connections[fd] = uid

            local payload = assert(pb.encode("proto.LoginRsp", rsp))
            msg = assert(pb.encode("proto.Msg", {
                id = constant.SystemID.CMD_Login,
                cmd = "LoginRsp",
                payload = payload
            }))
            CMD.write(fd, msg)

            ok, err = util.pcall(skynet.call, agent, "lua", "online")
            if not ok then
                close_internal(fd)
                log.error(err)
                return
            end
        else
            local Error = {
                code = err,
                message = ""
            }
            local payload = assert(pb.encode("proto.Error", Error))
            msg = assert(pb.encode("proto.Msg", {
                id = constant.SystemID.CMD_ERROR,
                cmd = "Error",
                payload = payload
            }))
            CMD.write(fd, msg)
        end
    end
end

function handle.close(fd, code, reason)
    LOGF("连接断开: fd=%s", fd)
    close_internal(fd)
end

function handle.error(fd)
    LOGF("连接发生错误: fd=%d", fd)
    close_internal(fd)
end

function CMD.write(fd, data)
    websocket.write(fd, data, "binary")
end

function CMD.push(uid, data)
    local player = players[uid]
    if not player then
        return
    end
    websocket.write(player.fd, data, "binary")
end

function CMD.broadcast(data)
    for _, player in pairs(players) do
        websocket.write(player.fd, data, "binary")
    end
end

-- 获取在线玩家
function CMD.get_online(uid)
    return players[uid]
end

-- 玩取玩家，可以拉起离线玩家
function CMD.get_player(uid)
    if players[uid] then
        return players[uid]
    end

    if cache_players[uid] then
        return cache_players[uid]
    end

    local agent = table.remove(agent_pool)
    if not agent then
        agent = skynet.newservice "agent"
    end
    local player = {uid=uid, agent=agent}
    local ok, err = util.pcall(skynet.call, agent, "lua", "load", uid)
    if not ok then
        log.error("加载玩家数据失败", err)
        skynet.send(agent, "lua", "exit")
        return nil
    end

    player.expiration = skynet.now() + 100*300 -- 缓存一个小时3600
    cache_players[uid] = player
    return player
end

--请求创建一个单人副本
function CMD.createFuben(uid,id)
    if not players[uid] then
       return 
    end
    local player = players[uid] 
    if not player.fuben then
        local fuben = skynet.newservice "fuben"
        player.fuben = fuben
    end
    local ok, err
    ok, err = util.pcall(skynet.call, player.fuben, "lua", "enter",id, player.agent)
    if not ok then
        log.error("进入游戏失败")
        return
    end
    LOG("enter scene 成功 ")
end

function CMD.start(conf)
    init(conf)
    local listenfd = socket.listen("0.0.0.0", conf.port)
    socket.start(listenfd, function(id, addr)
        local ok, err = websocket.accept(id, handle, "ws", addr)
        if not ok then
            log.error(err)
        end
    end)
end

-- call by agent
function CMD.logout(uid)
    local player = players[uid]
    if player then
        -- table.insert(agent_pool, player.agent)
        websocket.close(player.fd)
        connections[player.fd] = nil
        players[uid] = nil
        cur_client = cur_client - 1
        player.fd = 0
        player.expiration = skynet.now() + 100*300 -- 缓存一个小时
        cache_players[uid] = player
    end
end

function CMD.kick(uid, reason)
    local player = players[uid]
    if player then
        table.insert(agent_pool, player.agent)
        local payload = assert(pb.encode("proto.Kick", {reason=reason}))
        local msg = assert(pb.encode("proto.Msg", {
            seq = 0,
            cmd = "proto.Kick",
            payload = payload
        }))
        websocket.write(player.fd, msg, "binary")
        websocket.close(player.fd)
    end
end

local function clear_players()
    skynet.timeout(100*100, clear_players)
    local now = skynet.now()
    for uid, player in pairs(cache_players) do
        if now>= player.expiration then
            local agent = player.agent
            if agent then
                skynet.send(agent, "lua", "exit")
            end
            cache_players[uid]= nil
        end
    end
end

skynet.start(function()
    skynet.dispatch("lua", function (_, _, cmd, ...)
        local f = assert(CMD[cmd], cmd .. " not found")
        skynet.retpack(f(...))
    end)

    -- 每5分钟清理一次缓存
    skynet.timeout(100*100, clear_players)

    skynet.register("." .. SERVICE_NAME)
end)