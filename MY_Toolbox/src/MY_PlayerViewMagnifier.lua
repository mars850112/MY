--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : ���¼�
-- @author   : ���� @˫���� @׷����Ӱ
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
--------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
-----------------------------------------------------------------------------------------------------------
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
local UI, DEBUG_LEVEL, PATH_TYPE, PACKET_INFO = LIB.UI, LIB.DEBUG_LEVEL, LIB.PATH_TYPE, LIB.PACKET_INFO
local spairs, spairs_r, sipairs, sipairs_r = LIB.spairs, LIB.spairs_r, LIB.sipairs, LIB.sipairs_r
local ipairs_r, count_c, pairs_c, ipairs_c = LIB.ipairs_r, LIB.count_c, LIB.pairs_c, LIB.ipairs_c
local IsNil, IsBoolean, IsUserdata, IsFunction = LIB.IsNil, LIB.IsBoolean, LIB.IsUserdata, LIB.IsFunction
local IsString, IsTable, IsArray, IsDictionary = LIB.IsString, LIB.IsTable, LIB.IsArray, LIB.IsDictionary
local IsNumber, IsHugeNumber, IsEmpty, IsEquals = LIB.IsNumber, LIB.IsHugeNumber, LIB.IsEmpty, LIB.IsEquals
local Call, XpCall, GetTraceback, RandomChild = LIB.Call, LIB.XpCall, LIB.GetTraceback, LIB.RandomChild
local Get, Set, Clone, GetPatch, ApplyPatch = LIB.Get, LIB.Set, LIB.Clone, LIB.GetPatch, LIB.ApplyPatch
local EncodeLUAData, DecodeLUAData, CONSTANT = LIB.EncodeLUAData, LIB.DecodeLUAData, LIB.CONSTANT
-----------------------------------------------------------------------------------------------------------
local _L = LIB.LoadLangPack(PACKET_INFO.ROOT .. 'MY_Toolbox/lang/')

local function onFrameCreate()
	local config
	if arg0:GetName() == 'PlayerView' then
		config = { x = 35, y = 8, w = 30, h = 30, coefficient = 2.45 }
	elseif arg0:GetName() == 'ExteriorView' then
		config = { x = 20, y = 15, w = 40, h = 40, coefficient = 2.5 }
	end
	if config then
		local frame, ui, coefficient, posx, posy = arg0, UI(arg0), config.coefficient / Station.GetUIScale()
		ui:append(PACKET_INFO.ROOT .. 'MY_Toolbox/ui/Btn_MagnifierUp.ini:WndButton', {
			name = 'Btn_MY_MagnifierUp',
			x = config.x, y = config.y, w = config.w, h = config.h,
			onclick = function()
				posx, posy = ui:pos()
				frame:EnableDrag(true)
				frame:SetDragArea(0, 0, frame:GetW(), 50)
				frame:Scale(coefficient, coefficient)
				frame:SetPoint('CENTER', 0, 0, 'CENTER', 0, 0)
				ui:find('.Text'):fontScale(coefficient)
				ui:children('#Btn_MY_MagnifierUp'):hide()
				ui:children('#Btn_MY_MagnifierDown'):show()
			end,
			tip = _L['Click to enable MY player view magnifier'],
		})
		ui:append(PACKET_INFO.ROOT .. 'MY_Toolbox/ui/Btn_MagnifierDown.ini:WndButton', {
			name = 'Btn_MY_MagnifierDown',
			x = config.x, y = config.y, w = config.w, h = config.h, visible = false,
			onclick = function()
				frame:Scale(1 / coefficient, 1 / coefficient)
				ui:pos(posx, posy)
				ui:find('.Text'):fontScale(1)
				ui:children('#Btn_MY_MagnifierUp'):show()
				ui:children('#Btn_MY_MagnifierDown'):hide()
			end,
			tip = _L['Click to disable MY player view magnifier'],
		})
	end
end
LIB.RegisterFrameCreate('PlayerView.MY_PlayerViewMagnifier', onFrameCreate)
LIB.RegisterFrameCreate('ExteriorView.MY_PlayerViewMagnifier', onFrameCreate)
