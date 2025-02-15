--------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : 请求处理弹框界面
-- @copyright: Copyright (c) 2009 Kingsoft Co., Ltd.
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
local _L = X.LoadLangPack(X.PACKET_INFO.FRAMEWORK_ROOT .. 'lang/lib/')

local D = {}
local INI_PATH = X.PACKET_INFO.FRAMEWORK_ROOT .. 'ui/Request.ini'
local REQUEST_LIST = {}
local REQUEST_HANDLER = {}
local FRAME_NAME = X.NSFormatString('{$NS}_Request')

function D.GetFrame()
	return Station.SearchFrame(FRAME_NAME)
end

function D.Open()
	local frame = D.GetFrame()
	if not frame then
		frame = Wnd.OpenWindow(INI_PATH, FRAME_NAME)
	end
	return frame
end

function D.Close(bCompulsory)
	local function fnAction()
		REQUEST_LIST = {}
		Wnd.CloseWindow(D.GetFrame())
		for _, v in pairs(REQUEST_HANDLER) do
			X.SafeCall(v.OnClear)
		end
	end
	if bCompulsory or X.IsEmpty(REQUEST_LIST) then
		fnAction()
	else
		X.Confirm(_L['Clear list and close?'], fnAction)
	end
end

function D.RegisterRequest(szType, tHandler)
	if REQUEST_HANDLER[szType] then
		return X.Debug(FRAME_NAME, szType .. ' type already registered!', X.DEBUG_LEVEL.ERROR)
	end
	REQUEST_HANDLER[szType] = {
		szIconUITex = tHandler.szIconUITex,
		nIconFrame = tHandler.nIconFrame,
		Drawer = tHandler.Drawer,
		GetTip = tHandler.GetTip,
		GetIcon = tHandler.GetIcon,
		GetMenu = tHandler.GetMenu,
		OnClear = tHandler.OnClear,
	}
end

function D.Replace(szType, szKey, data)
	if not REQUEST_HANDLER[szType] then
		return X.Debug(FRAME_NAME, szType .. ' type not registered yet!', X.DEBUG_LEVEL.ERROR)
	end
	local bExist
	for i, v in X.ipairs_r(REQUEST_LIST) do
		if v.szType == szType and v.szKey == szKey then
			bExist = true
			v.data = data
		end
	end
	if not bExist then
		table.insert(REQUEST_LIST, { szType = szType, szKey = szKey, data = data })
	end
	X.DelayCall(FRAME_NAME .. '_Update', 1, D.RedrawList)
end

function D.RemoveRequest(szType, szKey)
	local bExist
	for i, v in X.ipairs_r(REQUEST_LIST) do
		if v.szType == szType and v.szKey == szKey then
			bExist = true
			table.remove(REQUEST_LIST, i)
		end
	end
	if not bExist then
		return
	end
	X.DelayCall(FRAME_NAME .. '_Update', 1, D.RedrawList)
end

function D.RedrawList()
	local frame = #REQUEST_LIST > 0
		and D.Open()
		or D.Close(true)
	if not frame then
		return
	end
	local scroll = frame:Lookup('Scroll_Request')
	local scrollbar = scroll:Lookup('ScrolBar_Request')
	local container = scroll:Lookup('WndContainer_Request')
	local nSumH = 0
	container:Clear()
	for i, info in ipairs(REQUEST_LIST) do
		local wnd = container:AppendContentFromIni(INI_PATH, 'WndWindow_Item')
		local handler = REQUEST_HANDLER[info.szType]
		local inner, nH = handler.Drawer(wnd, info.data)
		if inner then
			inner:SetName('Wnd_Content')
			inner:SetRelPos(56, 0)
			nH = inner:GetH()
			wnd:Lookup('', 'Image_Hover'):SetH(nH)
			wnd:Lookup('', 'Image_TypeIcon'):SetRelY((nH - wnd:Lookup('', 'Image_TypeIcon'):GetH()) / 2)
			wnd:Lookup('', 'Image_Spliter'):SetRelY(nH - 8)
			wnd:Lookup('', ''):FormatAllItemPos()
			wnd:SetH(nH)
		else
			X.Debug(FRAME_NAME, info.szType .. '#' .. info.szKey .. ' drawer does not return a wnd!', X.DEBUG_LEVEL.ERROR)
		end
		local szIconUITex, nIconFrame = handler.szIconUITex, handler.nIconFrame
		if handler.GetIcon then
			szIconUITex, nIconFrame = handler.GetIcon(info.data, szIconUITex, nIconFrame)
		end
		if szIconUITex == 'FromIconID' then
			wnd:Lookup('', 'Image_TypeIcon'):FromIconID(nIconFrame)
		elseif szIconUITex and nIconFrame and nIconFrame >= 0 then
			wnd:Lookup('', 'Image_TypeIcon'):FromUITex(szIconUITex, nIconFrame)
		elseif szIconUITex then
			wnd:Lookup('', 'Image_TypeIcon'):FromTextureFile(szIconUITex)
		end
		wnd:Lookup('', 'Image_Spliter'):SetVisible(i ~= #REQUEST_LIST)
		wnd.info = info
		nSumH = nSumH + nH
	end
	nSumH = math.min(nSumH, 475)
	scroll:SetH(nSumH)
	scrollbar:SetH(nSumH - 2)
	container:SetH(nSumH)
	container:FormatAllContentPos()
	frame:Lookup('', 'Image_Bg'):SetH(nSumH + 4)
	frame:SetH(nSumH + 30 + 4)
end

function D.OnFrameCreate()
	this:SetPoint('CENTER', 0, -200, 'CENTER', 0, 0)
	this:Lookup('', 'Text_Title'):SetText(_L['Request list'])
	X.RegisterEsc(X.NSFormatString('{$NS}_PartyRequest'), D.GetFrame, D.Close)
end

function D.OnItemMouseEnter()
	local name = this:GetName()
	if name == 'Image_TypeIcon' then
		local info = this:GetParent():GetParent().info
		local GetTip = REQUEST_HANDLER[info.szType].GetTip
		if GetTip then
			local x, y = this:GetAbsPos()
			local w, h = this:GetSize()
			local szTip = GetTip(info.data)
			OutputTip(szTip, 450, {x, y, w, h}, UI.TIP_POSITION.TOP_BOTTOM)
		end
	end
end

function D.OnItemMouseLeave()
	local name = this:GetName()
	if name == 'Image_TypeIcon' then
		HideTip()
	end
end

function D.OnLButtonClick()
	local name = this:GetName()
	if name == 'Btn_Setting' then
		local menu = {}
		for _, v in pairs(REQUEST_HANDLER) do
			if v.GetMenu then
				table.insert(menu, v.GetMenu())
			end
		end
		if #menu > 0 then
			PopupMenu(menu)
		end
	elseif name == 'Btn_Close' then
		D.Close()
	end
end

-- Global exports
do
local settings = {
	name = FRAME_NAME,
	exports = {
		{
			preset = 'UIEvent',
			root = D,
		},
	},
}
_G[FRAME_NAME] = X.CreateModule(settings)
end

UI.OpenRequest = D.Open
UI.CloseRequest = D.Close
UI.RegisterRequest = D.RegisterRequest
UI.ReplaceRequest = D.Replace
UI.RemoveRequest = D.RemoveRequest
