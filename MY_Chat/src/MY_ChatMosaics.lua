--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 聊天栏姓名一键打码
-- @author   : 茗伊 @双梦镇 @追风蹑影
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
--------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
-----------------------------------------------------------------------------------------------------------
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
local IsNil, IsBoolean, IsUserdata, IsFunction = LIB.IsNil, LIB.IsBoolean, LIB.IsUserdata, LIB.IsFunction
local IsString, IsTable, IsArray, IsDictionary = LIB.IsString, LIB.IsTable, LIB.IsArray, LIB.IsDictionary
local IsNumber, IsHugeNumber, IsEmpty, IsEquals = LIB.IsNumber, LIB.IsHugeNumber, LIB.IsEmpty, LIB.IsEquals
local Call, XpCall, GetTraceback, RandomChild = LIB.Call, LIB.XpCall, LIB.GetTraceback, LIB.RandomChild
local Get, Set, Clone, GetPatch, ApplyPatch = LIB.Get, LIB.Set, LIB.Clone, LIB.GetPatch, LIB.ApplyPatch
local EncodeLUAData, DecodeLUAData, CONSTANT = LIB.EncodeLUAData, LIB.DecodeLUAData, LIB.CONSTANT
-----------------------------------------------------------------------------------------------------------
local PLUGIN_NAME = 'MY_Chat'
local PLUGIN_ROOT = PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_ChatMosaics'
local _L = LIB.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not LIB.AssertVersion(MODULE_NAME, _L[MODULE_NAME], 0x2013900) then
	return
end
--------------------------------------------------------------------------
local D = {}
local O = {
	bEnabled = false,            -- 启用状态
	szMosaics = _L.MOSAICS_CHAR, -- 马赛克字符
	tIgnoreNames = {},           -- 忽略名单
	nMosaicsMode = 1,            -- 局部打码模式
	bIgnoreOwnName = false,      -- 不打码自己的名字
}
RegisterCustomData('MY_ChatMosaics.tIgnoreNames')
RegisterCustomData('MY_ChatMosaics.nMosaicsMode')
RegisterCustomData('MY_ChatMosaics.bIgnoreOwnName')

function D.ResetMosaics()
	-- re mosaics
	D.bForceUpdate = true
	for i = 1, 10 do
		D.Mosaics(Station.Lookup('Lowest2/ChatPanel' .. i .. '/Wnd_Message', 'Handle_Message'))
	end
	D.bForceUpdate = nil
	-- hook chat panel
	if O.bEnabled then
		LIB.HookChatPanel('AFTER.MY_ChatMosaics', function(h, nIndex)
			D.Mosaics(h, nIndex)
		end)
	else
		LIB.HookChatPanel('AFTER.MY_ChatMosaics', false)
	end
	FireUIEvent('ON_MY_MOSAICS_RESET')
end

function D.NameLink_GetText(h, ...)
	return h.__MY_ChatMosaics_szText or h.__MY_ChatMosaics_GetText(h, ...)
end

function D.MosaicsString(szText)
	if not O.bEnabled then
		return szText
	end
	local bQuote = szText:sub(1, 1) == '[' and szText:sub(-1, -1) == ']'
	if bQuote then
		szText = szText:sub(2, -2) -- 去掉[]括号
	end
	if (not O.bIgnoreOwnName or szText ~= GetClientPlayer().szName) and not O.tIgnoreNames[szText] then
		local nLen = wlen(szText)
		if O.nMosaicsMode == 1 and nLen > 2 then
			szText = wsub(szText, 1, 1) .. rep(O.szMosaics, nLen - 2) .. wsub(szText, nLen, nLen)
		elseif O.nMosaicsMode == 2 and nLen > 1 then
			szText = wsub(szText, 1, 1) .. rep(O.szMosaics, nLen - 1)
		elseif O.nMosaicsMode == 3 and nLen > 1 then
			szText = rep(O.szMosaics, nLen - 1) .. wsub(szText, nLen, nLen)
		elseif O.nMosaicsMode == 4 or nLen <= 1 then
			szText = rep(O.szMosaics, nLen)
		else
			szText = wsub(szText, 1, 1) .. rep(O.szMosaics, nLen - 1)
		end
	end
	if bQuote then
		szText = '[' .. szText .. ']' -- 加回[]括号
	end
	return szText
end

function D.Mosaics(h, nPos, nLen)
	if not h then
		return
	end
	if h:GetType() == 'Text' then
		if O.bEnabled then
			if not h.__MY_ChatMosaics_szText or D.bForceUpdate then
				h.__MY_ChatMosaics_szText = h.__MY_ChatMosaics_szText or h:GetText()
				if not h.__MY_ChatMosaics_GetText then
					h.__MY_ChatMosaics_GetText = h.GetText
					h.GetText = D.NameLink_GetText
				end
				h:SetText(D.MosaicsString(h.__MY_ChatMosaics_szText))
				h:AutoSize()
			end
		else
			if h.__MY_ChatMosaics_GetText then
				h.GetText = h.__MY_ChatMosaics_GetText
				h.__MY_ChatMosaics_GetText = nil
			end
			if h.__MY_ChatMosaics_szText then
				h:SetText(h.__MY_ChatMosaics_szText)
				h.__MY_ChatMosaics_szText = nil
				h:AutoSize()
			end
		end
	elseif h:GetType() == 'Handle' then
		local nEndPos = (nLen and (nPos + nLen)) or (h:GetItemCount() - 1)
		for i = nPos or 0, nEndPos do
			local hItem = h:Lookup(i)
			if hItem and (hItem:GetName():sub(0, 9)) == 'namelink_' then
				D.Mosaics(hItem)
			end
		end
		h:FormatAllItemPos()
	end
end

-- Global exports
do
local settings = {
	exports = {
		{
			fields = {
				Mosaics = D.Mosaics,
				MosaicsString = D.MosaicsString,
			},
		},
		{
			root = D,
			preset = 'UIEvent'
		},
		{
			fields = {
				bEnabled = true,
				szMosaics = true,
				tIgnoreNames = true,
				nMosaicsMode = true,
				bIgnoreOwnName = true,
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				bEnabled = true,
				szMosaics = true,
				tIgnoreNames = true,
				nMosaicsMode = true,
				bIgnoreOwnName = true,
			},
			triggers = {
				bEnabled = function ()
					D.ResetMosaics()
				end,
			},
			root = O,
		},
	},
}
MY_ChatMosaics = LIB.GeneGlobalNS(settings)
end

local PS = {}

function PS.OnPanelActive(wnd)
	local ui = UI(wnd)
	local w, h = ui:Size()
	local x, y = 20, 30

	ui:Append('WndCheckBox', {
		text = _L['chat mosaics (mosaics names in chat panel)'],
		x = x, y = y, w = 400,
		checked = MY_ChatMosaics.bEnabled,
		oncheck = function(bCheck)
			MY_ChatMosaics.bEnabled = bCheck
			D.ResetMosaics()
		end,
	})
	y = y + 30

	ui:Append('WndCheckBox', {
		text = _L['no mosaics on my own name'],
		x = x, y = y, w = 400,
		checked = MY_ChatMosaics.bIgnoreOwnName,
		oncheck = function(bCheck)
			MY_ChatMosaics.bIgnoreOwnName = bCheck
			D.ResetMosaics()
		end,
	})
	y = y + 30

	ui:Append('WndRadioBox', {
		text = _L['part mosaics A (mosaics except 1st and last character)'],
		x = x, y = y, w = 400,
		group = 'PART_MOSAICS',
		checked = MY_ChatMosaics.nMosaicsMode == 1,
		oncheck = function(bCheck)
			if bCheck then
				MY_ChatMosaics.nMosaicsMode = 1
				D.ResetMosaics()
			end
		end,
	})
	y = y + 30

	ui:Append('WndRadioBox', {
		text = _L['part mosaics B (mosaics except 1st character)'],
		x = x, y = y, w = 400,
		group = 'PART_MOSAICS',
		checked = MY_ChatMosaics.nMosaicsMode == 2,
		oncheck = function(bCheck)
			if bCheck then
				MY_ChatMosaics.nMosaicsMode = 2
				D.ResetMosaics()
			end
		end,
	})
	y = y + 30

	ui:Append('WndRadioBox', {
		text = _L['part mosaics C (mosaics except last character)'],
		x = x, y = y, w = 400,
		group = 'PART_MOSAICS',
		checked = MY_ChatMosaics.nMosaicsMode == 3,
		oncheck = function(bCheck)
			if bCheck then
				MY_ChatMosaics.nMosaicsMode = 3
				D.ResetMosaics()
			end
		end,
	})
	y = y + 30

	ui:Append('WndRadioBox', {
		text = _L['part mosaics D (mosaics all character)'],
		x = x, y = y, w = 400,
		group = 'PART_MOSAICS',
		checked = MY_ChatMosaics.nMosaicsMode == 4,
		oncheck = function(bCheck)
			if bCheck then
				MY_ChatMosaics.nMosaicsMode = 4
				D.ResetMosaics()
			end
		end,
	})
	y = y + 30

	ui:Append('WndEditBox', {
		placeholder = _L['mosaics character'],
		x = x, y = y, w = w - 2 * x, h = 25,
		text = MY_ChatMosaics.szMosaics,
		onchange = function(szText)
			if szText == '' then
				MY_ChatMosaics.szMosaics = _L.MOSAICS_CHAR
			else
				MY_ChatMosaics.szMosaics = szText
			end
			D.ResetMosaics()
		end,
	})
	y = y + 30

	ui:Append('WndEditBox', {
		placeholder = _L['unmosaics names (split by comma)'],
		x = x, y = y, w = w - 2 * x, h = h - y - 50,
		text = (function()
			local t = {}
			for szName, _ in pairs(MY_ChatMosaics.tIgnoreNames) do
				table.insert(t, szName)
			end
			table.concat(t, ',')
		end)(),
		onchange = function(szText)
			MY_ChatMosaics.tIgnoreNames = {}
			for _, szName in ipairs(LIB.SplitString(szText, ',')) do
				MY_ChatMosaics.tIgnoreNames[szName] = true
			end
			D.ResetMosaics()
		end,
	})
	y = y + 30
end

LIB.RegisterPanel('MY_Chat_ChatMosaics', _L['chat mosaics'], _L['Chat'], 'ui/Image/UICommon/yirong3.UITex|50', PS)
