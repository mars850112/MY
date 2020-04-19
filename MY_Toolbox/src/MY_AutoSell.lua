--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 自动售出物品
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
local HUGE, PI, random, abs = math.huge, math.pi, math.random, math.abs
local min, max, floor, ceil, modf = math.min, math.max, math.floor, math.ceil, math.modf
local pow, sqrt, sin, cos, tan, atan = math.pow, math.sqrt, math.sin, math.cos, math.tan, math.atan
local insert, remove, concat, sort = table.insert, table.remove, table.concat, table.sort
local pack, unpack = table.pack or function(...) return {...} end, table.unpack or unpack
-- jx3 apis caching
local wsub, wlen, wfind, wgsub = wstring.sub, wstring.len, StringFindW, StringReplaceW
local GetTime, GetLogicFrameCount, GetCurrentTime = GetTime, GetLogicFrameCount, GetCurrentTime
local GetClientTeam, UI_GetClientPlayerID = GetClientTeam, UI_GetClientPlayerID
local GetClientPlayer, GetPlayer, GetNpc, IsPlayer = GetClientPlayer, GetPlayer, GetNpc, IsPlayer
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
local MODULE_NAME = 'MY_Toolbox'
local _L = LIB.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not LIB.AssertVersion(MODULE_NAME, _L[MODULE_NAME], 0x2013900) then
	return
end
--------------------------------------------------------------------------

local D = {}
local O = {
	bEnable = false, -- 打开商店后自动售出总开关
	bSellGray = true, -- 自动出售灰色物品
	bSellWhiteBook = false, -- 自动出售已读白书
	bSellGreenBook = false, -- 自动出售已读绿书
	bSellBlueBook = false, -- 自动出售已读蓝书
	tSellItem = {
		[LIB.GetObjectName('ITEM_INFO', 5, 2863)] = true, -- 银叶子
		[LIB.GetObjectName('ITEM_INFO', 5, 2864)] = true, -- 真银叶子
		[LIB.GetObjectName('ITEM_INFO', 5, 2865)] = true, -- 大片真银叶子
		[LIB.GetObjectName('ITEM_INFO', 5, 2866)] = true, -- 金粉末
		[LIB.GetObjectName('ITEM_INFO', 5, 2867)] = true, -- 金叶子
		[LIB.GetObjectName('ITEM_INFO', 5, 2868)] = true, -- 大片金叶子
		[LIB.GetObjectName('ITEM_INFO', 5, 11682)] = true, -- 金条
		[LIB.GetObjectName('ITEM_INFO', 5, 11683)] = true, -- 金块
		[LIB.GetObjectName('ITEM_INFO', 5, 11640)] = true, -- 金砖
		[LIB.GetObjectName('ITEM_INFO', 5, 17130)] = true, -- 银叶子·试炼之地
		[LIB.GetObjectName('ITEM_INFO', 5, 22974)] = true, -- 破碎的金玄玉
	},
	tProtectItem = {
		[LIB.GetObjectName('ITEM_INFO', 5, 789)] = true, -- 真丝肚兜
		[LIB.GetObjectName('ITEM_INFO', 5, 797)] = true, -- 春宫图册
	},
}
RegisterCustomData('MY_AutoSell.bEnable', 2)
RegisterCustomData('MY_AutoSell.bSellGray')
RegisterCustomData('MY_AutoSell.bSellWhiteBook')
RegisterCustomData('MY_AutoSell.bSellGreenBook')
RegisterCustomData('MY_AutoSell.bSellBlueBook')
RegisterCustomData('MY_AutoSell.tSellItem')
RegisterCustomData('MY_AutoSell.tProtectItem')

-- 自动售出物品
function D.AutoSellItem(nNpcID, nShopID)
	local me = GetClientPlayer()
	local nIndex = LIB.GetBagPackageIndex()
	for dwBox = nIndex, nIndex + LIB.GetBagPackageCount() do
		local dwSize = me.GetBoxSize(dwBox) - 1
		for dwX = 0, dwSize do
			local item = me.GetItem(dwBox, dwX)
			if item and item.bCanTrade then
				local bSell, szReason = item.nQuality == 0, ''
				local szName = LIB.GetObjectName(item)
				if not O.tProtectItem[szName] then
					if not bSell and O.tSellItem[szName] then
						bSell = true
						szReason = _L['specified']
					end
					if not bSell and item.nGenre == ITEM_GENRE.BOOK and me.IsBookMemorized(GlobelRecipeID2BookID(item.nBookID)) then
						if O.bSellWhiteBook and item.nQuality == 1 then
							bSell = true
							szReason = _L['read white book']
						elseif O.bSellGreenBook and item.nQuality == 2 then
							bSell = true
							szReason = _L['read green book']
						elseif O.bSellBlueBook and item.nQuality == 3 then
							bSell = true
							szReason = _L['read blue book']
						end
					end
				end
				if bSell then
					local nCount = 1
					if item.nGenre == ITEM_GENRE.EQUIPMENT and item.nSub == EQUIPMENT_SUB.ARROW then --远程武器
						nCount = item.nCurrentDurability
					elseif item.bCanStack then
						nCount = item.nStackNum
					end
					SellItem(nNpcID, nShopID, dwBox, dwX, nCount)
					LIB.Sysmsg(_L('Auto sell %s item: %s.', szReason, szName))
				end
			end
		end
	end
end

function D.CheckEnable()
	if O.bEnable then
		LIB.RegisterEvent('SHOP_OPENSHOP', function()
			D.AutoSellItem(arg4, arg0)
		end)
	else
		LIB.RegisterEvent('SHOP_OPENSHOP', false)
	end
end
LIB.RegisterInit('MY_AutoSell', D.CheckEnable)

function D.OnPanelActivePartial(ui, X, Y, W, H, x, y)
	ui:Append('WndComboBox', {
		x = W - 150, y = 50, w = 130,
		text = _L['Auto sell items'],
		menu = function()
			local m0 = {
				{ szOption = _L['Auto sell when open shop'], bDisable = true },
				{
					szOption = _L['Enable'],
					bCheck = true, bChecked = MY_AutoSell.bEnable,
					fnAction = function(d, b) MY_AutoSell.bEnable = b end,
				},
				{
					szOption = _L['Sell grey items'],
					bCheck = true, bChecked = MY_AutoSell.bSellGray,
					fnAction = function(d, b) MY_AutoSell.bSellGray = b end,
					fnDisable = function() return not MY_AutoSell.bEnable end,
				},
				{
					szOption = _L['Sell read white books'],
					bCheck = true, bChecked = MY_AutoSell.bSellWhiteBook,
					fnAction = function(d, b) MY_AutoSell.bSellWhiteBook = b end,
					fnDisable = function() return not MY_AutoSell.bEnable end,
				},
				{
					szOption = _L['Sell read green books'], bCheck = true, bChecked = MY_AutoSell.bSellGreenBook,
					fnAction = function(d, b) MY_AutoSell.bSellGreenBook = b end,
					fnDisable = function() return not MY_AutoSell.bEnable end
				},
				{
					szOption = _L['Sell read blue books'], bCheck = true, bChecked = MY_AutoSell.bSellBlueBook,
					fnAction = function(d, b) MY_AutoSell.bSellBlueBook = b end,
					fnDisable = function() return not MY_AutoSell.bEnable end,
				},
				{ bDevide = true },
			}
			-- 自定义售卖物品
			local m1 = {
				szOption = _L['Sell specified items'],
				fnDisable = function() return not MY_AutoSell.bEnable end,
				{
					szOption = _L['* New *'],
					fnAction = function()
						GetUserInput(_L['Name of item'], function(szText)
							local szText = gsub(szText, '^%s*%[?(.-)%]?%s*$', '%1')
							if szText ~= '' then
								MY_AutoSell.tSellItem[szText] = true
							end
						end)
					end
				},
				{ bDevide = true },
			}
			local m2 = { bInline = true, nMaxHeight = 550 }
			for k, v in pairs(MY_AutoSell.tSellItem) do
				insert(m2, {
					szOption = k, bCheck = true, bChecked = v, fnAction = function(d, b) MY_AutoSell.tSellItem[k] = b end,
					{
						szOption = _L['Remove'],
						fnAction = function()
							MY_AutoSell.tSellItem[k] = nil
							for i, v in ipairs(m2) do
								if v.szOption == k then
									remove(m2, i)
									break
								end
							end
							return 0
						end,
					},
				})
			end
			insert(m1, m2)
			insert(m0, m1)
			-- 自定义不卖物品
			local m1 = {
				szOption = _L['Protect specified items'],
				fnDisable = function() return not MY_AutoSell.bEnable end,
				{
					szOption = _L['* New *'],
					fnAction = function()
						GetUserInput(_L['Name of item'], function(szText)
							local szText = gsub(szText, '^%s*%[?(.-)%]?%s*$', '%1')
							if szText ~= '' then
								MY_AutoSell.tProtectItem[szText] = true
							end
						end)
					end
				},
				{ bDevide = true },
			}
			local m2 = { bInline = true, nMaxHeight = 550 }
			for k, v in pairs(MY_AutoSell.tProtectItem) do
				insert(m2, {
					szOption = k, bCheck = true, bChecked = v, fnAction = function(d, b) MY_AutoSell.tProtectItem[k] = b end,
					{
						szOption = _L['Remove'],
						fnAction = function()
							MY_AutoSell.tProtectItem[k] = nil
							for i, v in ipairs(m2) do
								if v.szOption == k then
									remove(m2, i)
									break
								end
							end
							return 0
						end,
					},
				})
			end
			insert(m1, m2)
			insert(m0, m1)
			return m0
		end,
	})
	return x, y
end

-- Global exports
do
local settings = {
	exports = {
		{
			fields = {
				OnPanelActivePartial = D.OnPanelActivePartial,
			},
		},
		{
			fields = {
				bEnable = true,
				bSellGray = true,
				bSellWhiteBook = true,
				bSellGreenBook = true,
				bSellBlueBook = true,
				tSellItem = true,
				tProtectItem = true,
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				bEnable = true,
				bSellGray = true,
				bSellWhiteBook = true,
				bSellGreenBook = true,
				bSellBlueBook = true,
				tSellItem = true,
				tProtectItem = true,
			},
			triggers = {
				bEnable = D.CheckEnable,
			},
			root = O,
		},
	},
}
MY_AutoSell = LIB.GeneGlobalNS(settings)
end
