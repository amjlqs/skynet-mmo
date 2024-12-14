local require = require
local tostring = tostring
local table = table

local skynet = require "skynet"
local service = require "service"
local log = require "log"
local util = require "util.util"
local tableutil = require "util.table"
local snowflake = require "snowflake"
local constant = require "common.constant"
local stringutil = require "util.string"
local socket = require "skynet.socket"
local websocket = require "http.websocket"
local httpc = require "http.httpc"
--local dns = require "skynet.dns"
local cjson = require "cjson"

local lbconfig_tbcreatplayerconfig = require "lbconfig_tbcreatplayerconfig"

-- 加载 proto
local pb = require "pb"
local protoc = require "protoc"
local pc = protoc.new()
pc:addpath("proto/")
pc.include_imports = true
pc:loadfile("db/player.proto")
pc:loadfile("db/coin_log.proto")
pc:loadfile("user.proto")

local lastupdatetime = 0
local addenergytime = 0

local timeflag = false

local M = {
    uid = 0,
    player = {},
}


-- 客户端消息
    -- function service.client.user_InfoReq(uid, req)
--     local rsp = {
--         name = "test name"
--     }

--     -- 如果出现业务, 请返回错误
--     -- return nil, errors.XXXX
--     -- 错误码定义在lualib/errors/errors.lua中
--     return rsp
-- end

local function syncBaseInfo()
    local userInfoSyn = {
        actorid = M.player.actorid,
        name = M.player.name,
        rtime = M.player.rtime,
        energy = M.player.energy,
        coin = M.player.coin,
        gold = M.player.gold,
        head = M.player.head,
        totalpower = M.player.totalpower,
        chapterid = M.player.chapterid,
        autobattle = M.player.autobattle,
        attrslist = M.player.attrslist,
        equipslist = M.player.equipslist,
        skillslist = M.player.skillslist,
    }

    local payload = assert(pb.encode("proto.userInfoSyn", userInfoSyn))
    local msg = assert(pb.encode("proto.Msg", {
        id = constant.SystemID.CMD_Base,
        cmd = "userInfoSyn",
        payload = payload
    }))
    skynet.send(".wsgate", "lua", "push", M.uid, msg)
end

---------------------------------------------/////-------------------------------------------

-- 节点内消息
function service.cmd.change_attribute(attr_type, attr_value, action, extra, nopush)
    return service.method.change_attribute(attr_type, attr_value, action, extra, nopush)
end

function service.method.cfgReward(rewards)
    for _,reward in pairs(rewards or {}) do
        if reward.type == constant.EnumExId.petCfg then --宠物表
            service.method.InitPet(reward.cid,0,true)
        end  
    end
end

function service.method.change_attribute(attr_type, attr_value, action, extra, nopush)
    -- TODO: 根据attr_type获取相应的函数
    local f = service.method.change_function[attr_type]
    return f(attr_value, action, extra, nopush)
end

local function setAddEnergyTime(level)
    maxvalue = 60
end


--初始化玩家数据
function service.method.InitPlayer()
    --LOG("~~~ lbconfig_tbcreatplayerconfig: ",lbconfig_tbcreatplayerconfig)
    local cfg = lbconfig_tbcreatplayerconfig[1]
    M.player.energy = cfg.power
    M.player.head = cfg.head
    M.player.coin = cfg.coin
    M.player.gold = cfg.gold

    M.player.totalpower = 0
    M.player.chapterid = 0
    M.player.autobattle = 0
    local attrslist ={}
    local attrsDict = {
        attrid = 1001,
        level = 0
    }
    table.insert(attrslist,attrsDict)
    M.player.attrslist = attrslist

    local equipslist = {}
    local equipsDict = {
        pos = 1,
        itemuid = 10001
    }
    table.insert(equipslist,equipsDict)
    M.player.equipslist = equipslist

    local skillslist = {}
    local skillInfo = {
        pos = 1,
        skilluid = 100001
    }
    local skillpos = {}
    table.insert(skillpos,skillInfo)
    local skillsDict = {
        skillpos = skillpos,
        holenum = 3,
        isuse = false
    }
    table.insert(skillslist,skillsDict)
    M.player.skillslist = skillslist
    for k,v in pairs(cfg.attr) do
        if v.type ==  constant.EnumExId.petCfg then
            service.method.InitCard(v.cid,0)
        end
    end
    save() 
end

function savecoinlog(type,before_values,after_values,change_values,remark)
    local row = {
        id = snowflake.next(),
        actorid = M.uid,
        type = type,
        before_coin = before_values,
        after_coin = after_values,
        amount = change_values,
        game_id = 0,
        created_at = os.time(),
        remark = remark
    }
    local msg = pb.encode("db.coin_log", row)
    util.call("db", ".dbproxy", "insert", M.uid, "coin_log", "db.coin_log", msg)
end

-- TODO: 属性相关代码, 可以用工具来生成
-- BEGIN 玩家属性相关代码
function service.method.change_coin(attr_value, action, extra, nopush)
    if attr_value == 0 then
        return false
    end
    if not M.player.coin then
        M.player.coin = 0
    end

    local before_coin = M.player.coin
    if (M.player.coin + attr_value) < 0 then
        return false
    end
    M.player.coin = M.player.coin + attr_value
    if M.player.coin < 0 then
        log.warnf("%d %d %d", M.uid, attr_value, M.player.coin)

        M.player.coin = 0
    end

    local game_id = extra and extra.game_id or 0
    local remark = extra and extra.remark or ""
    savecoinlog(constant.ATTRIBUTE_TYPE.COIN,before_coin,M.player.coin,attr_value,remark)
    syncBaseInfo()
    if not nopush then   
        save()
    end
    return true
end

function service.method.check_coin(attr_value)
    if attr_value < 0 then
        log.warnf("%d %d", M.uid, attr_value)
        return false
    end

    if not M.player.coin then
        M.player.coin = 0
    end

    return M.player.coin - attr_value >= 0
end

function service.method.get_coin()
    if not M.player.coin then
        M.player.coin = 0
    end
    return M.player.coin
end

-- BEGIN 玩家属性相关代码
-- 消耗玩家体力
function service.method.change_energy(attr_value, action, extra, nopush)
    --LOG(" change_energy: attr_value: ",attr_value.." action: "..action.."  M.player.energy: ".. M.player.energy)
    local before_energy = M.player.energy
    if (M.player.energy + attr_value) >= 0 then
        M.player.energy = M.player.energy + attr_value
    else
        return false
    end
    if not nopush then
        syncBaseInfo()
    end

    save()
    local remark = extra and extra.remark or ""
    savecoinlog(constant.ATTRIBUTE_TYPE.ENERGY,before_energy,M.player.energy,attr_value,remark)
    return true
end

--改变元宝数量
function service.method.change_gold(attr_value, action, extra, nopush)
    local before_gold = M.player.gold 
    if (M.player.gold + attr_value) >= 0 then
        M.player.gold = M.player.gold + attr_value
    else
        return false
    end
    if M.player.gold < 0 then
        log.warnf("%d %d %d", M.uid, attr_value, M.player.gold)

        M.player.gold = 0
    end
    if not nopush then
        syncBaseInfo()
    end
    save()
    local remark = extra and extra.remark or ""
    savecoinlog(constant.ATTRIBUTE_TYPE.GOLD,before_gold,M.player.gold,attr_value,remark)
    return true
end

service.method.change_function = {
    [constant.ATTRIBUTE_TYPE.COIN] = service.method.change_coin,
    [constant.ATTRIBUTE_TYPE.GOLD] = service.method.change_gold,
    [constant.ATTRIBUTE_TYPE.ENERGY] = service.method.change_energy,
}

service.method.get_function = {
    [constant.ATTRIBUTE_TYPE.COIN] = service.method.get_coin
}

service.method.check_function = {
    [constant.ATTRIBUTE_TYPE.COIN] = service.method.check_coin
}
-- END 玩家属性相关代码

function service.method.get_user_info()
    return M.player
end



-- 模块
function M.onInit()

end

function M.onRelease()

end

local function updateEnergy(curtime)
    local maxvalue = 100
    if M.player.energy < maxvalue then
        local ratio = math.floor((curtime - M.player.energyupdatetime)/addenergytime)
        local before_energy = M.player.energy
        local addenergy = 1
        M.player.energy = M.player.energy + addenergy * ratio
        if M.player.energy > maxvalue then
            M.player.energy = maxvalue
        end
        syncBaseInfo()
        savecoinlog(constant.ATTRIBUTE_TYPE.ENERGY,before_energy,M.player.energy,addenergy,"自动增加的体力")
    end
end

function M.onRun()
    if not timeflag then
        return
    end
end


function save()
    local player = tableutil.copy(M.player)
    local playerdb = {
        actorid = player.actorid,
        name = player.name,
        rtime = player.rtime,
    
        energy = player.energy,
        coin = player.coin,
        gold = player.gold,
        totalpower = player.totalpower,
        head = player.head,
        serverindex = 1,
        chapterid = player.chapterid,
        autobattle = player.autobattle,
        attrslist = player.attrslist,
        equipslist = player.equipslist,
        skillslist = player.skillslist,
        onlinetime = os.time()
    }
    local data = pb.encode("db.playerdb", playerdb)
    util.call("db", ".dbproxy", "saveplayer", M.uid, "player", "db.playerdb", data)
end

function M.onBackup()
    if not timeflag then
        return
    end
    save()
end

function M.onLoad()
    --LOG("mod_user onLoad M.uid: ",M.uid)
    local playerdata = util.call("db", ".dbproxy", "load", M.uid, "player")
    if playerdata then
        local attrdata = {}
        if playerdata.attrs then
            attrdata = pb.decode("db.attrselfdb", playerdata.attrs)
        end

        local equipdata = {}
        if playerdata.equips then
            equipdata = pb.decode("db.equipselfdb", playerdata.equips)
        end

        local skilldata = {}
        if playerdata.skils then
            skilldata = pb.decode("db.skillselfdb", playerdata.skils)
        end

        M.player = {
            actorid = playerdata.actorid,
            name = playerdata.name,
            rtime = playerdata.rtime,
            energy = playerdata.energy,
            coin = playerdata.coin,
            gold = playerdata.gold,
            totalpower = playerdata.totalpower,
            head = playerdata.head,
            chapterid = playerdata.chapterid,
            autobattle = playerdata.autobattle,
            serverindex = playerdata.serverindex,
            onlinetime = os.time(),
            attrslist = attrdata.attrslist or {},
            equipslist = equipdata.equipslist or {}, 
            skillslist = skilldata.skillslist or {}
        }
    end
    --LOG("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   M.player: ",M.player)

    assert(not tableutil.empty(M.player))
end

-- 玩家所有数据已加载完毕后触发, 在该函数中可以处理离线逻辑
function M.onActivate()
    --setAddEnergyTime(M.player.level)
    timeflag = true
end

function M.onPlayerOnline()
    syncBaseInfo()
end

function M.onPlayerOffline()

end

function M.onTimeEvent(ct)

end

return M