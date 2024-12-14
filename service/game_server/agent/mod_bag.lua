local require = require
local string = string
local tostring = tostring
local table = table

local skynet = require "skynet"
local service = require "service"
local log = require "log"
local util = require "util.util"
local tableutil = require "util.table"
local snowflake = require "snowflake"
local constant = require "common.constant"
local cjson = require "cjson"

local stringutil = require "util.string"

local lbconfig_tbcommon = require "lbconfig_tbcommon"

local mysql = require "skynet.db.mysql"

local snowflake = require "snowflake"

local bagflag = false

-- 加载 proto
local pb = require "pb"
local protoc = require "protoc"
local pc = protoc.new()
pc:addpath("proto/")
pc.include_imports = true
pc:loadfile("db/bag.proto")
pc:loadfile("equip.proto")


local M = {
    uid = 0,
    baglist = {}
}

local function syncAllBagInfo()
    local bagList = {}
    for i,v in pairs(M.baglist) do
        if v.uid ~= 0 then
            local equipDict ={
                uid = v.uid,
                itemid = v.itemid,
                level = v.level,
                isequip = v.isequip
            }
            table.insert(bagList,equipDict)
        end
    end
    local bagbase = {
        equiplist = bagList
    }
    local payload = assert(pb.encode("proto.equipData", bagbase))
    local msg = assert(pb.encode("proto.Msg", {
        id = constant.SystemID.CMD_Equip,
        cmd = "equipData",
        payload = payload
    }))
    skynet.send(".wsgate", "lua", "push", M.uid, msg)
end
function service.client.pet_BagInfoReq(uid)
    syncAllBagInfo()
end

function InitBagInfo(cid, from, flag)
    local uuid = snowflake.next()
    local cfg = lbconfig_tbitem[cid]
    if not cfg then
        return false
    end
    local item = {
        uid = uuid,
        itemid = cid,
        level = cfg.level,
        isequip = false
    }

    table.insert(M.baglist,item)
    return item
end

function service.method.InitItem(cid, from, nopush)
    InitBagInfo(cid,from,false)
    if nopush then
        syncAllBagInfo()
    end 
end

function service.method.InitItems(cids, from, nopush)

end

-- 模块
function M.onInit()
    
end

function M.onRelease()

end

function M.onRun()
    if not bagflag then
        return
    end
end

function savebag()
    local bagListArray = {}
    for k,v in pairs(M.baglist) do
        local bagDict = {
            uid = v.uid,
            itemid = v.itemid,
            level = v.level,
            isequip = v.isequip
        }
        table.insert(bagListArray,bagDict)
    end
    local bagdb = {
        baglist = bagListArray
    }
    local bagdatas = pb.encode("db.bagdb", bagdb)
     util.call("db", ".dbproxy", "cardset", M.uid, "bag", "db.bagdb", bagdatas)
end

function M.onBackup()
    if not bagflag then
        return
    end
    savebag()
end


function M.onLoad()
    M.baglist = {}
    local _bagdata = util.call("db", ".dbproxy", "load", M.uid, "bag")
    if _bagdata then
        if _bagdata.data then
            local baginfo = pb.decode("db.bagdb", _bagdata.data)
            M.baglist = baginfo.baglist or {}
        end
    end
end

-- 玩家所有数据已加载完毕后触发, 在该函数中可以处理离线逻辑
function M.onActivate()
    bagflag = true
end

function M.onPlayerOnline()
    syncAllBagInfo()
end

function M.onPlayerOffline()

end

function M.onTimeEvent(ct)

end

return M