--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 职业特色增强
-- @author   : 茗伊 @双梦镇 @追风蹑影
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
--------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
-------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local ipairs, pairs, next, pcall, select = ipairs, pairs, next, pcall, select
local byte, char, len, find, format = string.byte, string.char, string.len, string.find, string.format
local gmatch, gsub, dump, reverse = string.gmatch, string.gsub, string.dump, string.reverse
local match, rep, sub, upper, lower = string.match, string.rep, string.sub, string.upper, string.lower
local type, tonumber, tostring = type, tonumber, tostring
local HUGE, PI, random, randomseed = math.huge, math.pi, math.random, math.randomseed
local min, max, floor, ceil, abs = math.min, math.max, math.floor, math.ceil, math.abs
local mod, modf, pow, sqrt = math.mod or math.fmod, math.modf, math.pow, math.sqrt
local sin, cos, tan, atan, atan2 = math.sin, math.cos, math.tan, math.atan, math.atan2
local insert, remove, concat, sort = table.insert, table.remove, table.concat, table.sort
local pack, unpack = table.pack or function(...) return {...} end, table.unpack or unpack
-- jx3 apis caching
local wsub, wlen, wfind, wgsub = wstring.sub, wstring.len, StringFindW, StringReplaceW
local GetTime, GetLogicFrameCount, GetCurrentTime = GetTime, GetLogicFrameCount, GetCurrentTime
local GetClientTeam, UI_GetClientPlayerID = GetClientTeam, UI_GetClientPlayerID
local GetClientPlayer, GetPlayer, GetNpc, IsPlayer = GetClientPlayer, GetPlayer, GetNpc, IsPlayer
-- lib apis caching
local LIB = MY
local UI, DEBUG_LEVEL, PATH_TYPE, PACKET_INFO = LIB.UI, LIB.DEBUG_LEVEL, LIB.PATH_TYPE, LIB.PACKET_INFO
local wsub, count_c = LIB.wsub, LIB.count_c
local pairs_c, ipairs_c, ipairs_r = LIB.pairs_c, LIB.ipairs_c, LIB.ipairs_r
local spairs, spairs_r, sipairs, sipairs_r = LIB.spairs, LIB.spairs_r, LIB.sipairs, LIB.sipairs_r
local IsNil, IsEmpty, IsEquals, IsString = LIB.IsNil, LIB.IsEmpty, LIB.IsEquals, LIB.IsString
local IsBoolean, IsNumber, IsHugeNumber = LIB.IsBoolean, LIB.IsNumber, LIB.IsHugeNumber
local IsTable, IsArray, IsDictionary = LIB.IsTable, LIB.IsArray, LIB.IsDictionary
local IsFunction, IsUserdata, IsElement = LIB.IsFunction, LIB.IsUserdata, LIB.IsElement
local Call, XpCall, GetTraceback, RandomChild = LIB.Call, LIB.XpCall, LIB.GetTraceback, LIB.RandomChild
local Get, Set, Clone, GetPatch, ApplyPatch = LIB.Get, LIB.Set, LIB.Clone, LIB.GetPatch, LIB.ApplyPatch
local EncodeLUAData, DecodeLUAData, CONSTANT = LIB.EncodeLUAData, LIB.DecodeLUAData, LIB.CONSTANT
-------------------------------------------------------------------------------------------------------
local PLUGIN_NAME = 'MY_Toolbox'
local PLUGIN_ROOT = PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_Force'
local _L = LIB.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not LIB.AssertVersion(MODULE_NAME, _L[MODULE_NAME], 0x2013900) then
	return
end
--------------------------------------------------------------------------

local D = {}
local O = {
	-- 导出设置
	bAlertPet      = true , -- 五毒宠物消失提醒
	bMarkPet       = false, -- 五毒宠物标记
	bFeedHorse     = true , -- 提示喂马
	bWarningDebuff = false, -- 警告 debuff 类型
	nDebuffNum     = 3    , -- debuff 类型达到几个时警告
	bAlertWanted   = false, -- 在线被悬赏时提醒自己
	-- 本地变量
	nFrameXJ = 0, -- 献祭、各种召唤跟宠的帧数
}
RegisterCustomData('MY_Force.bAlertPet')
RegisterCustomData('MY_Force.bMarkPet')
RegisterCustomData('MY_Force.bFeedHorse')
RegisterCustomData('MY_Force.bWarningDebuff')
RegisterCustomData('MY_Force.nDebuffNum')
RegisterCustomData('MY_Force.bAlertWanted')

-- check pet of 5D （XJ：2226）
function D.OnAlertPetChange(_, bAlertPet)
	if bAlertPet then
		LIB.RegisterEvent('NPC_LEAVE_SCENE.MY_Force__AlertPet', function()
			local me = GetClientPlayer()
			if me then
				local pet = me.GetPet()
				if pet and pet.dwID == arg0 and (GetLogicFrameCount() - O.nFrameXJ) >= 32 then
					OutputWarningMessage('MSG_WARNING_YELLOW', _L('Your pet [%s] disappeared!',  pet.szName))
					PlaySound(SOUND.UI_SOUND, g_sound.CloseAuction)
				end
			end
		end)
		LIB.RegisterEvent('DO_SKILL_CAST.MY_Force__AlertPet', function()
			if arg0 == UI_GetClientPlayerID() then
				-- 献祭、各种召唤：2965，2221 ~ 2226
				if arg1 == 2965 or (arg1 >= 2221 and arg1 <= 2226) then
					O.nFrameXJ = GetLogicFrameCount()
				end
			end
		end)
	else
		LIB.RegisterEvent('NPC_LEAVE_SCENE.MY_Force__AlertPet', false)
		LIB.RegisterEvent('DO_SKILL_CAST.MY_Force__AlertPet', false)
	end
end

-- check to mark pet
do
local function UpdatePetMark(bMark)
	local me = GetClientPlayer()
	if not me then
		return
	end
	local pet = me.GetPet()
	if pet then
		local dwEffect = 13
		if not bMark then
			dwEffect = 0
		end
		SceneObject_SetTitleEffect(TARGET.NPC, pet.dwID, dwEffect)
	end
end
function D.OnMarkPetChange(_, bMarkPet)
	if bMarkPet then
		LIB.RegisterEvent({'NPC_ENTER_SCENE.MY_Force__MarkPet', 'NPC_DISPLAY_DATA_UPDATE.MY_Force__MarkPet'}, function()
			local pet = GetClientPlayer().GetPet()
			if pet and arg0 == pet.dwID then
				LIB.DelayCall(500, function()
					UpdatePetMark(true)
				end)
			else
				local npc = GetNpc(arg0)
				if npc.dwTemplateID == 46297 and npc.dwEmployer == UI_GetClientPlayerID() then
					SceneObject_SetTitleEffect(TARGET.NPC, npc.dwID, 13)
				end
			end
		end)
	else
		LIB.RegisterEvent({'NPC_ENTER_SCENE.MY_Force__MarkPet', 'NPC_DISPLAY_DATA_UPDATE.MY_Force__MarkPet'}, false)
	end
	UpdatePetMark(bMarkPet)
end
end

-- check feed horse
function D.OnFeedHorseChange(_, bFeedHorse)
	if bFeedHorse then
		LIB.RegisterEvent('SYS_MSG.MY_Force__FeedHorse', function()
			local me = GetClientPlayer()
			-- 读条技能
			if arg0 == 'UI_OME_SKILL_CAST_LOG' then
				-- on prepare 骑乘
				if O.bFeedHorse and arg1 == me.dwID and (arg2 == 433 or arg2 == 53 or Table_GetSkillName(arg2, 1) == Table_GetSkillName(53, 1)) then
					local it = me.GetItem(INVENTORY_INDEX.EQUIP, EQUIPMENT_INVENTORY.HORSE)
					if it then
						OutputItemTip(UI_OBJECT_ITEM, INVENTORY_INDEX.EQUIP, EQUIPMENT_INVENTORY.HORSE)
						local hM = Station.Lookup('Topmost1/TipPanel_Normal', 'Handle_Message')
						for i = 0, hM:GetItemCount() - 1, 1 do
							local hT = hM:Lookup(i)
							if hT:GetType() == 'Text' and hT:GetFontScheme() == 164 then
								local szFullMeasure = LIB.TrimString(hT:GetText())
								local tDisplay = g_tTable.RideSubDisplay:Search(it.nDetail)
								if tDisplay and szFullMeasure ~= tDisplay.szFullMeasure3 then
									OutputWarningMessage('MSG_WARNING_YELLOW', Table_GetItemName(it.nUiId) .. ': ' .. szFullMeasure)
									PlaySound(SOUND.UI_SOUND, g_sound.CloseAuction)
								end
								break
							end
						end
						HideTip(false)
					end
				end
			end
		end)
	else
		LIB.RegisterEvent('SYS_MSG.MY_Force__FeedHorse', false)
	end
end

-- check warning buff type
function D.OnWarningDebuffChange(_, bWarningDebuff)
	if bWarningDebuff then
		LIB.RegisterEvent('BUFF_UPDATE.MY_Force__WarningDebuff', function()
			-- buff update：
			-- arg0：dwPlayerID，arg1：bDelete，arg2：nIndex，arg3：bCanCancel
			-- arg4：dwBuffID，arg5：nStackNum，arg6：nEndFrame，arg7：？update all?
			-- arg8：nLevel，arg9：dwSkillSrcID
			local me = GetClientPlayer()
			if arg0 ~= me.dwID or not O.bWarningDebuff or (not arg7 and arg3) then
				return
			end
			local t, t2 = {}, {}
			local aBuff, nCount = LIB.GetBuffList(me)
			for i = 1, nCount do
				local buff = aBuff[i]
				if not buff.bCanCancel and not t2[buff.dwID] then
					local info = GetBuffInfo(buff.dwID, buff.nLevel, {})
					if info and info.nDetachType > 2 then
						if not t[info.nDetachType] then
							t[info.nDetachType] = 1
						else
							t[info.nDetachType] = t[info.nDetachType] + 1
						end
						t2[buff.dwID] = true
					end
				end
			end
			for nType, nNum in pairs(t) do
				if nNum >= O.nDebuffNum then
					local szText = _L('Your debuff of type [%s] reached [%d]', g_tStrings.tBuffDetachType[nType], nNum)
					OutputWarningMessage('MSG_WARNING_GREEN', szText)
					PlaySound(SOUND.UI_SOUND, g_sound.CloseAuction)
				end
			end
		end)
	else
		LIB.RegisterEvent('BUFF_UPDATE.MY_Force__WarningDebuff', false)
	end
end

-- check on wanted msg
do
local function OnMsgAnnounce(szMsg)
	local _, _, sM, sN = find(szMsg, _L['Now somebody pay (%d+) gold to buy life of (.-)'])
	if sM and sN == GetClientPlayer().szName then
		local fW = function()
			OutputWarningMessage('MSG_WARNING_RED', _L('Congratulations, you offered a reward [%s] gold!', sM))
			PlaySound(SOUND.UI_SOUND, g_sound.CloseAuction)
		end
		SceneObject_SetTitleEffect(TARGET.PLAYER, UI_GetClientPlayerID(), 47)
		fW()
		LIB.DelayCall(2000, fW)
		LIB.DelayCall(4000, fW)
		O.bHasWanted = true
	end
end
function D.OnAlertWantedChange(_, bAlertWanted)
	if bAlertWanted then
		-- 变化时更新头顶效果
		LIB.RegisterEvent('PLAYER_STATE_UPDATE.MY_Force__AlertWanted', function()
			if arg0 == UI_GetClientPlayerID() then
				if O.bHasWanted then
					SceneObject_SetTitleEffect(TARGET.PLAYER, arg0, 47)
				end
			end
		end)
		-- 重伤后删除头顶效果
		LIB.RegisterEvent('SYS_MSG.MY_Force__AlertWanted', function()
			if arg0 == 'UI_OME_DEATH_NOTIFY' then
				if O.bHasWanted and arg1 == UI_GetClientPlayerID() then
					O.bHasWanted = nil
					SceneObject_SetTitleEffect(TARGET.PLAYER, arg1, 0)
				end
			end
		end)
		RegisterMsgMonitor(OnMsgAnnounce, {'MSG_GM_ANNOUNCE'})
	else
		LIB.RegisterEvent('PLAYER_STATE_UPDATE.MY_Force__AlertWanted', false)
		LIB.RegisterEvent('SYS_MSG.MY_Force__AlertWanted', false)
		UnRegisterMsgMonitor(OnMsgAnnounce, {'MSG_GM_ANNOUNCE'})
	end
end
end

LIB.RegisterEvent('LOADING_END.MY_Force', function()
	local buff = Table_GetBuff(374, 1)
	if buff then
		buff.bShowTime = 1
	end
end)

-------------------------------------
-- 全局导出接口
-------------------------------------
do
local settings = {
	exports = {
		{
			fields = {
				bAlertPet      = true,
				bMarkPet       = true,
				bFeedHorse     = true,
				bWarningDebuff = true,
				nDebuffNum     = true,
				bAlertWanted   = true,
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				bAlertPet      = true,
				bMarkPet       = true,
				bFeedHorse     = true,
				bWarningDebuff = true,
				nDebuffNum     = true,
				bAlertWanted   = true,
			},
			triggers = {
				bAlertPet      = D.OnAlertPetChange,
				bMarkPet       = D.OnMarkPetChange,
				bFeedHorse     = D.OnFeedHorseChange,
				bWarningDebuff = D.OnWarningDebuffChange,
				bAlertWanted   = D.OnAlertWantedChange,
			},
			root = O,
		},
	},
}
MY_Force = LIB.GeneGlobalNS(settings)
end

-------------------------------------
-- 设置界面
-------------------------------------
local PS = {}
function PS.OnPanelActive(frame)
	local ui = UI(frame)
	local X, Y = 10, 10
	local x, y = X, Y
	local w, h = ui:Size()
	-- wu du
	---------------
	ui:Append('Text', { text = g_tStrings.tForceTitle[CONSTANT.FORCE_TYPE.WU_DU], x = x, y = y, font = 27 })
	-- crlf
	x = X + 10
	y = y + 28
	-- disappear
	x = ui:Append('WndCheckBox', {
		x = x, y = y,
		text = _L['Alert when pet disappear unexpectedly (for 5D)'],
		checked = MY_Force.bAlertPet,
		oncheck = function(bChecked)
			MY_Force.bAlertPet = bChecked
		end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	-- mark pet
	ui:Append('WndCheckBox', {
		x = x, y = y,
		text = _L['Mark pet'],
		checked = MY_Force.bMarkPet,
		oncheck = function(bChecked)
			MY_Force.bMarkPet = bChecked
		end,
	}):AutoWidth()
	-- crlf
	x = X + 10
	y = y + 28
	-- guding
	x = ui:Append('WndCheckBox', {
		x = x, y = y,
		text = _L['Display GUDING of teammate, change color'],
		checked = MY_ForceGuding.bEnable,
		oncheck = function(bChecked)
			MY_ForceGuding.bEnable = bChecked
		end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 2
	x = ui:Append('Shadow', {
		x = x, y = y + 2, w = 18, h = 18,
		color = MY_ForceGuding.color,
		onclick = function()
			local ui = UI(this)
			OpenColorTablePanel(function(r, g, b)
				ui:Color(r, g, b)
				MY_ForceGuding.color = { r, g, b }
			end)
		end,
	}):Pos('BOTTOMRIGHT') + 10
	ui:Append('WndCheckBox', {
		x = x, y = y,
		text = _L['Auto talk in team channel after puting GUDING'],
		checked = MY_ForceGuding.bAutoSay,
		autoenable = function() return MY_ForceGuding.bEnable end,
		oncheck = function(bChecked)
			MY_ForceGuding.bAutoSay = bChecked
		end,
	})
	x = X + 10
	y = y + 28
	ui:Append('WndEditBox', {
		x = x, y = y, w = w - x * 2, h = 50,
		multiline = true, limit = 512,
		text = MY_ForceGuding.szSay,
		autoenable = function() return MY_ForceGuding.bAutoSay end,
		onchange = function(szText)
			MY_ForceGuding.szSay = szText
		end,
	})
	-- crlf
	y = y + 54
	if not LIB.IsShieldedVersion('MY_ForceGuding') then
		-- crlf
		x = X + 10
		x = ui:Append('WndCheckBox', {
			x = x, y = y,
			checked = MY_ForceGuding.bUseMana,
			text = _L['Automatic eat GUDING when mana below '],
			oncheck = function(bChecked)
				MY_ForceGuding.bUseMana = bChecked
			end,
		}):AutoWidth():Pos('BOTTOMRIGHT') + 5
		x = ui:Append('WndTrackbar', {
			x = x, y = y, w = 70, h = 25,
			range = {0, 100, 50},
			value = MY_ForceGuding.nManaMp,
			onchange = function(nVal) MY_ForceGuding.nManaMp = nVal end,
			autoenable = function() return MY_ForceGuding.bUseMana end,
		}):Pos('BOTTOMRIGHT') + 65
		x = ui:Append('Text', {
			x = x, y = y - 3,
			text = _L[', or life below '],
		}):AutoWidth():Pos('BOTTOMRIGHT') + 5
		x = ui:Append('WndTrackbar', {
			x = x, y = y, w = 70, h = 25,
			range = {0, 100, 50},
			value = MY_ForceGuding.nManaHp,
			onchange = function(nVal) MY_ForceGuding.nManaHp = nVal end,
			autoenable = function() return MY_ForceGuding.bUseMana end,
		}):Pos('BOTTOMRIGHT')
		y = y + 36
	end
	-- other
	---------------
	x = X
	ui:Append('Text', { text = _L['Others'], x = x, y = y, font = 27 })
	-- crlf
	x = X + 10
	y = y + 28
	-- hungry
	x = ui:Append('WndCheckBox', {
		x = x, y = y,
		text = _L['Alert when horse is hungry'], checked = MY_Force.bFeedHorse,
		oncheck = function(bChecked)
			MY_Force.bFeedHorse = bChecked
		end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	-- crlf
	x = X + 10
	y = y + 28
	-- be wanted alert
	ui:Append('WndCheckBox', {
		x = x, y = y,
		text = _L['Alert when I am wanted publishing online'],
		checked = MY_Force.bAlertWanted,
		oncheck = function(bChecked)
			MY_Force.bAlertWanted = bChecked
		end,
	})
	-- crlf
	x = X + 10
	y = y + 28
	-- debuff type num
	x = ui:Append('WndCheckBox', {
		x = x, y = y,
		text = _L['Alert when my same type of debuff reached a certain number '],
		checked = MY_Force.bWarningDebuff,
		oncheck = function(bChecked)
			MY_Force.bWarningDebuff = bChecked
		end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	ui:Append('WndComboBox', {
		x = x, y = y, w = 50, h = 25,
		autoenable = function() return MY_Force.bWarningDebuff end,
		text = tostring(MY_Force.nDebuffNum),
		menu = function()
			local ui = UI(this)
			local m0 = {}
			for i = 1, 10 do
				insert(m0, {
					szOption = tostring(i),
					fnAction = function()
						MY_Force.nDebuffNum = i
						ui:Text(tostring(i))
					end,
				})
			end
			return m0
		end,
	})
end
LIB.RegisterPanel('MY_Force', _L['MY_Force'], _L['Target'], 327, PS)
