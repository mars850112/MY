--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 目标监控数值计算相关
-- @author   : 茗伊 @双梦镇 @追风蹑影
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
--------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
---------------------------------------------------------------------------------------------------
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
local spairs, spairs_r, sipairs, sipairs_r = MY.spairs, MY.spairs_r, MY.sipairs, MY.sipairs_r
local IsArray, IsDictionary, IsEquals = MY.IsArray, MY.IsDictionary, MY.IsEquals
local IsNil, IsBoolean, IsNumber, IsFunction = MY.IsNil, MY.IsBoolean, MY.IsNumber, MY.IsFunction
local IsEmpty, IsString, IsTable, IsUserdata = MY.IsEmpty, MY.IsString, MY.IsTable, MY.IsUserdata
local Get, GetPatch, ApplyPatch, RandomChild = MY.Get, MY.GetPatch, MY.ApplyPatch, MY.RandomChild
---------------------------------------------------------------------------------------------------

local _L = MY.LoadLangPack(MY.GetAddonInfo().szRoot .. 'MY_TargetMon/lang/')
if not MY.AssertVersion('MY_TargetMon', _L['MY_TargetMon'], 0x2011800) then
	return
end
local C, D = {}, {
	GetTargetTypeList = MY_TargetMonConfig.GetTargetTypeList,
	ModifyMonitor = MY_TargetMonConfig.ModifyMonitor,
	CreateMonitorId = MY_TargetMonConfig.CreateMonitorId,
	ModifyMonitorId = MY_TargetMonConfig.ModifyMonitorId,
	CreateMonitorLevel = MY_TargetMonConfig.CreateMonitorLevel,
	ModifyMonitorLevel = MY_TargetMonConfig.ModifyMonitorLevel,
}
local BUFF_CACHE = {} -- 下标为目标ID的目标BUFF缓存数组 反正ID不可能是doodad不会冲突
local BUFF_INFO = {} -- BUFF反向索引
local BUFF_TIME = {} -- BUFF最长持续时间
local SKILL_EXTRA = {} -- 缓存自己放过的技能用于扫描
local SKILL_CACHE = {} -- 下标为目标ID的目标技能缓存数组 反正ID不可能是doodad不会冲突
local SKILL_INFO = {} -- 技能反向索引
local VIEW_LIST = {}
local BOX_SPARKING_FRAME = GLOBAL.GAME_FPS * 2 / 3

do
local function FilterMonitors(monitors, dwMapID, dwKungfuID)
	local ret = {}
	for i, mon in ipairs(monitors) do
		if mon.enable
		and (not next(mon.maps) or mon.maps.all or mon.maps[dwMapID])
		and (not next(mon.kungfus) or mon.kungfus.all or mon.kungfus[dwKungfuID]) then
			insert(ret, mon)
		end
	end
	return ret
end
local CACHE_CONFIG
function D.GetConfig(nIndex)
	if not CACHE_CONFIG then
		local me = GetClientPlayer()
		if not me then
			return MY_TargetMonConfig.GetConfig(nIndex)
		end
		local aConfig = {}
		local dwMapID = me.GetMapID() or 0
		local dwKungfuID = me.GetKungfuMountID() or 0
		for i, config in ipairs(MY_TargetMonConfig.GetConfig()) do
			aConfig[i] = setmetatable({
				monitors = FilterMonitors(config.monitors, dwMapID, dwKungfuID),
			}, { __index = config })
		end
		CACHE_CONFIG = aConfig
	end
	if nIndex then
		return CACHE_CONFIG[nIndex]
	end
	return CACHE_CONFIG
end

local function onFilterChange()
	CACHE_CONFIG = nil
end
MY.RegisterEvent('LOADING_END.MY_TargetMonData', onFilterChange)
MY.RegisterEvent('SKILL_MOUNT_KUNG_FU.MY_TargetMonData', onFilterChange)
MY.RegisterEvent('SKILL_UNMOUNT_KUNG_FU.MY_TargetMonData', onFilterChange)
MY.RegisterEvent('MY_TARGET_MON_MONITOR_CHANGE.MY_TargetMonData', onFilterChange)

local function onTargetMonReload()
	onFilterChange()
	D.OnTargetMonReload()
end
MY.RegisterEvent('MY_TARGET_MON_CONFIG_INIT.MY_TargetMonData', onTargetMonReload)
end

do
local TEAM_MARK = {
	['TEAM_MARK_CLOUD'] = 1,
	['TEAM_MARK_SWORD'] = 2,
	['TEAM_MARK_AX'   ] = 3,
	['TEAM_MARK_HOOK' ] = 4,
	['TEAM_MARK_DRUM' ] = 5,
	['TEAM_MARK_SHEAR'] = 6,
	['TEAM_MARK_STICK'] = 7,
	['TEAM_MARK_JADE' ] = 8,
	['TEAM_MARK_DART' ] = 9,
	['TEAM_MARK_FAN'  ] = 10,
}
function D.GetTarget(eTarType, eMonType)
	if eMonType == 'SKILL' or eTarType == 'CONTROL_PLAYER' then
		return TARGET.PLAYER, GetControlPlayerID()
	elseif eTarType == 'CLIENT_PLAYER' then
		return TARGET.PLAYER, UI_GetClientPlayerID()
	elseif eTarType == 'TARGET' then
		return MY.GetTarget()
	elseif eTarType == 'TTARGET' then
		local KTarget = MY.GetObject(MY.GetTarget())
		if KTarget then
			return MY.GetTarget(KTarget)
		end
	elseif TEAM_MARK[eTarType] then
		local mark = GetClientTeam().GetTeamMark()
		if mark then
			for dwID, nMark in pairs(mark) do
				if TEAM_MARK[eTarType] == nMark then
					return TARGET[IsPlayer(dwID) and 'PLAYER' or 'NPC'], dwID
				end
			end
		end
	end
	return TARGET.NO_TARGET, 0
end
end

do
local EVENT_UPDATE = {}
function D.RegisterDataUpdateEvent(frame, fnAction)
	if fnAction then
		EVENT_UPDATE[frame] = fnAction
	else
		EVENT_UPDATE[frame] = nil
	end
end

function D.FireDataUpdateEvent()
	for frame, fnAction in pairs(EVENT_UPDATE) do
		fnAction(frame)
	end
end
end

do
local SHIELDED
function D.IsShielded()
	if SHIELDED == nil then
		SHIELDED = MY.IsShieldedVersion() and MY.IsInArena()
	end
	return SHIELDED
end

local function onShieldedReset()
	SHIELDED = nil
end
MY.RegisterEvent('LOADING_END.MY_TargetMonData_Shield', onShieldedReset)
MY.RegisterEvent('MY_SHIELDED_VERSION.MY_TargetMonData_Shield', onShieldedReset)
end

do
local ALIAS
function D.IsShieldedAlias(szAlias)
	if D.IsShielded() then
		if not ALIAS then
			ALIAS = MY.ArrayToObject(_L.ALIAS)
		end
		return not ALIAS[szAlias]
	end
	return false
end
end

do
local SHIELDED_BUFF = {}
function D.IsShieldedBuff(dwID, nLevel)
	if D.IsShielded() then
		local szKey = dwID .. ',' .. nLevel
		if SHIELDED_BUFF[szKey] == nil then
			local info = Table_GetBuff(dwID, nLevel)
			SHIELDED_BUFF[szKey] = not info or info.bShow == 0
		end
		return SHIELDED_BUFF[szKey]
	end
	return false
end
end

do
local function OnSkill(dwID, nLevel)
	SKILL_EXTRA[dwID] = dwID
end
local function OnSysMsg(event)
	if arg0 == 'UI_OME_SKILL_CAST_LOG' then
		if arg1 ~= UI_GetClientPlayerID() then
			return
		end
		OnSkill(arg2, arg3)
	elseif arg0 == 'UI_OME_SKILL_HIT_LOG' then
		if arg1 ~= UI_GetClientPlayerID() then
			return
		end
		OnSkill(arg4, arg5)
	elseif arg0 == 'UI_OME_SKILL_EFFECT_LOG' then
		if arg4 ~= SKILL_EFFECT_TYPE.SKILL or arg1 ~= UI_GetClientPlayerID() then
			return
		end
		OnSkill(arg5, arg6)
	end
end
MY.RegisterEvent('SYS_MSG.MY_TargetMon_SKILL', OnSysMsg)
end

-- 更新BUFF数据 更新监控条
do
local EXTENT_ANIMATE = {
	['[0.7,0.9)'] = 'ui\\Image\\Common\\Box.UITex|17',
	['[0.9,1]'] = 'ui\\Image\\Common\\Box.UITex|20',
	NONE = '',
}
local MON_EXIST_CACHE = {}
local function Base_ShowMon(mon, dwTarKungfuID)
	if next(mon.tarkungfus) and not mon.tarkungfus.all and not mon.tarkungfus[dwTarKungfuID] then
		return
	end
	return true
end
local function Base_MonToView(mon, info, item, KObject, nIcon, config, tMonExist, tMonLast)
	-- 格式化完善视图列表信息
	if config.showTime and item.bCd and item.nTimeLeft and item.nTimeLeft > 0 then
		local nTimeLeft, szTimeLeft = item.nTimeLeft, ''
		if nTimeLeft <= 3600 then
			if nTimeLeft > 60 then
				if config.decimalTime == -1 or nTimeLeft < config.decimalTime then
					szTimeLeft = '%d\'%.1f'
				else
					szTimeLeft = '%d\'%d'
				end
				szTimeLeft = szTimeLeft:format(floor(nTimeLeft / 60), nTimeLeft % 60)
			else
				if config.decimalTime == -1 or nTimeLeft < config.decimalTime then
					szTimeLeft = '%.1f'
				else
					szTimeLeft = '%d'
				end
				szTimeLeft = szTimeLeft:format(nTimeLeft)
			end
		end
		item.szTimeLeft = szTimeLeft
	else
		item.szTimeLeft = ''
	end
	if not config.showName then
		item.szLongName = ''
		item.szShortName = ''
	end
	if not item.nIcon then
		item.nIcon = 13
	end
	if config.cdFlash and item.bCd then
		if item.fProgress >= 0.9 then
			item.szExtentAnimate = EXTENT_ANIMATE['[0.9,1]']
		elseif item.fProgress >= 0.7 then
			item.szExtentAnimate = EXTENT_ANIMATE['[0.7,0.9)']
		else
			item.szExtentAnimate = EXTENT_ANIMATE.NONE
		end
		item.bStaring = item.fProgress > 0.5
	else
		item.bStaring = false
		item.szExtentAnimate = EXTENT_ANIMATE.NONE
	end
	if item.szExtentAnimate == EXTENT_ANIMATE.NONE and item.bActive and mon.extentAnimate then
		item.szExtentAnimate = mon.extentAnimate
	end
	if not config.cdCircle then
		item.bCd = false
	end
	if info and info.bCool then
		if tMonLast and not tMonLast[mon.uuid] and config.playSound then
			local dwSoundID = RandomChild(mon.soundAppear)
			if dwSoundID then
				local szSoundPath = MY.GetSoundPath(dwSoundID)
				if szSoundPath then
					MY.PlaySound(SOUND.UI_SOUND, szSoundPath, '')
				end
			end
		end
		tMonExist[mon.uuid] = mon
	end
end
local function Buff_CaptureMon(mon)
	for _, buff in spairs(BUFF_INFO[mon.name]) do
		if not mon.iconid then
			D.ModifyMonitor(mon, 'iconid', buff.nIcon)
		end
		local tMonId = mon.ids[buff.dwID]
		if not tMonId then
			tMonId = D.CreateMonitorId(mon, buff.dwID)
		end
		if not tMonId.iconid then
			D.ModifyMonitorId(tMonId, 'iconid', buff.nIcon)
		end
		local tMonLevel = tMonId.levels[buff.nLevel]
		if not tMonLevel then
			tMonLevel = D.CreateMonitorLevel(tMonId, buff.nLevel)
		end
		if not tMonLevel.iconid then
			D.ModifyMonitorLevel(tMonLevel, 'iconid', buff.nIcon)
		end
	end
end
local function Buff_ShowMon(mon, dwTarKungfuID)
	return Base_ShowMon(mon, dwTarKungfuID)
end
local function Buff_MatchMon(tBuff, mon, config)
	-- ids={[13942]={enable=true,iconid=7237,ignoreLevel=false,levels={[2]={enable=true,iconid=7237}}}}
	for dwID, tMonId in pairs(mon.ids) do
		if tMonId.enable or mon.ignoreId then
			local tInfo = tBuff[dwID]
			if tInfo then
				for _, info in pairs(tInfo) do
					if info and info.bCool then
						if (
							config.hideOthers == mon.rHideOthers
							or info.dwSkillSrcID == UI_GetClientPlayerID()
							or info.dwSkillSrcID == GetControlPlayerID()
						) and (not D.IsShieldedBuff(dwID, info.nLevel)) then
							local tMonLevel = tMonId.levels[info.nLevel] or EMPTY_TABLE
							if tMonLevel.enable or tMonId.ignoreLevel then
								return info, tMonLevel.iconid or tMonId.iconid or mon.iconid or info.nIcon or 13
							end
						end
					end
				end
			end
		end
	end
	return nil, mon.iconid
end
local function Buff_MonToView(mon, buff, item, KObject, nIcon, config, tMonExist, tMonLast)
	if nIcon then
		item.nIcon = nIcon
	end
	if buff and buff.bCool then
		if not item.nIcon then
			item.nIcon = buff.nIcon
		end
		local nTimeLeft = buff.nLeft * 0.0625
		if not BUFF_TIME[KObject.dwID] then
			BUFF_TIME[KObject.dwID] = {}
		end
		if not BUFF_TIME[KObject.dwID][buff.szKey] or BUFF_TIME[KObject.dwID][buff.szKey] < nTimeLeft then
			BUFF_TIME[KObject.dwID][buff.szKey] = nTimeLeft
		end
		local nTimeTotal = BUFF_TIME[KObject.dwID][buff.szKey]
		item.bActive = true
		item.bCd = true
		item.fCd = nTimeLeft / nTimeTotal
		item.fCdBar = item.fCd
		item.fProgress = 1 - item.fCd
		item.bSparking = false
		item.dwID = buff.dwID
		item.nLevel = buff.nLevel
		item.nTimeLeft = nTimeLeft
		item.szStackNum = buff.nStackNum > 1 and buff.nStackNum or ''
		item.nTimeTotal = nTimeTotal
		if mon.longAlias and not D.IsShieldedAlias(mon.longAlias) then
			item.szLongName = mon.longAlias
		elseif mon.nameAlias and not D.IsShieldedAlias(mon.nameAlias) then
			item.szLongName = mon.name
		else
			item.szLongName = buff.szName
		end
		if mon.shortAlias and not D.IsShieldedAlias(mon.shortAlias) then
			item.szShortName = mon.shortAlias
		elseif mon.nameAlias and not D.IsShieldedAlias(mon.nameAlias) then
			item.szShortName = mon.name
		else
			item.szShortName = buff.szName
		end
	else
		item.bActive = false
		item.bCd = true
		item.fCd = 0
		item.fCdBar = 0
		item.fProgress = 0
		item.nTimeLeft = -1
		item.bSparking = true
		item.dwID = next(mon.ids) or -1
		item.nLevel = item.dwID and mon.ids[item.dwID] and next(mon.ids[item.dwID].levels) or -1
		item.szStackNum = ''
		item.szLongName = mon.longAlias or mon.name
		item.szShortName = mon.shortAlias or mon.name
	end
	item.aLongAliasRGB = mon.rgbLongAlias
	item.aShortAliasRGB = mon.rgbShortAlias
	Base_MonToView(mon, buff, item, KObject, nIcon, config, tMonExist, tMonLast)
end
local function Skill_CaptureMon(mon)
	for _, skill in spairs(SKILL_INFO[mon.name]) do
		if not mon.iconid then
			D.ModifyMonitor(mon, 'iconid', skill.nIcon)
		end
		local tMonId = mon.ids[skill.dwID]
		if not tMonId then
			tMonId = D.CreateMonitorId(mon, skill.dwID)
		end
		if not tMonId.iconid then
			D.ModifyMonitorId(tMonId, 'iconid', skill.nIcon)
		end
		local tMonLevel = tMonId.levels[skill.nLevel]
		if not tMonLevel then
			tMonLevel = D.CreateMonitorLevel(tMonId, skill.nLevel)
		end
		if not tMonLevel.iconid then
			D.ModifyMonitorLevel(tMonLevel, 'iconid', skill.nIcon)
		end
	end
end
local function Skill_ShowMon(mon, dwTarKungfuID)
	return Base_ShowMon(mon, dwTarKungfuID)
end
local function Skill_MatchMon(tSkill, mon, config)
	for dwID, tMonId in pairs(mon.ids) do
		if tMonId.enable or mon.ignoreId then
			local skill = tSkill[dwID]
			if skill and skill.bCool then
				-- if Base_MatchMon(mon) then
					local tMonLevel = tMonId.levels[skill.nLevel] or EMPTY_TABLE
					if tMonLevel.enable or tMonId.ignoreLevel then
						return skill, tMonLevel.iconid or tMonId.iconid or mon.iconid or skill.nIcon or 13
					end
				-- end
			end
		end
	end
	return nil, mon.iconid
end
local function Skill_MonToView(mon, skill, item, KObject, nIcon, config, tMonExist, tMonLast)
	if nIcon then
		item.nIcon = nIcon
	end
	if skill and skill.bCool then
		if not item.nIcon then
			item.nIcon = skill.nIcon
		end
		local nTimeLeft = skill.nCdLeft * 0.0625
		local nTimeTotal = skill.nCdTotal * 0.0625
		local nStackNum = skill.nCdMaxCount - skill.nCdCount
		item.bActive = false
		item.bCd = true
		item.fCd = 1 - nTimeLeft / nTimeTotal
		item.fCdBar = item.fCd
		item.fProgress = item.fCd
		item.bSparking = false
		item.dwID = skill.dwID
		item.nLevel = skill.nLevel
		item.nTimeLeft = nTimeLeft
		item.szStackNum = nStackNum > 0 and nStackNum or ''
		item.nTimeTotal = nTimeTotal
		item.szLongName = mon.longAlias or skill.szName
		item.szShortName = mon.shortAlias or skill.szName
	else
		item.bActive = true
		item.bCd = false
		item.fCd = 1
		item.fCdBar = 1
		item.fProgress = 0
		item.bSparking = true
		item.dwID = next(mon.ids) or -1
		item.nLevel = item.dwID and mon.ids[item.dwID] and next(mon.ids[item.dwID].levels) or -1
		item.szStackNum = ''
		item.szLongName = mon.longAlias or mon.name
		item.szShortName = mon.shortAlias or mon.name
	end
	item.aLongAliasRGB = mon.rgbLongAlias
	item.aShortAliasRGB = mon.rgbShortAlias
	Base_MonToView(mon, skill, item, KObject, nIcon, config, tMonExist, tMonLast)
end
local function UpdateView()
	local me = GetClientPlayer()
	local nViewIndex, nViewCount = 1, #VIEW_LIST
	for _, config in ipairs(D.GetConfig()) do
		if config.enable then
			local dwTarType, dwTarID = D.GetTarget(config.target, config.type)
			local KObject = MY.GetObject(dwTarType, dwTarID)
			local dwTarKungfuID = KObject and dwTarType == TARGET.PLAYER and KObject.GetKungfuMountID() or 0
			local view = VIEW_LIST[nViewIndex]
			if not view then
				view = {}
				VIEW_LIST[nViewIndex] = view
			end
			view.szUuid               = config.uuid
			view.szType               = config.type
			view.szTarget             = config.target
			view.szCaption            = config.caption
			view.tAnchor              = config.anchor
			view.bIgnoreSystemUIScale = config.ignoreSystemUIScale
			view.fUIScale             = (config.ignoreSystemUIScale and 1 or Station.GetUIScale()) * config.scale
			view.fFontScale           = (config.ignoreSystemUIScale and 1 or Station.GetUIScale()) * MY.GetFontScale() * config.scale * config.fontScale
			view.bPenetrable          = config.penetrable
			view.bDragable            = config.dragable
			view.szAlignment          = config.alignment
			view.nMaxLineCount        = config.maxLineCount
			view.bCdCircle            = config.cdCircle
			view.bCdFlash             = config.cdFlash
			view.bCdReadySpark        = config.cdReadySpark
			view.bCdBar               = config.cdBar
			view.nCdBarWidth          = config.cdBarWidth
			-- view.playSound         = config.playSound
			view.szCdBarUITex         = config.cdBarUITex
			view.szBoxBgUITex         = config.boxBgUITex
			local aItem = view.aItem
			if not aItem then
				aItem = {}
				view.aItem = aItem
			end
			local nItemIndex, nItemCount = 1, #aItem
			local tMonExist, tMonLast = {}, MON_EXIST_CACHE[config.uuid]
			if config.type == 'BUFF' then
				local tBuff = KObject and BUFF_CACHE[KObject.dwID] or EMPTY_TABLE
				for _, mon in ipairs(config.monitors) do
					if Buff_ShowMon(mon, dwTarKungfuID) then
						-- 如果开启了捕获 从BUFF索引中捕获新的BUFF
						if mon.capture then
							Buff_CaptureMon(mon)
						end
						-- 通过监控项生成视图列表
						local buff, nIcon = Buff_MatchMon(tBuff, mon, config)
						if buff or config.hideVoid == mon.rHideVoid then
							local item = aItem[nItemIndex]
							if not item then
								item = {}
								aItem[nItemIndex] = item
							end
							Buff_MonToView(mon, buff, item, KObject, nIcon, config, tMonExist, tMonLast)
							nItemIndex = nItemIndex + 1
						end
					end
				end
			elseif config.type == 'SKILL' then
				local tSkill = KObject and SKILL_CACHE[KObject.dwID] or EMPTY_TABLE
				for _, mon in ipairs(config.monitors) do
					if Skill_ShowMon(mon, dwTarKungfuID) then
						-- 如果开启了捕获 从BUFF索引中捕获新的BUFF
						if mon.capture then
							Skill_CaptureMon(mon)
						end
						-- 通过监控项生成视图列表
						local skill, nIcon = Skill_MatchMon(tSkill, mon, config)
						if skill or config.hideVoid == mon.rHideVoid then
							local item = aItem[nItemIndex]
							if not item then
								item = {}
								aItem[nItemIndex] = item
							end
							Skill_MonToView(mon, skill, item, KObject, nIcon, config, tMonExist, tMonLast)
							nItemIndex = nItemIndex + 1
						end
					end
				end
			end
			for i = nItemIndex, nItemCount do
				aItem[i] = nil
			end
			if tMonLast then
				for uuid, mon in pairs(tMonLast) do
					if not tMonExist[uuid] and config.playSound then
						local dwSoundID = RandomChild(mon.soundDisappear)
						if dwSoundID then
							local szSoundPath = MY.GetSoundPath(dwSoundID)
							if szSoundPath then
								MY.PlaySound(SOUND.UI_SOUND, szSoundPath, '')
							end
						end
					end
				end
			end
			MON_EXIST_CACHE[config.uuid] = tMonExist
			nViewIndex = nViewIndex + 1
		end
	end
	for i = nViewIndex, nViewCount do
		VIEW_LIST[i] = nil
	end
	D.FireDataUpdateEvent()
end

local function OnBreathe()
	-- 更新各目标BUFF数据
	local nLogicFrame = GetLogicFrameCount()
	for _, eType in ipairs(D.GetTargetTypeList('BUFF')) do
		local KObject = MY.GetObject(D.GetTarget(eType, 'BUFF'))
		if KObject then
			local tCache = BUFF_CACHE[KObject.dwID]
			if not tCache then
				tCache = {}
				BUFF_CACHE[KObject.dwID] = tCache
			end
			-- 当前身上的buff
			local aBuff, info = MY.GetBuffList(KObject)
			for _, buff in ipairs(aBuff) do -- 缓存时必须复制buff表 否则buff过期后表会被回收导致显示错误的BUFF
				-- 正向索引用于监控
				if not tCache[buff.dwID] then
					tCache[buff.dwID] = {}
				end
				info = tCache[buff.dwID][buff.szKey]
				if not info then
					info = {}
					tCache[buff.dwID][buff.szKey] = info
				end
				MY.CloneBuff(buff, info)
				info.nLeft = max(buff.nEndFrame - nLogicFrame, 0)
				info.bCool = true
				info.nRenderFrame = nLogicFrame
				-- 反向索引用于捕获
				if not BUFF_INFO[buff.szName] then
					BUFF_INFO[buff.szName] = {}
				end
				if not BUFF_INFO[buff.szName][buff.szKey] then
					BUFF_INFO[buff.szName][buff.szKey] = {
						szName = buff.szName,
						dwID = buff.dwID,
						nLevel = buff.nLevel,
						szKey = buff.szKey,
						nIcon = buff.nIcon,
					}
				end
			end
			-- 处理消失的buff
			for _, tBuff in pairs(tCache) do
				for k, info in pairs(tBuff) do
					if info.nRenderFrame ~= nLogicFrame then
						if info.bCool then
							info.nLeft = 0
							info.bCool = false
						end
						info.nRenderFrame = nLogicFrame
					end
				end
			end
		end
	end
	for _, eType in ipairs(D.GetTargetTypeList('SKILL')) do
		local KObject = MY.GetObject(D.GetTarget(eType, 'SKILL'))
		if KObject then
			local tSkill = {}
			local aSkill = MY.GetSkillMountList()
			-- 遍历所有技能 生成反向索引
			for _, dwID in spairs(aSkill, SKILL_EXTRA) do
				if not tSkill[dwID] then
					local nLevel = KObject.GetSkillLevel(dwID)
					local KSkill, info = MY.GetSkill(dwID, nLevel)
					if KSkill and info then
						local szKey, szName = dwID, MY.GetSkillName(dwID)
						if not SKILL_INFO[szName] then
							SKILL_INFO[szName] = {}
						end
						if not SKILL_INFO[szName][szKey] then
							SKILL_INFO[szName][szKey] = {}
						end
						local skill = SKILL_INFO[szName][szKey]
						local bCool, szType, nLeft, nInterval, nTotal, nCount, nMaxCount, nSurfaceNum = MY.GetSkillCDProgress(KObject, dwID, nLevel, true)
						skill.szKey = szKey
						skill.dwID = dwID
						skill.nLevel = info.nLevel
						skill.bCool = bCool or nCount > 0
						skill.szCdType = szType
						skill.nCdLeft = nLeft
						skill.nCdInterval = nInterval
						skill.nCdTotal = nTotal
						skill.nCdCount = nCount
						skill.nCdMaxCount = nMaxCount
						skill.nSurfaceNum = nSurfaceNum
						skill.nIcon = info.nIcon
						skill.szName = MY.GetSkillName(dwID)
						tSkill[szKey] = skill
						tSkill[dwID] = skill
						tSkill[szName] = skill
					end
				end
			end
			-- 处理消失的buff
			local tLastSkill = SKILL_CACHE[KObject.dwID]
			if tLastSkill then
				for k, skill in pairs(tLastSkill) do
					if not tSkill[k] then
						if skill.bCool then
							skill.bCool = false
							skill.nLeft = 0
							skill.nCount = 0
						end
						tSkill[k] = skill
					end
				end
			end
			SKILL_CACHE[KObject.dwID] = tSkill
		end
	end
	UpdateView()
end

function D.OnTargetMonReload()
	OnBreathe()
	FireUIEvent('MY_TARGET_MON_DATA_INIT')
	MY.BreatheCall('MY_TargetMonData', OnBreathe)
end
end

function D.GetViewData(nIndex)
	if nIndex then
		return VIEW_LIST[nIndex]
	end
	return VIEW_LIST
end

----------------------------------------------------------------------------------------------
-- 快捷键
----------------------------------------------------------------------------------------------
do
for i = 1, 5 do
	for j = 1, 10 do
		Hotkey.AddBinding(
			'MY_TargetMon_' .. i .. '_' .. j, _L('Cancel buff %d - %d', i, j),
			i == 1 and j == 1 and _L['MY Buff Monitor'] or '',
			function()
				if MY.IsShieldedVersion() and not MY.IsInDungeon() then
					OutputMessage('MSG_ANNOUNCE_RED', _L['Cancel buff is disabled outside dungeon.'])
					return
				end
				local tViewData = D.GetViewData(i)
				if not tViewData or tViewData.szType ~= 'BUFF' then
					OutputMessage('MSG_ANNOUNCE_RED', _L['Hotkey cancel is only allowed for buff.'])
					return
				end
				local KTarget = MY.GetObject(D.GetTarget(tViewData.szTarget, tViewData.szType))
				if not KTarget then
					OutputMessage('MSG_ANNOUNCE_RED', _L['Cannot find target to cancel buff.'])
					return
				end
				local item = tViewData.aItem[j]
				if not item or not item.bActive then
					OutputMessage('MSG_ANNOUNCE_RED', _L['Cannot find buff to cancel.'])
					return
				end
				MY.CancelBuff(KTarget, item.dwID, item.nLevel)
			end, nil)
	end
end
end

-- Global exports
do
local settings = {
	exports = {
		{
			fields = {
				GetTarget = D.GetTarget,
				GetViewData = D.GetViewData,
				RegisterDataUpdateEvent = D.RegisterDataUpdateEvent,
			},
		},
	},
}
MY_TargetMonData = MY.GeneGlobalNS(settings)
end
