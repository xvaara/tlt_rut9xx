#!/usr/bin/env lua
local sqlite = require "lsqlite3"
local db -- database identifier

local dbPath = "/log/" -- place for running database
local dbName = "log.db" -- database file name
local dbFullPath = dbPath .. dbName -- full path to database
local table_name = "SMS_COUNT"



function failture()
	local out =
	[[ Wrong argument
		send	SLOT (SLOT1,SLOT2)
		recieve	SLOT (SLOT1,SLOT2)
		reset	SLOT (SLOT1,SLOT2,both)
		value	SLOT (SLOT1,SLOT2,both)
	]]
	print(out)
	db:close()
	os.exit()
end

function check_table()
	local query = "select * from " .. table_name
	local stmt = db:prepare(query)
	if stmt == nil then
		local query = "create table ".. table_name .. " (ID INTEGER PRIMARY KEY AUTOINCREMENT, SLOT char(15), SEND INTEGER, RECIEVED INTEGER);insert into SMS_COUNT (SLOT,SEND,RECIEVED) values ('SLOT1',0,0);insert into SMS_COUNT (SLOT,SEND,RECIEVED) values ('SLOT2',0,0)"
		db:exec(query)
	end
end

function get_values(slot)
	if slot == "SLOT0" then
		slot = "SLOT2"
	end
	if slot == "SLOT1" or slot == "SLOT2" or slot =="both" then
		local query = ""
		if slot == "SLOT1" or slot == "SLOT2" then
			query = "select * from " .. table_name .." where SLOT='".. slot .."'"
		else
			query = "select * from " .. table_name
		end
		local list = {}
		for row in db:nrows(query) do
			list[#list+1] = row
		end
		if slot == "SLOT1" or slot == "SLOT2" then
			print(list[1].SEND .. " " .. list[1].RECIEVED )
		else
			print(list[1].SEND .. " " .. list[1].RECIEVED .. "\n" .. list[2].SEND .. " " .. list[2].RECIEVED)
		end
	else
		failture()
	end
end

function send(slot)
	if slot == "SLOT0" then
		slot = "SLOT2"
	end
	if slot == "SLOT1" or slot == "SLOT2" then
		local query = "select SEND from ".. table_name .." where SLOT='".. slot .."'"
		for row in db:nrows(query) do
				row.SEND = row.SEND + 1
				local query = "update " .. table_name .." set SEND=".. row.SEND .." where SLOT='".. slot .."'"
				db:exec(query) 
		end
	else
		failture()
	end
end

function recieve(slot)
	if slot == "SLOT0" then
		slot = "SLOT2"
	end
	if slot == "SLOT1" or slot == "SLOT2" then
		local query = "select RECIEVED from ".. table_name .." where SLOT='".. slot .."'"
		for row in db:nrows(query) do
				row.RECIEVED = row.RECIEVED + 1
				local query = "update " .. table_name .." set RECIEVED=".. row.RECIEVED .." where SLOT='".. slot .."'"
				db:exec(query) 
		end
	else
		failture()
	end
	
end

function reset(slot)
	if slot == "SLOT0" then
		slot = "SLOT2"
	end
	if slot == "SLOT1" or slot == "SLOT2" or slot =="both" then
		if slot == "SLOT1" or slot == "both" then
			local query = "update " .. table_name .." set SEND=0 where SLOT='".. slot .."'; update " .. table_name .." set RECIEVED=0 where SLOT='".. slot .."'"
			db:exec(query)
		end
		if slot == "SLOT2" or slot == "both" then
			local query = "update " .. table_name .." set SEND=0 where SLOT='".. slot .."'; update " .. table_name .." set RECIEVED=0 where SLOT='".. slot .."'"
			db:exec(query)
		end
	else
		failture()
	end
end

function start()

	if arg[1] and arg[2] then
		db = sqlite.open(dbFullPath)
		check_table()
		if arg[1] == "send" then
			send(arg[2])
		elseif arg[1] == "recieve" then
			recieve(arg[2])
		elseif arg[1] == "reset" then
			reset(arg[2])
		elseif arg[1] == "value" then
			get_values(arg[2])
		else
			failture()
		end
	else
		failture()
	end
	db:close()
end

start()



