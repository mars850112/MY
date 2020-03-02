--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 弹出菜单
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
local _L = LIB.LoadLangPack()
-----------------------------------------------------------------------------------------------------------

local D = {}
local SZ_INI = PACKET_INFO.FRAMEWORK_ROOT .. 'ui/MY_PopupMenu.ini'
local SZ_TPL_INI = PACKET_INFO.FRAMEWORK_ROOT .. 'ui/MY_PopupMenu.tpl.ini'
local LAYER_LIST = {'Lowest', 'Lowest1', 'Lowest2', 'Normal', 'Normal1', 'Normal2', 'Topmost', 'Topmost1', 'Topmost2'}
local ENABLE_FONT = 162
local DISABLE_FONT = 161

--[[
	menu = {
		nMinWidth = 100,
		{
			szOption = 'Option 0',
		},
		{
			bInline = true,
			nMaxHeight = 200,
			{
				szOption = 'Option 1',
				fnAction = function()
					Output('1')
				end,
			},
		},
	}
]]

function D.Open(menu)
	local frame = D.GetFrame()
	if not frame then
		frame = Wnd.OpenWindow(SZ_INI, 'MY_PopupMenu')
	end
	frame:SetDS(menu)
end

function D.Close()
	local frame = D.GetFrame()
	if frame then
		Wnd.CloseWindow(frame)
	end
end

function D.GetFrame()
	for _, v in ipairs(LAYER_LIST) do
		local frame = Station.Lookup(v .. '/MY_PopupMenu')
		if frame then
			return frame
		end
	end
end

function D.SetDS(frame, menu)
	frame.aMenu = {menu}
	D.UpdateUI(frame)
end

function D.AppendContentFromIni(parentWnd, szIni, szPath, szName)
	local frameTemp = Wnd.OpenWindow(szIni, 'MY_PopupMenu__TempWnd')
	local wnd = frameTemp:Lookup(szPath)
	if wnd then
		if szName then
			wnd:SetName(szName)
		end
		wnd:ChangeRelation(parentWnd, true, true)
	end
	Wnd.CloseWindow(frameTemp)
	return wnd
end

-----------------------------------------------
-- 判断两个菜单选项最上层菜单是不是一致
-----------------------------------------------
function D.IsEquals(m1, m2)
	if not m1 or not m2 then
		return false
	end
	if #m1 ~= #m2 then
		return false
	end
	for i = 1, #m1 do
		local ms1, ms2 = m1[i], m2[i]
		if ms1.szOption ~= ms2.szOption
		or ms1.bInline ~= ms2.bInline
		or (#ms1 == 0) ~= (#ms2 == 0) then
			return false
		end
		if ms1.bInline and not D.IsEquals(ms1, ms2) then
			return false
		end
	end
	return true
end

-- 更新鼠标进入状态防止闪烁 必须在刷新宽度后执行
function D.UpdateMouseOver(scroll, nCurX, nCurY)
	local container = scroll:Lookup('WndContainer_Menu')
	for i = 0, container:GetAllContentCount() - 1 do
		local wnd = container:LookupContent(i)
		if wnd:GetName() == 'Wnd_Item' then
			local h = wnd:Lookup('', '')
			h:Lookup('Image_Over'):SetVisible(not wnd.bDisable and h:PtInItem(nCurX, nCurY))
		elseif wnd:GetName() == 'WndScroll_Menu' then
			D.UpdateMouseOver(wnd, nCurX, nCurY)
		end
	end
end

-- 根据渲染的内容调整选项宽度（由于宽度受所有子元素影响 所以独立成函数在绘制结束后统一调用）
function D.UpdateScrollContainerWidth(scroll, nHeaderWidth, nContentWidth, nFooterWidth)
	local nWidth = nHeaderWidth + nContentWidth + nFooterWidth
	local container = scroll:Lookup('WndContainer_Menu')
	for i = 0, container:GetAllContentCount() - 1 do
		local wnd = container:LookupContent(i)
		if wnd:GetName() == 'Wnd_Item' then
			local h = wnd:Lookup('', '')
			local hHeader = h:Lookup('Handle_Item_L')
			local hContent = h:Lookup('Handle_Content')
			local hFooter = h:Lookup('Handle_Item_R')
			hHeader:SetW(nHeaderWidth)
			hContent:SetW(nContentWidth)
			hContent:SetRelX(nHeaderWidth)
			hFooter:SetW(nFooterWidth)
			hFooter:SetRelX(nHeaderWidth + nContentWidth)
			h:Lookup('Image_Over'):SetW(nWidth)
			h:Lookup('Image_Devide'):SetW(nWidth)
			h:SetW(nWidth)
			h:FormatAllItemPos()
			wnd:SetW(nWidth)
		elseif wnd:GetName() == 'WndScroll_Menu' then
			D.UpdateScrollContainerWidth(wnd, nHeaderWidth, nContentWidth, nFooterWidth)
		end
	end
	container:SetW(nWidth)
	-- 滚动条位置大小
	local nWidth, nHeight = container:GetSize()
	scroll:Lookup('Scroll_Menu'):SetH(nHeight)
	scroll:Lookup('Scroll_Menu'):SetRelX(nWidth)
	scroll:SetW(nWidth)
end

-- 绘制选项列表
function D.DrawScrollContainer(scroll, menu, bInlineContainer)
	local nMinWidth = menu.nMinWidth or 0
	local nHeaderWidth, nContentWidth, nFooterWidth = 10, 0, 10
	local container = scroll:Lookup('WndContainer_Menu')
	container:Clear()
	for _, m in ipairs(menu) do
		if menu.bInline then
			local scroll = container:AppendContentFromIni(SZ_TPL_INI, 'WndScroll_Menu')
			local n1, n2, n3 = D.DrawScrollContainer(scroll, menu, true)
			nHeaderWidth = max(nHeaderWidth, n1)
			nContentWidth = max(nContentWidth, n2)
			nFooterWidth = max(nFooterWidth, n3)
		else
			local wnd = container:AppendContentFromIni(SZ_TPL_INI, 'Wnd_Item')
			local h = wnd:Lookup('', '')
			local hHeader = h:Lookup('Handle_Item_L')
			local hContent = h:Lookup('Handle_Content')
			local hFooter = h:Lookup('Handle_Item_R')
			local imgDevide = h:Lookup('Image_Devide')
			if m.bDevide or m.bDivide then
				wnd.bDisable = true
				imgDevide:Show()
				wnd:SetH(imgDevide:GetH())
				hHeader:Hide()
				hContent:Hide()
				hFooter:Hide()
				h:ClearHoverElement()
			else
				if m.bDisable then
					wnd.bDisable = true
				else
					h.OnItemLButtonClick = m.fnAction
				end
				imgDevide:Hide()
				-- 左侧图标
				hHeader:Lookup('Handle_Check/Image_Check'):SetVisible(m.bCheck and m.bChecked)
				hHeader:Lookup('Handle_MCheck/Image_MCheck'):SetVisible(m.bMCheck and m.bChecked)
				hHeader:SetW(99999)
				hHeader:FormatAllItemPos()
				nHeaderWidth = max(nHeaderWidth, hHeader:GetAllItemSize())
				-- 正文
				local hContentInner = hContent:Lookup('Handle_ContentInner')
				local nFont = m.bDisable and DISABLE_FONT or ENABLE_FONT
				local rgb = m.rgb or CONSTANT.EMPTY_TABLE
				local r, g, b = rgb.r or rgb[1] or m.r, rgb.b or rgb[2] or m.g, rgb.g or rgb[3] or m.b
				hContentInner:AppendItemFromString(GetFormatText(m.szOption, nFont, r, g, b))
				hContentInner:SetW(99999)
				hContentInner:FormatAllItemPos()
				hContentInner:SetSizeByAllItemSize()
				hContentInner:SetRelY((hContent:GetH() - hContentInner:GetH()) / 2)
				hContent:SetW(hContentInner:GetW())
				hContent:FormatAllItemPos()
				nContentWidth = max(nContentWidth, hContent:GetW())
				-- 右侧图标
				if m.nPushCount then
					hFooter:Lookup('Handle_PushInfo/Text_PushInfo'):SetText(m.nPushCount)
					hFooter:Lookup('Handle_PushInfo'):Show()
				else
					hFooter:Lookup('Handle_PushInfo'):Hide()
				end
				hFooter:Lookup('Image_Color'):Hide()
				if m.aCustomIcon then
					for _, v in ipairs(m.aCustomIcon) do
						local img = h:AppendItemFromIni(SZ_TPL_INI, 'Image_CustomIcon')
						if v.szUITex and v.nFrame then
							img:FromUITex(v.szUITex, v.nFrame)
						elseif v.szUITex then
							img:FromTextureFile(v.szUITex)
						elseif v.nIconID then
							img:FromIconID(v.nIconID)
						end
						if v.nWidth then
							img:SetW(v.nWidth)
						end
						if v.nHeight then
							img:SetW(v.nHeight)
						end
						img:ChangeRelation(hFooter:Lookup('Image_Color'), true, false)
					end
				end
				hFooter:Lookup('Image_Child'):Hide()
				hFooter:SetW(99999)
				hFooter:FormatAllItemPos()
				nFooterWidth = max(nFooterWidth, hFooter:GetAllItemSize())
			end
		end
	end
	-- 滚动区域最大高度
	container:FormatAllContentPos()
	local _, nHeight = container:GetAllContentSize()
	if menu.nMaxHeight then
		nHeight = min(nHeight, menu.nMaxHeight)
	end
	container:SetH(nHeight)
	scroll:SetH(nHeight)
	-- 非嵌套层则开始更新所有宽度
	if not bInlineContainer then
		nContentWidth = max(nMinWidth - nHeaderWidth - nFooterWidth, nContentWidth)
		D.UpdateScrollContainerWidth(scroll, nHeaderWidth, nContentWidth, nFooterWidth)
		D.UpdateMouseOver(scroll, Cursor.GetPos())
	end
	return nHeaderWidth, nContentWidth, nFooterWidth
end

function D.UpdateWnd(wnd, menu)
	if D.IsEquals(wnd.menuSnapshot, menu) then
		return
	end
	-- 绘制列表
	local scroll = wnd:Lookup('WndScroll_Menu')
	local container = scroll:Lookup('WndContainer_Menu')
	D.DrawScrollContainer(scroll, menu, false)
	-- 绘制背景
	local nWidth, nHeight = container:GetSize()
	wnd:SetSize(nWidth + 10, nHeight + 10)
	wnd:Lookup('', ''):SetSize(nWidth + 10, nHeight + 10)
	wnd:Lookup('', 'Image_Bg'):SetSize(nWidth + 10, nHeight + 10)
	wnd.menuSnapshot = Clone(menu)
end

-- 判断一个菜单配置项是不是另一个的子项
function D.IsSubMenu(menu, t)
	for _, v in pairs(menu) do
		if v == t then
			return true
		end
		if v.bInline and D.IsSubMenu(v, t) then
			return true
		end
	end
	return false
end

-- 根据menu数据刷新显示
function D.UpdateUI(frame)
	-- 销毁模板
	local wnd = frame:Lookup('Wnd_Menu')
	if wnd then
		wnd:Destroy()
	end
	-- 逐个绘制菜单
	local aMenu, bExist = frame.aMenu, true
	for nLevel = 1, #aMenu do
		local menu = aMenu[nLevel]
		local wnd = frame:Lookup('Wnd_Menu' .. nLevel)
		if nLevel > 1 then
			bExist = D.IsSubMenu(aMenu[nLevel - 1], menu)
		end
		if bExist then -- 确认绘制
			if not wnd then
				wnd = D.AppendContentFromIni(frame, SZ_TPL_INI, 'Wnd_Menu', 'Wnd_Menu' .. nLevel)
			end
			D.UpdateWnd(wnd, menu)
		else -- 需要清理的菜单（已不存在）
			if wnd then
				wnd:Destroy()
			end
			aMenu[nLevel] = nil
		end
	end
end

function D.OnFrameCreate()
	this.SetDS = D.SetDS
end

function D.OnFrameBreathe()
	D.UpdateUI(this)
end

-- Global exports
do
local settings = {
	exports = {
		{
			fields = {
				Open = D.Open,
				Close = D.Close,
			},
		},
		{
			root = D,
			preset = 'UIEvent'
		},
	},
}
MY_PopupMenu = LIB.GeneGlobalNS(settings)
end
