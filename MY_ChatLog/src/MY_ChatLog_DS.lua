--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 聊天记录 数据库集群控制器
-- @author   : 茗伊 @双梦镇 @追风蹑影
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
--------------------------------------------------------
-------------------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
-------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local ipairs, pairs, next, pcall = ipairs, pairs, next, pcall
local sub, len, format, rep = string.sub, string.len, string.format, string.rep
local find, byte, char, gsub = string.find, string.byte, string.char, string.gsub
local type, tonumber, tostring = type, tonumber, tostring
local HUGE, PI, random, abs = math.huge, math.pi, math.random, math.abs
local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil
local pow, sqrt, sin, cos, tan, atan = math.pow, math.sqrt, math.sin, math.cos, math.tan, math.atan
local insert, remove, concat, sort = table.insert, table.remove, table.concat, table.sort
local pack, unpack = table.pack or function(...) return {...} end, table.unpack or unpack
-- jx3 apis caching
local wsub, wlen, wfind = wstring.sub, wstring.len, wstring.find
local GetTime, GetLogicFrameCount = GetTime, GetLogicFrameCount
local GetClientTeam, UI_GetClientPlayerID = GetClientTeam, UI_GetClientPlayerID
local GetClientPlayer, GetPlayer, GetNpc, IsPlayer = GetClientPlayer, GetPlayer, GetNpc, IsPlayer
local LIB = MY
local UI, DEBUG_LEVEL, PATH_TYPE = LIB.UI, LIB.DEBUG_LEVEL, LIB.PATH_TYPE
local var2str, str2var, ipairs_r = LIB.var2str, LIB.str2var, LIB.ipairs_r
local spairs, spairs_r, sipairs, sipairs_r = LIB.spairs, LIB.spairs_r, LIB.sipairs, LIB.sipairs_r
local GetTraceback, Call, XpCall = LIB.GetTraceback, LIB.Call, LIB.XpCall
local Get, Set, RandomChild = LIB.Get, LIB.Set, LIB.RandomChild
local GetPatch, ApplyPatch, clone, FullClone = LIB.GetPatch, LIB.ApplyPatch, LIB.clone, LIB.FullClone
local IsArray, IsDictionary, IsEquals = LIB.IsArray, LIB.IsDictionary, LIB.IsEquals
local IsNumber, IsHugeNumber = LIB.IsNumber, LIB.IsHugeNumber
local IsNil, IsBoolean, IsFunction = LIB.IsNil, LIB.IsBoolean, LIB.IsFunction
local IsEmpty, IsString, IsTable, IsUserdata = LIB.IsEmpty, LIB.IsString, LIB.IsTable, LIB.IsUserdata
local MENU_DIVIDER, EMPTY_TABLE, XML_LINE_BREAKER = LIB.MENU_DIVIDER, LIB.EMPTY_TABLE, LIB.XML_LINE_BREAKER
-------------------------------------------------------------------------------------------------------------
local XML_LINE_BREAKER = XML_LINE_BREAKER

local _L = LIB.LoadLangPack(LIB.GetAddonInfo().szRoot .. 'MY_ChatLog/lang/')
if not LIB.AssertVersion('MY_ChatLog', _L['MY_ChatLog'], 0x2013500) then
	return
end

------------------------------------------------------------------------------------------------------
-- 数据库控制器
------------------------------------------------------------------------------------------------------
local EXPORT_SLICE = 100
local DIVIDE_TABLE_AMOUNT = 25000 -- 如果某张表大小超过25000
local SINGLE_TABLE_AMOUNT = 20000 -- 则将最久远的20000条消息独立成表
-- 频道对应数据库中数值 可添加 但不可随意修改
local CHANNELS = {
	[1] = 'MSG_WHISPER',
	[2] = 'MSG_PARTY',
	[3] = 'MSG_TEAM',
	[4] = 'MSG_FRIEND',
	[5] = 'MSG_GUILD',
	[6] = 'MSG_GUILD_ALLIANCE',
	[7] = 'MSG_SELF_DEATH',
	[8] = 'MSG_SELF_KILL',
	[9] = 'MSG_PARTY_DEATH',
	[10] = 'MSG_PARTY_KILL',
	[11] = 'MSG_MONEY',
	[12] = 'MSG_EXP',
	[13] = 'MSG_ITEM',
	[14] = 'MSG_REPUTATION',
	[15] = 'MSG_CONTRIBUTE',
	[16] = 'MSG_ATTRACTION',
	[17] = 'MSG_PRESTIGE',
	[18] = 'MSG_TRAIN',
	[19] = 'MSG_MENTOR_VALUE',
	[20] = 'MSG_THEW_STAMINA',
	[21] = 'MSG_TONG_FUND',
	[22] = 'MSG_MY_MONITOR',
}
local CHANNELS_R = LIB.FlipObjectKV(CHANNELS)

local function SToNChannel(aChannel)
	local aNChannel = {}
	for _, szChannel in ipairs(aChannel) do
		insert(aNChannel, CHANNELS_R[szChannel])
	end
	return aNChannel
end

local DS = class()
local DS_CACHE = setmetatable({}, {__mode = 'v'})

function DS:ctor(szRoot)
	self.szRoot = szRoot
	self.aInsertQueue = {}
	self.aDeleteQueue = {}
	return self
end

function DS:InitDB()
	if not self.aDB then
		-- 初始化数据库集群列表
		self.aDB = {}
		for _, szName in ipairs(CPath.GetFileList(self.szRoot) or {}) do
			local db = szName:find('^chatlog_[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]%.db') and MY_ChatLog_DB(self.szRoot .. szName)
			if db then
				insert(self.aDB, db)
			end
		end
		sort(self.aDB, function(a, b) return a:GetMinTime() < b:GetMinTime() end)
		-- 检查集群最新活跃节点压力是否超限
		local nCount = #self.aDB
		if nCount ~= 0 then
			local db = self.aDB[nCount]
			if not IsHugeNumber(db:GetMaxTime()) then
				if db:CountMsg() > SINGLE_TABLE_AMOUNT then
					db:SetMaxTime(db:GetMaxRecTime())
				end
			end
		end
		-- 检查集群最新活跃节点是否不存在
		if nCount == 0 or not IsHugeNumber(self.aDB[nCount]:GetMaxTime()) then
			local szPath
			repeat
				szPath = self.szRoot .. ('chatlog_%x'):format(math.random(0x100000, 0xFFFFFF)) .. '.db'
			until not IsLocalFileExist(szPath)
			local db = MY_ChatLog_DB(szPath)
			local nMinTime = 0
			if nCount ~= 0 then
				nMinTime = self.aDB[nCount]:GetMaxTime() + 1
			end
			db:SetMinTime(nMinTime)
			insert(self.aDB, db)
		end
	end
	return self
end

function DS:InsertMsg(szChannel, szText, szMsg, szTalker, nTime)
	local szHash, nChannel
	szMsg    = AnsiToUTF8(szMsg or '') or ''
	szText   = AnsiToUTF8(szText or '') or ''
	szHash   = GetStringCRC(szMsg)
	szTalker = szTalker and AnsiToUTF8(szTalker or '') or ''
	nChannel = CHANNELS_R[szChannel]
	if nChannel and nTime and not IsEmpty(szMsg) and szText and not IsEmpty(szHash) then
		insert(self.aInsertQueue, {szHash = szHash, nChannel = nChannel, nTime = nTime, szTalker = szTalker, szText = szText, szMsg = szMsg})
	end
	return self
end

function DS:CountMsg(aChannel, szSearch)
	if #aChannel == 0 then
		return 0
	end
	if not szSearch then
		szSearch = ''
	end
	if szSearch ~= '' then
		szSearch = AnsiToUTF8('%' .. szSearch .. '%')
	end
	self:InitDB()
	local aNChannel, nCount = SToNChannel(aChannel), 0
	for _, db in ipairs(self.aDB) do
		nCount = nCount + db:CountMsg(aNChannel, szSearch)
	end
	return nCount
end

function DS:SelectMsg(aChannel, szSearch, nOffset, nLimit)
	if #aChannel == 0 then
		return {}
	end
	self:InitDB()
	if not szSearch then
		szSearch = ''
	end
	if szSearch ~= '' then
		szSearch = AnsiToUTF8('%' .. szSearch .. '%')
	end
	local aNChannel, aResult = SToNChannel(aChannel), {}
	for _, db in ipairs(self.aDB) do
		if nLimit == 0 then
			break
		end
		local nCount = db:CountMsg(aNChannel, szSearch)
		if nOffset >= nCount then
			nOffset = nOffset - nCount
		else
			local res = db:SelectMsg(aNChannel, szSearch, nOffset, nLimit)
			for _, p in ipairs(res) do
				p.szChannel = CHANNELS[p.nChannel]
				p.nChannel = nil
				p.szTalker = UTF8ToAnsi(p.szTalker)
				p.szText = UTF8ToAnsi(p.szText)
				p.szMsg = UTF8ToAnsi(p.szMsg)
				insert(aResult, p)
			end
			if nOffset > 0 then
				nOffset = max(nOffset - nCount, 0)
			end
			nLimit = max(nLimit - #res, 0)
		end
	end
	return aResult
end

function DS:DeleteMsg(szHash, nTime)
	if nTime and not IsEmpty(szHash) then
		insert(self.aDeleteQueue, {szHash = szHash, nTime = nTime})
	end
	return self
end

function DS:PushDB()
	if not IsEmpty(self.aInsertQueue) or not IsEmpty(self.aDeleteQueue) then
		self:InitDB()
		-- 插入记录
		sort(self.aInsertQueue, function(a, b) return a.nTime < b.nTime end)
		local i, db = 1, self.aDB[1]
		for _, p in ipairs(self.aInsertQueue) do
			while db and p.nTime > db:GetMaxTime() do
				i = i + 1
				db = self.aDB[i]
			end
			assert(db, 'ChatLog db indexing error while PushDB: [i]' .. i .. ' [time]' .. p.nTime)
			db:InsertMsg(p.nChannel, p.szText, p.szMsg, p.szTalker, p.nTime, p.szHash)
		end
		self.aInsertQueue = {}
		-- 删除记录
		sort(self.aDeleteQueue, function(a, b) return a.nTime < b.nTime end)
		local i, db = 1, self.aDB[1]
		for _, p in ipairs(self.aDeleteQueue) do
			while db and p.nTime > db:GetMaxTime() do
				i = i + 1
				db = self.aDB[i]
			end
			assert(db, 'ChatLog db indexing error while PushDB: [i]' .. i .. ' [time]' .. p.nTime)
			db:DeleteMsg(p.szHash, p.nTime)
		end
		self.aDeleteQueue = {}
		-- 执行数据库操作
		for _, db in ipairs(self.aDB) do
			db:PushDB()
		end
	end
	return self
end

function DS:ReleaseDB()
	if self.aDB then
		for _, db in ipairs(self.aDB) do
			db:Disconnect()
		end
		self.aDB = nil
	end
	return self
end

function MY_ChatLog_DS(szRoot)
	if not DS_CACHE[szRoot] then
		DS_CACHE[szRoot] = DS.new(szRoot)
	end
	return DS_CACHE[szRoot]
end
