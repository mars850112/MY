--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 团队工具界面
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
local sub, len, format, rep = string.sub, string.len, string.format, string.rep
local find, byte, char, gsub = string.find, string.byte, string.char, string.gsub
local type, tonumber, tostring = type, tonumber, tostring
local HUGE, PI, random, abs = math.huge, math.pi, math.random, math.abs
local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil
local pow, sqrt, sin, cos, tan, atan = math.pow, math.sqrt, math.sin, math.cos, math.tan, math.atan
local insert, remove, concat, sort = table.insert, table.remove, table.concat, table.sort
local pack, unpack = table.pack or function(...) return {...} end, table.unpack or unpack
-- jx3 apis caching
local wsub, wlen, wfind, wgsub = wstring.sub, wstring.len, wstring.find, StringReplaceW
local GetTime, GetLogicFrameCount, GetCurrentTime = GetTime, GetLogicFrameCount, GetCurrentTime
local GetClientTeam, UI_GetClientPlayerID = GetClientTeam, UI_GetClientPlayerID
local GetClientPlayer, GetPlayer, GetNpc, IsPlayer = GetClientPlayer, GetPlayer, GetNpc, IsPlayer
local LIB = MY
local UI, DEBUG_LEVEL, PATH_TYPE, PACKET_INFO = LIB.UI, LIB.DEBUG_LEVEL, LIB.PATH_TYPE, LIB.PACKET_INFO
local spairs, spairs_r, sipairs, sipairs_r = LIB.spairs, LIB.spairs_r, LIB.sipairs, LIB.sipairs_r
local ipairs_r, count_c, pairs_c, ipairs_c = LIB.ipairs_r, LIB.count_c, LIB.pairs_c, LIB.ipairs_c
local IsNil, IsEmpty, IsEquals, IsString = LIB.IsNil, LIB.IsEmpty, LIB.IsEquals, LIB.IsString
local IsBoolean, IsNumber, IsHugeNumber = LIB.IsBoolean, LIB.IsNumber, LIB.IsHugeNumber
local IsTable, IsArray, IsDictionary = LIB.IsTable, LIB.IsArray, LIB.IsDictionary
local IsFunction, IsUserdata, IsElement = LIB.IsFunction, LIB.IsUserdata, LIB.IsElement
local Call, XpCall, GetTraceback, RandomChild = LIB.Call, LIB.XpCall, LIB.GetTraceback, LIB.RandomChild
local Get, Set, Clone, GetPatch, ApplyPatch = LIB.Get, LIB.Set, LIB.Clone, LIB.GetPatch, LIB.ApplyPatch
local EncodeLUAData, DecodeLUAData, CONSTANT = LIB.EncodeLUAData, LIB.DecodeLUAData, LIB.CONSTANT
-------------------------------------------------------------------------------------------------------
local PLUGIN_NAME = 'MY_TeamTools'
local PLUGIN_ROOT = PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_TeamTools'
local _L = LIB.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not LIB.AssertVersion(MODULE_NAME, _L[MODULE_NAME], 0x2013900) then
	return
end
--------------------------------------------------------------------------
local PS = {}
function PS.OnPanelActive(wnd)
	local ui = UI(wnd)
	local X, Y = 20, 30
	local x, y = X, Y
	local W, H = ui:Size()

	y = y + ui:Append('Text', { x = x, y = y, text = _L['MY_TeamTools'], font = 27 }):Height() + 5
	x = X + 10
	x = x + ui:Append('WndCheckBox', {
		x = x, y = y,
		checked = MY_TeamNotice.bEnable,
		text = _L['Team Message'],
		oncheck = function(bChecked)
			MY_TeamNotice.bEnable = bChecked
		end,
	}):AutoWidth():Width() + 5

	x = x + ui:Append('WndCheckBox', {
		x = x, y = y,
		checked = MY_CharInfo.bEnable,
		text = _L['Allow view charinfo'],
		oncheck = function(bChecked)
			MY_CharInfo.bEnable = bChecked
		end,
	}):AutoWidth():Width() + 5

	if not LIB.IsShieldedVersion('MY_WorldMark') then
		x = x + ui:Append('WndCheckBox', {
			x = x, y = y,
			checked = MY_WorldMark.bEnable,
			text = _L['World mark enhance'],
			oncheck = function(bChecked)
				MY_WorldMark.bEnable = bChecked
				MY_WorldMark.CheckEnable()
			end,
		}):AutoWidth():Width() + 5
	end
	y = y + 20

	x = X
	y = y + 20
	y = y + ui:Append('Text', { x = x, y = y, text = _L['Party Request'], font = 27 }):Height() + 5
	x = X + 10
	ui:Append('WndCheckBox', {
		x = x, y = y,
		checked = MY_PartyRequest.bEnable,
		text = _L['Party Request'],
		oncheck = function(bChecked)
			MY_PartyRequest.bEnable = bChecked
		end,
	}):AutoWidth()
	x = x + 10
	y = y + 25
	ui:Append('WndCheckBox', {
		x = x, y = y,
		checked = MY_PartyRequest.bRefuseLowLv,
		text = _L['Auto refuse low level player'],
		oncheck = function(bChecked)
			MY_PartyRequest.bRefuseLowLv = bChecked
		end,
		autoenable = function() return MY_PartyRequest.bEnable end,
	}):AutoWidth()
	y = y + 25
	ui:Append('WndCheckBox', {
		x = x, y = y,
		checked = MY_PartyRequest.bRefuseRobot,
		text = _L['Auto refuse robot player'],
		tip = _L['Full level and equip score less than 2/3 of yours'],
		tippostype = UI.TIP_POSITION.BOTTOM_TOP,
		oncheck = function(bChecked)
			MY_PartyRequest.bRefuseRobot = bChecked
		end,
		autoenable = function() return MY_PartyRequest.bEnable end,
	}):AutoWidth()
	y = y + 25
	ui:Append('WndCheckBox', {
		x = x, y = y,
		checked = MY_PartyRequest.bAcceptFriend,
		text = _L['Auto accept friend'],
		oncheck = function(bChecked)
			MY_PartyRequest.bAcceptFriend = bChecked
		end,
		autoenable = function() return MY_PartyRequest.bEnable end,
	}):AutoWidth()
	y = y + 25
	ui:Append('WndCheckBox', {
		x = x, y = y,
		checked = MY_PartyRequest.bAcceptTong,
		text = _L['Auto accept tong member'],
		oncheck = function(bChecked)
			MY_PartyRequest.bAcceptTong = bChecked
		end,
		autoenable = function() return MY_PartyRequest.bEnable end,
	}):AutoWidth()
	y = y + 25
	ui:Append('WndCheckBox', {
		x = x, y = y,
		checked = MY_PartyRequest.bAcceptAll,
		text = _L['Auto accept all'],
		oncheck = function(bChecked)
			MY_PartyRequest.bAcceptAll = bChecked
		end,
		autoenable = function() return MY_PartyRequest.bEnable end,
	}):AutoWidth()
	y = y + 25

	x, y = MY_TeamRestore.OnPanelActivePartial(ui, X, Y, W, H, x, y)
end
LIB.RegisterPanel('MY_TeamTools', _L['MY_TeamTools'], _L['Raid'], 5962, PS)
