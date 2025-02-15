--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 秘境CD统计
-- @author   : 茗伊 @双梦镇 @追风蹑影
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
--------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
-------------------------------------------------------------------------------------------------------
local ipairs, pairs, next, pcall, select = ipairs, pairs, next, pcall, select
local string, math, table = string, math, table
-- lib apis caching
local X = MY
local UI, GLOBAL, CONSTANT, wstring, lodash = X.UI, X.GLOBAL, X.CONSTANT, X.wstring, X.lodash
-------------------------------------------------------------------------------------------------------
local PLUGIN_NAME = 'MY_RoleStatistics'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_RoleStatistics_DungeonStat'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
--------------------------------------------------------------------------

CPath.MakeDir(X.FormatPath({'userdata/role_statistics', X.PATH_TYPE.GLOBAL}))

local DB = X.SQLiteConnect(_L['MY_RoleStatistics_DungeonStat'], {'userdata/role_statistics/dungeon_stat.v3.db', X.PATH_TYPE.GLOBAL})
if not DB then
	return X.Sysmsg(_L['MY_RoleStatistics_DungeonStat'], _L['Cannot connect to database!!!'], CONSTANT.MSG_THEME.ERROR)
end
local SZ_INI = X.PACKET_INFO.ROOT .. 'MY_RoleStatistics/ui/MY_RoleStatistics_DungeonStat.ini'

DB:Execute([[
	CREATE TABLE IF NOT EXISTS DungeonInfo (
		guid NVARCHAR(20) NOT NULL,
		account NVARCHAR(255) NOT NULL,
		region NVARCHAR(20) NOT NULL,
		server NVARCHAR(20) NOT NULL,
		name NVARCHAR(20) NOT NULL,
		force INTEGER NOT NULL,
		level INTEGER NOT NULL,
		equip_score INTEGER NOT NULL,
		copy_info NVARCHAR(65535) NOT NULL,
		progress_info NVARCHAR(65535) NOT NULL,
		time INTEGER NOT NULL,
		extra TEXT NOT NULL,
		PRIMARY KEY(guid)
	)
]])
local DB_DungeonInfoW = DB:Prepare('REPLACE INTO DungeonInfo (guid, account, region, server, name, force, level, equip_score, copy_info, progress_info, time, extra) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
local DB_DungeonInfoG = DB:Prepare('SELECT * FROM DungeonInfo WHERE guid = ?')
local DB_DungeonInfoR = DB:Prepare('SELECT * FROM DungeonInfo WHERE account LIKE ? OR name LIKE ? OR region LIKE ? OR server LIKE ? ORDER BY time DESC')
local DB_DungeonInfoD = DB:Prepare('DELETE FROM DungeonInfo WHERE guid = ?')

local O = X.CreateUserSettingsModule('MY_RoleStatistics_DungeonStat', _L['General'], {
	aColumn = {
		ePathType = X.PATH_TYPE.GLOBAL,
		szLabel = _L['MY_RoleStatistics'],
		xSchema = X.Schema.Collection(X.Schema.String),
		xDefaultValue = {
			'name',
			'force',
			'week_team_dungeon',
			'week_raid_dungeon',
			'dungeon_427',
			'dungeon_428',
			'time_days',
		},
	},
	szSort = {
		ePathType = X.PATH_TYPE.GLOBAL,
		szLabel = _L['MY_RoleStatistics'],
		xSchema = X.Schema.String,
		xDefaultValue = 'time_days',
	},
	szSortOrder = {
		ePathType = X.PATH_TYPE.GLOBAL,
		szLabel = _L['MY_RoleStatistics'],
		xSchema = X.Schema.String,
		xDefaultValue = 'desc',
	},
	bFloatEntry = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_RoleStatistics'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bAdviceFloatEntry = {
		ePathType = X.PATH_TYPE.ROLE,
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bSaveDB = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_RoleStatistics'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bAdviceSaveDB = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_RoleStatistics'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
})
local D = {
	tMapSaveCopy = {}, -- 单秘境 CD
	bMapSaveCopyValid = false, -- 客户端缓存的单秘境 CD 数据有效
	dwMapSaveCopyRequestTime = 0, -- 最后一次请求单秘境 CD 时间
	tMapProgress = {}, -- 单首领 CD 进度
	tMapProgressValid = {}, -- 客户端缓存的单首领 CD 进度数据有效
	tMapProgressRequestTime = setmetatable({}, { __index = function() return 0 end }), -- 客户端缓存的单首领 CD 进度数据有效
	aMapProgressRequestQueue = {}, -- 单首领 CD 获取队列 （一次获取太多可能会被踢）
}

local EXCEL_WIDTH = 960
local DUNGEON_MIN_WIDTH = 80
local function GeneCommonFormatText(id)
	return function(r)
		return GetFormatText(r[id], 162, 255, 255, 255)
	end
end
local function GeneCommonCompare(id)
	return function(r1, r2)
		if r1[id] == r2[id] then
			return 0
		end
		return r1[id] > r2[id] and 1 or -1
	end
end
local COLUMN_LIST = {
	-- guid,
	-- account,
	{ -- 大区
		id = 'region',
		bHideInFloat = true,
		szTitle = _L['Region'],
		nMinWidth = 100, nMaxWidth = 100,
		GetFormatText = GeneCommonFormatText('region'),
		Compare = GeneCommonCompare('region'),
	},
	{ -- 服务器
		id = 'server',
		bHideInFloat = true,
		szTitle = _L['Server'],
		nMinWidth = 100, nMaxWidth = 100,
		GetFormatText = GeneCommonFormatText('server'),
		Compare = GeneCommonCompare('server'),
	},
	{ -- 名字
		id = 'name',
		bHideInFloat = true,
		szTitle = _L['Name'],
		nMinWidth = 110, nMaxWidth = 200,
		GetFormatText = function(rec)
			local name = rec.name
			if MY_ChatMosaics and MY_ChatMosaics.MosaicsString then
				name = MY_ChatMosaics.MosaicsString(name)
			end
			return GetFormatText(name, 162, X.GetForceColor(rec.force, 'foreground'))
		end,
		Compare = GeneCommonCompare('name'),
	},
	{ -- 门派
		id = 'force',
		bHideInFloat = true,
		szTitle = _L['Force'],
		nMinWidth = 50, nMaxWidth = 70,
		GetFormatText = function(rec)
			return GetFormatText(g_tStrings.tForceTitle[rec.force], 162, 255, 255, 255)
		end,
		Compare = GeneCommonCompare('force'),
	},
	{ -- 等级
		id = 'level',
		szTitle = _L['Level'],
		nMinWidth = 50, nMaxWidth = 50,
		GetFormatText = GeneCommonFormatText('level'),
		Compare = GeneCommonCompare('level'),
	},
	{ -- 装分
		id = 'equip_score',
		bHideInFloat = true,
		szTitle = _L['EquSC'],
		nMinWidth = 100, nMaxWidth = 100,
		GetFormatText = GeneCommonFormatText('equip_score'),
		Compare = GeneCommonCompare('equip_score'),
	},
	{ -- 时间
		id = 'time',
		bHideInFloat = true,
		szTitle = _L['Cache time'],
		nMinWidth = 165, nMaxWidth = 200,
		GetFormatText = function(rec)
			return GetFormatText(X.FormatTime(rec.time, '%yyyy/%MM/%dd %hh:%mm:%ss'), 162, 255, 255, 255)
		end,
		Compare = GeneCommonCompare('time'),
	},
	{ -- 时间计时
		id = 'time_days',
		bHideInFloat = true,
		szTitle = _L['Cache time days'],
		nMinWidth = 120, nMaxWidth = 120,
		GetFormatText = function(rec)
			local nTime = GetCurrentTime() - rec.time
			local nSeconds = math.floor(nTime)
			local nMinutes = math.floor(nSeconds / 60)
			local nHours   = math.floor(nMinutes / 60)
			local nDays    = math.floor(nHours / 24)
			local nYears   = math.floor(nDays / 365)
			local nDay     = nDays % 365
			local nHour    = nHours % 24
			local nMinute  = nMinutes % 60
			local nSecond  = nSeconds % 60
			if nYears > 0 then
				return GetFormatText(_L('%d years %d days before', nYears, nDay), 162, 255, 255, 255)
			end
			if nDays > 0 then
				return GetFormatText(_L('%d days %d hours before', nDays, nHour), 162, 255, 255, 255)
			end
			if nHours > 0 then
				return GetFormatText(_L('%d hours %d mins before', nHours, nMinute), 162, 255, 255, 255)
			end
			if nMinutes > 0 then
				return GetFormatText(_L('%d mins %d secs before', nMinutes, nSecond), 162, 255, 255, 255)
			end
			if nSecond > 10 then
				return GetFormatText(_L('%d secs before', nSecond), 162, 255, 255, 255)
			end
			return GetFormatText(_L['Just now'], 162, 255, 255, 255)
		end,
		Compare = GeneCommonCompare('time'),
	},
}
local COLUMN_DICT = setmetatable({}, { __index = function(t, id)
	if id == 'week_team_dungeon' then
		if GLOBAL.GAME_BRANCH ~= 'classic' then
			return {
				id = id,
				szTitle = _L['Week routine: '] .. _L.ACTIVITY_WEEK_TEAM_DUNGEON,
				nMinWidth = DUNGEON_MIN_WIDTH * #X.GetActivityMap('WEEK_TEAM_DUNGEON'),
			}
		end
	elseif id == 'week_raid_dungeon' then
		if GLOBAL.GAME_BRANCH ~= 'classic' then
			return {
				id = id,
				szTitle = _L['Week routine: '] .. _L.ACTIVITY_WEEK_RAID_DUNGEON,
				nMinWidth = DUNGEON_MIN_WIDTH * #X.GetActivityMap('WEEK_RAID_DUNGEON'),
			}
		end
	elseif wstring.find(id, 'dungeon_') then
		local id, via = wstring.gsub(id, 'dungeon_', ''), ''
		if wstring.find(id, '@') then
			local ids = X.SplitString(id, '@')
			id, via = tonumber(ids[1]), ids[2]
		else
			id = tonumber(id)
		end
		local map = id and X.GetMapInfo(id)
		if map then
			local col = { -- 秘境CD
				id = 'dungeon_' .. id,
				szTitle = map.szName,
				nMinWidth = DUNGEON_MIN_WIDTH,
			}
			if via then
				local colVia = t[via]
				if colVia then
					col.szTitleTip = col.szTitle .. ' (' .. colVia.szTitle .. ')'
				end
			end
			if X.IsDungeonRoleProgressMap(map.dwID) then
				col.GetFormatText = function(rec)
					local aCopyID = rec.copy_info[map.dwID]
					local aBossKill = rec.progress_info[map.dwID]
					local nNextTime, nCircle = X.GetDungeonRefreshTime(map.dwID)
					if not aBossKill or nNextTime - nCircle > rec.time then
						return GetFormatText(_L['--'], 162, 255, 255, 255)
					end
					local aXml = {}
					if IsCtrlKeyDown() and aCopyID then
						table.insert(aXml, GetFormatText(table.concat(aCopyID, ',') .. ' '))
					end
					for _, bKill in ipairs(aBossKill) do
						table.insert(aXml, '<image>path="' .. PLUGIN_ROOT .. '/img/MY_RoleStatistics.UITex" name="Image_ProgressBoss" eventid=786 frame='
							.. (bKill and 1 or 0) .. ' w=12 h=12 script="this.mapid=' .. map.dwID .. '"</image>')
					end
					return table.concat(aXml)
				end
				col.Compare = function(r1, r2)
					local k1 = r1.progress_info and r1.progress_info[map.dwID]
					local k2 = r2.progress_info and r2.progress_info[map.dwID]
					if k1 and not k2 then
						return 1
					end
					if k2 and not k1 then
						return -1
					end
					if not k1 and not k2 then
						return 0
					end
					local s1, s2 = 0, 0
					for _, p in ipairs(k1) do
						if p then
							s1 = s1 + 1
						end
					end
					for _, p in ipairs(k2) do
						if p then
							s2 = s2 + 1
						end
					end
					if s1 == s2 then
						return 0
					end
					return s1 > s2 and 1 or -1
				end
			else
				col.GetFormatText = function(rec)
					local aCopyID = rec.copy_info[map.dwID]
					local nNextTime, nCircle = X.GetDungeonRefreshTime(map.dwID)
					local szText = nNextTime - nCircle < rec.time
						and (aCopyID and aCopyID[1] or _L['None'])
						or (_L['--'])
					return GetFormatText(szText, 162, 255, 255, 255, 786, 'this.mapid=' .. map.dwID, 'Text_CD')
				end
				col.Compare = function(r1, r2)
					local k1 = r1.copy_info and r1.copy_info[map.dwID] and r1.copy_info[map.dwID][1]
					local k2 = r2.copy_info and r2.copy_info[map.dwID] and r2.copy_info[map.dwID][1]
					if k1 and not k2 then
						return 1
					end
					if k2 and not k1 then
						return -1
					end
					if not k1 and not k2 then
						return 0
					end
					if k1 == k2 then
						return 0
					end
					return k1 > k2 and 1 or -1
				end
			end
			return col
		end
	end
end })
for _, p in ipairs(COLUMN_LIST) do
	if not p.Compare then
		p.Compare = function(r1, r2)
			local k1 = r1[p.szKey]
			local k2 = r2[p.szKey]
			if k1 and not k2 then
				return 1
			end
			if k2 and not k1 then
				return -1
			end
			if not k1 and not k2 then
				return 0
			end
			if k1 == k2 then
				return 0
			end
			return k1 > k2 and 1 or -1
		end
	end
	COLUMN_DICT[p.id] = p
end
local TIP_COLUMN = {
	'region',
	'server',
	'name',
	'force',
	'level',
	'equip_score',
	'DUNGEON',
	'time',
	'time_days',
}

function D.GetPlayerGUID(me)
	return me.GetGlobalID() ~= '0' and me.GetGlobalID() or me.szName
end

do
local REC_CACHE
function D.GetClientPlayerRec(bForceUpdate)
	local me = GetClientPlayer()
	if not me then
		return
	end
	local rec = REC_CACHE
	local guid = D.GetPlayerGUID(me)
	if not rec then
		rec = {}
		REC_CACHE = rec
	end
	D.UpdateMapProgress(bForceUpdate)

	-- 基础信息
	rec.guid = guid
	rec.account = X.GetAccount() or ''
	rec.region = X.GetRealServer(1)
	rec.server = X.GetRealServer(2)
	rec.name = me.szName
	rec.force = me.dwForceID
	rec.level = me.nLevel
	rec.equip_score = me.GetBaseEquipScore() + me.GetStrengthEquipScore() + me.GetMountsEquipScore()
	rec.time = GetCurrentTime()
	rec.copy_info = D.tMapSaveCopy
	rec.progress_info = D.tMapProgress
	return rec
end
end

function D.ProcessProgressRequestQueue()
	local szKey = 'MY_RoleStatistics_DungeonStat__ProcessProgressRequestQueue'
	if #D.aMapProgressRequestQueue > 0 then
		X.BreatheCall(szKey, function()
			local dwID = table.remove(D.aMapProgressRequestQueue)
			if dwID then
				D.tMapProgressRequestTime[dwID] = GetTime()
				--[[#DEBUG BEGIN]]
				X.Debug(
					_L['PMTool'],
					_L('[MY_RoleStatistics_DungeonStat] ApplyDungeonRoleProgress: %d.', dwID),
					X.DEBUG_LEVEL.PMLOG)
				--[[#DEBUG END]]
				ApplyDungeonRoleProgress(dwID, UI_GetClientPlayerID())
			else
				X.BreatheCall(szKey, false)
			end
		end)
	else
		X.BreatheCall(szKey, false)
	end
end

function D.Migration()
	local DB_V2_PATH = X.FormatPath({'userdata/role_statistics/dungeon_stat.v2.db', X.PATH_TYPE.GLOBAL})
	if not IsLocalFileExist(DB_V2_PATH) then
		return
	end
	X.Confirm(
		_L['Ancient database detected, do you want to migrate data from it?'],
		function()
			-- 转移V2旧版数据
			if IsLocalFileExist(DB_V2_PATH) then
				local DB_V2 = SQLite3_Open(DB_V2_PATH)
				if DB_V2 then
					DB:Execute('BEGIN TRANSACTION')
					local aDungeonInfo = DB_V2:Execute('SELECT * FROM DungeonInfo WHERE guid IS NOT NULL AND name IS NOT NULL')
					if aDungeonInfo then
						for _, rec in ipairs(aDungeonInfo) do
							DB_DungeonInfoW:ClearBindings()
							DB_DungeonInfoW:BindAll(
								rec.guid,
								rec.account,
								rec.region,
								rec.server,
								rec.name,
								rec.force,
								rec.level,
								rec.equip_score,
								rec.copy_info,
								rec.progress_info,
								rec.time,
								''
							)
							DB_DungeonInfoW:Execute()
						end
						DB_DungeonInfoW:Reset()
					end
					DB:Execute('END TRANSACTION')
					DB_V2:Release()
				end
				CPath.Move(DB_V2_PATH, DB_V2_PATH .. '.bak' .. X.FormatTime(GetCurrentTime(), '%yyyy%MM%dd%hh%mm%ss'))
			end
			FireUIEvent('MY_ROLE_STAT_DUNGEON_UPDATE')
			X.Alert(_L['Migrate succeed!'])
		end)
end

function D.FlushDB(bForceUpdate)
	if not D.bReady or not O.bSaveDB then
		return
	end
	--[[#DEBUG BEGIN]]
	local nTickCount = GetTickCount()
	--[[#DEBUG END]]

	local rec = X.Clone(D.GetClientPlayerRec(bForceUpdate))
	D.EncodeRow(rec)

	DB:Execute('BEGIN TRANSACTION')
	DB_DungeonInfoW:ClearBindings()
	DB_DungeonInfoW:BindAll(
		rec.guid, rec.account, rec.region, rec.server,
		rec.name, rec.force, rec.level, rec.equip_score,
		rec.copy_info, rec.progress_info, rec.time, '')
	DB_DungeonInfoW:Execute()
	DB_DungeonInfoW:Reset()
	DB:Execute('END TRANSACTION')

	--[[#DEBUG BEGIN]]
	nTickCount = GetTickCount() - nTickCount
	X.Debug('MY_RoleStatistics_DungeonStat', _L('Flushing to database costs %dms...', nTickCount), X.DEBUG_LEVEL.LOG)
	--[[#DEBUG END]]
end
X.RegisterFlush('MY_RoleStatistics_DungeonStat', function() D.FlushDB() end)

function D.InitDB()
	local me = GetClientPlayer()
	if me then
		DB_DungeonInfoG:ClearBindings()
		DB_DungeonInfoG:BindAll(AnsiToUTF8(D.GetPlayerGUID(me)))
		local result = DB_DungeonInfoG:GetAll()
		DB_DungeonInfoG:Reset()
		local rec = result[1]
		if rec then
			D.DecodeRow(rec)
			D.tMapSaveCopy = X.DecodeLUAData(rec.copy_info) or {}
			D.tMapProgress = X.DecodeLUAData(rec.progress_info) or {}
		end
	end
end
X.RegisterInit('MY_RoleStatistics_DungeonStat', D.InitDB)

function D.UpdateSaveDB()
	if not D.bReady then
		return
	end
	local me = GetClientPlayer()
	if not me then
		return
	end
	if not O.bSaveDB then
		--[[#DEBUG BEGIN]]
		X.Debug('MY_RoleStatistics_DungeonStat', 'Remove from database...', X.DEBUG_LEVEL.LOG)
		--[[#DEBUG END]]
		DB_DungeonInfoD:ClearBindings()
		DB_DungeonInfoD:BindAll(AnsiToUTF8(D.GetPlayerGUID(me)))
		DB_DungeonInfoD:Execute()
		DB_DungeonInfoD:Reset()
		--[[#DEBUG BEGIN]]
		X.Debug('MY_RoleStatistics_DungeonStat', 'Remove from database finished...', X.DEBUG_LEVEL.LOG)
		--[[#DEBUG END]]
	end
	FireUIEvent('MY_ROLE_STAT_DUNGEON_UPDATE')
end

function D.GetColumns()
	local aCol = {}
	for _, id in ipairs(O.aColumn) do
		if id == 'week_team_dungeon' then
			for _, map in ipairs(X.GetActivityMap('WEEK_TEAM_DUNGEON')) do
				local col = COLUMN_DICT['dungeon_' .. map.dwID .. '@' .. id]
				if col then
					table.insert(aCol, col)
				end
			end
		elseif id == 'week_raid_dungeon' then
			for _, map in ipairs(X.GetActivityMap('WEEK_RAID_DUNGEON')) do
				local col = COLUMN_DICT['dungeon_' .. map.dwID .. '@' .. id]
				if col then
					table.insert(aCol, col)
				end
			end
		else
			local col = COLUMN_DICT[id]
			if col then
				table.insert(aCol, col)
			end
		end
	end
	return aCol
end

function D.UpdateUI(page)
	local hCols = page:Lookup('Wnd_Total/WndScroll_DungeonStat', 'Handle_DungeonStatColumns')
	hCols:Clear()

	local aCol, nX, Sorter = D.GetColumns(), 0, nil
	local nExtraWidth = EXCEL_WIDTH
	for i, col in ipairs(aCol) do
		nExtraWidth = nExtraWidth - col.nMinWidth
	end
	for i, col in ipairs(aCol) do
		local hCol = hCols:AppendItemFromIni(SZ_INI, 'Handle_DungeonStatColumn')
		local txt = hCol:Lookup('Text_DungeonStat_Title')
		local imgAsc = hCol:Lookup('Image_DungeonStat_Asc')
		local imgDesc = hCol:Lookup('Image_DungeonStat_Desc')
		local nWidth = i == #aCol
			and (EXCEL_WIDTH - nX)
			or math.min(nExtraWidth * col.nMinWidth / (EXCEL_WIDTH - nExtraWidth) + col.nMinWidth, col.nMaxWidth or math.huge)
		local nSortDelta = nWidth > 70 and 25 or 15
		if i == 0 then
			hCol:Lookup('Image_DungeonStat_Break'):Hide()
		end
		hCol.szSort = col.id
		hCol.szTip = col.szTitleTip
		hCol.szDebugTip = 'id: ' .. col.id
		hCol:SetRelX(nX)
		hCol:SetW(nWidth)
		txt:SetW(nWidth)
		txt:SetText(col.szTitle)
		imgAsc:SetRelX(nWidth - nSortDelta)
		imgDesc:SetRelX(nWidth - nSortDelta)
		if O.szSort == col.id then
			Sorter = function(r1, r2)
				if O.szSortOrder == 'asc' then
					return col.Compare(r1, r2) < 0
				end
				return col.Compare(r1, r2) > 0
			end
		end
		imgAsc:SetVisible(O.szSort == col.id and O.szSortOrder == 'asc')
		imgDesc:SetVisible(O.szSort == col.id and O.szSortOrder == 'desc')
		hCol:FormatAllItemPos()
		nX = nX + nWidth
	end
	hCols:FormatAllItemPos()

	local szSearch = page:Lookup('Wnd_Total/Wnd_Search/Edit_Search'):GetText()
	local szUSearch = AnsiToUTF8('%' .. szSearch .. '%')
	DB_DungeonInfoR:ClearBindings()
	DB_DungeonInfoR:BindAll(szUSearch, szUSearch, szUSearch, szUSearch)
	local result = DB_DungeonInfoR:GetAll()
	DB_DungeonInfoR:Reset()

	for _, rec in ipairs(result) do
		D.DecodeRow(rec)
	end

	if Sorter then
		table.sort(result, Sorter)
	end

	local aCol = D.GetColumns()
	local hList = page:Lookup('Wnd_Total/WndScroll_DungeonStat', 'Handle_List')
	hList:Clear()
	for i, rec in ipairs(result) do
		local hRow = hList:AppendItemFromIni(SZ_INI, 'Handle_Row')
		hRow.rec = rec
		hRow:Lookup('Image_RowBg'):SetVisible(i % 2 == 1)
		local nX = 0
		for j, col in ipairs(aCol) do
			local hItem = hRow:AppendItemFromIni(SZ_INI, 'Handle_Item') -- 外部居中层
			local hItemContent = hItem:Lookup('Handle_ItemContent') -- 内部文本布局层
			hItemContent:AppendItemFromString(col.GetFormatText(rec))
			hItemContent:SetW(99999)
			hItemContent:FormatAllItemPos()
			hItemContent:SetSizeByAllItemSize()
			local nWidth = j == #aCol
				and (EXCEL_WIDTH - nX)
				or math.min(nExtraWidth * col.nMinWidth / (EXCEL_WIDTH - nExtraWidth) + col.nMinWidth, col.nMaxWidth or math.huge)
			if j == #aCol then
				nWidth = EXCEL_WIDTH - nX
			end
			hItem:SetRelX(nX)
			hItem:SetW(nWidth)
			hItemContent:SetRelPos((nWidth - hItemContent:GetW()) / 2, (hItem:GetH() - hItemContent:GetH()) / 2)
			hItem:FormatAllItemPos()
			nX = nX + nWidth
		end
		hRow:FormatAllItemPos()
	end
	hList:FormatAllItemPos()
end

function D.UpdateMapProgress(bForceUpdate)
	local me = GetClientPlayer()
	if not me then -- 确保不可能在切换GS时请求
		return
	end
	local tProgressBossMapID = {}
	-- 监控数据里的地图 ID
	for _, col in ipairs(D.GetColumns()) do
		local szID = wstring.find(col.id, 'dungeon_') and wstring.gsub(col.id, 'dungeon_', '')
		local dwID = szID and tonumber(szID)
		if dwID then
			tProgressBossMapID[dwID] = true
		end
	end
	-- 已经有 CD 的地图 ID
	for k, v in pairs(D.tMapSaveCopy) do
		if v then
			tProgressBossMapID[k] = true
		end
	end
	-- 获取这些地图的进度
	for dwID, _ in pairs(tProgressBossMapID) do
		local aProgressBoss = dwID and X.IsDungeonRoleProgressMap(dwID) and Table_GetCDProcessBoss(dwID)
		if aProgressBoss then
			-- 强制刷新秘境进度，或者进度数据已过期并且5秒内未请求过，则发起请求
			if bForceUpdate or (not D.tMapProgressValid[dwID] and GetTime() - D.tMapProgressRequestTime[dwID] > 5000) then
				if not lodash.includes(D.aMapProgressRequestQueue, dwID) then
					table.insert(D.aMapProgressRequestQueue, dwID)
				end
			end
			-- 检测是否有进度数据（修正脏数据标记位）
			local bMapProgressValid = D.tMapProgressValid[dwID]
			if not bMapProgressValid then
				for i, boss in ipairs(aProgressBoss) do
					if GetDungeonRoleProgress(dwID, UI_GetClientPlayerID(), boss.dwProgressID) then
						bMapProgressValid = true
						break
					end
				end
			end
			-- 已经获取到进度的秘境，或者没有 CD 数据的秘境
			if bMapProgressValid or (D.bMapSaveCopyValid and not D.tMapSaveCopy[dwID]) then
				local aProgress = {}
				for i, boss in ipairs(aProgressBoss) do
					aProgress[i] = GetDungeonRoleProgress(dwID, UI_GetClientPlayerID(), boss.dwProgressID)
				end
				D.tMapProgress[dwID] = aProgress
			end
		end
		D.ProcessProgressRequestQueue()
	end
	-- 强制刷新秘境进度，或者进度数据已过期并且5秒内未请求过，则发起请求
	if bForceUpdate or (not D.bMapSaveCopyValid and GetTime() - D.dwMapSaveCopyRequestTime > 5000) then
		D.dwMapSaveCopyRequestTime = GetTime()
		ApplyMapSaveCopy()
	end
end

function D.EncodeRow(rec)
	rec.guid   = AnsiToUTF8(rec.guid)
	rec.name   = AnsiToUTF8(rec.name)
	rec.region = AnsiToUTF8(rec.region)
	rec.server = AnsiToUTF8(rec.server)
	rec.copy_info = X.EncodeLUAData(rec.copy_info)
	rec.progress_info = X.EncodeLUAData(rec.progress_info)
end

function D.DecodeRow(rec)
	rec.guid   = UTF8ToAnsi(rec.guid)
	rec.name   = UTF8ToAnsi(rec.name)
	rec.region = UTF8ToAnsi(rec.region)
	rec.server = UTF8ToAnsi(rec.server)
	rec.copy_info = X.DecodeLUAData(rec.copy_info or '') or {}
	rec.progress_info = X.DecodeLUAData(rec.progress_info or '') or {}
end

function D.GetDungeonRecTipInfo(rec, dwMapID)
	local col = COLUMN_DICT['dungeon_' .. dwMapID]
	if col then
		local a = {}
		local nMaxPlayerCount = select(3, GetMapParams(dwMapID))
		table.insert(a, GetFormatText(col.szTitle, 162, 255, 255, 0))
		table.insert(a, GetFormatText(':  ', 162, 255, 255, 0))
		table.insert(a, col.GetFormatText(rec))
		table.insert(a, GetFormatText('\n', 162, 255, 255, 255))
		return { dwMapID = dwMapID, nMaxPlayerCount = nMaxPlayerCount, szXml = table.concat(a) }
	else
		local map = X.GetMapInfo(dwMapID)
		local aCopyID = rec.copy_info[dwMapID]
		if map and aCopyID then
			local a = {}
			local nMaxPlayerCount = select(3, GetMapParams(dwMapID))
			table.insert(a, GetFormatText(map.szName, 162, 255, 255, 0))
			table.insert(a, GetFormatText(':  ', 162, 255, 255, 0))
			table.insert(a, GetFormatText(table.concat(aCopyID, ',')))
			table.insert(a, GetFormatText('\n', 162, 255, 255, 255))
			return { dwMapID = dwMapID, nMaxPlayerCount = nMaxPlayerCount, szXml = table.concat(a) }
		end
	end
end

function D.OutputRowTip(this, rec)
	local aXml = {}
	local bFloat = this:GetRoot():GetName() ~= 'MY_RoleStatistics'
	for _, id in ipairs(TIP_COLUMN) do
		if id == 'DUNGEON' then
			local aMapID = {}
			for _, col in ipairs(D.GetColumns()) do
				local dwMapID = wstring.find(col.id, 'dungeon_')
					and tonumber(col.id:sub(#'dungeon_' + 1))
					or nil
				table.insert(aMapID, dwMapID)
			end
			for dwMapID, _ in pairs(rec.copy_info) do
				table.insert(aMapID, dwMapID)
			end
			local tDungeon, aDungeon = {}, {}
			for _, dwMapID in ipairs(aMapID) do
				local info = dwMapID and not tDungeon[dwMapID] and D.GetDungeonRecTipInfo(rec, dwMapID)
				if info then
					table.insert(aDungeon, info)
					tDungeon[dwMapID] = true
				end
			end
			table.sort(aDungeon, function(p1, p2)
				if p1.nMaxPlayerCount == p2.nMaxPlayerCount then
					return p1.dwMapID < p2.dwMapID
				end
				return p1.nMaxPlayerCount < p2.nMaxPlayerCount
			end)
			local nMaxPlayerCount = 0
			for _, p in ipairs(aDungeon) do
				if nMaxPlayerCount ~= p.nMaxPlayerCount then
					nMaxPlayerCount = p.nMaxPlayerCount
					table.insert(aXml, GetFormatText(_L('---- %d players dungeon ----', nMaxPlayerCount) .. '\n', 162, 255, 255, 0))
				end
				table.insert(aXml, p.szXml)
			end
		else
			local col = COLUMN_DICT[id]
			if col and (not bFloat or not col.bHideInFloat) then
				table.insert(aXml, GetFormatText(col.szTitle, 162, 255, 255, 0))
				table.insert(aXml, GetFormatText(':  ', 162, 255, 255, 0))
				table.insert(aXml, col.GetFormatText(rec))
				table.insert(aXml, GetFormatText('\n', 162, 255, 255, 255))
			end
		end
	end
	local x, y = this:GetAbsPos()
	local w, h = this:GetSize()
	local nPosType = bFloat and UI.TIP_POSITION.TOP_BOTTOM or UI.TIP_POSITION.RIGHT_LEFT
	OutputTip(table.concat(aXml), 450, {x, y, w, h}, nPosType)
end

function D.CloseRowTip()
	HideTip()
end

function D.OnInitPage()
	local page = this
	local frameTemp = Wnd.OpenWindow(SZ_INI, 'MY_RoleStatistics_DungeonStat')
	local wnd = frameTemp:Lookup('Wnd_Total')
	wnd:ChangeRelation(page, true, true)
	Wnd.CloseWindow(frameTemp)

	UI(wnd):Append('WndComboBox', {
		x = 800, y = 20, w = 180,
		text = _L['Columns'],
		menu = function()
			local t, aColumn, tChecked, nMinW = {}, O.aColumn, {}, 0
			-- 已添加的
			for i, id in ipairs(aColumn) do
				local col = COLUMN_DICT[id]
				if col then
					table.insert(t, {
						szOption = col.szTitle,
						{
							szOption = _L['Move up'],
							fnAction = function()
								if i > 1 then
									aColumn[i], aColumn[i - 1] = aColumn[i - 1], aColumn[i]
									O.aColumn = aColumn
									D.UpdateUI(page)
								end
								UI.ClosePopupMenu()
							end,
						},
						{
							szOption = _L['Move down'],
							fnAction = function()
								if i < #aColumn then
									aColumn[i], aColumn[i + 1] = aColumn[i + 1], aColumn[i]
									O.aColumn = aColumn
									D.UpdateUI(page)
								end
								UI.ClosePopupMenu()
							end,
						},
						{
							szOption = _L['Delete'],
							fnAction = function()
								table.remove(aColumn, i)
								O.aColumn = aColumn
								D.UpdateUI(page)
								UI.ClosePopupMenu()
							end,
						},
					})
					nMinW = nMinW + col.nMinWidth
				end
				tChecked[id] = true
			end
			-- 未添加的
			local function fnAction(id, nWidth)
				local bExist = false
				for i, v in ipairs(aColumn) do
					if v == id then
						table.remove(aColumn, i)
						O.aColumn = aColumn
						bExist = true
						break
					end
				end
				if not bExist then
					if nMinW + nWidth > EXCEL_WIDTH then
						X.Alert(_L['Too many column selected, width overflow, please delete some!'])
					else
						table.insert(aColumn, id)
						O.aColumn = aColumn
					end
				end
				D.FlushDB(true)
				D.UpdateUI(page)
				UI.ClosePopupMenu()
			end
			-- 普通选项
			for _, col in ipairs(COLUMN_LIST) do
				if not tChecked[col.id] then
					table.insert(t, {
						szOption = col.szTitle,
						fnAction = function()
							fnAction(col.id, col.nMinWidth)
						end,
					})
				end
			end
			-- 秘境选项
			local tDungeonChecked = {}
			for _, id in ipairs(aColumn) do
				local szID = wstring.find(id, 'dungeon_') and wstring.gsub(id, 'dungeon_', '')
				local dwID = szID and tonumber(szID)
				if dwID then
					tDungeonChecked[dwID] = true
				end
			end
			local tDungeonMenu = X.GetDungeonMenu(function(info)
				fnAction('dungeon_' .. info.dwID, DUNGEON_MIN_WIDTH)
			end, nil, tDungeonChecked)
			-- 动态活动秘境选项
			for _, szType in ipairs({
				'week_team_dungeon',
				'week_raid_dungeon',
			}) do
				local col = COLUMN_DICT[szType]
				if col then
					table.insert(tDungeonMenu, {
						szOption = col.szTitle,
						bCheck = true, bChecked = tChecked[col.id],
						fnAction = function()
							fnAction(col.id, col.nMinWidth)
						end,
					})
				end
			end
			-- 子菜单标题
			tDungeonMenu.szOption = _L['Dungeon copy']
			table.insert(t, tDungeonMenu)
			return t
		end,
	})

	local frame = page:GetRoot()
	frame:RegisterEvent('ON_MY_MOSAICS_RESET')
	frame:RegisterEvent('UPDATE_DUNGEON_ROLE_PROGRESS')
	frame:RegisterEvent('ON_APPLY_PLAYER_SAVED_COPY_RESPOND')
	frame:RegisterEvent('MY_ROLE_STAT_DUNGEON_UPDATE')
end

function D.CheckAdvice()
	for _, p in ipairs({
		{
			szMsg = _L('%s stat has not been enabled, this character\'s data will not be saved, are you willing to save this character?\nYou can change this config by click option button on the top-right conner.', _L[MODULE_NAME]),
			szAdviceKey = 'bAdviceSaveDB',
			szSetKey = 'bSaveDB',
		},
		-- {
		-- 	szMsg = _L('%s stat float entry has not been enabled, are you willing to enable it?\nYou can change this config by click option button on the top-right conner.', _L[MODULE_NAME]),
		-- 	szAdviceKey = 'bAdviceFloatEntry',
		-- 	szSetKey = 'bFloatEntry',
		-- },
	}) do
		if not O[p.szAdviceKey] and not O[p.szSetKey] then
			X.Confirm(p.szMsg, function()
				MY_RoleStatistics_DungeonStat[p.szSetKey] = true
				MY_RoleStatistics_DungeonStat[p.szAdviceKey] = true
				D.CheckAdvice()
			end, function()
				MY_RoleStatistics_DungeonStat[p.szAdviceKey] = true
				D.CheckAdvice()
			end)
			return
		end
	end
end

function D.OnActivePage()
	D.Migration()
	D.CheckAdvice()
	D.FlushDB(true)
	D.UpdateUI(this)
end

function D.OnEvent(event)
	if event == 'ON_MY_MOSAICS_RESET' then
		D.UpdateUI(this)
	elseif event == 'UPDATE_DUNGEON_ROLE_PROGRESS' or event == 'ON_APPLY_PLAYER_SAVED_COPY_RESPOND' then
		D.FlushDB()
		D.UpdateUI(this)
	elseif event == 'MY_ROLE_STAT_DUNGEON_UPDATE' then
		D.FlushDB()
		D.UpdateUI(this)
	end
end

function D.OnLButtonClick()
	local name = this:GetName()
	if name == 'Btn_Delete' then
		local wnd = this:GetParent()
		local page = this:GetParent():GetParent():GetParent():GetParent():GetParent()
		X.Confirm(_L('Are you sure to delete item record of %s?', wnd.name), function()
			DB_DungeonInfoD:ClearBindings()
			DB_DungeonInfoD:BindAll(AnsiToUTF8(wnd.guid))
			DB_DungeonInfoD:Execute()
			DB_DungeonInfoD:Reset()
			D.UpdateUI(page)
		end)
	end
end

function D.OnItemLButtonClick()
	local name = this:GetName()
	if name == 'Handle_DungeonStatColumn' then
		if this.szSort then
			local page = this:GetParent():GetParent():GetParent():GetParent():GetParent()
			if O.szSort == this.szSort then
				O.szSortOrder = O.szSortOrder == 'asc' and 'desc' or 'asc'
			else
				O.szSort = this.szSort
			end
			D.UpdateUI(page)
		end
	end
end

function D.OnItemRButtonClick()
	local name = this:GetName()
	if name == 'Handle_Row' then
		local rec = this.rec
		local page = this:GetParent():GetParent():GetParent():GetParent():GetParent()
		local menu = {
			{
				szOption = _L['Delete'],
				fnAction = function()
					DB_DungeonInfoD:ClearBindings()
					DB_DungeonInfoD:BindAll(AnsiToUTF8(rec.guid))
					DB_DungeonInfoD:Execute()
					DB_DungeonInfoD:Reset()
					D.UpdateUI(page)
				end,
			},
		}
		PopupMenu(menu)
	end
end

function D.OnEditSpecialKeyDown()
	local name = this:GetName()
	local szKey = GetKeyName(Station.GetMessageKey())
	if szKey == 'Enter' then
		if name == 'Edit_Search' then
			local page = this:GetParent():GetParent():GetParent()
			D.UpdateUI(page)
		end
		return 1
	end
end

function D.OnItemMouseEnter()
	local name = this:GetName()
	if name == 'Handle_Row' then
		D.OutputRowTip(this, this.rec)
	elseif name == 'Image_ProgressBoss' or name == 'Text_CD' then
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		local aText = {}
		local map = X.GetMapInfo(this.mapid)
		if map then
			local szName = map.szName
			local aCD = D.tMapSaveCopy[map.dwID]
			if not X.IsEmpty(aCD) then
				szName = szName .. ' (' .. table.concat(aCD, ', ') .. ')'
			end
			table.insert(aText, szName)
		end
		if name == 'Image_ProgressBoss' then
			table.insert(aText, '')
			local rec = this:GetParent():GetParent():GetParent().rec
			for i, boss in ipairs(Table_GetCDProcessBoss(this.mapid)) do
				table.insert(aText, boss.szName .. '\t' .. _L[rec.progress_info[this.mapid][i] and 'x' or 'r'])
			end
		end
		table.insert(aText, '')
		local nTime = X.GetDungeonRefreshTime(this.mapid) - GetCurrentTime()
		table.insert(aText, _L('Refresh: %s', X.FormatDuration(nTime, 'CHINESE')))
		OutputTip(GetFormatText(table.concat(aText, '\n'), 162, 255, 255, 255), 400, { x, y, w, h })
	elseif name == 'Handle_DungeonStatColumn' then
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		local szXml = GetFormatText(this.szTip or this:Lookup('Text_DungeonStat_Title'):GetText(), 162, 255, 255, 255)
		if IsCtrlKeyDown() and this.szDebugTip then
			szXml = szXml .. CONSTANT.XML_LINE_BREAKER .. GetFormatText(this.szDebugTip, 102)
		end
		OutputTip(szXml, 450, {x, y, w, h}, UI.TIP_POSITION.TOP_BOTTOM)
	elseif this.tip then
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		OutputTip(this.tip, 400, {x, y, w, h, false}, nil, false)
	end
end
D.OnItemRefreshTip = D.OnItemMouseEnter

function D.OnItemMouseLeave()
	HideTip()
end

-- 浮动框
function D.ApplyFloatEntry(bFloatEntry)
	local frame = Station.Lookup('Normal/SprintPower')
	if not frame then
		return
	end
	local btn = frame:Lookup('Btn_MY_RoleStatistics_DungeonEntry')
	if bFloatEntry then
		if btn then
			return
		end
		local frameTemp = Wnd.OpenWindow(PLUGIN_ROOT .. '/ui/MY_RoleStatistics_DungeonEntry.ini', 'MY_RoleStatistics_DungeonEntry')
		btn = frameTemp:Lookup('Btn_MY_RoleStatistics_DungeonEntry')
		btn:ChangeRelation(frame, true, true)
		btn:SetRelPos(72, 13)
		Wnd.CloseWindow(frameTemp)
		btn.OnMouseEnter = function()
			local rec = D.GetClientPlayerRec(true)
			if not rec then
				return
			end
			D.OutputRowTip(this, rec)
		end
		btn.OnMouseLeave = function()
			D.CloseRowTip()
		end
		btn.OnLButtonClick = function()
			MY_RoleStatistics.Open('DungeonStat')
		end
	else
		if not btn then
			return
		end
		btn:Destroy()
	end
end

function D.UpdateFloatEntry()
	if not D.bReady then
		return
	end
	D.ApplyFloatEntry(O.bFloatEntry)
end

-- 首领死亡刷新秘境进度（秘境内同步拾取则视为进度更新）
X.RegisterEvent('SYNC_LOOT_LIST', 'MY_RoleStatistics_DungeonStat__UpdateMapCopy', function()
	if not D.bReady or not X.IsInDungeon() then
		return
	end
	local me = GetClientPlayer()
	if me then
		D.bMapSaveCopyValid = false
		D.tMapProgressValid[me.GetMapID()] = false
	end
	X.DelayCall('MY_RoleStatistics_DungeonStat__UpdateMapCopy', 300, function() D.UpdateMapProgress() end)
end)
X.RegisterEvent('UPDATE_DUNGEON_ROLE_PROGRESS', function()
	local dwMapID, dwPlayerID = arg0, arg1
	if dwPlayerID ~= UI_GetClientPlayerID() then
		return
	end
	D.tMapProgressValid[dwMapID] = true
	D.FlushDB()
end)
X.RegisterEvent('ON_APPLY_PLAYER_SAVED_COPY_RESPOND', function()
	local tMapCopy = arg0
	D.tMapSaveCopy = tMapCopy
	D.bMapSaveCopyValid = true
	D.FlushDB()
end)
X.RegisterInit('MY_RoleStatistics_DungeonEntry', function()
	D.UpdateMapProgress()
end)
X.RegisterUserSettingsUpdate('@@INIT@@', 'MY_RoleStatistics_DungeonStat', function()
	D.bReady = true
	D.UpdateSaveDB()
	D.FlushDB()
	D.UpdateFloatEntry()
end)
X.RegisterReload('MY_RoleStatistics_DungeonEntry', function() D.ApplyFloatEntry(false) end)
X.RegisterFrameCreate('SprintPower', 'MY_RoleStatistics_DungeonEntry', D.UpdateFloatEntry)

-- Module exports
do
local settings = {
	name = 'MY_RoleStatistics_DungeonStat',
	exports = {
		{
			preset = 'UIEvent',
			fields = {
				'OnInitPage',
				szSaveDB = 'MY_RoleStatistics_DungeonStat.bSaveDB',
				szFloatEntry = 'MY_RoleStatistics_DungeonStat.bFloatEntry',
			},
			root = D,
		},
	},
}
MY_RoleStatistics.RegisterModule('DungeonStat', _L['MY_RoleStatistics_DungeonStat'], X.CreateModule(settings))
end

-- Global exports
do
local settings = {
	name = 'MY_RoleStatistics_DungeonStat',
	exports = {
		{
			preset = 'UIEvent',
			root = D,
		},
		{
			fields = {
				'aColumn',
				'szSort',
				'szSortOrder',
				'bFloatEntry',
				'bSaveDB',
				'bAdviceSaveDB',
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				'aColumn',
				'szSort',
				'szSortOrder',
				'bFloatEntry',
				'bSaveDB',
				'bAdviceSaveDB',
			},
			triggers = {
				bFloatEntry = D.UpdateFloatEntry,
				bSaveDB = D.UpdateSaveDB,
			},
			root = O,
		},
	},
}
MY_RoleStatistics_DungeonStat = X.CreateModule(settings)
end
