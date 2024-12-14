local require = require
local pairs = pairs
local assert = assert
local pcall = pcall
local string = string

local service = require "service"
local skynet = require "skynet"
local errors = require "common.errors"
local log = require "log"
local timer = require "timer"
local lfs = require "lfs"
local util = require "util.util"
local tableutil = require "util.table"
local constant = require "common.constant"

local snowflake = require "snowflake"

local lbconfig_tbadventureconfig = require "lbconfig_tbadventureconfig"
local lbconfig_tbmonsterconfig = require "lbconfig_tbmonsterconfig"

-- 玩家代理服务，一个在线玩家，对就一个agent服务
-- 某些游戏类型，所有玩家共用一个agent服务更合理

local myagent = nil


local monsterlist = {}
local curround = 0

local function initMonster(info)
    local cfg = lbconfig_tbmonsterconfig[info.monterid]
    if cfg then
        local monster = {
            uid = snowflake.next(),
            monsterid = info.monterid,
            hp = cfg.hp,
            speed =cfg.speed,
            x= 0,
            y=0,
            target=nil
        }
        table.insert(monsterlist,monster)
    end
end

--onewave={{monterid=5000000,montercnt=1,},{monterid=5000001,montercnt=2,},}
local function createMonster(cfg)
    if curround == 1 then
        for k,v in pairs(cfg.onewave) do
            initMonster(v)
        end
    end
    LOG("~~~~~~~~~~~~~ fuben monsterlist: ",monsterlist)
end

function service.cmd.enter(id, agent)
    LOG("fuben enter ok! id: ",id)
    myagent = agent
    local cfg = lbconfig_tbadventureconfig[1]
    LOG("~~~~~~~ fuben lbconfig_tbadventureconfig cfg : ",cfg or {})
    if not cfg then
        return
    end
    if curround == 0 then
        curround = 1
    end
    createMonster(cfg)
end

local function update(frame)

end


service.init {
    init = function ()
        skynet.fork(function () --开启协程
        --包吃帧率执行
        LOG("~~~~~~~~~~~~~~ process: waittime: frame: ")
        local stime = skynet.now()
        local frame = 0
        while true do
            frame = frame + 1
            local isok, err = pcall(update, frame) --在死循环中执行update，传入当前帧frame
            if not isok then
                skynet.error(err)
            end
            local etime = skynet.now()
            local waittime = frame * 20 - (etime - stime)
            if waittime <= 0 then
                waittime = 2
            end
            --LOG("~~~~~~~~~~~~~~ process: waittime: "..waittime.." frame: ",frame)
            skynet.sleep(waittime) --利用死循环和skynet.sleep实现每隔一段时间执行逻辑主循环update
        end 
        end)
    end
}

--[[service.init = function ()
    skynet.fork(function () --开启协程
        --包吃帧率执行
        LOG("~~~~~~~~~~~~~~ process: waittime: frame: ")
        local stime = skynet.now()
        local frame = 0
        while true do
            frame = frame + 1
            local isok, err = pcall(update, frame) --在死循环中执行update，传入当前帧frame
            if not isok then
                skynet.error(err)
            end
            local etime = skynet.now()
            local waittime = frame * 20 - (etime - stime)
            if waittime <= 0 then
                waittime = 2
            end
            LOG("~~~~~~~~~~~~~~ process: waittime: "..waittime.." frame: ",frame)
            skynet.sleep(waittime) --利用死循环和skynet.sleep实现每隔一段时间执行逻辑主循环update
        end 
    end)
end]]

--[[
service.init {
    init = function ()
        skynet.fork(function () --开启协程
        --包吃帧率执行
            local stime = skynet.now()
            local frame = 0
            while true do
                frame = frame + 1
                local isok, err = pcall(update, frame) --在死循环中执行update，传入当前帧frame
                if not isok then
                    skynet.error(err)
                end
                local etime = skynet.now()
                local waittime = frame * 20 - (etime - stime)
                if waittime <= 0 then
                    waittime = 2
                end
                LOG("~~~~~~~~~~~~~~ process: waittime: "..waittime.." frame: ",frame)
                skynet.sleep(waittime) --利用死循环和skynet.sleep实现每隔一段时间执行逻辑主循环update
            end 
        end)
    end
}]]
