local skynet = require "skynet"
require "skynet.manager"

local log = require "log"
local util = require "util.util"
local tableutil = require "util.table"
local lfs = require "lfs"

local mysql = require "skynet.db.mysql"

local pb = require "pb"
local protoc = require "protoc"
local pc = protoc.new()
pc:addpath("proto/db")
pc.include_imports = true

for file in lfs.dir("./proto/db") do
    if file:match("%.proto$") then
        pc:loadfile(file)
    end
end

local CMD = {}

local MAX_ACTOR_CREATE = ((1 << 30) - 1) - 1
local actorid_series_ = 0
local serverindex = skynet.getenv("serverindex")

local function check_actorid_series()
	local sql = string.format("call loadmaxactoridseries(%d)", serverindex)
	local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
	if rs and rs[1] then
		--LOG(rs)
		if rs[1][1].maxid then
			actorid_series_ = rs[1][1].maxid
			actorid_series_ = actorid_series_ + 1
		else
			actorid_series_ = 0
		end
	else
		actorid_series_ = 0
	end
	LOG("actorid_series_ : ", actorid_series_)
end

function  CMD.start()

end

-- pb message中包含表名
function CMD.load(uid, table_name)
	local sql = string.format("SELECT * FROM `%s` WHERE `actorid`=%d LIMIT 1", table_name, uid)
	local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
	local row = #rs > 0 and rs[1] or rs
	return row
end

-- 各个模块定时备份，调用该函数
function CMD.set(uid, table_name, msg_name, msg)
		local key = "table:" .. table_name .. ":" .. tostring(uid)
	local data = util.do_redis("get", key)
	if data then
		if data == msg then
			-- 数据没有改变，直接返回
			return
		end
	end

	local t = pb.decode(msg_name, msg)
	local pk = "`actorid`"
	local pk_value = uid
	if t.id then
		pk = "`id`"
		pk_value = t.id
	end

	local counter = 0
	local set_clause = ""
	for k, v in pairs(t) do
		if counter > 0 then
			set_clause = set_clause .. ","
		end
		set_clause = set_clause .. "`" .. k .. "`" .. "="
		if type(v) == "string" then
			v = "'" .. v .. "'"
		end
		set_clause = set_clause .. v
		counter = counter + 1
	end

	local sql = ""
	sql = sql .. "UPDATE "
	sql = sql .. "`" .. table_name .. "`"
	sql = sql .. " SET "
	sql = sql .. set_clause
	sql = sql .. " WHERE "
	sql = sql .. pk
	sql = sql .. "=";
	sql = sql .. tostring(pk_value)

	--LOG(sql)

	skynet.call(".mysqlpool", "lua", "execute", sql)
	util.do_redis("set", key, msg)
end

-- update 与 set 的区别就在于没有缓存
function CMD.update(uid, table_name, msg_name, msg)
	local t = pb.decode(msg_name, msg)
	local pk = "`actorid`"
	local pk_value = uid
	if t.id then
		pk = "`id`"
		pk_value = t.id
	end
	local counter = 0
	local set_clause = ""
	for k, v in pairs(t) do
		if counter > 0 then
			set_clause = set_clause .. ","
		end
		set_clause = set_clause .. "`" .. k .. "`" .. "="
		if type(v) == "string" then
			v = "'" .. v .. "'"
		end
		set_clause = set_clause .. v
		counter = counter + 1
	end

	local sql = ""

	sql = sql .. "UPDATE "
	sql = sql .. "`" .. table_name .. "`"
	sql = sql .. " SET "
	sql = sql .. set_clause
	sql = sql .. " WHERE "
	sql = sql .. pk
	sql = sql .. "=";
	sql = sql .. tostring(pk_value)

	LOG(sql)

	return skynet.call(".mysqlpool", "lua", "execute", sql)
end

function CMD.query(uid, table_name, fields, where_clause)
	local columns
	if tableutil.empty(fields) then
		columns = "*"
	else
		local counter = 0
		for _, field in ipairs(fields) do
			if counter == 0 then
				columns = "`" .. field .. "`"
			else
				columns = columns .. "," .. "`" .. field .. "`"
			end
			counter = counter + 1
		end
	end

	local sql
	if where_clause and where_clause ~= "" then
		sql = string.format("SELECT %s FROM `%s` WHERE %s", columns, table_name, where_clause)
	else
		sql = string.format("SELECT %s FROM `%s`", columns, table_name)
	end

	LOG(sql)

	return skynet.call(".mysqlpool", "lua", "execute", sql)
end

function CMD.insert(uid, table_name, msg_name, msg)
	local t = pb.decode(msg_name, msg)
	local counter = 0
	local clause1 = ""
	local clause2 = ""
	for k, v in pairs(t) do
		if counter > 0 then
			clause1 = clause1 .. ","
			clause2 = clause2 .. ","
		end
		clause1 = clause1 .. "`" .. k .. "`"
		if type(v) == "string" then
			v = "'" .. v .. "'"
		end
		clause2 = clause2 .. v
		counter = counter + 1
	end

	local sql = ""

	sql = sql .. "INSERT INTO "
	sql = sql .. "`" .. table_name .. "`"
	sql = sql .. "("
	sql = sql .. clause1
	sql = sql .. ") VALUES("
	sql = sql .. clause2
	sql = sql .. ")";

	LOG(sql)

	return skynet.call(".mysqlpool", "lua", "execute", sql)
end

function CMD.remove(uid, table_name, msg_name, msg)
	local t = pb.decode(msg_name, msg)
	local pk = "`actorid`"
	local pk_value = uid
	if t.id then
		pk = "`id`"
		pk_value = t.id
	end

	local sql = ""

	sql = sql .. "DELETE FROM "
	sql = sql .. "`" .. table_name .. "`"
	sql = sql .. " WHERE "
	sql = sql .. pk
	sql = sql .. "="
	sql = sql .. tostring(pk_value)
	sql = sql .. " LIMIT 1";

	LOG(sql)

	return skynet.call(".mysqlpool", "lua", "execute", sql)
end

function CMD.execute(uid, sql)
	return skynet.call(".mysqlpool", "lua", "execute", sql)
end

function CMD.createrole(uid, table_name, msg_name, msg)
	local t = pb.decode(msg_name, msg)
	local counter = 0
	local clause1 = ""
	local clause2 = ""
	for k, v in pairs(t) do
		if counter > 0 then
			clause1 = clause1 .. ","
			clause2 = clause2 .. ","
		end
		clause1 = clause1 .. "`" .. k .. "`"
		if type(v) == "string" then
			v = "'" .. v .. "'"
		end
		clause2 = clause2 .. v
		counter = counter + 1
	end

	local actor_id = ((actorid_series_ << 30) | tonumber(serverindex))
	actorid_series_ = actorid_series_ + 1

	--local sql = ""
	local sql = "INSERT INTO `user` (`email`,`password`,`actorid`,`created_at`,`account`) VALUES ('',".."'"..t.password.."'"..","..actor_id..","..t.created_at..",".."'"..t.account.."'"..");"

	LOG(sql)

	return skynet.call(".mysqlpool", "lua", "execute", sql),actor_id
end

-- update 与 set 的区别就在于没有缓存
function CMD.updateuser_bind(uid, openid)
	local sql = "UPDATE user_bind SET actorid = "..uid.." WHERE openid = '"..openid.."'"
	--LOG(sql)

	return skynet.call(".mysqlpool", "lua", "execute", sql)
end

-- 各个模块定时备份，调用该函数
function CMD.saveplayer(uid, table_name, msg_name, msg)
	local key = "table:" .. table_name .. ":" .. tostring(uid)
	local data = util.do_redis("get", key)
	if data then
		if data == msg then
			-- 数据没有改变，直接返回
			return
		end
	end
	local t = pb.decode(msg_name, msg)
	
	local attrdb = {
		attrslist = t.attrslist
	}
	local attrdata = pb.encode("db.attrselfdb", attrdb)

	local equipdb = {
		equipslist = t.equipslist
	}
	local equipdata = pb.encode("db.equipselfdb", equipdb)

	local skilldb = {
		skillslist = t.skillslist
	}
	local skilldata = pb.encode("db.skillselfdb", skilldb)

	local sql = string.format("update player set name='%s', energy=%d, coin=%d, yuanbao=%d, totalpower=%d, head=%s, chapterid=%d,".. 
			" autobattle=%d, onlinetime=%d, attrs=%s, equips=%s, skils=%s where actorid=%d",t.name,t.energy,t.coin,t.yuanbao,t.totalpower,
			t.head,t.chapterid,t.autobattle,t.onlinetime,mysql.quote_sql_str(attrdata),mysql.quote_sql_str(equipdata),
		    mysql.quote_sql_str(skilldata),uid)
	--LOG(sql)

	skynet.call(".mysqlpool", "lua", "execute", sql)
	util.do_redis("set", key, msg)

end

-- 各个模块定时备份，调用该函数
function CMD.cardset(uid, table_name, msg_name, msg)
	local key = "table:" .. table_name .. ":" .. tostring(uid)
	local data = util.do_redis("get", key)
	if data then
		if data == msg then
			-- 数据没有改变，直接返回
			return
		end
	end
	local sql = string.format("update %s set data=%s where actorid=%d", table_name, mysql.quote_sql_str(msg),uid)
	--LOG(sql)
	skynet.call(".mysqlpool", "lua", "execute", sql)
	util.do_redis("set", key, msg)

end

skynet.start(function ()
	skynet.dispatch("lua", function (_, _, cmd, ...)
		local f = assert(CMD[cmd], cmd .. " not found")
		skynet.retpack(f(...))
	end)
	skynet.timeout(5, check_actorid_series)
	skynet.register("." .. SERVICE_NAME)
end)
