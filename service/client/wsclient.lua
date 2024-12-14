local skynet = require "skynet"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local httpc = require "http.httpc"

require "skynet.manager"

local log = require "log"
local uuid = require "uuid"

local pb = require "pb"
local protoc = require "protoc"
local pc = protoc.new()
pc:addpath("proto/")
pc.include_imports = true
pc:loadfile("proto.proto")
pc:loadfile("login.proto")
pc:loadfile("chat.proto")
pc:loadfile("api/passport.proto")
pc:loadfile("user.proto")
pc:loadfile("card.proto")
pc:loadfile("equip.proto")
pc:loadfile("skill.proto")
pc:loadfile("pm.proto")



local ws_port = skynet.getenv("ws_port")
local ws_id
local seq = 0
local logged = false

local function inc_seq()
    seq = seq + 1
end
local actorid = 0

local userdata = {}
local carddata = {}

local function recv_msg_loop()
    while true do
        local data, close_reason = websocket.read(ws_id)
        if not data then
            LOG("server close")
            os.exit()
        end
        local m = assert(pb.decode("proto.Msg", data))
        LOGF("recv msg cmd=%s", m.cmd)
        --local rsp = assert(pb.decode("proto.LoginRsp", m.payload))
        --LOG(rsp)
        if m.cmd == "LoginRsp" then
            local rsp = assert(pb.decode("proto.LoginRsp", m.payload))
            logged = true
            actorid = rsp.uid
        end

        if m.cmd == "userInfoSyn" then
            local res = assert(pb.decode("proto.userInfoSyn", m.payload))
            userdata = res
        end
        if m.cmd == "cardData" then
            local res = assert(pb.decode("proto.cardData", m.payload))
            carddata = res
        end
    end
end

local function heartbeat()
    skynet.timeout(30*100, heartbeat)
    local msg = {
        id = 253,
        cmd = "Noop",
        payload = nil
    }

    local req = {
    }
    local payload = assert(pb.encode("proto.Noop", req))
    msg.payload = payload

    local data = assert(pb.encode("proto.Msg", msg))
    websocket.write(ws_id, data, "binary")
end

local CMD = {}

function CMD.login(openid, device_id)
    if not openid then
        openid = "xxxx"
    end

    ws_id = websocket.connect("ws://127.0.0.1:"..ws_port.."/ws")

    skynet.fork(recv_msg_loop)

    skynet.timeout(30*100, heartbeat)

    local msg = {
        id = 255,
        cmd = "LoginReq",
        payload = nil
    }
    local req = {
        openid = openid,
        server = 1
    }
    local payload = assert(pb.encode("proto.LoginReq", req))
    msg.payload = payload

    local data = assert(pb.encode("proto.Msg", msg))
    websocket.write(ws_id, data, "binary")
end

function CMD.pm(args)
    local msg = {
        id = 250,
        cmd = "PmReq",
        payload = nil
    }

    local req = {
        args = args,
    }
    local payload = assert(pb.encode("proto.PmReq", req))
    msg.payload = payload
    local data = assert(pb.encode("proto.Msg", msg))
    websocket.write(ws_id, data, "binary")
end


local function split_cmdline(cmdline)
	local split = {}
	for i in string.gmatch(cmdline, "%S+") do
		table.insert(split,i)
	end
	return split
end

local function console_main_loop()
	local stdin = socket.stdin()
	while true do
		local cmdline = socket.readline(stdin, "\n")
        local cmd, args = cmdline:match("^%s*([^%s]+)%s(.*)")
        if cmd == "pm" then
            if not logged then
                LOG("请先登录再执行该命令")
            else
                CMD[cmd](args)
            end
        else
            local split = split_cmdline(cmdline)
            cmd = split[1]
            local f = CMD[cmd]
            if f then
                if (not logged) and cmd ~= "login" then
                    LOG("请先登录再执行该命令")
                else
                    f(table.unpack(split, 2))
                end
            else
                LOG("unknown cmd")
            end
            inc_seq()
        end

        inc_seq()
	end
end

skynet.start(function ()
    skynet.fork(console_main_loop)
end)

