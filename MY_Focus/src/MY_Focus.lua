--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 焦点列表
-- @author   : 茗伊 @双梦镇 @追风蹑影
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
--------------------------------------------------------
--------------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
--------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local ipairs, pairs, next, pcall = ipairs, pairs, next, pcall
local sub, len, format, rep = string.sub, string.len, string.format, string.rep
local find, byte, char, gsub = string.find, string.byte, string.char, string.gsub
local type, tonumber, tostring = type, tonumber, tostring
local huge, pi, random, abs = math.huge, math.pi, math.random, math.abs
local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil
local pow, sqrt, sin, cos, tan = math.pow, math.sqrt, math.sin, math.cos, math.tan
local insert, remove, concat, sort = table.insert, table.remove, table.concat, table.sort
local pack, unpack = table.pack or function(...) return {...} end, table.unpack or unpack
-- jx3 apis caching
local wsub, wlen, wfind = wstring.sub, wstring.len, wstring.find
local GetTime, GetLogicFrameCount = GetTime, GetLogicFrameCount
local GetClientTeam, UI_GetClientPlayerID = GetClientTeam, UI_GetClientPlayerID
local GetClientPlayer, GetPlayer, GetNpc, IsPlayer = GetClientPlayer, GetPlayer, GetNpc, IsPlayer
local MY, UI = MY, MY.UI
local var2str, str2var, clone, empty, ipairs_r = MY.var2str, MY.str2var, MY.clone, MY.empty, MY.ipairs_r
local spairs, spairs_r, sipairs, sipairs_r = MY.spairs, MY.spairs_r, MY.sipairs, MY.sipairs_r
local GetPatch, ApplyPatch = MY.GetPatch, MY.ApplyPatch
local Get, Set, RandomChild, GetTraceback = MY.Get, MY.Set, MY.RandomChild, MY.GetTraceback
local IsArray, IsDictionary, IsEquals = MY.IsArray, MY.IsDictionary, MY.IsEquals
local IsNil, IsBoolean, IsNumber, IsFunction = MY.IsNil, MY.IsBoolean, MY.IsNumber, MY.IsFunction
local IsEmpty, IsString, IsTable, IsUserdata = MY.IsEmpty, MY.IsString, MY.IsTable, MY.IsUserdata
local MENU_DIVIDER, EMPTY_TABLE, XML_LINE_BREAKER = MY.MENU_DIVIDER, MY.EMPTY_TABLE, MY.XML_LINE_BREAKER
--------------------------------------------------------------------------------------------------------
local CHANGGE_REAL_SHADOW_TPLID = 46140 -- 清绝歌影 的主体影子
local INI_PATH = MY.GetAddonInfo().szRoot .. 'MY_Focus/ui/MY_Focus.ini'
local _L = MY.LoadLangPack(MY.GetAddonInfo().szRoot .. 'MY_Focus/lang/')
local FOCUS_LIST = {}
local l_tTempFocusList = {
	[TARGET.PLAYER] = {},   -- dwID
	[TARGET.NPC]    = {},   -- dwTemplateID
	[TARGET.DOODAD] = {},   -- dwTemplateID
}
local l_dwLockType, l_dwLockID, l_lockInDisplay
local D = { PASSPHRASE = {111, 198, 5} }
MY_Focus = {}
MY_Focus.bEnable            = false -- 是否启用
MY_Focus.bMinimize          = false -- 是否最小化
MY_Focus.bFocusINpc         = true  -- 焦点重要NPC
MY_Focus.bFocusFriend       = false -- 焦点附近好友
MY_Focus.bFocusTong         = false -- 焦点帮会成员
MY_Focus.bOnlyPublicMap     = true  -- 仅在公共地图焦点好友帮会成员
MY_Focus.bSortByDistance    = false -- 优先焦点近距离目标
MY_Focus.bFocusEnemy        = false -- 焦点敌对玩家
MY_Focus.bFocusAnmerkungen  = true  -- 焦点记在小本本里的玩家
MY_Focus.bAutoHide          = true  -- 无焦点时隐藏
MY_Focus.nMaxDisplay        = 5     -- 最大显示数量
MY_Focus.bAutoFocus         = true  -- 启用默认焦点
MY_Focus.bEmbeddedFocus     = true  -- 启用内嵌默认焦点
MY_Focus.bHideDeath         = false -- 隐藏死亡目标
MY_Focus.bDisplayKungfuIcon = false -- 显示心法图标
MY_Focus.bFocusJJCParty     = false -- 焦竞技场队友
MY_Focus.bFocusJJCEnemy     = true  -- 焦竞技场敌队
MY_Focus.bShowTarget        = false -- 显示目标目标
MY_Focus.szDistanceType     = 'global' -- 坐标距离计算方式
MY_Focus.bTraversal         = false -- 遍历焦点列表
MY_Focus.bHealHelper        = false -- 辅助治疗模式
MY_Focus.bEnableSceneNavi   = false -- 场景追踪点
MY_Focus.fScaleX            = 1     -- 缩放比例
MY_Focus.fScaleY            = 1     -- 缩放比例
MY_Focus.tAutoFocus = {}    -- 默认焦点
MY_Focus.tFocusList = {     -- 永久焦点
	[TARGET.PLAYER] = {},   -- dwID
	[TARGET.NPC]    = {},   -- dwTemplateID
	[TARGET.DOODAD] = {},   -- dwTemplateID
}
MY_Focus.anchor = { x=-300, y=220, s='TOPRIGHT', r='TOPRIGHT' } -- 默认坐标
RegisterCustomData('MY_Focus.bEnable', 1)
RegisterCustomData('MY_Focus.bMinimize')
RegisterCustomData('MY_Focus.bFocusINpc')
RegisterCustomData('MY_Focus.bFocusFriend')
RegisterCustomData('MY_Focus.bFocusTong')
RegisterCustomData('MY_Focus.bOnlyPublicMap')
RegisterCustomData('MY_Focus.bSortByDistance')
RegisterCustomData('MY_Focus.bFocusEnemy')
RegisterCustomData('MY_Focus.bFocusAnmerkungen')
RegisterCustomData('MY_Focus.bAutoHide')
RegisterCustomData('MY_Focus.nMaxDisplay')
RegisterCustomData('MY_Focus.bAutoFocus')
RegisterCustomData('MY_Focus.bEmbeddedFocus')
RegisterCustomData('MY_Focus.bHideDeath')
RegisterCustomData('MY_Focus.bDisplayKungfuIcon')
RegisterCustomData('MY_Focus.bFocusJJCParty')
RegisterCustomData('MY_Focus.bFocusJJCEnemy')
RegisterCustomData('MY_Focus.bShowTarget')
RegisterCustomData('MY_Focus.szDistanceType')
RegisterCustomData('MY_Focus.bTraversal')
RegisterCustomData('MY_Focus.bHealHelper')
RegisterCustomData('MY_Focus.bEnableSceneNavi')
RegisterCustomData('MY_Focus.tAutoFocus')
RegisterCustomData('MY_Focus.tFocusList')
RegisterCustomData('MY_Focus.anchor')
RegisterCustomData('MY_Focus.fScaleX')
RegisterCustomData('MY_Focus.fScaleY')

local function FormatAutoFocusData(data)
	local ds = {
		szMethod = 'NAME',
		szPattern = '',
		szDisplay = '',
		dwMapID = -1,
		tType = {
			bAll = true,
			[TARGET.NPC] = false,
			[TARGET.PLAYER] = false,
			[TARGET.DOODAD] = false,
		},
		tRelation = {
			bAll = true,
			bEnemy = false,
			bAlly = false,
		},
		tLife = {
			bEnable = false,
			szOperator = '>',
			nValue = 0,
		},
		nMaxDistance = 0,
	}
	return MY.FormatDataStructure(data, ds)
end
function MY_Focus.IsShielded() return MY.IsShieldedVersion() and MY.IsInShieldedMap() end
function MY_Focus.IsEnabled() return MY_Focus.bEnable and not MY_Focus.IsShielded() end

function MY_Focus.SetScale(fScaleX, fScaleY)
	MY_Focus.fScaleX = fScaleX
	MY_Focus.fScaleY = fScaleY
	FireUIEvent('MY_FOCUS_SCALE_UPDATE')
end

function MY_Focus.SetMaxDisplay(nMaxDisplay)
	MY_Focus.nMaxDisplay = nMaxDisplay
	FireUIEvent('MY_FOCUS_MAX_DISPLAY_UPDATE')
end

function MY_Focus.SetAutoHide(bAutoHide)
	MY_Focus.bAutoHide = bAutoHide
	FireUIEvent('MY_FOCUS_AUTO_HIDE_UPDATE')
end

-- 添加默认焦点
function MY_Focus.SetFocusPattern(szName)
	szName = MY.TrimString(szName)
	for _, v in ipairs(MY_Focus.tAutoFocus) do
		if v.szPattern == szName then
			return
		end
	end
	local tData = FormatAutoFocusData({
		szPattern = szName,
	})
	insert(MY_Focus.tAutoFocus, tData)
	-- 更新焦点列表
	MY_Focus.ScanNearby()
	return tData
end

-- 删除默认焦点
function MY_Focus.RemoveFocusPattern(szPattern)
	local p
	for i = #MY_Focus.tAutoFocus, 1, -1 do
		if MY_Focus.tAutoFocus[i].szPattern == szPattern then
			p = MY_Focus.tAutoFocus[i]
			remove(MY_Focus.tAutoFocus, i)
			break
		end
	end
	if not p then
		return
	end
	-- 刷新UI
	if p.szMethod == 'NAME' then
		-- 全字符匹配模式：检查是否在永久焦点中 没有则删除Handle （节约性能）
		for i = #FOCUS_LIST, 1, -1 do
			local p = FOCUS_LIST[i]
			local KObject = MY.GetObject(p.dwType, p.dwID)
			local dwTemplateID = p.dwType == TARGET.PLAYER and p.dwID or KObject.dwTemplateID
			if KObject and MY.GetObjectName(KObject, 'never') == szPattern
			and not l_tTempFocusList[p.dwType][p.dwID]
			and not MY_Focus.tFocusList[p.dwType][dwTemplateID] then
				MY_Focus.OnObjectLeaveScene(p.dwType, p.dwID)
			end
		end
	else
		-- 其他模式：重绘焦点列表
		MY_Focus.RescanNearby()
	end
end

-- 添加ID焦点
function MY_Focus.SetFocusID(dwType, dwID, bSave)
	dwType, dwID = tonumber(dwType), tonumber(dwID)
	if bSave then
		local KObject = MY.GetObject(dwType, dwID)
		local dwTemplateID = dwType == TARGET.PLAYER and dwID or KObject.dwTemplateID
		if MY_Focus.tFocusList[dwType][dwTemplateID] then
			return
		end
		MY_Focus.tFocusList[dwType][dwTemplateID] = true
		MY_Focus.RescanNearby()
	else
		if l_tTempFocusList[dwType][dwID] then
			return
		end
		l_tTempFocusList[dwType][dwID] = true
		MY_Focus.OnObjectEnterScene(dwType, dwID)
	end
end

-- 删除ID焦点
function MY_Focus.RemoveFocusID(dwType, dwID)
	dwType, dwID = tonumber(dwType), tonumber(dwID)
	if l_tTempFocusList[dwType][dwID] then
		l_tTempFocusList[dwType][dwID] = nil
		MY_Focus.OnObjectLeaveScene(dwType, dwID)
	end
	local KObject = MY.GetObject(dwType, dwID)
	local dwTemplateID = dwType == TARGET.PLAYER and dwID or KObject.dwTemplateID
	if MY_Focus.tFocusList[dwType][dwTemplateID] then
		MY_Focus.tFocusList[dwType][dwTemplateID] = nil
		MY_Focus.RescanNearby()
	end
end

-- 清空焦点列表
function MY_Focus.ClearFocus()
	FOCUS_LIST = {}
	FireUIEvent('MY_FOCUS_UPDATE')
end

-- 重新扫描附近对象更新焦点列表（只增不减）
function MY_Focus.ScanNearby()
	for _, dwID in ipairs(MY.GetNearPlayerID()) do
		MY_Focus.OnObjectEnterScene(TARGET.PLAYER, dwID)
	end
	for _, dwID in ipairs(MY.GetNearNpcID()) do
		MY_Focus.OnObjectEnterScene(TARGET.NPC, dwID)
	end
	for _, dwID in ipairs(MY.GetNearDoodadID()) do
		MY_Focus.OnObjectEnterScene(TARGET.DOODAD, dwID)
	end
end

-- 重新扫描附近焦点
function MY_Focus.RescanNearby()
	MY_Focus.ClearFocus()
	MY_Focus.ScanNearby()
end

function D.GetEligibleRule(tRules, dwMapID, dwType, dwID, dwTemplateID, szName, szTong)
	for _, v in ipairs(tRules) do
		if (v.tType.bAll or v.tType[dwType])
		and (v.dwMapID == -1 or v.dwMapID == dwMapID)
		and (
			(v.szMethod == 'NAME' and v.szPattern == szName)
			or (v.szMethod == 'NAME_PATT' and szName:find(v.szPattern))
			or (v.szMethod == 'ID' and tonumber(v.szPattern) == dwID)
			or (v.szMethod == 'TEMPLATE_ID' and tonumber(v.szPattern) == dwTemplateID)
			or (v.szMethod == 'TONG_NAME' and v.szPattern == szTong)
			or (v.szMethod == 'TONG_NAME_PATT' and szTong:find(v.szPattern))
		) then
			return v
		end
	end
end

function D.LoadEmbeddedRule()
	-- auto generate embedded data
	local DAT_ROOT = 'MY_Resource/data/focus/'
	local SRC_ROOT = MY.FormatPath(MY.GetAddonInfo().szRoot .. '!src-dist/dat/' .. DAT_ROOT)
	local DST_ROOT = MY.FormatPath(MY.GetAddonInfo().szRoot .. DAT_ROOT)
	for _, szFile in ipairs(CPath.GetFileList(SRC_ROOT)) do
		MY.Sysmsg(_L['Encrypt and compressing: '] .. DAT_ROOT .. szFile)
		local data = LoadDataFromFile(SRC_ROOT .. szFile)
		if IsEncodedData(data) then
			data = DecodeData(data)
		end
		data = EncodeData(data, true, true)
		SaveDataToFile(data, DST_ROOT .. szFile, D.PASSPHRASE)
	end
	-- load embedded data
	local function LoadConfigData(szPath)
		local szPath = MY.GetAddonInfo().szRoot .. szPath
		return MY.LoadLUAData(szPath, { passphrase = D.PASSPHRASE }) or MY.LoadLUAData(szPath) or {}
	end
	-- load and format data
	local data = LoadConfigData('MY_Resource/data/focus/$lang.jx3dat') or {}
	for i, v in ipairs(data) do
		data[i] = FormatAutoFocusData(v)
	end
	D.EMBEDDED_FOCUS = data
end

-- 对象进入视野
function MY_Focus.OnObjectEnterScene(dwType, dwID, nRetryCount)
	if nRetryCount and nRetryCount > 5 then
		return
	end
	if not D.EMBEDDED_FOCUS then
		return MY.DelayCall(5000, function() MY_Focus.OnObjectEnterScene(dwType, dwID) end)
	end
	local me = GetClientPlayer()
	local KObject = MY.GetObject(dwType, dwID)
	if not KObject then
		return
	end

	local szName = MY.GetObjectName(KObject, 'never')
	-- 解决玩家刚进入视野时名字为空的问题
	if (dwType == TARGET.PLAYER and not szName) or not me then -- 解决自身刚进入场景的时候的问题
		MY.DelayCall(300, function()
			MY_Focus.OnObjectEnterScene(dwType, dwID, (nRetryCount or 0) + 1)
		end)
	else-- if szName then -- 判断是否需要焦点
		if not szName then
			szName = MY.GetObjectName(KObject, 'auto')
		end
		local bFocus, bDeletable = false, true
		local szVia, tRule = '', nil
		local dwMapID = me.GetMapID()
		local dwTemplateID, szTong = -1, ''
		if dwType == TARGET.PLAYER then
			if KObject.dwTongID ~= 0 then
				szTong = GetTongClient().ApplyGetTongName(KObject.dwTongID, 253)
				if not szTong or szTong == '' then -- 解决目标刚进入场景的时候帮会获取不到的问题
					MY.DelayCall(300, function()
						MY_Focus.OnObjectEnterScene(dwType, dwID, (nRetryCount or 0) + 1)
					end)
				end
			end
		else
			dwTemplateID = KObject.dwTemplateID
		end
		-- 判断临时焦点
		if l_tTempFocusList[dwType][dwID] then
			bFocus = true
			bDeletable = true
			szVia = _L['Temp focus']
		end
		-- 判断永久焦点
		if not bFocus then
			local dwTemplateID = dwType == TARGET.PLAYER and dwID or KObject.dwTemplateID
			if MY_Focus.tFocusList[dwType][dwTemplateID]
			and not (
				dwType == TARGET.NPC
				and dwTemplateID == CHANGGE_REAL_SHADOW_TPLID
				and IsEnemy(UI_GetClientPlayerID(), dwID)
				and MY.IsShieldedVersion()
			) then
				bFocus = true
				bDeletable = true
				szVia = _L['Static focus']
			end
		end
		-- 判断默认焦点
		if not bFocus and MY_Focus.bAutoFocus then
			tRule = D.GetEligibleRule(MY_Focus.tAutoFocus, dwMapID, dwType, dwID, dwTemplateID, szName, szTong)
			if tRule then
				bFocus = true
				bDeletable = false
				szVia = _L['Auto focus'] .. ' ' .. tRule.szPattern
			end
		end
		-- 判断内嵌默认焦点
		if not bFocus and MY_Focus.bEmbeddedFocus then
			tRule = D.GetEligibleRule(D.EMBEDDED_FOCUS, dwMapID, dwType, dwID, dwTemplateID, szName, szTong)
			if tRule then
				bFocus = true
				bDeletable = false
				szVia = _L['Embedded focus']
			end
		end

		-- 判断竞技场
		if not bFocus then
			if MY.IsInArena() or MY.IsInPubg() or MY.IsInZombieMap() then
				if dwType == TARGET.PLAYER then
					if MY_Focus.bFocusJJCEnemy and MY_Focus.bFocusJJCParty then
						bFocus = true
						bDeletable = false
						szVia = _L['JJC focus']
					elseif MY_Focus.bFocusJJCParty then
						if not IsEnemy(UI_GetClientPlayerID(), dwID) then
							bFocus = true
							bDeletable = false
							szVia = _L['JJC focus party']
						end
					elseif MY_Focus.bFocusJJCEnemy then
						if IsEnemy(UI_GetClientPlayerID(), dwID) then
							bFocus = true
							bDeletable = false
							szVia = _L['JJC focus enemy']
						end
					end
				elseif dwType == TARGET.NPC then
					if MY_Focus.bFocusJJCParty
					and KObject.dwTemplateID == CHANGGE_REAL_SHADOW_TPLID
					and not (IsEnemy(UI_GetClientPlayerID(), dwID) and MY.IsShieldedVersion()) then
						D.OnRemoveFocus(TARGET.PLAYER, KObject.dwEmployer)
						bFocus = true
						bDeletable = false
						szVia = _L['JJC focus party']
					end
				end
			else
				if not MY_Focus.bOnlyPublicMap or (not MY.IsInBattleField() and not MY.IsInDungeon() and not MY.IsInArena()) then
					-- 判断好友
					if dwType == TARGET.PLAYER
					and MY_Focus.bFocusFriend
					and MY.GetFriend(dwID) then
						bFocus = true
						bDeletable = false
						szVia = _L['Friend focus']
					end
					-- 判断同帮会
					if dwType == TARGET.PLAYER
					and MY_Focus.bFocusTong
					and dwID ~= MY.GetClientInfo().dwID
					and MY.GetTongMember(dwID) then
						bFocus = true
						bDeletable = false
						szVia = _L['Tong member focus']
					end
				end
				-- 判断敌对玩家
				if dwType == TARGET.PLAYER
				and MY_Focus.bFocusEnemy
				and IsEnemy(UI_GetClientPlayerID(), dwID) then
					bFocus = true
					bDeletable = false
					szVia = _L['Enemy focus']
				end
			end
		end

		-- 判断重要NPC
		if not bFocus and MY_Focus.bFocusINpc
		and dwType == TARGET.NPC
		and MY.IsImportantNpc(me.GetMapID(), KObject.dwTemplateID) then
			bFocus = true
			bDeletable = false
			szVia = _L['Important npc focus']
		end

		-- 判断小本本
		if not bFocus and MY_Focus.bFocusAnmerkungen
		and dwType == TARGET.PLAYER
		and MY_Anmerkungen.GetPlayerNote(dwID) then
			bFocus = true
			bDeletable = false
			szVia = _L['Anmerkungen']
		end

		-- 判断屏蔽的NPC
		if bFocus and dwType == TARGET.NPC and MY.IsShieldedNpc(dwTemplateID) and MY.IsShieldedVersion() then
			bFocus = false
			bDeletable = false
		end

		-- 加入焦点
		if bFocus then
			D.OnSetFocus(dwType, dwID, szName, bDeletable, szVia, tRule)
		end
	end
end

-- 对象离开视野
function MY_Focus.OnObjectLeaveScene(dwType, dwID)
	local KObject = MY.GetObject(dwType, dwID)
	if KObject then
		if dwType == TARGET.NPC then
			if MY_Focus.bFocusJJCParty
			and KObject.dwTemplateID == CHANGGE_REAL_SHADOW_TPLID
			and MY.IsInArena() and not (IsEnemy(UI_GetClientPlayerID(), dwID) and MY.IsShieldedVersion()) then
				D.OnSetFocus(TARGET.PLAYER, KObject.dwEmployer, MY.GetObjectName(KObject, 'never'), false, _L['JJC focus party'])
			end
		end
	end
	D.OnRemoveFocus(dwType, dwID)
end

-- 目标加入焦点列表
function D.OnSetFocus(dwType, dwID, szName, bDeletable, szVia, tRule)
	local nIndex
	for i, p in ipairs(FOCUS_LIST) do
		if p.dwType == dwType and p.dwID == dwID then
			nIndex = i
			break
		end
	end
	if not nIndex then
		table.insert(FOCUS_LIST, {
			dwType = dwType,
			dwID = dwID,
			szName = szName,
			szVia = szVia,
			tRule = tRule,
			bDeletable = bDeletable,
		})
		nIndex = #FOCUS_LIST
	end
	FireUIEvent('MY_FOCUS_UPDATE')
end

-- 目标移除焦点列表
function D.OnRemoveFocus(dwType, dwID)
	-- 从列表数据中删除
	for i = #FOCUS_LIST, 1, -1 do
		local p = FOCUS_LIST[i]
		if p.dwType == dwType and p.dwID == dwID then
			table.remove(FOCUS_LIST, i)
			break
		end
	end
	FireUIEvent('MY_FOCUS_UPDATE')
end

-- 排序
function MY_Focus.SortFocus(fn)
	local p = GetClientPlayer()
	fn = fn or function(p1, p2)
		p1 = MY.GetObject(p1.dwType, p1.dwID)
		p2 = MY.GetObject(p2.dwType, p2.dwID)
		if p1 and p2 then
			return pow(p.nX - p1.nX, 2) + pow(p.nY - p1.nY, 2) < pow(p.nX - p2.nX, 2) + pow(p.nY - p2.nY, 2)
		end
		return true
	end
	table.sort(FOCUS_LIST, fn)
end

-- 获取焦点列表
function MY_Focus.GetFocusList()
	local t = {}
	for _, v in ipairs(FOCUS_LIST) do
		table.insert(t, v)
	end
	return t
end

-- 获取当前显示的焦点列表
function MY_Focus.GetDisplayList()
	local t = {}
	local me = GetClientPlayer()
	if not MY_Focus.IsShielded() and me then
		for _, p in ipairs(FOCUS_LIST) do
			if #t >= MY_Focus.nMaxDisplay then
				break
			end
			local KObject, bFocus = MY.GetObject(p.dwType, p.dwID), true
			if not KObject then
				bFocus = false
			end
			if bFocus and MY_Focus.bHideDeath then
				if p.dwType == TARGET.NPC or p.dwType == TARGET.PLAYER then
					bFocus = KObject.nMoveState ~= MOVE_STATE.ON_DEATH
				else--if p.dwType == TARGET.DOODAD then
					bFocus = KObject.nKind ~= DOODAD_KIND.CORPSE
				end
			end
			if bFocus and p.tRule then
				if bFocus and p.tRule.tLife.bEnable
				and not MY.JudgeOperator(p.tRule.tLife.szOperator, KObject.nCurrentLife / KObject.nMaxLife * 100, p.tRule.tLife.nValue) then
					bFocus = false
				end
				if bFocus and p.tRule.nMaxDistance ~= 0
				and MY.GetDistance(me, KObject, MY_Focus.szDistanceType) > p.tRule.nMaxDistance then
					bFocus = false
				end
				if bFocus and not p.tRule.tRelation.bAll then
					if MY.IsEnemy(me.dwID, KObject.dwID) then
						bFocus = p.tRule.tRelation.bEnemy
					else
						bFocus = p.tRule.tRelation.bAlly
					end
				end
			end
			if bFocus then
				insert(t, p)
			end
		end
	end
	return t
end

function MY_Focus.GetTargetMenu(dwType, dwID)
	return {{
		szOption = _L['add to temp focus list'],
		fnAction = function()
			if not MY_Focus.bEnable then
				MY_Focus.bEnable = true
				MY_Focus.Open()
			end
			MY_Focus.SetFocusID(dwType, dwID)
		end,
	}, {
		szOption = _L['add to static focus list'],
		fnAction = function()
			if not MY_Focus.bEnable then
				MY_Focus.bEnable = true
				MY_Focus.Open()
			end
			MY_Focus.SetFocusID(dwType, dwID, true)
		end,
	}}
end

do
local function onInit()
	-- 密码生成
	local k = char(80, 65, 83, 83, 80, 72, 82, 65, 83, 69)
	if IsTable(D[k]) then
		for i = 0, 50 do
			for j, v in ipairs({ 23, 112, 234, 156 }) do
				insert(D[k], (i * j * ((31 * v) % 256)) % 256)
			end
		end
		D[k] = char(unpack(D[k]))
	end
	-- 用户自定义默认焦点
	if not MY_Focus.tAutoFocus then
		MY_Focus.tAutoFocus = {}
	end
	for i, v in ipairs(MY_Focus.tAutoFocus) do
		if IsString(v) then
			v = { szPattern = v }
		end
		MY_Focus.tAutoFocus[i] = FormatAutoFocusData(v)
	end
	-- 永久焦点
	if not MY_Focus.tFocusList then
		MY_Focus.tFocusList = {}
	end
	for _, dwType in ipairs({TARGET.PLAYER, TARGET.NPC, TARGET.DOODAD}) do
		if not MY_Focus.tFocusList[dwType] then
			MY_Focus.tFocusList[dwType] = {}
		end
	end
	-- 内嵌默认焦点
	D.LoadEmbeddedRule()
end
MY.RegisterInit('MY_Focus', onInit)
MY.RegisterEvent('CUSTOM_DATA_LOADED', onInit)
end

do
local function onMenu()
	local dwType, dwID = GetClientPlayer().GetTarget()
	return MY_Focus.GetTargetMenu(dwType, dwID)
end
MY.RegisterTargetAddonMenu('MY_Focus', onMenu)
end

do
local function onHotKey()
	local dwType, dwID = MY.GetTarget()
	local aList = MY_Focus.GetDisplayList()
	local t = aList[1]
	if not t then
		return
	end
	for i, p in ipairs(aList) do
		if p.dwType == dwType and p.dwID == dwID then
			t = aList[i + 1] or t
		end
	end
	MY.SetTarget(t.dwType, t.dwID)
end
MY.RegisterHotKey('MY_Focus_LoopTarget', _L['Loop target in focus'], onHotKey)
end

MY.RegisterTutorial({
	szKey = 'MY_Focus',
	szMessage = _L['Would you like to use MY focus?'],
	fnRequire = function() return not MY_Focus.bEnable end,
	{
		szOption = _L['Use'],
		bDefault = true,
		fnAction = function()
			MY_Focus.bEnable = true
			MY_Focus.Open()
			MY.RedrawTab('MY_Focus')
		end,
	},
	{
		szOption = _L['Not use'],
		fnAction = function()
			MY_Focus.bEnable = false
			MY_Focus.Close()
			MY.RedrawTab('MY_Focus')
		end,
	},
})
