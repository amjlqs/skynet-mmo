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

local skillflag = false

-- 加载 proto
local pb = require "pb"
local protoc = require "protoc"
local pc = protoc.new()
pc:addpath("proto/")
pc.include_imports = true
pc:loadfile("db/skill.proto")
pc:loadfile("skill.proto")


local M = {
    uid = 0,
    skillList = {}
}

local function syncAllSkillInfo()
    local skillList = {}
    for i,v in pairs(M.skillList) do
        if v.uid ~= 0 then
            local skillDict ={
                uid = v.uid,
                skillid = v.skillid,
                level = v.level,
                isequip = v.isequip
            }
            table.insert(skillList,skillDict)
        end
    end
    local skillData = {
        skillList = skillList
    }
    local payload = assert(pb.encode("proto.skillData", skillData))
    local msg = assert(pb.encode("proto.Msg", {
        id = constant.SystemID.CMD_Skill,
        cmd = "skillData",
        payload = payload
    }))
    skynet.send(".wsgate", "lua", "push", M.uid, msg)
end
function service.client.pet_SkillInfoReq(uid)
    syncAllSkillInfo()
end

function InitSkillInfo(cid, from, flag)
    local uuid = snowflake.next()
    --LOG("~~~~~~uuid: ",uuid)
    local cfg = lbconfig_tbskill[cid]
    if not cfg then
        return false
    end
    local skill = {
        uid = uuid,
        skillid = cid,
        level = cfg.level,
        isequip = false
    }

    table.insert(M.skillList,skill)
    return skill
end

function service.method.InitSkill(cid, from, nopush)
    InitSkillInfo(cid,from,false)
    if nopush then
        syncAllSkillInfo()
    end 
end

function service.method.InitSkills(cids, from, nopush)

end

-- 模块
function M.onInit()
    
end

function M.onRelease()

end

function M.onRun()
    if not skillflag then
        return
    end
    local curtime = os.time()
end

function saveskill()
    local skillListArray = {}
    for k,v in pairs(M.skillList) do
        local skillDict = {
            uid = v.uid,
            skillid = v.skillid,
            level = v.level,
            isequip = v.isequip
        }
        table.insert(skillListArray,skillDict)
    end
    local skilldb = {
        skillList = skillListArray
    }
    local skilldatas = pb.encode("db.skilldb", skilldb)
     util.call("db", ".dbproxy", "cardset", M.uid, "skill", "db.skilldb", skilldatas)
end

function M.onBackup()
    if not bagflag then
        return
    end
    saveskill()
end


function M.onLoad()
    M.skillList = {}
    local _skilldata = util.call("db", ".dbproxy", "load", M.uid, "skill")
    if _skilldata then
        if _skilldata.data then
            local skillinfo = pb.decode("db.skilldb", _skilldata.data)
            M.skillList = skillinfo.skillList or {}
        end
    end
end

-- 玩家所有数据已加载完毕后触发, 在该函数中可以处理离线逻辑
function M.onActivate()
    skillflag = true
end

function M.onPlayerOnline()
    syncAllSkillInfo()
end

function M.onPlayerOffline()

end

function M.onTimeEvent(ct)

end

return M