--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 焦点列表
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
local mod, modf, pow, sqrt = math['mod'] or math['fmod'], math.modf, math.pow, math.sqrt
local sin, cos, tan, atan, atan2 = math.sin, math.cos, math.tan, math.atan, math.atan2
local insert, remove, concat = table.insert, table.remove, table.concat
local pack, unpack = table['pack'] or function(...) return {...} end, table['unpack'] or unpack
local sort, getn = table.sort, table['getn'] or function(t) return #t end
-- jx3 apis caching
local wlen, wfind, wgsub, wlower = wstring.len, StringFindW, StringReplaceW, StringLowerW
local GetTime, GetLogicFrameCount, GetCurrentTime = GetTime, GetLogicFrameCount, GetCurrentTime
local GetClientTeam, UI_GetClientPlayerID = GetClientTeam, UI_GetClientPlayerID
local GetClientPlayer, GetPlayer, GetNpc, IsPlayer = GetClientPlayer, GetPlayer, GetNpc, IsPlayer
-- lib apis caching
local LIB = MY
local UI, GLOBAL, CONSTANT = LIB.UI, LIB.GLOBAL, LIB.CONSTANT
local PACKET_INFO, DEBUG_LEVEL, PATH_TYPE = LIB.PACKET_INFO, LIB.DEBUG_LEVEL, LIB.PATH_TYPE
local wsub, count_c, lodash = LIB.wsub, LIB.count_c, LIB.lodash
local pairs_c, ipairs_c, ipairs_r = LIB.pairs_c, LIB.ipairs_c, LIB.ipairs_r
local spairs, spairs_r, sipairs, sipairs_r = LIB.spairs, LIB.spairs_r, LIB.sipairs, LIB.sipairs_r
local IsNil, IsEmpty, IsEquals, IsString = LIB.IsNil, LIB.IsEmpty, LIB.IsEquals, LIB.IsString
local IsBoolean, IsNumber, IsHugeNumber = LIB.IsBoolean, LIB.IsNumber, LIB.IsHugeNumber
local IsTable, IsArray, IsDictionary = LIB.IsTable, LIB.IsArray, LIB.IsDictionary
local IsFunction, IsUserdata, IsElement = LIB.IsFunction, LIB.IsUserdata, LIB.IsElement
local EncodeLUAData, DecodeLUAData = LIB.EncodeLUAData, LIB.DecodeLUAData
local GetTraceback, RandomChild, GetGameAPI = LIB.GetTraceback, LIB.RandomChild, LIB.GetGameAPI
local Get, Set, Clone, GetPatch, ApplyPatch = LIB.Get, LIB.Set, LIB.Clone, LIB.GetPatch, LIB.ApplyPatch
local Call, XpCall, SafeCall, NSFormatString = LIB.Call, LIB.XpCall, LIB.SafeCall, LIB.NSFormatString
-------------------------------------------------------------------------------------------------------
local PLUGIN_NAME = 'MY_Focus'
local PLUGIN_ROOT = PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_Focus'
local _L = LIB.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not LIB.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^4.0.0') then
	return
end
--------------------------------------------------------------------------

local PS = {}
function PS.OnPanelActive(wnd)
	local ui = UI(wnd)
	local w  = ui:Width()
	local h  = max(ui:Height(), 440)
	local xr, yr, wr = w - 260, 5, 260
	local xl, yl, wl = 5,  5, w - wr -15

	-- 左侧
	local x, y = xl, yl
	x = x + ui:Append('WndCheckBox', {
		x = x, y = y, w = 250, text = _L['Enable'],
		r = 255, g = 255, b = 0, checked = MY_Focus.bEnable,
		oncheck = function(bChecked)
			MY_Focus.bEnable = bChecked
		end,
		tip = function()
			if MY_Focus.IsShielded() then
				return _L['Can not use in shielded map!']
			end
		end,
		autoenable = function() return not MY_Focus.IsShielded() end,
	}):AutoWidth():Width() + 10

	ui:Append('WndEditBox', {
		x = x, y = y, w = wl - x, h = 25,
		placeholder = _L['Style'],
		text = MY_Focus.szStyle,
		onblur = function()
			local szStyle = UI(this):Text():gsub('%s', '')
			if szStyle == '' then
				return
			end
			MY_Focus.szStyle = szStyle
			LIB.SwitchTab('MY_Focus', true)
		end,
	})
	x, y = xl, y + 25

	-- <hr />
	ui:Append('Image', {x = x, y = y, w = wl, h = 1, image = 'UI/Image/UICommon/ScienceTreeNode.UITex', imageframe = 62})
	y = y + 5

	ui:Append('WndCheckBox', {
		x = x, y = y, text = _L['Auto focus'], checked = MY_Focus.bAutoFocus,
		oncheck = function(bChecked)
			MY_Focus.bAutoFocus = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})

	local list = ui:Append('WndListBox', {
		x = x, y = y + 30, w = wl - x + xl, h = h - y - 40,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	-- 初始化list控件
	for _, v in ipairs(MY_Focus.GetAllFocusPattern()) do
		list:ListBox('insert', MY_Focus.FormatRuleText(v), v, v)
	end
	list:ListBox('onmenu', function(oID, szText, tData)
		local t = {{
			szOption = _L['Delete'],
			fnAction = function()
				MY_Focus.RemoveFocusPattern(tData.szPattern)
				list:ListBox('delete', 'id', oID)
				UI.ClosePopupMenu()
			end,
		}}
		-- 匹配方式
		local t1 = { szOption = _L['Judge method'] }
		for _, eType in ipairs({ 'NAME', 'NAME_PATT', 'ID', 'TEMPLATE_ID', 'TONG_NAME', 'TONG_NAME_PATT' }) do
			insert(t1, {
				szOption = _L.JUDGE_METHOD[eType],
				bCheck = true, bMCheck = true,
				bChecked = tData.szMethod == eType,
				fnAction = function()
					tData.szMethod = eType
					MY_Focus.SetFocusPattern(tData.szPattern, tData)
				end,
			})
		end
		insert(t, t1)
		-- 目标类型
		local t1 = {
			szOption = _L['Target type'], {
				szOption = _L['All'],
				bCheck = true, bChecked = tData.tType.bAll,
				fnAction = function()
					tData.tType.bAll = not tData.tType.bAll
					MY_Focus.SetFocusPattern(tData.szPattern, tData)
					list:ListBox('update', 'id', oID, {'text'}, {MY_Focus.FormatRuleText(tData)})
				end,
			}
		}
		for _, eType in ipairs({ TARGET.NPC, TARGET.PLAYER, TARGET.DOODAD }) do
			insert(t1, {
				szOption = _L.TARGET[eType],
				bCheck = true, bChecked = tData.tType[eType],
				fnAction = function()
					tData.tType[eType] = not tData.tType[eType]
					MY_Focus.SetFocusPattern(tData.szPattern, tData)
					list:ListBox('update', 'id', oID, {'text'}, {MY_Focus.FormatRuleText(tData)})
				end,
				fnDisable = function()
					return tData.tType.bAll
				end,
			})
		end
		insert(t, t1)
		-- 目标关系
		local t1 = {
			szOption = _L['Target relation'], {
				szOption = _L['All'],
				bCheck = true, bChecked = tData.tRelation.bAll,
				fnAction = function()
					tData.tRelation.bAll = not tData.tRelation.bAll
					MY_Focus.SetFocusPattern(tData.szPattern, tData)
					list:ListBox('update', 'id', oID, {'text'}, {MY_Focus.FormatRuleText(tData)})
				end,
			}
		}
		for _, szRelation in ipairs({ 'Enemy', 'Ally' }) do
			insert(t1, {
				szOption = _L.RELATION[szRelation],
				bCheck = true, bChecked = tData.tRelation['b' .. szRelation],
				fnAction = function()
					tData.tRelation['b' .. szRelation] = not tData.tRelation['b' .. szRelation]
					MY_Focus.SetFocusPattern(tData.szPattern, tData)
					list:ListBox('update', 'id', oID, {'text'}, {MY_Focus.FormatRuleText(tData)})
				end,
				fnDisable = function()
					return tData.tRelation.bAll
				end,
			})
		end
		insert(t, t1)
		-- 目标血量百分比
		local t1 = {
			szOption = _L['Target life percentage'], {
				szOption = _L['Enable'],
				bCheck = true, bChecked = tData.tLife.bEnable,
				fnAction = function()
					tData.tLife.bEnable = not tData.tLife.bEnable
				end,
			},
			LIB.InsertOperatorMenu({
				szOption = _L['Operator'],
				fnDisable = function() return not tData.tLife.bEnable end,
			}, tData.tLife.szOperator, function(op)
				tData.tLife.szOperator = op
				MY_Focus.SetFocusPattern(tData.szPattern, tData)
			end), {
				szOption = _L['Value'],
				fnMouseEnter = function()
					OutputTip(GetFormatText(tData.tLife.nValue .. '%', nil, 255, 255, 0), 600, {this:GetAbsX(), this:GetAbsY(), this:GetW(), this:GetH()}, ALW.RIGHT_LEFT)
				end,
				fnAction = function()
					GetUserInputNumber(tData.tLife.nValue, 100, nil, function(val)
						tData.tLife.nValue = val
						MY_Focus.SetFocusPattern(tData.szPattern, tData)
					end, nil, function() return not LIB.IsPanelVisible() end)
				end,
				fnDisable = function() return not tData.tLife.bEnable end,
			},
		}
		insert(t, t1)
		-- 最远距离
		local t1 = {
			szOption = _L['Max distance'],
			fnMouseEnter = function()
				if tData.nMaxDistance == 0 then
					return
				end
				OutputTip(GetFormatText(tData.nMaxDistance .. g_tStrings.STR_METER , nil, 255, 255, 0), 600, {this:GetAbsX(), this:GetAbsY(), this:GetW(), this:GetH()}, ALW.RIGHT_LEFT)
			end,
			fnAction = function()
				GetUserInput(_L['Please input max distance, leave blank to disable:'], function(val)
					tData.nMaxDistance = tonumber(val) or 0
					MY_Focus.SetFocusPattern(tData.szPattern, tData)
				end, nil, function() return not LIB.IsPanelVisible() end, nil, tData.nMaxDistance)
			end,
		}
		insert(t, t1)
		-- 名称显示
		local t1 = {
			szOption = _L['Name display'],
			fnMouseEnter = function()
				if tData.szDisplay == '' then
					return
				end
				OutputTip(GetFormatText(tData.szDisplay, nil, 255, 255, 0), 600, {this:GetAbsX(), this:GetAbsY(), this:GetW(), this:GetH()}, ALW.RIGHT_LEFT)
			end,
			fnAction = function()
				GetUserInput(_L['Please input display name, leave blank to use its own name:'], function(val)
					tData.szDisplay = val
					MY_Focus.SetFocusPattern(tData.szPattern, tData)
				end, nil, function() return not LIB.IsPanelVisible() end, nil, tData.szDisplay)
			end,
		}
		insert(t, t1)
		return t
	end)
	-- add
	ui:Append('WndButton', {
		x = wl - 80, y = y, w = 80,
		text = _L['Add'],
		onclick = function()
			GetUserInput(_L['Add auto focus'], function(szText)
				local tData = MY_Focus.SetFocusPattern(szText)
				if not tData then
					return
				end
				list:ListBox('insert', MY_Focus.FormatRuleText(tData), tData, tData)
			end, function() end, function() end, nil, '')
		end,
		tip = _L['Right click list to delete'],
		autoenable = function() return MY_Focus.IsEnabled() end,
	})

	-- 右侧
	local x, y = xr, yr
	local deltaY = (h - y * 2) / 20
	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Hide when empty'],
		checked = MY_Focus.bAutoHide,
		oncheck = function(bChecked)
			MY_Focus.bAutoHide = bChecked
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Auto focus very important npc'],
		tip = _L['Boss list is always been collecting and updating'],
		tippostype = UI.TIP_POSITION.TOP_BOTTOM,
		checked = MY_Focus.bFocusINpc,
		oncheck = function(bChecked)
			MY_Focus.bFocusINpc = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['TeamMon focus'],
		tip = _L['TeamMon focus is related to MY_TeamMon data.'],
		tippostype = UI.TIP_POSITION.TOP_BOTTOM,
		checked = MY_Focus.bTeamMonFocus,
		oncheck = function(bChecked)
			MY_Focus.bTeamMonFocus = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Auto focus friend'],
		checked = MY_Focus.bFocusFriend,
		oncheck = function(bChecked)
			MY_Focus.bFocusFriend = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('Image', {
		x = x + 5, y = y - 3, w = 10, h = 8,
		image = 'ui/Image/UICommon/ScienceTree.UITex',
		imageframe = 10,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Auto focus tong'],
		checked = MY_Focus.bFocusTong,
		oncheck = function(bChecked)
			MY_Focus.bFocusTong = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('Image', {
		x = x + 5, y = y, w = 10, h = 10,
		image = 'ui/Image/UICommon/ScienceTree.UITex',
		imageframe = 10,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	ui:Append('Image', {
		x = x + 10, y = y + 5, w = 10, h = 10,
		image = 'ui/Image/UICommon/ScienceTree.UITex',
		imageframe = 8,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	ui:Append('WndCheckBox', {
		x = x + 20, y = y, w = wr, text = _L['Auto focus only in public map'],
		checked = MY_Focus.bOnlyPublicMap,
		oncheck = function(bChecked)
			MY_Focus.bOnlyPublicMap = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Auto focus enemy'],
		checked = MY_Focus.bFocusEnemy,
		oncheck = function(bChecked)
			MY_Focus.bFocusEnemy = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Auto focus party in arena'],
		checked = MY_Focus.bFocusJJCParty,
		oncheck = function(bChecked)
			MY_Focus.bFocusJJCParty = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Auto focus enemy in arena'],
		checked = MY_Focus.bFocusJJCEnemy,
		oncheck = function(bChecked)
			MY_Focus.bFocusJJCEnemy = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Anmerkungen auto focus'],
		checked = MY_Focus.bFocusAnmerkungen,
		oncheck = function(bChecked)
			MY_Focus.bFocusAnmerkungen = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Show focus\'s target'],
		checked = MY_Focus.bShowTarget,
		oncheck = function(bChecked)
			MY_Focus.bShowTarget = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Hide dead object'],
		checked = MY_Focus.bHideDeath,
		oncheck = function(bChecked)
			MY_Focus.bHideDeath = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Display kungfu icon instead of location'],
		checked = MY_Focus.bDisplayKungfuIcon,
		oncheck = function(bChecked)
			MY_Focus.bDisplayKungfuIcon = bChecked
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		name = 'WndCheckBox_SortByDistance',
		x = x, y = y, w = wr,
		text = _L['Sort by distance'],
		checked = MY_Focus.bSortByDistance,
		oncheck = function(bChecked)
			MY_Focus.bSortByDistance = bChecked
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		name = 'WndCheckBox_EnableSceneNavi',
		x = x, y = y, w = wr,
		text = _L['Enable scene navi'],
		checked = MY_Focus.bEnableSceneNavi,
		oncheck = function(bChecked)
			MY_Focus.bEnableSceneNavi = bChecked
			MY_Focus.RescanNearby()
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Show tip at right bottom'],
		checked = MY_Focus.bShowTipRB,
		oncheck = function(bChecked)
			MY_Focus.bShowTipRB = bChecked
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	x = x + ui:Append('WndCheckBox', {
		x = x, y = y, w = wr, text = _L['Heal healper'],
		tip = _L['Select target when mouse enter'],
		tippostype = UI.TIP_POSITION.BOTTOM_TOP,
		checked = MY_Focus.bHealHelper,
		oncheck = function(bChecked)
			MY_Focus.bHealHelper = bChecked
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	}):AutoWidth():Width() + 5

	ui:Append('WndComboBox', {
		x = x, y = y, w = wr, text = _L['Distance type'],
		menu = function()
			return LIB.GetDistanceTypeMenu(true, MY_Focus.szDistanceType, function(p)
				MY_Focus.szDistanceType = p.szType
			end)
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	}):AutoWidth()

	x = xr
	y = y + deltaY

	ui:Append('WndTrackbar', {
		x = x, y = y, w = 150,
		textfmt = function(val) return _L('Max display count %d.', val) end,
		range = {1, 20},
		trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE,
		value = MY_Focus.nMaxDisplay,
		onchange = function(val)
			MY_Focus.nMaxDisplay = val
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndTrackbar', {
		x = x, y = y, w = 150,
		textfmt = function(val) return _L('Current scale-x is %d%%.', val) end,
		range = {10, 300},
		trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE,
		value = MY_Focus.fScaleX * 100,
		onchange = function(val)
			MY_Focus.fScaleX = val / 100
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY

	ui:Append('WndTrackbar', {
		x = x, y = y, w = 150,
		textfmt = function(val) return _L('Current scale-y is %d%%.', val) end,
		range = {10, 300},
		trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE,
		value = MY_Focus.fScaleY * 100,
		onchange = function(val)
			MY_Focus.fScaleY = val / 100
		end,
		autoenable = function() return MY_Focus.IsEnabled() end,
	})
	y = y + deltaY
end
LIB.RegisterPanel(_L['Target'], 'MY_Focus', _L['Focus list'], 'ui/Image/button/SystemButton_1.UITex|9', PS)
