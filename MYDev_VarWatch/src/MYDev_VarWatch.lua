--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 变量监控
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
local UI, Get, RandomChild = MY.UI, MY.Get, MY.RandomChild
local IsNil, IsBoolean, IsNumber, IsFunction = MY.IsNil, MY.IsBoolean, MY.IsNumber, MY.IsFunction
local IsEmpty, IsString, IsTable, IsUserdata = MY.IsEmpty, MY.IsString, MY.IsTable, MY.IsUserdata
---------------------------------------------------------------------------------------------------
local _L = MY.LoadLangPack(MY.GetAddonInfo().szRoot .. 'MYDev_VarWatch/lang/')
if not MY.AssertVersion('MYDev_VarWatch', _L['MYDev_VarWatch'], 0x2011800) then
	return
end
local _C = {}
local XML_LINE_BREAKER = XML_LINE_BREAKER
local srep, tostring, string2byte = string.rep, tostring, string.byte
local tconcat, tinsert, tremove = table.concat, table.insert, table.remove
local type, next, print, pairs, ipairs = type, next, print, pairs, ipairs
local DATA_PATH = {'config/dev_varwatch.jx3dat', MY_DATA_PATH.GLOBAL}
_C.tVarList = MY.LoadLUAData(DATA_PATH) or {}

local function var2str_x(var, indent, level) -- 只解析一层table且不解析方法
	local function table_r(var, level, indent)
		local t = {}
		local szType = type(var)
		if szType == 'nil' then
			tinsert(t, 'nil')
		elseif szType == 'number' then
			tinsert(t, tostring(var))
		elseif szType == 'string' then
			tinsert(t, string.format('%q', var))
		elseif szType == 'boolean' then
			tinsert(t, tostring(var))
		elseif szType == 'table' then
			tinsert(t, '{')
			local s_tab_equ = ']='
			if indent then
				s_tab_equ = '] = '
				if not empty(var) then
					tinsert(t, '\n')
				end
			end
			for key, val in pairs(var) do
				if indent then
					tinsert(t, srep(indent, level + 1))
				end
				tinsert(t, '[')
				tinsert(t, tostring(key))
				tinsert(t, s_tab_equ) --'] = '
				tinsert(t, tostring(val))
				tinsert(t, ',')
				if indent then
					tinsert(t, '\n')
				end
			end
			if indent and not empty(var) then
				tinsert(t, srep(indent, level))
			end
			tinsert(t, '}')
		else --if (szType == 'userdata') then
			tinsert(t, '"')
			tinsert(t, tostring(var))
			tinsert(t, '"')
		end
		return tconcat(t)
	end
	return table_r(var, level or 0, indent)
end

MY.RegisterPanel(
'Dev_VarWatch', _L['VarWatch'], _L['Development'],
'ui/Image/UICommon/BattleFiled.UITex|7', {
	OnPanelActive = function(wnd)
		local ui = UI(wnd)
		local x, y = 10, 10
		local w, h = ui:size()
		local nLimit = 20

		local tWndEditK = {}
		local tWndEditV = {}

		for i = 1, nLimit do
			tWndEditK[i] = ui:append('WndEditBox', {
				name = 'WndEditBox_K' .. i,
				text = _C.tVarList[i],
				x = x, y = y + (i - 1) * 25,
				w = 150, h = 25,
				color = {255, 255, 255},
				onchange = function(text)
					_C.tVarList[i] = MY.TrimString(text)
					MY.SaveLUAData(DATA_PATH, _C.tVarList)
				end,
			}):children('#WndEditBox_K' .. i)

			tWndEditV[i] = ui:append('WndEditBox', {
				name = 'WndEditBox_V' .. i,
				x = x + 150, y = y + (i - 1) * 25,
				w = w - 2 * x - 150, h = 25,
				color = {255, 255, 255},
			}):children('#WndEditBox_V' .. i)
		end

		MY.BreatheCall('DEV_VARWATCH', function()
			for i = 1, nLimit do
				local szKey = _C.tVarList[i]
				local hFocus = Station.GetFocusWindow()
				if not empty(szKey) and -- 忽略空白的Key
				wnd:GetRoot():IsVisible() and ( -- 主界面隐藏了就不要解析了
					not hFocus or (
						not hFocus:GetTreePath():find(tWndEditK[i]:name()) and  -- 忽略K编辑中的
						not hFocus:GetTreePath():find(tWndEditV[i]:name()) -- 忽略V编辑中的
					)
				) then
					if loadstring then
						local t = {select(2, pcall(loadstring('return ' .. szKey)))}
						for k, v in pairs(t) do
							t[k] = tostring(v)
						end
						tWndEditV[i]:text(tconcat(t, ', '))
					else
						tWndEditV[i]:text(var2str_x(MY.GetGlobalValue(szKey)))
					end
				end
			end
		end)
	end,
	OnPanelDeactive = function()
		MY.BreatheCall('DEV_VARWATCH', false)
	end,
})
