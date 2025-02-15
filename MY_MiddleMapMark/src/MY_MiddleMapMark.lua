--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 中地图标记 记录所有NPC和Doodad位置 提供搜索
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
local PLUGIN_NAME = 'MY_MiddleMapMark'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_MiddleMapMark'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
X.RegisterRestriction('MY_MiddleMapMark.MapRestriction', { ['*'] = true })
--------------------------------------------------------------------------
X.CreateDataRoot(X.PATH_TYPE.GLOBAL)
local l_szKeyword, l_dwMapID, l_nMapIndex, l_renderTime = '', nil, nil, 0
local DB = X.SQLiteConnect(_L['MY_MiddleMapMark'], {'cache/npc_doodad_rec.v5.db', X.PATH_TYPE.GLOBAL})
if not DB then
	return X.Sysmsg(_L['MY_MiddleMapMark'], _L['Cannot connect to database!!!'], CONSTANT.MSG_THEME.ERROR)
end
DB:Execute([[
	CREATE TABLE IF NOT EXISTS NpcInfo (
		templateid INTEGER NOT NULL,
		poskey INTEGER NOT NULL,
		mapid INTEGER NOT NULL,
		x INTEGER NOT NULL,
		y INTEGER NOT NULL,
		z INTEGER NOT NULL,
		name NVARCHAR(20) NOT NULL,
		title NVARCHAR(20) NOT NULL,
		level INTEGER NOT NULL,
		extra TEXT NOT NULL,
		PRIMARY KEY(templateid, poskey)
	)
]])
DB:Execute('CREATE INDEX IF NOT EXISTS mmm_name_idx ON NpcInfo(name, mapid)')
DB:Execute('CREATE INDEX IF NOT EXISTS mmm_title_idx ON NpcInfo(title, mapid)')
DB:Execute('CREATE INDEX IF NOT EXISTS mmm_template_idx ON NpcInfo(templateid, mapid)')
local DBN_W  = DB:Prepare('REPLACE INTO NpcInfo (templateid, poskey, mapid, x, y, z, name, title, level, extra) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
local DBN_DM  = DB:Prepare('DELETE FROM NpcInfo WHERE mapid = ?')
local DBN_RI = DB:Prepare('SELECT templateid, poskey, mapid, x, y, name, title, level FROM NpcInfo WHERE templateid = ?')
local DBN_RN = DB:Prepare('SELECT templateid, poskey, mapid, x, y, name, title, level FROM NpcInfo WHERE name LIKE ? OR title LIKE ?')
local DBN_RNM = DB:Prepare('SELECT templateid, poskey, mapid, x, y, name, title, level FROM NpcInfo WHERE (name LIKE ? AND mapid = ?) OR (title LIKE ? AND mapid = ?)')
DB:Execute([[
	CREATE TABLE IF NOT EXISTS DoodadInfo (
		templateid INTEGER NOT NULL,
		poskey INTEGER NOT NULL,
		mapid INTEGER NOT NULL,
		x INTEGER NOT NULL,
		y INTEGER NOT NULL,
		z INTEGER NOT NULL,
		name NVARCHAR(20) NOT NULL,
		extra TEXT NOT NULL,
		PRIMARY KEY (templateid, poskey)
	)
]])
DB:Execute('CREATE INDEX IF NOT EXISTS mmm_name_idx ON DoodadInfo(name, mapid)')
local DBD_W  = DB:Prepare('REPLACE INTO DoodadInfo (templateid, poskey, mapid, x, y, z, name, extra) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
local DBD_DM  = DB:Prepare('DELETE FROM DoodadInfo WHERE mapid = ?')
local DBD_RI = DB:Prepare('SELECT templateid, poskey, mapid, x, y, name FROM DoodadInfo WHERE templateid = ?')
local DBD_RN = DB:Prepare('SELECT templateid, poskey, mapid, x, y, name FROM DoodadInfo WHERE name LIKE ?')
local DBD_RNM = DB:Prepare('SELECT templateid, poskey, mapid, x, y, name FROM DoodadInfo WHERE name LIKE ? AND mapid = ?')

local D = {}

---------------------------------------------------------------
-- 数据存储
---------------------------------------------------------------
local L16 = 0x10000
local L32 = 0x100000000
-- NPC 最大独立距离8尺（低于该距离的两个实体视为同一个）
-- DOODAD 最大独立距离2尺（低于该距离的两个实体视为同一个）
-- 不可随意更改，更改需要清空数据库重新建立key索引
local NPC_MAX_DISTINCT_DISTANCE = 8 * 64
local DOODAD_MAX_DISTINCT_DISTANCE = 2 * 64
-- 47 - 32 位 mapid
-- 31 - 16 位 x
-- 15 -  0 位 y
local function GeneNpcInfoPosKey(mapid, x, y)
	return mapid * L32 + math.floor(x / NPC_MAX_DISTINCT_DISTANCE) * L16 + math.floor(y / NPC_MAX_DISTINCT_DISTANCE)
end
local function GeneDoodadInfoPosKey(mapid, x, y)
	return mapid * L32 + math.floor(x / DOODAD_MAX_DISTINCT_DISTANCE) * L16 + math.floor(y / DOODAD_MAX_DISTINCT_DISTANCE)
end

function D.Migration()
	local DB_V1_ROOT = 'cache/NPC_DOODAD_REC/'
	local DB_V1_PATH = X.FormatPath({DB_V1_ROOT, X.PATH_TYPE.DATA})
	local DB_V2_PATH = X.FormatPath({'cache/npc_doodad_rec.v2.db', X.PATH_TYPE.GLOBAL})
	local DB_V3_PATH = X.FormatPath({'cache/npc_doodad_rec.v3.db', X.PATH_TYPE.GLOBAL})
	local DB_V4_PATH = X.FormatPath({'cache/npc_doodad_rec.v4.db', X.PATH_TYPE.GLOBAL})
	if not IsLocalFileExist(DB_V1_PATH) and not IsLocalFileExist(DB_V2_PATH) and not IsLocalFileExist(DB_V3_PATH) and not IsLocalFileExist(DB_V4_PATH) then
		return
	end
	X.Confirm(
		_L['Ancient database detected, do you want to migrate data from it?'],
		function()
			-- 转移V1旧版数据
			if IsLocalFileExist(DB_V1_PATH) then
				DB:Execute('BEGIN TRANSACTION')
				for _, dwMapID in ipairs(GetMapList()) do
					local data = X.LoadLUAData({DB_V1_ROOT .. dwMapID .. '.{$lang}.jx3dat', X.PATH_TYPE.DATA})
					if type(data) == 'string' then
						data = X.JsonDecode(data)
					end
					if data then
						for _, p in ipairs(data.Npc) do
							DBN_W:ClearBindings()
							DBN_W:BindAll(p.dwTemplateID, GeneNpcInfoPosKey(dwMapID, p.nX, p.nY), dwMapID, p.nX, p.nY, -1, AnsiToUTF8(p.szName), AnsiToUTF8(p.szTitle), p.nLevel, '')
							DBN_W:Execute()
						end
						DBN_W:Reset()
						for _, p in ipairs(data.Doodad) do
							DBD_W:ClearBindings()
							DBD_W:BindAll(p.dwTemplateID, GeneDoodadInfoPosKey(dwMapID, p.nX, p.nY), dwMapID, p.nX, p.nY, -1, AnsiToUTF8(p.szName), '')
							DBD_W:Execute()
						end
						DBD_W:Reset()
						--[[#DEBUG BEGIN]]
						X.Debug('MY_MiddleMapMark', 'MiddleMapMark cache trans from file to sqlite finished!', X.DEBUG_LEVEL.LOG)
						--[[#DEBUG END]]
					end
				end
				DB:Execute('END TRANSACTION')
				CPath.DelDir(X.FormatPath({DB_V1_ROOT, X.PATH_TYPE.DATA}))
			end
			-- 转移V2旧版数据
			if IsLocalFileExist(DB_V2_PATH) then
				local DB_V2 = SQLite3_Open(DB_V2_PATH)
				if DB_V2 then
					DB:Execute('BEGIN TRANSACTION')
					local aNpcInfo = DB_V2:Execute('SELECT * FROM NpcInfo WHERE templateid IS NOT NULL')
					if aNpcInfo then
						for _, rec in ipairs(aNpcInfo) do
							if rec.templateid and rec.poskey then
								DBN_W:ClearBindings()
								DBN_W:BindAll(
									rec.templateid,
									rec.poskey,
									rec.mapid or -1,
									rec.x or -1,
									rec.y or -1,
									-1,
									rec.name or '',
									rec.title or '',
									rec.level or -1,
									''
								)
								DBN_W:Execute()
							end
						end
						DBN_W:Reset()
					end
					local aDoodadInfo = DB_V2:Execute('SELECT * FROM DoodadInfo WHERE templateid IS NOT NULL')
					if aDoodadInfo then
						for _, rec in ipairs(aDoodadInfo) do
							if rec.templateid and rec.poskey then
								DBD_W:ClearBindings()
								DBD_W:BindAll(
									rec.templateid,
									rec.poskey,
									rec.mapid or -1,
									rec.x or -1,
									rec.y or -1,
									-1,
									rec.name or '',
									''
								)
								DBD_W:Execute()
							end
						end
						DBD_W:Reset()
					end
					DB:Execute('END TRANSACTION')
					DB_V2:Release()
				end
				CPath.Move(DB_V2_PATH, DB_V2_PATH .. '.bak' .. X.FormatTime(GetCurrentTime(), '%yyyy%MM%dd%hh%mm%ss'))
			end
			-- 转移V3旧版数据
			if IsLocalFileExist(DB_V3_PATH) then
				local DB_V3 = SQLite3_Open(DB_V3_PATH)
				if DB_V3 then
					DB:Execute('BEGIN TRANSACTION')
					local aNpcInfo = DB_V3:Execute('SELECT * FROM NpcInfo WHERE templateid IS NOT NULL')
					if aNpcInfo then
						for _, rec in ipairs(aNpcInfo) do
							if rec.templateid and rec.poskey then
								DBN_W:ClearBindings()
								DBN_W:BindAll(
									rec.templateid,
									rec.poskey,
									rec.mapid or -1,
									rec.x or -1,
									rec.y or -1,
									-1,
									rec.name or '',
									rec.title or '',
									rec.level or -1,
									''
								)
								DBN_W:Execute()
							end
						end
						DBN_W:Reset()
					end
					local aDoodadInfo = DB_V3:Execute('SELECT * FROM DoodadInfo WHERE templateid IS NOT NULL')
					if aDoodadInfo then
						for _, rec in ipairs(aDoodadInfo) do
							if rec.templateid and rec.poskey then
								DBD_W:ClearBindings()
								DBD_W:BindAll(
									rec.templateid,
									rec.poskey,
									rec.mapid or -1,
									rec.x or -1,
									rec.y or -1,
									-1,
									rec.name or '',
									''
								)
								DBD_W:Execute()
							end
						end
						DBD_W:Reset()
					end
					DB:Execute('END TRANSACTION')
					DB_V3:Release()
				end
				CPath.Move(DB_V3_PATH, DB_V3_PATH .. '.bak' .. X.FormatTime(GetCurrentTime(), '%yyyy%MM%dd%hh%mm%ss'))
			end
			-- 转移V4旧版数据
			if IsLocalFileExist(DB_V4_PATH) then
				local DB_V4 = SQLite3_Open(DB_V4_PATH)
				if DB_V4 then
					DB:Execute('BEGIN TRANSACTION')
					local aNpcInfo = DB_V4:Execute('SELECT * FROM NpcInfo WHERE templateid IS NOT NULL')
					if aNpcInfo then
						for _, rec in ipairs(aNpcInfo) do
							if rec.templateid and rec.poskey then
								DBN_W:ClearBindings()
								DBN_W:BindAll(
									rec.templateid,
									rec.poskey,
									rec.mapid or -1,
									rec.x or -1,
									rec.y or -1,
									-1,
									rec.name or '',
									rec.title or '',
									rec.level or -1,
									''
								)
								DBN_W:Execute()
							end
						end
						DBN_W:Reset()
					end
					local aDoodadInfo = DB_V4:Execute('SELECT * FROM DoodadInfo WHERE templateid IS NOT NULL')
					if aDoodadInfo then
						for _, rec in ipairs(aDoodadInfo) do
							if rec.templateid and rec.poskey then
								DBD_W:ClearBindings()
								DBD_W:BindAll(
									rec.templateid,
									rec.poskey,
									rec.mapid or -1,
									rec.x or -1,
									rec.y or -1,
									-1,
									rec.name or '',
									''
								)
								DBD_W:Execute()
							end
						end
						DBD_W:Reset()
					end
					DB:Execute('END TRANSACTION')
					DB_V4:Release()
				end
				CPath.Move(DB_V4_PATH, DB_V4_PATH .. '.bak' .. X.FormatTime(GetCurrentTime(), '%yyyy%MM%dd%hh%mm%ss'))
			end
			X.Alert(_L['Migrate succeed!'])
		end)
end
---------------------------------------------------------------
-- 数据采集
---------------------------------------------------------------
local l_npc = {}
local l_doodad = {}
local l_tempMap = false
local MAX_RENDER_INTERVAL = GLOBAL.GAME_FPS * 5
local function FlushDB()
	if X.IsEmpty(l_npc) and X.IsEmpty(l_doodad) then
		return
	end
	DB:Execute('BEGIN TRANSACTION')

	for i, p in pairs(l_npc) do
		if not p.temp then
			DBN_W:ClearBindings()
			DBN_W:BindAll(p.templateid, p.poskey, p.mapid, p.x, p.y, p.z, AnsiToUTF8(p.name), AnsiToUTF8(p.title), p.level, '')
			DBN_W:Execute()
		end
	end
	DBN_W:Reset()
	l_npc = {}

	for i, p in pairs(l_doodad) do
		if not p.temp then
			DBD_W:ClearBindings()
			DBD_W:BindAll(p.templateid, p.poskey, p.mapid, p.x, p.y, p.z, AnsiToUTF8(p.name), '')
			DBD_W:Execute()
		end
	end
	DBD_W:Reset()
	l_doodad = {}

	DB:Execute('END TRANSACTION')
end
local function onLoadingEnding()
	l_tempMap = X.IsInZombieMap() or X.IsInPubg() or X.IsInArena() or X.IsInBattleField() or false
	if l_tempMap then
		local dwMapID = GetClientPlayer().GetMapID()
		DBN_DM:ClearBindings()
		DBN_DM:BindAll(dwMapID)
		DBN_DM:Execute()
		DBN_DM:Reset()
		DBD_DM:ClearBindings()
		DBD_DM:BindAll(dwMapID)
		DBD_DM:Execute()
		DBD_DM:Reset()
	end
	FlushDB()
end
X.RegisterEvent('LOADING_ENDING', 'MY_MiddleMapMark', onLoadingEnding)

local function Flush()
	FlushDB()
end
X.RegisterFlush('MY_MiddleMapMark_Save', Flush)

local function OnExit()
	DB:Release()
end
X.RegisterExit('MY_MiddleMapMark_Save', OnExit)

local function Rerender()
	D.Search(true)
end

local function AutomaticRerender()
	if GetTime() - l_renderTime > MAX_RENDER_INTERVAL then
		Rerender()
	elseif not X.DelayCall('MY_MiddleMapMark_Refresh') then
		X.DelayCall('MY_MiddleMapMark_Refresh', MAX_RENDER_INTERVAL, Rerender)
	end
end

local NpcTpl = X.LoadLUAData(X.PACKET_INFO.ROOT .. 'MY_MiddleMapMark/data/npc/{$lang}.jx3dat')
local DoodadTpl = X.LoadLUAData(X.PACKET_INFO.ROOT .. 'MY_MiddleMapMark/data/doodad/{$lang}.jx3dat')
local function OnNpcEnterScene()
	if l_tempMap and X.IsRestricted('MY_MiddleMapMark.MapRestriction') then
		return
	end
	local npc = GetNpc(arg0)
	local player = GetClientPlayer()
	if not (npc and player) then
		return
	end
	-- avoid special npc
	if NpcTpl[npc.dwTemplateID] then
		return
	end
	-- avoid player's pets
	if npc.dwEmployer and npc.dwEmployer ~= 0 then
		return
	end
	-- avoid full number named npc
	local szName = X.GetObjectName(npc, 'never')
	if not szName or X.TrimString(szName) == '' then
		return
	end
	-- switch map
	local dwMapID = player.GetMapID()
	local dwPosKey = GeneNpcInfoPosKey(dwMapID, npc.nX, npc.nY)

	-- add rec
	l_npc[npc.dwTemplateID .. ',' .. dwPosKey] = {
		decoded = true,
		temp = l_tempMap,
		x = npc.nX,
		y = npc.nY,
		z = npc.nZ,
		mapid = dwMapID,
		level = npc.nLevel,
		name  = szName,
		title = npc.szTitle,
		poskey = dwPosKey,
		templateid = npc.dwTemplateID,
	}
	-- redraw ui
	AutomaticRerender()
end
X.RegisterEvent('NPC_ENTER_SCENE', 'MY_MIDDLEMAPMARK', OnNpcEnterScene)

local REC_DOODAD_TYPES = {
	[DOODAD_KIND.INVALID     ] = false,
	[DOODAD_KIND.NORMAL      ] = true , -- 普通的Doodad,有Tip,不能操作
	[DOODAD_KIND.CORPSE      ] = false, -- 尸体
	[DOODAD_KIND.QUEST       ] = true , -- 任务相关的Doodad
	[DOODAD_KIND.READ        ] = true , -- 可以看的Doodad
	[DOODAD_KIND.DIALOG      ] = true , -- 可以对话的Doodad
	[DOODAD_KIND.ACCEPT_QUEST] = true , -- 可以接任务的Doodad,本质上上面3个类型是一样的,只是图标不同而已
	[DOODAD_KIND.TREASURE    ] = false, -- 宝箱
	[DOODAD_KIND.ORNAMENT    ] = false, -- 装饰物,不能操作
	[DOODAD_KIND.CRAFT_TARGET] = true , -- 生活技能的采集物
	[DOODAD_KIND.CLIENT_ONLY ] = false, -- 客户端用
	[DOODAD_KIND.CHAIR       ] = true , -- 可以坐的Doodad
	[DOODAD_KIND.GUIDE       ] = false, -- 路标
	[DOODAD_KIND.DOOR        ] = false, -- 门之类有动态障碍的Doodad
	[DOODAD_KIND.NPCDROP     ] = false, -- 使用NPC掉落模式的doodad
	[DOODAD_KIND.SPRINT      ] = false, -- 轻功落脚点
}
local function OnDoodadEnterScene()
	if l_tempMap and X.IsRestricted('MY_MiddleMapMark.MapRestriction') then
		return
	end
	local doodad = GetDoodad(arg0)
	local player = GetClientPlayer()
	if not (doodad and player) then
		return
	end
	if not REC_DOODAD_TYPES[doodad.nKind] then
		return
	end
	-- avoid special doodad
	if DoodadTpl[doodad.dwTemplateID] then
		return
	end
	-- avoid full number named doodad
	local szName = X.GetObjectName(doodad, 'never')
	if not szName or X.TrimString(szName) == '' then
		return
	end
	-- switch map
	local dwMapID = player.GetMapID()
	local dwPosKey = GeneDoodadInfoPosKey(dwMapID, doodad.nX, doodad.nY)

	-- add rec
	l_doodad[doodad.dwTemplateID .. ',' .. dwPosKey] = {
		decoded = true,
		temp = l_tempMap,
		x = doodad.nX,
		y = doodad.nY,
		z = doodad.nZ,
		name = szName,
		mapid = dwMapID,
		poskey = dwPosKey,
		templateid = doodad.dwTemplateID,
	}
	-- redraw ui
	AutomaticRerender()
end
X.RegisterEvent('DOODAD_ENTER_SCENE', 'MY_MIDDLEMAPMARK', OnDoodadEnterScene)

function D.SearchNpc(szText, dwMapID)
	local aInfos
	local szSearch = AnsiToUTF8('%' .. szText .. '%')
	if dwMapID then
		DBN_RNM:ClearBindings()
		DBN_RNM:BindAll(szSearch, dwMapID, szSearch, dwMapID)
		aInfos = DBN_RNM:GetAll()
		DBN_RNM:Reset()
	else
		DBN_RN:ClearBindings()
		DBN_RN:BindAll(szSearch, szSearch)
		aInfos = DBN_RN:GetAll()
		DBN_RN:Reset()
	end
	for i = #aInfos, 1, -1 do
		local p = aInfos[i]
		if (not dwMapID or p.mapid == dwMapID)
		and l_npc[p.templateid .. ',' .. p.poskey] then
			table.remove(aInfos, i)
		end
	end
	for _, info in pairs(l_npc) do
		if (not dwMapID or info.mapid == dwMapID)
		and (wstring.find(info.name, szText) or wstring.find(info.title, szText)) then
			table.insert(aInfos, 1, info)
		end
	end
	return aInfos
end

function D.SearchDoodad(szText, dwMapID)
	local aInfos
	local szSearch = AnsiToUTF8('%' .. szText .. '%')
	if dwMapID then
		DBD_RNM:ClearBindings()
		DBD_RNM:BindAll(szSearch, dwMapID)
		aInfos = DBD_RNM:GetAll()
		DBD_RNM:Reset()
	else
		DBD_RN:ClearBindings()
		DBD_RN:BindAll(szSearch)
		aInfos = DBD_RN:GetAll()
		DBD_RN:Reset()
	end
	for i = #aInfos, 1, -1 do
		local p = aInfos[i]
		if (not dwMapID or p.mapid == dwMapID)
		and l_doodad[p.templateid .. ',' .. p.poskey] then
			table.remove(aInfos, i)
		end
	end
	for _, info in pairs(l_doodad) do
		if (not dwMapID or info.mapid == dwMapID)
		and (wstring.find(info.name, szText)) then
			table.insert(aInfos, 1, info)
		end
	end
	return aInfos
end

---------------------------------------------------------------
-- 中地图HOOK
---------------------------------------------------------------
-- HOOK MAP SWITCH
function D.ShowMap()
	D.Search(true)
end

function D.UpdateCurrentMap()
	D.Search(true)
end

-- HOOK OnEditChanged
function D.OnEditChanged()
	if this:GetName() == 'Edit_Search' then
		X.DelayCall('MY_MiddleMapMark__EditChanged', 500, D.Search)
	end
end

-- HOOK OnMouseEnter
function D.OnMouseEnter()
	if this:GetName() == 'Edit_Search' then
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		OutputTip(
			GetFormatText(_L['MY middle map mark'], nil, 255, 255, 0)
				.. CONSTANT.XML_LINE_BREAKER
				.. GetFormatText(_L['Type to search, use comma to split.'], nil, 255, 255, 192),
			w,
			{x - 10, y, w, h},
			UI.TIP_POSITION.TOP_BOTTOM
		)
	end
end

-- HOOK OnMouseLeave
function D.OnMouseLeave()
	if this:GetName() == 'Edit_Search' then
		HideTip()
	end
end

function D.HookEdit()
	local edit = Station.Lookup('Topmost1/MiddleMap/Wnd_Tool/Edit_Search')
	if edit then
		HookTableFunc(edit, 'OnEditChanged', D.OnEditChanged, { bAfterOrigin = true })
	end
end
X.RegisterFrameCreate('MiddleMap', 'MY_MiddleMapMark', D.HookEdit)

function D.Hook()
	D.HookEdit()
	HookTableFunc(MiddleMap, 'ShowMap', D.ShowMap, { bAfterOrigin = true })
	HookTableFunc(MiddleMap, 'UpdateCurrentMap', D.UpdateCurrentMap, { bAfterOrigin = true })
	HookTableFunc(MiddleMap, 'OnEditChanged', D.OnEditChanged, { bAfterOrigin = true })
	HookTableFunc(MiddleMap, 'OnMouseEnter', D.OnMouseEnter, { bAfterOrigin = true })
	HookTableFunc(MiddleMap, 'OnMouseLeave', D.OnMouseLeave, { bAfterOrigin = true })
end
X.RegisterInit('MY_MiddleMapMark', D.Hook)

function D.Unhook()
	local h = Station.Lookup('Topmost1/MiddleMap', 'Handle_Inner/Handle_MY_MMM')
	if h then
		h:GetParent():RemoveItem(h)
	end
	UnhookTableFunc(MiddleMap, 'ShowMap', D.ShowMap)
	UnhookTableFunc(MiddleMap, 'UpdateCurrentMap', D.UpdateCurrentMap)
	UnhookTableFunc(MiddleMap, 'OnEditChanged', D.OnEditChanged)
	UnhookTableFunc(MiddleMap, 'OnMouseEnter', D.OnMouseEnter)
	UnhookTableFunc(MiddleMap, 'OnMouseLeave', D.OnMouseLeave)
end
X.RegisterReload('MY_MiddleMapMark', D.Unhook)

function D.GetEditSearch()
	return Station.Lookup('Topmost1/MiddleMap/Wnd_NormalMap/Wnd_Tool/Edit_Search')
		or Station.Lookup('Topmost1/MiddleMap/Wnd_Tool/Edit_Search')
end

-- start search
local MAX_DISPLAY_COUNT = 1000
local function OnMMMItemMouseEnter()
	local me = GetClientPlayer()
	local x, y = this:GetAbsPos()
	local w, h = this:GetSize()
	local szTip = (this.decoded and this.name or UTF8ToAnsi(this.name))
		.. (this.level and this.level > 0 and (' lv.' .. this.level) or '')
		.. (this.title and this.title ~= '' and ('\n<' .. (this.decoded and this.title or UTF8ToAnsi(this.title)) .. '>') or '')
	if this.type == 'Doodad' then
		local dwRecipeID = me and X.GetDoodadBookRecipeID(this.templateid)
		if dwRecipeID then
			local dwBookID, dwSegmentID = X.RecipeToSegmentID(dwRecipeID)
			if dwBookID and dwSegmentID then
				if me.IsBookMemorized(dwBookID, dwSegmentID) then
					szTip = szTip .. '\n' .. _L['[Read]']
				else
					szTip = szTip .. '\n' .. _L['[Not read]']
				end
			end
		end
	end
	if IsCtrlKeyDown() then
		szTip = szTip .. (this.templateid and ('\n' .. this.type .. ' Template ID: ' .. this.templateid) or '')
			.. '\n' .. this.x .. ', ' .. this.y .. ',' .. this.z
	end
	OutputTip(GetFormatText(szTip, 136), 450, {x, y, w, h}, ALW.TOP_BOTTOM)
end
local function OnMMMItemMouseLeave()
	HideTip()
end
function D.Search(bForce)
	local frame = Station.Lookup('Topmost1/MiddleMap')
	local player = GetClientPlayer()
	if not player or not frame or not frame:IsVisible() then
		return
	end
	local edit = D.GetEditSearch()
	if not edit then
		return
	end
	local szKeyword = edit:GetText()
	local dwMapID = MiddleMap.dwMapID or player.GetMapID()
	local nMapIndex = MiddleMap.nIndex
	if not bForce and l_dwMapID == dwMapID and l_nMapIndex == nMapIndex and l_szKeyword == szKeyword then
		return
	end
	l_renderTime = GetTime()
	l_dwMapID, l_nMapIndex, l_szKeyword = dwMapID, nMapIndex, szKeyword

	local hInner = frame:Lookup('', 'Handle_Inner')
	local nW, nH = hInner:GetSize()
	local hMMM = hInner:Lookup('Handle_MY_MMM')
	if not hMMM then
		hInner:AppendItemFromString('<handle>firstpostype=0 name="Handle_MY_MMM" w=' .. nW .. ' h=' .. nH .. '</handle>')
		hMMM = hInner:Lookup('Handle_MY_MMM')
		hInner:FormatAllItemPos()
	end
	local nCount = 0
	local nItemCount = hMMM:GetItemCount()

	local infos
	local aKeywords = {}
	do
		local i = 1
		for _, szSearch in ipairs(X.SplitString(szKeyword, ',')) do
			szSearch = X.TrimString(szSearch)
			if szSearch ~= '' then
				aKeywords[i] = szSearch
				i = i + 1
			end
		end
	end
	local nX, nY, item

	for i, szSearch in ipairs(aKeywords) do
		infos = D.SearchNpc(szSearch, dwMapID)
		for _, info in ipairs(infos) do
			if nCount < MAX_DISPLAY_COUNT then
				nX, nY = MiddleMap.LPosToHPos(info.x, info.y, 13, 13)
				if nX > 0 and nY > 0 and nX < nW and nY < nH then
					nCount = nCount + 1
					if nCount > nItemCount then
						hMMM:AppendItemFromString('<image>w=13 h=13 path="ui/Image/Minimap/MapMark.UITex" frame=95 eventid=784</image>')
						nItemCount = nItemCount + 1
					end
					item = hMMM:Lookup(nCount - 1)
					item:Show()
					item:SetRelPos(nX, nY)
					item.decoded = info.decoded
					item.type = 'Npc'
					item.name = info.name
					item.x = info.x
					item.y = info.y
					item.z = info.z
					item.title = info.title
					item.level = info.level
					item.templateid = info.templateid
					item.OnItemMouseEnter = OnMMMItemMouseEnter
					item.OnItemMouseLeave = OnMMMItemMouseLeave
				end
			end
		end
	end

	for i, szSearch in ipairs(aKeywords) do
		infos = D.SearchDoodad(szSearch, dwMapID)
		for _, info in ipairs(infos) do
			if nCount < MAX_DISPLAY_COUNT then
				nX, nY = MiddleMap.LPosToHPos(info.x, info.y, 13, 13)
				if nX > 0 and nY > 0 and nX < nW and nY < nH then
					nCount = nCount + 1
					if nCount > nItemCount then
						hMMM:AppendItemFromString('<image>w=13 h=13 path="ui/Image/Minimap/MapMark.UITex" frame=95 eventid=784</image>')
						nItemCount = nItemCount + 1
					end
					item = hMMM:Lookup(nCount - 1)
					item:Show()
					item:SetRelPos(nX, nY)
					item.decoded = info.decoded
					item.type = 'Doodad'
					item.name = info.name
					item.x = info.x
					item.y = info.y
					item.z = info.z
					item.title = info.title
					item.level = info.level
					item.templateid = info.templateid
					item.OnItemMouseEnter = OnMMMItemMouseEnter
					item.OnItemMouseLeave = OnMMMItemMouseLeave
				end
			end
		end
	end

	for i = nCount, nItemCount - 1 do
		hMMM:Lookup(i):Hide()
	end
	hMMM:FormatAllItemPos()
end

---------------------------------------------------------------
-- 主面板搜索
---------------------------------------------------------------
local PS = { nPriority = 4.1 }
function PS.OnPanelActive(wnd)
	D.Migration()

	local ui = UI(wnd)
	local x, y = 0, 0
	local w, h = ui:Size()

	local list, muProgress
	local function UpdateList(szText)
		if X.IsEmpty(szText) then
			list:ListBox('clear')
			for i, s in ipairs(_L['MY_MiddleMapMark TIPS']) do
				list:ListBox('insert', { id = 'TIP' .. i, text = s, r = 255, g = 255, b = 0 })
			end
		else
			local nMaxDisp = 500
			local nDisp = 0
			local nCount = 0
			local tNames = {}
			local infos, szName, szTitle
			list:ListBox('clear')

			infos = D.SearchNpc(szText)
			nCount = nCount + #infos
			for _, info in ipairs(infos) do
				szName  = info.decoded and info.name  or UTF8ToAnsi(info.name)
				szTitle = info.decoded and info.title or UTF8ToAnsi(info.title)
				if not tNames[info.mapid .. szName] then
					list:ListBox('insert', {
						text = '[' .. Table_GetMapName(info.mapid) .. '] ' .. szName
							.. ((szTitle and #szTitle > 0 and '<' .. szTitle .. '>') or ''),
						data = { szName  = szName, dwMapID = info.mapid },
					})
					nDisp = nDisp + 1
					if nDisp >= nMaxDisp then
						return
					end
					tNames[info.mapid .. szName] = true
				end
			end

			infos = D.SearchDoodad(szText)
			nCount = nCount + #infos
			for _, info in ipairs(infos) do
				szName = info.decoded and info.name or UTF8ToAnsi(info.name)
				if not tNames[info.mapid .. szName] then
					list:ListBox('insert', {
						text = '[' .. Table_GetMapName(info.mapid) .. '] ' .. szName,
						data = { szName  = szName, dwMapID = info.mapid },
					})
					nDisp = nDisp + 1
					if nDisp >= nMaxDisp then
						return
					end
					tNames[info.mapid .. szName] = true
				end
			end
		end
	end

	ui:Append('WndEditBox', {
		name = 'WndEdit_Search',
		x = x, y = y,
		w = w, h = 25,
		onchange = function(szText)
			UpdateList(szText)
		end,
	})
	y = y + 25

	muProgress = ui:Append('Image', {
		name = 'Image_Progress',
		x = x, y = y,
		w = w, h = 4,
		image = 'ui/Image/UICommon/RaidTotal.UITex|45',
	})
	y = y + 4

	list = ui:Append('WndListBox', {
		name = 'WndListBox_1',
		x = x, y = y,
		w = w, h = h - y,
		listbox = {
			{
				'onhover',
				function(id, text, data)
					if X.IsString(id) and id:sub(1, 3) == 'TIP' then
						return false
					end
				end,
			},
			{
				'onlclick',
				function(id, text, data, selected)
					if X.IsString(id) and id:sub(1, 3) == 'TIP' then
						return false
					end
					OpenMiddleMap(data.dwMapID, 0)
					UI(D.GetEditSearch()):Text(X.EscapeString(data.szName))
					Station.SetFocusWindow('Topmost1/MiddleMap')
					if not selected then -- avoid unselect
						return false
					end
				end,
			},
		},
	})

	UpdateList('')
end

function PS.OnPanelResize(wnd)
	local ui = UI(wnd)
	local x, y = ui:Pos()
	local w, h = ui:Size()

	ui:Children('#WndListBox_1'):Size(w - 32, h - 50)
	ui:Children('#Image_Progress'):Size(w - 30, 4)
	ui:Children('#WndEdit_Search'):Size(w - 26, 25)
end

X.RegisterPanel(_L['General'], 'MY_MiddleMapMark', _L['middle map mark'], 'ui/Image/MiddleMap/MapWindow2.UITex|4', PS)
