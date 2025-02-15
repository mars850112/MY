--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 成就查询
-- @author   : 茗伊 @双梦镇 @追风蹑影
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
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
local PLUGIN_NAME = 'MY_Toolbox'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_Toolbox'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
--------------------------------------------------------------------------

local O = X.CreateUserSettingsModule('MY_AchievementWiki', _L['General'], {
	bEnable = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Toolbox'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	nW = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Toolbox'],
		xSchema = X.Schema.Number,
		xDefaultValue = 850,
	},
	nH = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Toolbox'],
		xSchema = X.Schema.Number,
		xDefaultValue = 610,
	},
})
local D = {}

function D.OnWebSizeChange()
	O.nW, O.nH = this:GetSize()
end

function D.Open(dwAchievement)
	local achi = X.GetAchievement(dwAchievement)
	if not achi then
		return
	end
	local szURL = 'https://page.j3cx.com/wiki/' .. dwAchievement .. '?'
		.. X.EncodePostData(X.UrlEncode({
			l = AnsiToUTF8(GLOBAL.GAME_LANG),
			L = AnsiToUTF8(GLOBAL.GAME_EDITION),
			player = AnsiToUTF8(GetUserRoleName()),
		}))
	local szKey = 'AchievementWiki_' .. dwAchievement
	local szTitle = achi.szName .. ' - ' .. achi.szDesc
	szKey = UI.OpenBrowser(szURL, {
		key = szKey,
		title = szTitle,
		w = O.nW, h = O.nH,
		readonly = true,
	})
	UI(UI.LookupBrowser(szKey)):Size(D.OnWebSizeChange)
end

function D.OnAchieveItemMouseEnter()
	if O.bEnable then
		this:SetObjectMouseOver(true)
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		local xml = {}
		table.insert(xml, GetFormatText(_L['Click for achievement wiki'], 41))
		if IsCtrlKeyDown() then
			local h = this:GetParent()
			local t = {}
			for k, v in pairs(h) do
				if k ~= '___id' and k ~= '___type' then
					table.insert(t, k .. ': ' .. X.EncodeLUAData(v, '  '))
				end
			end
			table.insert(xml, GetFormatText('\n\n' .. g_tStrings.DEBUG_INFO_ITEM_TIP .. '\n', 102))
			table.insert(xml, GetFormatText(table.concat(t, '\n'), 102))
		end
		OutputTip(table.concat(xml), 300, { x, y, w, h })
	end
end

function D.OnAchieveItemMouseLeave()
	if O.bEnable then
		this:SetObjectMouseOver(false)
		HideTip()
	end
end

function D.OnAchieveItemLButtonClick()
	local name = this:GetName()
	if name == 'Box_AchiBox' and O.bEnable then
		D.Open(this:GetParent().dwAchievement)
	end
end

function D.OnAchieveAppendItem(res, hList)
	local hItem = res[1]
	if not hItem then
		return
	end
	local boxAchi = hItem:Lookup('Box_AchiBox') or hItem:Lookup('Box_AchiBoxShort')
	local txtName = hItem:Lookup('Text_AchiName')
	local txtDescribe = hItem:Lookup('Text_AchiDescribe')
	if not boxAchi or not txtName or not txtDescribe then
		return
	end
	boxAchi:RegisterEvent(ITEM_EVENT.LBUTTONCLICK)
	boxAchi:RegisterEvent(ITEM_EVENT.MOUSEENTERLEAVE)
	UnhookTableFunc(boxAchi, 'OnItemMouseEnter', D.OnAchieveItemMouseEnter)
	UnhookTableFunc(boxAchi, 'OnItemMouseLeave', D.OnAchieveItemMouseLeave)
	UnhookTableFunc(boxAchi, 'OnItemLButtonClick', D.OnAchieveItemLButtonClick)
	HookTableFunc(boxAchi, 'OnItemMouseEnter', D.OnAchieveItemMouseEnter)
	HookTableFunc(boxAchi, 'OnItemMouseLeave', D.OnAchieveItemMouseLeave)
	HookTableFunc(boxAchi, 'OnItemLButtonClick', D.OnAchieveItemLButtonClick)
end

function D.HookAchieveHandle(h)
	if not h then
		return
	end
	for i = 0, h:GetItemCount() - 1 do
		D.OnAchieveAppendItem({h:Lookup(i)}, h)
	end
	HookTableFunc(h, 'AppendItemFromData', D.OnAchieveAppendItem, { bAfterOrigin = true, bPassReturn = true })
end

function D.HookAchieveFrame(frame)
	D.HookAchieveHandle(frame:Lookup('PageSet_Achievement/Page_Achievement/WndScroll_AShow', ''))
	D.HookAchieveHandle(frame:Lookup('PageSet_Achievement/Page_TopRecord/WndScroll_TRShow', ''))
	D.HookAchieveHandle(frame:Lookup('PageSet_Achievement/Page_Summary/WndContainer_AchiPanel/PageSet_Achi/Page_Chi/PageSet_RecentAchi/Page_Scene', ''))
	D.HookAchieveHandle(frame:Lookup('PageSet_Achievement/Page_Summary/WndContainer_AchiPanel/PageSet_Achi/Page_Chi/PageSet_RecentAchi/Page_AlmostFinish', ''))
end

X.RegisterInit('MY_AchievementWiki', function()
	local frame = Station.Lookup('Normal/AchievementPanel')
	if not frame then
		return
	end
	D.HookAchieveFrame(frame)
end)

X.RegisterFrameCreate('AchievementPanel', 'MY_AchievementWiki', function(name, frame)
	D.HookAchieveFrame(frame)
end)

function D.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nX, nY)
	nX = nX + ui:Append('WndCheckBox', {
		x = nX, y = nY, w = 'auto',
		text = _L['Achievement wiki'],
		tip = _L['Click icon on achievemnt panel to view achievement wiki'],
		tippostype = UI.TIP_POSITION.BOTTOM_TOP,
		checked = MY_AchievementWiki.bEnable,
		oncheck = function(bChecked)
			MY_AchievementWiki.bEnable = bChecked
		end,
	}):Width() + 5
	return nX, nY
end

-- Global exports
do
local settings = {
	name = 'MY_AchievementWiki',
	exports = {
		{
			fields = {
				'Open',
				'OnPanelActivePartial',
			},
			root = D,
		},
		{
			fields = {
				'bEnable',
				'nW',
				'nH',
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				'bEnable',
				'nW',
				'nH',
			},
			root = O,
		},
	},
}
MY_AchievementWiki = X.CreateModule(settings)
end
