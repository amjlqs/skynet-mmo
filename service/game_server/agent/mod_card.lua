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


local lbconfig_tbcard = require "lbconfig_tbcard"
local lbconfig_tbcommon = require "lbconfig_tbcommon"

local mysql = require "skynet.db.mysql"

local snowflake = require "snowflake"

local updateflag = false

-- 加载 proto
local pb = require "pb"
local protoc = require "protoc"
local pc = protoc.new()
pc:addpath("proto/")
pc.include_imports = true
pc:loadfile("db/card.proto")
pc:loadfile("card.proto")


local M = {
    uid = 0,
    cardlist = {}
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

local function syncAllCardInfo()
    local cardList = {}
    for i,v in pairs(M.cardlist) do
        if v.uid ~= 0 then
            local cardDict ={
                uid = v.uid,
                cardid = v.cardid,
                level = v.level,
                isbattle = v.isbattle
            }
            table.insert(cardList,cardDict)
        end
    end
    local cardbase = {
        cardlist = cardList
    }
    local payload = assert(pb.encode("proto.cardData", cardbase))
    local msg = assert(pb.encode("proto.Msg", {
        id = constant.SystemID.CMD_Role,
        cmd = "cardData",
        payload = payload
    }))
    skynet.send(".wsgate", "lua", "push", M.uid, msg)
end
function service.client.pet_PetInfoReq(uid)
    syncAllPetInfo()
end

function InitCardInfo(cid, from, flag)
    local uuid = snowflake.next()
    local cfg = lbconfig_tbcard[cid]
    if not cfg then
        return false
    end
    local card = {
        uid = uuid,
        cardid = cid,
        level = cfg.level,
        isbattle = false
    }

    table.insert(M.cardlist,card)
    savecard()
    return card
end

function service.method.InitCard(cid, from, nopush)
    InitCardInfo(cid,from,false)
    if nopush then
        syncAllCardInfo()
    end 
end

-- 模块
function M.onInit()
    
end

function M.onRelease()

end

function M.onRun()
    if not updateflag then
        return
    end
    local curtime = os.time()
end

function savecard()
    local cardListArray = {}
    for k,v in pairs(M.cardlist) do
        local cardDict = {
            uid = v.uid,
            cardid = v.cardid,
            level = v.level,
            isbattle = v.isbattle
        }
        table.insert(cardListArray,cardDict)
    end
    local carddb = {
        cardlist = cardListArray
    }
    local carddatas = pb.encode("db.carddb", carddb)
     util.call("db", ".dbproxy", "cardset", M.uid, "card", "db.carddb", carddatas)
end

function M.onBackup()
    if not updateflag then
        return
    end
    savecard()
end


function M.onLoad()
    M.cardlist = {}
    local _carddata = util.call("db", ".dbproxy", "load", M.uid, "card")
    if _carddata then
        if _carddata.data then
            local petatrinfo = pb.decode("db.carddb", _carddata.data)
            M.cardlist = petatrinfo.cardlist or {}
        end
    end
end

-- 玩家所有数据已加载完毕后触发, 在该函数中可以处理离线逻辑
function M.onActivate()
    updateflag = true
end

function M.onPlayerOnline()
    syncAllCardInfo()
end

function M.onPlayerOffline()

end

function M.onTimeEvent(ct)

end

return M