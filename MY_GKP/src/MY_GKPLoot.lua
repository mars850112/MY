--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 金团记录 拾取界面
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
local PLUGIN_NAME = 'MY_GKP'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_GKP'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
X.RegisterRestriction('MY_GKPLoot.FastLoot', { ['*'] = true })
X.RegisterRestriction('MY_GKPLoot.ForceLoot', { ['*'] = true })
--------------------------------------------------------------------------

local DEBUG_LOOT = false -- 测试拾取分配 强制进入分配模式并最终不调用分配接口
local GKP_LOOT_INIFILE = PLUGIN_ROOT .. '/ui/MY_GKPLoot.ini'
local MY_GKP_LOOT_BOSS -- 散件老板
local GKP_AUTO_LOOT_DEBOUNCE_TIME = GLOBAL.GAME_FPS / 2 -- 自动拾取时延

local GKP_LOOT_HUANGBABA_ICON = 2589 -- 玄晶图标
local GKP_LOOT_HUANGBABA_QUALITY = CONSTANT.ITEM_QUALITY.NACARAT -- 玄晶品级
local GKP_LOOT_ZIBABA_ICON = 2588 -- 小铁图标
local GKP_LOOT_ZIBABA_QUALITY = CONSTANT.ITEM_QUALITY.PURPLE -- 小铁品级

local GKP_LOOT_RECENT = {} -- 记录上次物品或物品组分配给了谁
local GKP_ITEM_QUALITIES = {
	{ nQuality = CONSTANT.ITEM_QUALITY.WHITE  , szTitle = g_tStrings.STR_WHITE               },
	{ nQuality = CONSTANT.ITEM_QUALITY.GREEN  , szTitle = g_tStrings.STR_ROLLQUALITY_GREEN   },
	{ nQuality = CONSTANT.ITEM_QUALITY.BLUE   , szTitle = g_tStrings.STR_ROLLQUALITY_BLUE    },
	{ nQuality = CONSTANT.ITEM_QUALITY.PURPLE , szTitle = g_tStrings.STR_ROLLQUALITY_PURPLE  },
	{ nQuality = CONSTANT.ITEM_QUALITY.NACARAT, szTitle = g_tStrings.STR_ROLLQUALITY_NACARAT },
}

local O = X.CreateUserSettingsModule('MY_GKPLoot', _L['General'], {
	bOn = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bInTeamDungeon = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	bInRaidDungeon = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	bInBattlefield = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	bInOtherMap = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	anchor = {
		ePathType = X.PATH_TYPE.ROLE,
		xSchema = X.Schema.FrameAnchor,
		xDefaultValue = { x = 0, y = 0, s = 'CENTER', r = 'CENTER' },
	},
	bVertical = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	bSetColor = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	nConfirmQuality = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Number,
		xDefaultValue = 3,
	},
	bShow2ndKungfuLoot = { -- 显示第二心法装备推荐提示图标
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	tConfirm = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Map(X.Schema.String, X.Schema.Boolean),
		xDefaultValue = {
			Huangbaba  = true,
			Book       = true,
			Pendant    = true,
			Outlook    = true,
			Pet        = true,
			Horse      = true,
			HorseEquip = true,
		},
	},
	tFilterQuality = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Map(X.Schema.Number, X.Schema.Boolean),
		xDefaultValue = {},
	},
	bFilterGrayItem = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bNameFilter = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	tNameFilter = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Map(X.Schema.String, X.Schema.Boolean),
		xDefaultValue = {},
	},
	bFilterBookRead = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bFilterBookHave = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bAutoPickupFilterBookRead = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bAutoPickupFilterBookHave = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bAutoPickupTaskItem = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bAutoPickupBook = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	bAutoPickupQuality = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	tAutoPickupQuality = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Map(X.Schema.Number, X.Schema.Boolean),
		xDefaultValue = (function()
			local t = {}
			for _, p in ipairs(GKP_ITEM_QUALITIES) do
				t[p.nQuality] = true
			end
			return t
		end)(),
	},
	tAutoPickupNames = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Map(X.Schema.String, X.Schema.Boolean),
		xDefaultValue = {},
	},
	tAutoPickupFilters = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_GKPLoot'],
		xSchema = X.Schema.Map(X.Schema.String, X.Schema.Boolean),
		xDefaultValue = {},
	},
})
local D = {
	aDoodadID = {},
}
local ITEM_CONFIG = setmetatable({}, {
	__index = function(_, k)
		if k == 'bFilterGrayItem'
			or k == 'tNameFilter'
			or k == 'bFilterBookRead'
			or k == 'bFilterBookHave'
			or k == 'bAutoPickupFilterBookRead'
			or k == 'bAutoPickupFilterBookHave'
			or k == 'bAutoPickupTaskItem'
			or k == 'bAutoPickupBook'
			or k == 'bAutoPickupQuality'
			or k == 'tAutoPickupQuality'
			or k == 'tAutoPickupNames'
			or k == 'tAutoPickupFilters'
		then
			return O[k]
		end
		if k == 'tFilterQuality'
			or k == 'bNameFilter'
		then
			return D[k]
		end
	end,
	__newindex = function(_, k, v)
		if k == 'bFilterGrayItem'
			or k == 'tNameFilter'
			or k == 'bFilterBookRead'
			or k == 'bFilterBookHave'
			or k == 'bAutoPickupFilterBookRead'
			or k == 'bAutoPickupFilterBookHave'
			or k == 'bAutoPickupTaskItem'
			or k == 'bAutoPickupBook'
			or k == 'bAutoPickupQuality'
			or k == 'tAutoPickupQuality'
			or k == 'tAutoPickupNames'
			or k == 'tAutoPickupFilters'
		then
			O[k] = v
		elseif k == 'tFilterQuality'
			or k == 'bNameFilter'
		then
			D[k] = v
		end
	end,
})
RegisterCustomData('MY_GKP_Loot.tConfirm')
RegisterCustomData('MY_GKP_Loot.tItemConfig')

function D.UpdateShielded()
	GKP_AUTO_LOOT_DEBOUNCE_TIME = X.IsRestricted('MY_GKPLoot.FastLoot')
		and GLOBAL.GAME_FPS / 2
		or 0
end

X.RegisterEvent('MY_RESTRICTION', 'MY_GKPLoot', function()
	if arg0 and arg0 ~= 'MY_GKPLoot.FastLoot' then
		return
	end
	D.UpdateShielded()
end)

X.RegisterEvent('LOADING_END', 'MY_GKPLoot', function()
	D.UpdateShielded()
	D.aDoodadID = {}
	ITEM_CONFIG.tFilterQuality = {}
	ITEM_CONFIG.bNameFilter = false
end)

X.RegisterInit('MY_GKPLoot', function()
	for _, k in ipairs({'tConfirm'}) do
		if D[k] then
			X.SafeCall(X.Set, O, k, D[k])
			D[k] = nil
		end
	end
	if D.tItemConfig and X.IsTable(D.tItemConfig) then
		for k, v in pairs(D.tItemConfig) do
			X.SafeCall(X.Set, O, k, v)
		end
		D.tItemConfig = nil
	end
	D.bReady = true
end)

function D.IsEnabled()
	if not D.bReady then
		return false
	end
	if not O.bOn then
		return false
	end
	if O.bInTeamDungeon and O.bInRaidDungeon and O.bInBattlefield and O.bInOtherMap then
		return true
	end
	if X.IsInDungeon(false) then
		return O.bInTeamDungeon
	end
	if X.IsInDungeon(true) then
		return O.bInRaidDungeon
	end
	if X.IsInBattleField() or X.IsInPubg() or X.IsInZombieMap() then
		return O.bInBattlefield
	end
	return O.bInOtherMap
end

function D.OutputEnable()
	X.Systopmsg(
		D.IsEnabled()
			and _L['MY_GKPLoot enabled in current map']
			or _L['MY_GKPLoot disabled in current map']
	)
end

function D.CanDialog(tar, doodad)
	return doodad.CanDialog(tar)
end

function D.IsItemDisplay(itemData, config)
	if X.IsTable(config.tFilterQuality) and config.tFilterQuality[itemData.nQuality] then
		return false
	end
	-- 名称过滤
	if config.bNameFilter and config.tNameFilter[itemData.szName] then
		return false
	end
	-- 过滤已读、已有书籍
	if (config.bFilterBookRead or config.bFilterBookHave) and itemData.nGenre == ITEM_GENRE.BOOK then
		local me = GetClientPlayer()
		if config.bFilterBookRead then
			local nBookID, nSegmentID = X.RecipeToSegmentID(itemData.nBookID)
			if me and me.IsBookMemorized(nBookID, nSegmentID) then
				return false
			end
		end
		if config.bFilterBookHave then
			if X.GetItemAmountInAllPackages(itemData.dwTabType, itemData.dwIndex, itemData.nBookID) > 0 then
				return false
			end
		end
	end
	-- 过滤灰色物品
	if config.bFilterGrayItem and itemData.nQuality == CONSTANT.ITEM_QUALITY.GRAY then
		return false
	end
	return true
end

function D.IsItemAutoPickup(itemData, config, doodad, bCanDialog)
	if not bCanDialog then
		return false
	end
	-- 超过可拾取上限则不捡
	local itemInfo = GetItemInfo(itemData.dwTabType, itemData.dwIndex)
	if itemInfo and itemInfo.nMaxExistAmount > 0
	and X.GetItemAmountInAllPackages(itemData.dwTabType, itemData.dwIndex, itemData.nBookID) + itemData.nStackNum > itemInfo.nMaxExistAmount then
		return false
	end
	-- 不拾取已读、已有书籍
	if (config.bAutoPickupFilterBookRead or config.bAutoPickupFilterBookHave) and itemData.nGenre == ITEM_GENRE.BOOK then
		local me = GetClientPlayer()
		if config.bAutoPickupFilterBookRead then
			local nBookID, nSegmentID = X.RecipeToSegmentID(itemData.nBookID)
			if me and me.IsBookMemorized(nBookID, nSegmentID) then
				return false
			end
		end
		if config.bAutoPickupFilterBookHave then
			if X.GetItemAmountInAllPackages(itemData.dwTabType, itemData.dwIndex, itemData.nBookID) > 0 then
				return false
			end
		end
	end
	-- 自动拾取书籍
	if config.bAutoPickupBook and itemData.nGenre == ITEM_GENRE.BOOK then
		return true
	end
	-- 自动拾取过滤
	if config.tAutoPickupFilters and config.tAutoPickupFilters[itemData.szName] then
		return false
	end
	-- 自动拾取名单
	if config.tAutoPickupNames and config.tAutoPickupNames[itemData.szName] then
		return true
	end
	-- 自动拾取任务物品
	if config.bAutoPickupTaskItem and itemData.nGenre == ITEM_GENRE.TASK_ITEM then
		return true
	end
	-- 自动拾取品级
	if config.bAutoPickupQuality and config.tAutoPickupQuality[itemData.nQuality] then
		return true
	end
	return false
end

function D.CloseLootWindow()
	local me = GetClientPlayer()
	if me and X.GetOTActionState(me) == CONSTANT.CHARACTER_OTACTION_TYPE.ACTION_PICKING then
		me.OnCloseLootWindow()
	end
end

function D.OnFrameCreate()
	this:RegisterEvent('UI_SCALED')
	this:RegisterEvent('PARTY_LOOT_MODE_CHANGED')
	this:RegisterEvent('PARTY_DISBAND')
	this:RegisterEvent('PARTY_DELETE_MEMBER')
	this:RegisterEvent('DOODAD_LEAVE_SCENE')
	this:RegisterEvent('MY_GKP_LOOT_RELOAD')
	this:RegisterEvent('MY_GKP_LOOT_BOSS')
	local a = O.anchor
	this:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	this:Lookup('Scroll_DoodadList/WndContainer_DoodadList'):Clear()
	D.AdjustFrame(this)
end

function D.OnFrameBreathe()
	local nLFC = GetLogicFrameCount()
	local me = GetClientPlayer()
	local wnd = this:Lookup('Scroll_DoodadList/WndContainer_DoodadList'):LookupContent(0)
	while wnd do
		local doodad = GetDoodad(wnd.dwDoodadID)
		-- 拾取判定
		local bCanDialog = D.CanDialog(me, doodad)
		local hList, hItem = wnd:Lookup('', 'Handle_ItemList')
		for i = 0, hList:GetItemCount() - 1 do
			hItem = hList:Lookup(i)
			if (not hItem.nAutoLootLFC or nLFC - hItem.nAutoLootLFC >= GKP_AUTO_LOOT_DEBOUNCE_TIME)
			and D.IsItemAutoPickup(hItem.itemData, ITEM_CONFIG, doodad, bCanDialog)
			and not hItem.itemData.bDist and not hItem.itemData.bNeedRoll and not hItem.itemData.bBidding then
				X.ExecuteWithThis(hItem, D.OnItemLButtonClick)
				hItem.nAutoLootLFC = nLFC
			end
		end
		wnd:Lookup('', 'Image_DoodadTitleBg'):SetFrame(bCanDialog and 0 or 3)
		-- 目标距离
		local nDistance = 0
		if me and doodad then
			nDistance = math.floor(math.sqrt(math.pow(me.nX - doodad.nX, 2) + math.pow(me.nY - doodad.nY, 2)) * 10 / 64) / 10
		end
		wnd:Lookup('', 'Handle_Compass/Compass_Distance'):SetText(nDistance < 4 and '' or nDistance .. '"')
		-- 自身面向
		if me then
			wnd:Lookup('', 'Handle_Compass/Image_Player'):Show()
			wnd:Lookup('', 'Handle_Compass/Image_Player'):SetRotate( - me.nFaceDirection / 128 * math.pi)
		end
		-- 物品位置
		local nRotate, nRadius = 0, 10.125
		if me and doodad and nDistance > 0 then
			-- 特判角度
			if me.nX == doodad.nX then
				if me.nY > doodad.nY then
					nRotate = math.pi / 2
				else
					nRotate = - math.pi / 2
				end
			else
				nRotate = math.atan((me.nY - doodad.nY) / (me.nX - doodad.nX))
			end
			if nRotate < 0 then
				nRotate = nRotate + math.pi
			end
			if doodad.nY < me.nY then
				nRotate = math.pi + nRotate
			end
		end
		local nX = nRadius + nRadius * math.cos(nRotate) + 2
		local nY = nRadius - 3 - nRadius * math.sin(nRotate)
		wnd:Lookup('', 'Handle_Compass/Image_PointGreen'):SetRelPos(nX, nY)
		wnd:Lookup('', 'Handle_Compass'):FormatAllItemPos()
		wnd = wnd:GetNext()
	end
end

function D.OnEvent(szEvent)
	if szEvent == 'DOODAD_LEAVE_SCENE' then
		D.RemoveLootList(arg0)
	elseif szEvent == 'PARTY_LOOT_MODE_CHANGED' then
		if arg1 ~= PARTY_LOOT_MODE.DISTRIBUTE then
			-- Wnd.CloseWindow(this)
		end
	elseif szEvent == 'PARTY_DISBAND' or szEvent == 'PARTY_DELETE_MEMBER' then
		if szEvent == 'PARTY_DELETE_MEMBER' and arg1 ~= UI_GetClientPlayerID() then
			return
		end
		D.CloseFrame()
	elseif szEvent == 'UI_SCALED' then
		local a = this.anchor or O.anchor
		this:SetPoint(a.s, 0, 0, a.r, a.x, a.y)
	elseif szEvent == 'MY_GKP_LOOT_RELOAD' or szEvent == 'MY_GKP_LOOT_BOSS' then
		D.ReloadFrame()
	end
end

function D.OnFrameDragEnd()
	this:CorrectPos()
	this.anchor = GetFrameAnchor(this, 'LEFTTOP')
	O.anchor = this.anchor
end

function D.OnFrameDragSetPosEnd()
	this:CorrectPos()
end

function D.OnCheckBoxCheck()
	local name = this:GetName()
	if name == 'CheckBox_Mini' then
		D.AdjustWnd(this:GetParent())
		D.AdjustFrame(this:GetRoot())
	end
end

function D.OnCheckBoxUncheck()
	local name = this:GetName()
	if name == 'CheckBox_Mini' then
		D.AdjustWnd(this:GetParent())
		D.AdjustFrame(this:GetRoot())
	end
end

function D.OnMouseEnter()
	local name = this:GetName()
	if name == 'Btn_Boss' then
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		local szXml = ''
		local dwDoodadID = this:GetParent().dwDoodadID
		local aPartyMember = D.GetaPartyMember(dwDoodadID)
		local p = MY_GKP_LOOT_BOSS and aPartyMember(MY_GKP_LOOT_BOSS)
		if p then
			local r, g, b = X.GetForceColor(p.dwForceID)
			szXml = szXml .. GetFormatText(_L['LClick to distrubute all equipment to '], 136)
			szXml = szXml .. GetFormatText('['.. p.szName ..']', 162, r, g, b)
			szXml = szXml .. GetFormatText(_L['.'] .. '\n' .. _L['Ctrl + LClick to distrubute all lootable items to '], 136)
			szXml = szXml .. GetFormatText('['.. p.szName ..']', 162, r, g, b)
			szXml = szXml .. GetFormatText(_L['.'] .. '\n' .. _L['RClick to reselect Equipment Boss.'], 136)
		elseif MY_GKP_LOOT_BOSS then
			szXml = szXml .. GetFormatText(_L['LClick to distrubute all equipment to Equipment Boss.'] .. '\n', 136)
			szXml = szXml .. GetFormatText(_L['Ctrl + LClick to distrubute all lootable items to Equipment Boss.'] .. '\n', 136)
			szXml = szXml .. GetFormatText(_L['RClick to reselect Equipment Boss.'], 136)
		else
			szXml = szXml .. GetFormatText(_L['Click to select Equipment Boss.'], 136)
		end
		OutputTip(szXml, 450, {x, y, w, h}, ALW.TOP_BOTTOM)
	end
end

function D.OnMouseLeave()
	local name = this:GetName()
	if name == 'Btn_Boss' then
		HideTip()
	end
end

function D.OnLButtonClick()
	local szName = this:GetName()
	if szName == 'Btn_Close' then
		if IsCtrlKeyDown() then
			D.CloseFrame()
			D.aDoodadID = {}
		else
			D.RemoveLootList(this:GetParent().dwDoodadID)
		end
	elseif szName == 'Btn_Style' then
		local wnd = this:GetParent()
		local dwDoodadID = wnd.dwDoodadID
		local menu = {
			{
				szOption = _L['Set Force Color'],
				bCheck = true, bChecked = O.bSetColor,
				fnAction = function()
					O.bSetColor = not O.bSetColor
					FireUIEvent('MY_GKP_LOOT_RELOAD')
				end,
			},
			{ bDevide = true },
			{
				szOption = _L['Link All Item'],
				fnAction = function()
					local aItemData = D.GetDoodadLootInfo(dwDoodadID)
					local t = {}
					for k, v in ipairs(aItemData) do
						table.insert(t, MY_GKP.GetFormatLink(v.item))
					end
					X.SendChat(PLAYER_TALK_CHANNEL.RAID, t)
				end,
			},
			{ bDevide = true },
			{
				szOption = _L['switch styles'],
				fnAction = function()
					O.bVertical = not O.bVertical
					FireUIEvent('MY_GKP_LOOT_RELOAD')
				end,
			},
			{ bDevide = true },
			{
				szOption = _L['Config'],
				fnAction = function()
					X.ShowPanel()
					X.SwitchTab('MY_GKPDoodad')
				end,
			},
			{
				szOption = _L['About'],
				fnAction = function()
					X.Alert(_L['GKP_TIPS'])
				end,
			},
		}
		if IsCtrlKeyDown() then
			table.insert(menu, 1, { szOption = dwDoodadID, bDisable = true })
		end
		table.insert(menu, CONSTANT.MENU_DIVIDER)
		table.insert(menu, D.GetFilterMenu())
		table.insert(menu, D.GetAutoPickupMenu())
		UI.PopupMenu(menu)
	elseif szName == 'Btn_Boss' then
		if not D.AuthCheck(this:GetParent().dwDoodadID) then
			return X.Topmsg(_L['You are not the distrubutor.'])
		end
		D.GetBossAction(this:GetParent().dwDoodadID, type(MY_GKP_LOOT_BOSS) == 'nil')
	end
end

function D.OnRButtonClick()
	local szName = this:GetName()
	if szName == 'Btn_Boss' then
		D.GetBossAction(this:GetParent().dwDoodadID, true)
	end
end

function D.OnItemLButtonDown()
	local szName = this:GetName()
	if szName == 'Handle_Item' then
		this = this:Lookup('Box_Item')
		this.OnItemLButtonDown()
	end
end

function D.OnItemLButtonUp()
	local szName = this:GetName()
	if szName == 'Handle_Item' then
		this = this:Lookup('Box_Item')
		this.OnItemLButtonUp()
	end
end

function D.OnItemMouseEnter()
	local szName = this:GetName()
	if szName == 'Handle_Item' or szName == 'Box_Item' then
		local hItem = szName == 'Handle_Item' and this or this:GetParent()
		local box   = hItem:Lookup('Box_Item')
		if IsAltKeyDown() and not IsCtrlKeyDown() and not IsShiftKeyDown() then
			X.OutputTip(this, X.EncodeLUAData(hItem.itemData, '  ') .. '\n' .. X.EncodeLUAData({
				nUiId = hItem.itemData.item.nUiId,
				dwID = hItem.itemData.item.dwID,
				nGenre = hItem.itemData.item.nGenre,
				nSub = hItem.itemData.item.nSub,
				nDetail = hItem.itemData.item.nDetail,
				nLevel = hItem.itemData.item.nLevel,
				nPrice = hItem.itemData.item.nPrice,
				dwScriptID = hItem.itemData.item.dwScriptID,
				nMaxDurability = hItem.itemData.item.nMaxDurability,
				nMaxExistAmount = hItem.itemData.item.nMaxExistAmount,
				nMaxExistTime = hItem.itemData.item.nMaxExistTime,
				bCanTrade = hItem.itemData.item.bCanTrade,
				bCanDestory = hItem.itemData.item.bCanDestory,
				szName = hItem.itemData.item.szName,
			}, '  '))
		elseif szName == 'Handle_Item' then
			X.ExecuteWithThis(box, box.OnItemMouseEnter)
		end
		-- local item = hItem.itemData.item
		-- if itme and item.nGenre == ITEM_GENRE.EQUIPMENT then
		-- 	if itme.nSub == CONSTANT.EQUIPMENT_SUB.MELEE_WEAPON then
		-- 		this:SetOverText(3, g_tStrings.WeapenDetail[item.nDetail])
		-- 	else
		-- 		this:SetOverText(3, g_tStrings.tEquipTypeNameTable[item.nSub])
		-- 	end
		-- end
	elseif szName == 'Image_GroupDistrib' then
		local hItem = this:GetParent()
		local hList = hItem:GetParent()
		for i = 0, hList:GetItemCount() - 1 do
			local h = hList:Lookup(i)
			h:Lookup('Shadow_Highlight'):SetVisible(h.itemData.szType == hItem.itemData.szType)
		end
		X.OutputTip(hItem, GetFormatText(_L['Onekey distrib this group'], 136), true)
	end
end

function D.OnItemMouseLeave()
	local szName = this:GetName()
	if szName == 'Handle_Item' or szName == 'Box_Item' then
		if szName == 'Handle_Item' then
			local box = this:Lookup('Box_Item')
			if box and box.OnItemMouseLeave then
				X.ExecuteWithThis(box, box.OnItemMouseLeave)
			end
		end
		-- if this and this:IsValid() and this.SetOverText then
		-- 	this:SetOverText(3, '')
		-- end
	elseif szName == 'Image_GroupDistrib' then
		local hItem = this:GetParent()
		local hList = hItem:GetParent()
		for i = 0, hList:GetItemCount() - 1 do
			hList:Lookup(i):Lookup('Shadow_Highlight'):Hide()
		end
		HideTip()
	end
end

-- 分配菜单
function D.OnItemLButtonClick()
	local szName = this:GetName()
	if IsCtrlKeyDown() or IsAltKeyDown() then
		return
	end
	if szName == 'Handle_Item' or szName == 'Box_Item' then
		local hItem      = szName == 'Handle_Item' and this or this:GetParent()
		local box        = hItem:Lookup('Box_Item')
		local data       = hItem.itemData
		local me, team   = GetClientPlayer(), GetClientTeam()
		local dwDoodadID = data.dwDoodadID
		local doodad     = GetDoodad(dwDoodadID)
		if not data.bDist and not data.bNeedRoll and not data.bBidding then
			if doodad.CanLoot(me.dwID) then
				X.OpenDoodad(me, doodad)
			elseif not doodad.CanDialog(me) then
				X.Topmsg(g_tStrings.TIP_TOO_FAR)
			end
		end
		if data.bDist then
			if not doodad then
				--[[#DEBUG BEGIN]]
				X.Debug('MY_GKPLoot:OnItemLButtonClick', 'Doodad does not exist!', X.DEBUG_LEVEL.WARNING)
				--[[#DEBUG END]]
				return D.RemoveLootList(dwDoodadID)
			end
			if not D.AuthCheck(dwDoodadID) then
				return
			end
			return UI.PopupMenu(D.GetDistributeMenu(data, data.item.nUiId))
		elseif data.bBidding then
			if team.nLootMode ~= PARTY_LOOT_MODE.BIDDING then
				return OutputMessage('MSG_ANNOUNCE_RED', g_tStrings.GOLD_CHANGE_BID_LOOT)
			end
			X.Sysmsg(_L['GKP does not support bidding, please re open loot list.'])
		elseif data.bNeedRoll then
			X.Topmsg(g_tStrings.ERROR_LOOT_ROLL)
		else -- 左键摸走
			LootItem(dwDoodadID, data.dwID)
		end
		X.DelayCall('MY_GKPLoot__LootDoodad', 150, D.CloseLootWindow)
	elseif szName == 'Image_GroupDistrib' then
		local hItem     = this:GetParent()
		local hList     = hItem:GetParent()
		local aItemData = {}
		for i = 0, hList:GetItemCount() - 1 do
			local h = hList:Lookup(i)
			if h.itemData.szType == hItem.itemData.szType then
				table.insert(aItemData, h.itemData)
			end
		end
		for _, data in ipairs(aItemData) do
			local dwDoodadID = data.dwDoodadID
			local doodad     = GetDoodad(dwDoodadID)
			if not doodad then
				--[[#DEBUG BEGIN]]
				X.Debug('MY_GKPLoot:OnItemLButtonClick', 'Doodad does not exist!', X.DEBUG_LEVEL.WARNING)
				--[[#DEBUG END]]
				return D.RemoveLootList(dwDoodadID)
			end
			if not D.AuthCheck(dwDoodadID) then
				return X.Topmsg(_L['You are not the distrubutor.'])
			end
		end
		return UI.PopupMenu(D.GetDistributeMenu(aItemData, hItem.itemData.szType))
	end
end

-- 右键拍卖
function D.OnItemRButtonClick()
	local szName = this:GetName()
	if szName == 'Handle_Item' or szName == 'Box_Item' then
		local hItem = szName == 'Handle_Item' and this or this:GetParent()
		local box   = hItem:Lookup('Box_Item')
		local data = hItem.itemData
		if not data.bDist then
			return
		end
		local me, team   = GetClientPlayer(), GetClientTeam()
		local dwDoodadID = data.dwDoodadID
		if not D.AuthCheck(dwDoodadID) then
			return
		end
		UI.PopupMenu(D.GetItemBiddingMenu(dwDoodadID, data))
	end
end

function D.GetFilterMenu()
	local t = {
		szOption = _L['Loot item filter'],
		-- 过滤已读书籍
		{
			szOption = _L['Filter book read'],
			bCheck = true,
			bChecked = O.bFilterBookRead,
			fnAction = function()
				O.bFilterBookRead = not O.bFilterBookRead
				D.ReloadFrame()
			end,
		},
		-- 过滤已有书籍
		{
			szOption = _L['Filter book have'],
			bCheck = true,
			bChecked = O.bFilterBookHave,
			fnAction = function()
				O.bFilterBookHave = not O.bFilterBookHave
				D.ReloadFrame()
			end,
		},
		-- 过滤灰色物品
		{
			szOption = _L['Filter gray item'],
			bCheck = true,
			bChecked = O.bFilterGrayItem,
			fnAction = function()
				O.bFilterGrayItem = not O.bFilterGrayItem
				D.ReloadFrame()
			end,
		},
	}
	-- 品级过滤
	local t1 = {
		szOption = _L['Quality filter'],
		{
			szOption = _L['Will be reset when loading'],
			bDisable = true,
		},
		CONSTANT.MENU_DIVIDER,
	}
	for i, p in ipairs(GKP_ITEM_QUALITIES) do
		table.insert(t1, {
			szOption = p.szTitle,
			rgb = { GetItemFontColorByQuality(p.nQuality) },
			bCheck = true,
			bChecked = ITEM_CONFIG.tFilterQuality[p.nQuality],
			fnAction = function()
				ITEM_CONFIG.tFilterQuality[p.nQuality] = not ITEM_CONFIG.tFilterQuality[p.nQuality]
				D.ReloadFrame()
			end,
		})
	end
	table.insert(t, t1)
	-- 名称过滤
	local t1 = {
		szOption = _L['Name filter'],
		{
			szOption = _L['Will be disable when loading'],
			bDisable = true,
		},
		{
			szOption = _L['Enable'],
			bCheck = true, bChecked = ITEM_CONFIG.bNameFilter,
			fnAction = function()
				ITEM_CONFIG.bNameFilter = not ITEM_CONFIG.bNameFilter
				D.ReloadFrame()
			end,
		},
		CONSTANT.MENU_DIVIDER,
	}
	for szName, bEnable in pairs(O.tNameFilter) do
		table.insert(t1, {
			szOption = szName,
			bCheck = true,
			bChecked = bEnable,
			fnAction = function()
				O.tNameFilter[szName] = not O.tNameFilter[szName]
				O.tNameFilter = O.tNameFilter
				D.ReloadFrame()
			end,
			szIcon = 'ui/Image/UICommon/CommonPanel2.UITex',
			nFrame = 49,
			nMouseOverFrame = 51,
			nIconWidth = 17,
			nIconHeight = 17,
			szLayer = 'ICON_RIGHTMOST',
			fnClickIcon = function()
				O.tNameFilter[szName] = nil
				O.tNameFilter = O.tNameFilter
				UI.ClosePopupMenu()
				D.ReloadFrame()
			end,
			fnDisable = function() return not ITEM_CONFIG.bNameFilter end,
		})
	end
	if not X.IsEmpty(O.tNameFilter) then
		table.insert(t1, CONSTANT.MENU_DIVIDER)
	end
	table.insert(t1, {
		szOption = _L['Add'],
		fnAction = function()
			GetUserInput(_L['Please input filter name'], function(szText)
				O.tNameFilter[szText] = true
				O.tNameFilter = O.tNameFilter
				D.ReloadFrame()
			end, nil, nil, nil, '', nil)
		end,
		fnDisable = function() return not ITEM_CONFIG.bNameFilter end,
	})
	table.insert(t, t1)
	return t
end

function D.GetAutoPickupMenu()
	local t = { szOption = _L['Auto pickup'] }
	table.insert(t, { szOption = _L['Filters have higher priority'], bDisable = true })
	-- 拾取过滤
	-- 过滤已读书籍
	table.insert(t, {
		szOption = _L['Filter book read'],
		bCheck = true,
		bChecked = O.bAutoPickupFilterBookRead,
		fnAction = function()
			O.bAutoPickupFilterBookRead = not O.bAutoPickupFilterBookRead
		end,
	})
	-- 过滤已有书籍
	table.insert(t, {
		szOption = _L['Filter book have'],
		bCheck = true,
		bChecked = O.bAutoPickupFilterBookHave,
		fnAction = function()
			O.bAutoPickupFilterBookHave = not O.bAutoPickupFilterBookHave
		end,
	})
	-- 自动拾取物品过滤
	local t1 = { szOption = _L['Auto pickup filters'] }
	for s, b in pairs(O.tAutoPickupFilters or {}) do
		table.insert(t1, {
			szOption = s,
			bCheck = true, bChecked = b,
			fnAction = function()
				O.tAutoPickupFilters[s] = not O.tAutoPickupFilters[s]
				O.tAutoPickupFilters = O.tAutoPickupFilters
			end,
			szIcon = 'ui/Image/UICommon/CommonPanel2.UITex',
			nFrame = 49,
			nMouseOverFrame = 51,
			nIconWidth = 17,
			nIconHeight = 17,
			szLayer = 'ICON_RIGHTMOST',
			fnClickIcon = function()
				O.tAutoPickupFilters[s] = nil
				O.tAutoPickupFilters = O.tAutoPickupFilters
				UI.ClosePopupMenu()
			end,
		})
	end
	if #t1 > 0 then
		table.insert(t1, CONSTANT.MENU_DIVIDER)
	end
	table.insert(t1, {
		szOption = _L['Add new'],
		fnAction = function()
			GetUserInput(_L['Please input new auto pickup filter:'], function(text)
				O.tAutoPickupFilters[text] = true
				O.tAutoPickupFilters = O.tAutoPickupFilters
			end)
		end,
	})
	table.insert(t, t1)
	-- 自动拾取
	table.insert(t, CONSTANT.MENU_DIVIDER)
	-- 自动拾取任务物品
	table.insert(t, {
		szOption = _L['Auto pickup quest item'],
		bCheck = true, bChecked = O.bAutoPickupTaskItem,
		fnAction = function()
			O.bAutoPickupTaskItem = not O.bAutoPickupTaskItem
		end,
	})
	-- 自动拾取书籍
	table.insert(t, {
		szOption = _L['Auto pickup book'],
		bCheck = true, bChecked = O.bAutoPickupBook,
		fnAction = function()
			O.bAutoPickupBook = not O.bAutoPickupBook
		end,
	})
	-- 自动拾取品级
	local t1 = {
		szOption = _L['Auto pickup by item quality'],
		{
			szOption = _L['Enable'],
			bCheck = true,
			bChecked = O.bAutoPickupQuality,
			fnAction = function()
				O.bAutoPickupQuality = not O.bAutoPickupQuality
			end,
		},
		CONSTANT.MENU_DIVIDER,
	}
	for i, p in ipairs(GKP_ITEM_QUALITIES) do
		table.insert(t1, {
			szOption = p.szTitle,
			rgb = { GetItemFontColorByQuality(p.nQuality) },
			bCheck = true,
			bChecked = O.tAutoPickupQuality[p.nQuality],
			fnAction = function()
				O.tAutoPickupQuality[p.nQuality] = not O.tAutoPickupQuality[p.nQuality]
				O.tAutoPickupQuality = O.tAutoPickupQuality
			end,
			fnDisable = function() return not O.bAutoPickupQuality end,
		})
	end
	table.insert(t, t1)
	-- 自动拾取物品名称
	local t1 = { szOption = _L['Auto pickup names'] }
	for s, b in pairs(O.tAutoPickupNames or {}) do
		table.insert(t1, {
			szOption = s,
			bCheck = true, bChecked = b,
			fnAction = function()
				O.tAutoPickupNames[s] = not O.tAutoPickupNames[s]
				O.tAutoPickupNames = O.tAutoPickupNames
			end,
			szIcon = 'ui/Image/UICommon/CommonPanel2.UITex',
			nFrame = 49,
			nMouseOverFrame = 51,
			nIconWidth = 17,
			nIconHeight = 17,
			szLayer = 'ICON_RIGHTMOST',
			fnClickIcon = function()
				O.tAutoPickupNames[s] = nil
				O.tAutoPickupNames = O.tAutoPickupNames
				UI.ClosePopupMenu()
			end,
		})
	end
	if #t1 > 0 then
		table.insert(t1, CONSTANT.MENU_DIVIDER)
	end
	table.insert(t1, {
		szOption = _L['Add new'],
		fnAction = function()
			GetUserInput(_L['Please input new auto pickup name:'], function(text)
				O.tAutoPickupNames[text] = true
				O.tAutoPickupNames = O.tAutoPickupNames
			end)
		end,
	})
	table.insert(t, t1)
	return t
end

function D.GetBossAction(dwDoodadID, bMenu)
	if not D.AuthCheck(dwDoodadID) then
		return
	end
	local aItemData = D.GetDoodadLootInfo(dwDoodadID)
	local fnAction = function()
		local aEquipmentItemData = {}
		for k, v in ipairs(aItemData) do
			if (
				(v.item.nGenre == ITEM_GENRE.EQUIPMENT and (
					v.item.nSub == CONSTANT.EQUIPMENT_SUB.MELEE_WEAPON
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.RANGE_WEAPON
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.CHEST
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.HELM
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.AMULET
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.RING
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.WAIST
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.PENDANT
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.PANTS
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.BOOTS
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.BANGLE
					or v.item.nSub == CONSTANT.EQUIPMENT_SUB.ARROW
				))
				or IsCtrlKeyDown()
			) and v.bDist then -- 按住Ctrl的情况下 无视分类 否则只给装备
				table.insert(aEquipmentItemData, v)
			end
		end
		if #aEquipmentItemData == 0 then
			return X.Alert(_L['No Equiptment left for Equiptment Boss'])
		end
		local aPartyMember = D.GetaPartyMember(dwDoodadID)
		local p = aPartyMember(MY_GKP_LOOT_BOSS)
		if p and p.bOnlineFlag then  -- 这个人存在团队的情况下
			local szXml = GetFormatText(_L['Are you sure you want the following item\n'], 162, 255, 255, 255)
			local r, g, b = X.GetForceColor(p.dwForceID)
			for k, v in ipairs(aEquipmentItemData) do
				local r, g, b = GetItemFontColorByQuality(v.item.nQuality)
				szXml = szXml .. GetFormatText('['.. X.GetItemNameByItem(v.item) ..']\n', 166, r, g, b)
			end
			szXml = szXml .. GetFormatText(_L['All distrubute to'], 162, 255, 255, 255)
			szXml = szXml .. GetFormatText('['.. p.szName ..']', 162, r, g, b)
			local msg = {
				szMessage = szXml,
				szName = 'GKP_Distribute',
				szAlignment = 'CENTER',
				bRichText = true,
				{
					szOption = g_tStrings.STR_HOTKEY_SURE,
					fnAction = function()
						D.DistributeItem(MY_GKP_LOOT_BOSS, aEquipmentItemData, nil, true)
					end
				},
				{
					szOption = g_tStrings.STR_HOTKEY_CANCEL
				},
			}
			MessageBox(msg)
		else
			return X.Alert(_L['Cannot distrubute items to Equipment Boss, may due to Equipment Boss is too far away or got dropline when looting.'])
		end
	end
	if bMenu then
		local menu = MY_GKP.GetTeamMemberMenu(function(v)
			MY_GKP_LOOT_BOSS = v.dwID
			fnAction()
		end, false, true)
		table.insert(menu, 1, { bDevide = true })
		table.insert(menu, 1, { szOption = _L['select equip boss'], bDisable = true })
		UI.PopupMenu(menu)
	else
		fnAction()
	end
end

function D.AuthCheck(dwID)
	local me, team       = GetClientPlayer(), GetClientTeam()
	local doodad         = GetDoodad(dwID)
	if not doodad then
		--[[#DEBUG BEGIN]]
		X.Debug('MY_GKPLoot:AuthCheck', 'Doodad does not exist!', X.DEBUG_LEVEL.WARNING)
		--[[#DEBUG END]]
		return
	end
	local nLootMode      = team.nLootMode
	local dwBelongTeamID = doodad.GetBelongTeamID()
	if nLootMode ~= PARTY_LOOT_MODE.DISTRIBUTE and not X.IsDebugClient('MY_GKP') then -- 需要分配者模式
		OutputMessage('MSG_ANNOUNCE_RED', g_tStrings.GOLD_CHANGE_DISTRIBUTE_LOOT)
		return false
	end
	if not X.IsDistributor() and not X.IsDebugClient('MY_GKP') then -- 需要自己是分配者
		OutputMessage('MSG_ANNOUNCE_RED', g_tStrings.ERROR_LOOT_DISTRIBUTE)
		return false
	end
	if dwBelongTeamID ~= team.dwTeamID then
		OutputMessage('MSG_ANNOUNCE_RED', g_tStrings.ERROR_LOOT_DISTRIBUTE)
		return false
	end
	return true
end

-- 拾取对象
function D.GetaPartyMember(aDoodadID)
	if not X.IsTable(aDoodadID) then
		aDoodadID = {aDoodadID}
	end
	local team = GetClientTeam()
	local tDoodadID = {}
	local tPartyMember = {}
	local aPartyMember = {}
	for _, dwDoodadID in ipairs(aDoodadID) do
		if not tDoodadID[dwDoodadID] then
			local doodad = GetDoodad(dwDoodadID)
			if doodad then
				local aLooterList = doodad.GetLooterList()
				if aLooterList then
					for _, p in ipairs(aLooterList) do
						if not tPartyMember[p.dwID] then
							table.insert(aPartyMember, p)
							tPartyMember[p.dwID] = true
						end
					end
				else
					X.Sysmsg(_L['Pick up time limit exceeded, please try again.'])
				end
			end
			tDoodadID[dwDoodadID] = true
		end
	end
	for k, v in ipairs(aPartyMember) do
		local player = team.GetMemberInfo(v.dwID)
		aPartyMember[k].dwForceID = player.dwForceID
		aPartyMember[k].dwMapID   = player.dwMapID
	end
	setmetatable(aPartyMember, { __call = function(me, dwID)
		for k, v in ipairs(me) do
			if v.dwID == dwID or v.szName == dwID then
				return v
			end
		end
	end })
	return aPartyMember
end

-- 严格判断
function D.DistributeItem(dwID, info, szAutoDistType, bSkipRecordPanel)
	if X.IsArray(info) then
		for _, p in ipairs(info) do
			D.DistributeItem(dwID, p, szAutoDistType, bSkipRecordPanel)
		end
		return
	end
	local doodad = GetDoodad(info.dwDoodadID)
	if not D.AuthCheck(info.dwDoodadID) then
		return
	end
	local me = GetClientPlayer()
	local item = GetItem(info.dwID)
	if not item then
		--[[#DEBUG BEGIN]]
		X.Debug('MY_GKPLoot', 'Item does not exist, check!!', X.DEBUG_LEVEL.WARNING)
		--[[#DEBUG END]]
		local aItemData = D.GetDoodadLootInfo(info.dwDoodadID)
		for k, v in ipairs(aItemData) do
			if v.nQuality == info.nQuality and X.GetItemNameByItem(v.item) == info.szName then
				info.dwID = v.item.dwID
				--[[#DEBUG BEGIN]]
				X.Debug('MY_GKPLoot', 'Item matching, ' .. X.GetItemNameByItem(v.item), X.DEBUG_LEVEL.LOG)
				--[[#DEBUG END]]
				break
			end
		end
	end
	local item         = GetItem(info.dwID)
	local team         = GetClientTeam()
	local player       = team.GetMemberInfo(dwID)
	local aPartyMember = D.GetaPartyMember(info.dwDoodadID)
	if item then
		if not player or (player and not player.bIsOnLine) then -- 不在线
			return X.Alert(_L['No Pick up Object, may due to Network off - line'])
		end
		if not aPartyMember(dwID) then -- 给不了
			return X.Alert(_L['No Pick up Object, may due to Network off - line'])
		end
		if player.dwMapID ~= me.GetMapID() then -- 不在同一地图
			return X.Alert(_L['No Pick up Object, Please confirm that in the Dungeon.'])
		end
		local tab = {
			szPlayer   = player.szName,
			dwID       = item.dwID,
			nUiId      = item.nUiId,
			szNpcName  = doodad.szName,
			dwDoodadID = doodad.dwID,
			dwTabType  = item.dwTabType,
			dwIndex    = item.dwIndex,
			nVersion   = item.nVersion,
			nTime      = GetCurrentTime(),
			nQuality   = item.nQuality,
			dwForceID  = player.dwForceID,
			szName     = X.GetItemNameByItem(item),
			nGenre     = item.nGenre,
		}
		if item.bCanStack and item.nStackNum > 1 then
			tab.nStackNum = item.nStackNum
		end
		if item.nGenre == ITEM_GENRE.BOOK then
			tab.nBookID = item.nBookID
		end
		MY_GKP_MI.NewAuction(tab, IsShiftKeyDown() or bSkipRecordPanel)
		if szAutoDistType then
			GKP_LOOT_RECENT[szAutoDistType] = dwID
		end
		if DEBUG_LOOT then
			return X.Sysmsg('LOOT: ' .. info.dwID .. '->' .. dwID) -- !!! Debug
		end
		doodad.DistributeItem(info.dwID, dwID)
	else
		X.Sysmsg(_L['Userdata is overdue, distribut failed, please try again.'])
	end
end

function D.GetMessageBox(dwID, aItemData, szAutoDistType, bSkipRecordPanel)
	if not X.IsArray(aItemData) then
		aItemData = {aItemData}
	end
	local team = GetClientTeam()
	local info = team.GetMemberInfo(dwID)
	local fr, fg, fb = X.GetForceColor(info.dwForceID)
	local aItemName = {}
	for _, data in ipairs(aItemData) do
		local ir, ig, ib = GetItemFontColorByQuality(data.nQuality)
		table.insert(aItemName, GetFormatText('['.. data.szName .. ']', 166, ir, ig, ib))
	end
	local msg = {
		szMessage = FormatLinkString(
			g_tStrings.PARTY_DISTRIBUTE_ITEM_SURE,
			'font=162',
			table.concat(aItemName, GetFormatText(g_tStrings.STR_PAUSE)),
			GetFormatText('['.. info.szName .. ']', 162, fr, fg, fb)
		),
		szName = 'GKP_Distribute',
		bRichText = true,
		{
			szOption = g_tStrings.STR_HOTKEY_SURE,
			fnAction = function()
				D.DistributeItem(dwID, aItemData, szAutoDistType, bSkipRecordPanel)
			end
		},
		{ szOption = g_tStrings.STR_HOTKEY_CANCEL },
	}
	MessageBox(msg)
end

do
local function IsItemRequireConfirm(data)
	if data.nQuality >= O.nConfirmQuality
	or (O.tConfirm.Huangbaba -- 玄晶
		and data.item.nQuality == GKP_LOOT_HUANGBABA_QUALITY
		and X.GetItemIconByUIID(data.item.nUiId) == GKP_LOOT_HUANGBABA_ICON
	)
	or (O.tConfirm.Book and data.item.nGenre == ITEM_GENRE.BOOK) -- 书籍
	or (O.tConfirm.Pendant and data.item.nGenre == ITEM_GENRE.EQUIPMENT and ( -- 挂件
		data.item.nSub == EQUIPMENT_REPRESENT.WAIST_EXTEND
		or data.item.nSub == EQUIPMENT_REPRESENT.BACK_EXTEND
		or data.item.nSub == EQUIPMENT_REPRESENT.FACE_EXTEND
	))
	or (O.tConfirm.Outlook and data.item.nGenre == ITEM_GENRE.EQUIPMENT and ( -- 肩饰披风
		data.item.nSub == CONSTANT.EQUIPMENT_SUB.BACK_CLOAK_EXTEND
		or data.item.nSub == CONSTANT.EQUIPMENT_SUB.L_SHOULDER_EXTEND
		or data.item.nSub == CONSTANT.EQUIPMENT_SUB.R_SHOULDER_EXTEND
	))
	or (O.tConfirm.Pet and ( -- 跟宠
		data.item.nGenre == ITEM_GENRE.CUB
		or (data.item.nGenre == ITEM_GENRE.EQUIPMENT and data.item.nSub == CONSTANT.EQUIPMENT_SUB.PET)
	))
	or (O.tConfirm.Horse and ( -- 坐骑
		data.item.nGenre == ITEM_GENRE.EQUIPMENT and data.item.nSub == CONSTANT.EQUIPMENT_SUB.HORSE
	))
	or (O.tConfirm.HorseEquip and ( -- 马具
		data.item.nGenre == ITEM_GENRE.EQUIPMENT and data.item.nSub == CONSTANT.EQUIPMENT_SUB.HORSE_EQUIP
	))
	then
		return true
	end
	return false
end
local function GetMemberMenu(member, aItemData, szAutoDistType, aDoodadID)
	local frame = D.GetFrame()
	local szIcon, nFrame = GetForceImage(member.dwForceID)
	local szOption = member.szName
	return {
		szOption = szOption,
		bDisable = not member.bOnlineFlag,
		rgb = { X.GetForceColor(member.dwForceID) },
		szIcon = szIcon, nFrame = nFrame,
		fnAutoClose = function()
			for _, v in ipairs(aDoodadID) do
				if D.GetDoodadWnd(frame, v) then
					return false
				end
			end
			return true
		end,
		szLayer = 'ICON_RIGHTMOST',
		fnAction = function()
			local bConfirm = false
			for _, data in ipairs(aItemData) do
				if IsItemRequireConfirm(data) then
					bConfirm = true
					break
				end
			end
			if bConfirm then
				D.GetMessageBox(member.dwID, aItemData, szAutoDistType, IsShiftKeyDown())
			else
				D.DistributeItem(member.dwID, aItemData, szAutoDistType, IsShiftKeyDown())
			end
		end,
		fnMouseEnter = function()
			X.OutputTip(_L['Hold shift click to skip gkp record panel'], 136)
		end,
		fnMouseLeave = function()
			HideTip()
		end,
	}
end
function D.GetDistributeMenu(aItemData, szAutoDistType)
	if not X.IsArray(aItemData) then
		aItemData = {aItemData}
	end
	local aDoodadID = {}
	for _, p in ipairs(aItemData) do
		if p.bDist then
			table.insert(aDoodadID, p.dwDoodadID)
		end
	end
	local me, team     = GetClientPlayer(), GetClientTeam()
	local dwMapID      = me.GetMapID()
	local aPartyMember = D.GetaPartyMember(aDoodadID)
	table.sort(aPartyMember, function(a, b)
		return a.dwForceID < b.dwForceID
	end)
	local aItemName = {}
	for _, p in ipairs(aItemData) do
		table.insert(aItemName, p.szName)
	end
	local menu = {
		{ szOption = table.concat(aItemName, g_tStrings.STR_PAUSE), bDisable = true },
		{ bDevide = true }
	}
	local dwAutoDistID
	if szAutoDistType then
		dwAutoDistID = GKP_LOOT_RECENT[szAutoDistType]
		if dwAutoDistID then
			local member = aPartyMember(dwAutoDistID)
			if member then
				table.insert(menu, GetMemberMenu(member, aItemData, szAutoDistType, aDoodadID))
				table.insert(menu, { bDevide = true })
			end
		end
	end
	for _, member in ipairs(aPartyMember) do
		table.insert(menu, GetMemberMenu(member, aItemData, szAutoDistType, aDoodadID))
	end
	return menu
end
end

function D.GetItemBiddingMenu(dwDoodadID, data)
	local menu = {}
	table.insert(menu, { szOption = data.szName , bDisable = true })
	table.insert(menu, { bDevide = true })
	table.insert(menu, {
		szOption = 'Roll',
		fnAction = function()
			if MY_RollMonitor then
				if MY_RollMonitor.OpenPanel and MY_RollMonitor.Clear then
					MY_RollMonitor.OpenPanel()
					MY_RollMonitor.Clear({echo=false})
				end
			end
			X.SendChat(PLAYER_TALK_CHANNEL.RAID, { MY_GKP.GetFormatLink(data.item), MY_GKP.GetFormatLink(_L['Roll the dice if you wang']) })
			return 0
		end
	})
	table.insert(menu, { bDevide = true })
	for k, v in ipairs(MY_GKP.aScheme) do
		if v[3] then
			table.insert(menu, {
				szOption = v[1] .. ',' .. v[2],
				fnAction = function()
					local bNewBidding = MY_GKP.bNewBidding == not IsShiftKeyDown()
					if bNewBidding then
						MY_Bidding.Open({
							nPriceMin = v[1],
							nPriceStep = v[2],
							nNumber = data.item.bCanStack and data.item.nStackNum or 1,
							dwTabType = data.item.dwTabType,
							dwTabIndex = data.item.dwIndex,
							nBookID = data.item.nGenre == ITEM_GENRE.BOOK and data.item.nBookID or nil,
						})
						return 0
					end
					MY_GKP_Chat.OpenFrame(data.item, D.GetDistributeMenu(data, data.nUiId), {
						dwDoodadID = dwDoodadID,
						data = data,
					})
					X.SendChat(PLAYER_TALK_CHANNEL.RAID, {
						MY_GKP.GetFormatLink(data.item),
						MY_GKP.GetFormatLink(_L(' %d Gold Start Bidding, off a price if you want.', v[1])),
					})
					return 0
				end,
				fnMouseEnter = function()
					local szMsg = GetFormatText(
						MY_GKP.bNewBidding
							and _L['Hold SHIFT click to raise ancient bidding panel.']
							or _L['Hold SHIFT click to raise new bidding panel.']
						, nil, 255, 255, 0)
					OutputTip(szMsg, 600, {this:GetAbsX(), this:GetAbsY(), this:GetW(), this:GetH()}, ALW.RIGHT_LEFT)
				end,
				fnMouseLeave = function()
					HideTip()
				end,
			})
		end
	end
	return menu
end

function D.AdjustFrame(frame)
	local scroll = frame:Lookup('Scroll_DoodadList')
	local scrollbar = scroll:Lookup('ScrolBar_DoodadList')
	local container = scroll:Lookup('WndContainer_DoodadList')
	local nW, nH = frame:GetW(), 0
	local wnd = container:LookupContent(0)
	while wnd do
		nW = wnd:GetW()
		nH = nH + wnd:GetH()
		wnd = wnd:GetNext()
	end
	nH = math.min(nH, select(2, Station.GetClientSize()) * 4 / 5)
	scroll:SetSize(nW, nH)
	scrollbar:SetH(nH)
	scrollbar:SetRelX(nW - 8)
	container:SetSize(nW, nH)
	container:FormatAllContentPos()
	frame:SetSize(nW, nH)
end

function D.AdjustWnd(wnd)
	local nInnerW = O.bVertical and 270 or (52 * 8)
	local nOuterW = O.bVertical and nInnerW or (nInnerW + 10)
	local hDoodad = wnd:Lookup('', '')
	local hList = hDoodad:Lookup('Handle_ItemList')
	local bMini = wnd:Lookup('CheckBox_Mini'):IsCheckBoxChecked()
	hList:SetW(nInnerW)
	hList:SetRelX((nOuterW - nInnerW) / 2)
	hList:FormatAllItemPos()
	hList:SetSizeByAllItemSize()
	hList:SetVisible(not bMini)
	hDoodad:SetSize(nOuterW, (bMini and 0 or hList:GetH()) + 30)
	hDoodad:Lookup('Handle_Compass'):SetRelX(nOuterW - 107)
	hDoodad:Lookup('Image_DoodadTitleBg'):SetW(nOuterW)
	hDoodad:Lookup('Image_DoodadBg'):SetSize(nOuterW, hDoodad:GetH() - 20)
	hDoodad:FormatAllItemPos()
	wnd:SetSize(nOuterW, hDoodad:GetH())
	wnd:Lookup('Btn_Boss'):SetRelX(nOuterW - 80)
	wnd:Lookup('CheckBox_Mini'):SetRelX(nOuterW - 50)
	wnd:Lookup('Btn_Close'):SetRelX(nOuterW - 28)
end

function D.GetDoodadWnd(frame, dwID, bCreate)
	if not frame then
		return
	end
	local container = frame:Lookup('Scroll_DoodadList/WndContainer_DoodadList')
	local wnd = container:LookupContent(0)
	while wnd and wnd.dwDoodadID ~= dwID do
		wnd = wnd:GetNext()
	end
	if not wnd and bCreate then
		wnd = container:AppendContentFromIni(GKP_LOOT_INIFILE, 'Wnd_Doodad')
		wnd.dwDoodadID = dwID
	end
	return wnd
end

local function IsItemDataSuitable(data)
	local me = GetClientPlayer()
	if not me then
		return 'NOT_SUITABLE'
	end
	local aKungfu = X.ForceIDToKungfuIDs(me.dwForceID)
	if data.szType == 'BOOK' then
		local nBookID, nSegmentID = X.RecipeToSegmentID(data.item.nBookID)
		if me.IsBookMemorized(nBookID, nSegmentID) then
			return 'NOT_SUITABLE'
		end
		return 'SUITABLE'
	else
		local szSuit = X.DoesEquipmentSuit(data.item, true) and 'SUITABLE' or 'NOT_SUITABLE'
		if szSuit == 'SUITABLE' then
			if data.szType == 'EQUIPMENT' or data.szType == 'WEAPON' then
				szSuit = X.IsItemFitKungfu(data.item) and 'SUITABLE' or 'NOT_SUITABLE'
				if szSuit == 'NOT_SUITABLE' and O.bShow2ndKungfuLoot then
					for _, dwKungfuID in ipairs(aKungfu) do
						if X.IsItemFitKungfu(data.item, dwKungfuID) then
							szSuit = 'MAYBE_SUITABLE'
							break
						end
					end
				end
			elseif data.szType == 'EQUIPMENT_SIGN' then
				szSuit = wstring.find(data.item.szName, g_tStrings.tForceTitle[me.dwForceID]) and 'SUITABLE' or 'NOT_SUITABLE'
			end
		end
		if szSuit == 'SUITABLE' and X.IsBetterEquipment(data.item) then
			return 'BETTER'
		end
		return szSuit
	end
end

function D.InsertLootList(dwID)
	local bExist = false
	for _, v in ipairs(D.aDoodadID) do
		if v == dwID then
			bExist = true
			break
		end
	end
	if not bExist then
		table.insert(D.aDoodadID, dwID)
	end
	D.DrawLootList(dwID)
end

function D.DrawLootList(dwID, bRemove)
	--[[#DEBUG BEGIN]]
	local nTickCount = GetTickCount()
	--[[#DEBUG END]]
	local frame = D.GetFrame()
	local wnd = D.GetDoodadWnd(frame, dwID)

	if bRemove then
		if wnd then
			wnd:Destroy()
			local container = frame:Lookup('Scroll_DoodadList/WndContainer_DoodadList')
			if container:GetAllContentCount() == 0 then
				D.CloseFrame()
			else
				D.AdjustFrame(frame)
			end
		end
	else
		local config = ITEM_CONFIG
		-- 计算掉落
		local aItemData, nMoney, szName, bSpecial = D.GetDoodadLootInfo(dwID)
		if nMoney > 0 then
			LootMoney(dwID)
		end
		local nCount = #aItemData
		if not X.IsEmpty(config.tFilterQuality) or config.bFilterBookRead or config.bFilterBookHave or config.bFilterGrayItem then
			nCount = 0
			for i, v in ipairs(aItemData) do
				if D.IsItemDisplay(v, config) then
					nCount = nCount + 1
				end
			end
		end
		--[[#DEBUG BEGIN]]
		X.Debug('MY_GKPLoot', ('Doodad %d, items %d, display %d.'):format(dwID, #aItemData, nCount), X.DEBUG_LEVEL.LOG)
		--[[#DEBUG END]]

		if not szName or nCount == 0 then
			if not szName then
				D.RemoveLootList(dwID)
				--[[#DEBUG BEGIN]]
				X.Debug('MY_GKPLoot:DrawLootList', 'Doodad does not exist!', X.DEBUG_LEVEL.LOG)
				--[[#DEBUG END]]
			elseif frame then
				D.DrawLootList(dwID, true)
			end
			return
		end

		-- 获取/创建UI元素
		if not frame then
			frame = D.OpenFrame()
		end
		if not wnd then
			wnd = D.GetDoodadWnd(frame, dwID, true)
		end

		-- 修改UI元素
		local bDist = false
		local hDoodad = wnd:Lookup('', '')
		local hList = hDoodad:Lookup('Handle_ItemList')
		hList:Clear()
		for i, itemData in ipairs(aItemData) do
			local item = itemData.item
			if D.IsItemDisplay(itemData, config) then
				local szName = X.GetItemNameByItem(item)
				local h = hList:AppendItemFromIni(GKP_LOOT_INIFILE, 'Handle_Item')
				local box = h:Lookup('Box_Item')
				local txt = h:Lookup('Text_Item')
				txt:SetText(szName)
				txt:SetFontColor(GetItemFontColorByQuality(item.nQuality))
				if O.bSetColor and item.nGenre == ITEM_GENRE.MATERIAL then
					for dwForceID, szForceTitle in pairs(g_tStrings.tForceTitle) do
						if szName:find(szForceTitle) then
							txt:SetFontColor(X.GetForceColor(dwForceID))
							break
						end
					end
				end
				if O.bVertical then
					local szSuit = IsItemDataSuitable(itemData)
					h:Lookup('Image_GroupDistrib'):SetVisible(itemData.bDist
						and (i == 1 or aItemData[i - 1].szType ~= itemData.szType or not aItemData[i - 1].bDist))
					h:Lookup('Image_Suitable'):SetVisible(szSuit == 'SUITABLE')
					h:Lookup('Image_MaybeSuitable'):SetVisible(szSuit == 'MAYBE_SUITABLE')
					h:Lookup('Image_Better'):SetVisible(szSuit == 'BETTER')
					h:Lookup('Image_Spliter'):SetVisible(i ~= #aItemData)
				else
					txt:Hide()
					box:SetSize(48, 48)
					box:SetRelPos(2, 2)
					h:SetSize(52, 52)
					h:FormatAllItemPos()
					h:Lookup('Image_GroupDistrib'):Hide()
					h:Lookup('Image_Spliter'):Hide()
					h:Lookup('Image_Hover'):SetSize(0, 0)
				end
				UpdateBoxObject(box, UI_OBJECT_ITEM_ONLY_ID, item.dwID)
				-- box:SetOverText(3, '')
				-- box:SetOverTextFontScheme(3, 15)
				-- box:SetOverTextPosition(3, ITEM_POSITION.LEFT_TOP)
				if GKP_LOOT_RECENT[item.nUiId] then
					box:SetObjectStaring(true)
				end
				if itemData.bDist then
					bDist = true
				end
				h.itemData = itemData
				h.nAutoLootLFC = nil
			end
		end
		if bSpecial then
			hDoodad:Lookup('Image_DoodadBg'):FromUITex('ui/Image/OperationActivity/RedEnvelope2.uitex', 14)
			hDoodad:Lookup('Image_DoodadTitleBg'):FromUITex('ui/Image/OperationActivity/RedEnvelope2.uitex', 14)
			hDoodad:Lookup('Text_Title'):SetAlpha(255)
			hDoodad:Lookup('SFX'):Show()
		end
		hDoodad:Lookup('Text_Title'):SetText(szName .. ' (' .. nCount ..  ')')
		wnd:Lookup('Btn_Boss'):Enable(bDist)

		-- 修改UI大小
		D.AdjustWnd(wnd)
		D.AdjustFrame(frame)

		-- 立即自动拾取一次
		X.ExecuteWithThis(frame, D.OnFrameBreathe)
		--[[#DEBUG BEGIN]]
		nTickCount = GetTickCount() - nTickCount
		X.Debug(
			_L['PMTool'],
			_L('DrawLootList %d in %dms.', dwID, nTickCount),
			X.DEBUG_LEVEL.PMLOG)
		--[[#DEBUG END]]
	end
end

function D.RemoveLootList(dwID)
	for i, v in ipairs(D.aDoodadID) do
		if dwID == v then
			table.remove(D.aDoodadID, i)
			break
		end
	end
	D.DrawLootList(dwID, true)
end

function D.GetFrame()
	return Station.Lookup('Normal/MY_GKPLoot')
end

function D.OpenFrame()
	local frame = D.GetFrame()
	if not frame then
		frame = Wnd.OpenWindow(GKP_LOOT_INIFILE, 'MY_GKPLoot')
		PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
	end
	return frame
end

-- 手动关闭 不适用自定关闭
function D.CloseFrame(dwID)
	local frame = D.GetFrame(dwID)
	if frame then
		Wnd.CloseWindow(frame)
		PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
	end
end

function D.ReloadFrame()
	if #D.aDoodadID == 0 then
		D.CloseFrame()
	else
		D.OpenFrame()
		for _, dwID in ipairs(D.aDoodadID) do
			D.DrawLootList(dwID)
		end
	end
end

local ITEM_DATA_WEIGHT = {
	COIN_SHOP      = 1,	-- 外观 披风 礼盒
	OUTLOOK        = 1,	-- 外观 披风 礼盒
	PENDANT        = 2,	-- 挂件
	PET            = 3,	-- 宠物
	HORSE          = 4,	-- 坐骑 马
	HORSE_EQUIP    = 5,	-- 马具
	BOOK           = 6,	-- 书籍
	WEAPON         = 7,	-- 武器
	EQUIPMENT_SIGN = 8,	-- 装备兑换牌
	EQUIPMENT      = 9,	-- 散件装备
	MATERIAL       = 10, -- 材料
	ZIBABA         = 11, -- 小铁
	ENCHANT_ITEM   = 12, -- 附魔
	TASK_ITEM      = 13, -- 任务道具
	OTHER          = 14,
	GARBAGE        = 15, -- 垃圾
}
local function GetItemDataType(data)
	-- 外观 披风 礼盒
	if data.item.nGenre == ITEM_GENRE.COIN_SHOP_QUANTITY_LIMIT_ITEM then
		return 'COIN_SHOP'
	end
	if data.item.nGenre == ITEM_GENRE.EQUIPMENT and (
		data.item.nSub == CONSTANT.EQUIPMENT_SUB.L_SHOULDER_EXTEND
		or data.item.nSub == CONSTANT.EQUIPMENT_SUB.R_SHOULDER_EXTEND
		or data.item.nSub == CONSTANT.EQUIPMENT_SUB.BACK_CLOAK_EXTEND
	) then
		return 'OUTLOOK'
	end
	-- 挂件
	if data.item.nGenre == ITEM_GENRE.EQUIPMENT and (
		data.item.nSub == CONSTANT.EQUIPMENT_SUB.WAIST_EXTEND
		or data.item.nSub == CONSTANT.EQUIPMENT_SUB.BACK_EXTEND
		or data.item.nSub == CONSTANT.EQUIPMENT_SUB.FACE_EXTEND
	) then
		return 'PENDANT'
	end
	-- 宠物
	if (data.item.nGenre == ITEM_GENRE.CUB)
	or (data.item.nGenre == ITEM_GENRE.EQUIPMENT and data.item.nSub == CONSTANT.EQUIPMENT_SUB.PET) then
		return 'PET'
	end
	-- 坐骑 马
	if (data.item.nGenre == ITEM_GENRE.EQUIPMENT and data.item.nSub == CONSTANT.EQUIPMENT_SUB.HORSE) then
		return 'HORSE'
	end
	-- 马具
	if (data.item.nGenre == ITEM_GENRE.EQUIPMENT and data.item.nSub == CONSTANT.EQUIPMENT_SUB.HORSE_EQUIP) then
		return 'HORSE_EQUIP'
	end
	-- 书籍
	if (data.item.nGenre == ITEM_GENRE.BOOK) then
		return 'BOOK'
	end
	-- 武器
	if data.item.nGenre == ITEM_GENRE.EQUIPMENT
	and (data.item.nSub == CONSTANT.EQUIPMENT_SUB.MELEE_WEAPON or data.item.nSub == CONSTANT.EQUIPMENT_SUB.RANGE_WEAPON) then
		return 'WEAPON'
	end
	-- 装备兑换牌
	if (data.item.nGenre == ITEM_GENRE.MATERIAL and data.item.nSub == 6) then -- TODO: 枚举？
		return 'EQUIPMENT_SIGN'
	end
	-- 散件装备
	if data.item.nGenre == ITEM_GENRE.EQUIPMENT then -- TODO: 枚举？
		return 'EQUIPMENT'
	end
	-- 材料
	if data.item.nGenre == ITEM_GENRE.MATERIAL then
		-- 小铁
		if data.item.nQuality == GKP_LOOT_ZIBABA_QUALITY and X.GetItemIconByUIID(data.item.nUiId) == GKP_LOOT_ZIBABA_ICON then
			return 'ZIBABA'
		end
		-- 材料
		return 'MATERIAL'
	end
	-- 附魔
	if data.item.nGenre == ITEM_GENRE.ENCHANT_ITEM then
		return 'ENCHANT_ITEM'
	end
	-- 任务道具
	if data.item.nGenre == ITEM_GENRE.TASK_ITEM then
		return 'TASK_ITEM'
	end
	-- 垃圾
	if data.item.nQuality == 0 then
		return 'GARBAGE'
	end
	return 'OTHER'
end

function D.GetItemData(me, d, i)
	local item, bNeedRoll, bDist, bBidding = d.GetLootItem(i, me)
	if item then
		-- itemData
		local data = {
			dwDoodadID   = d.dwID        ,
			szDoodadName = d.szName      ,
			item         = item          ,
			szName       = X.GetItemNameByItem(item),
			dwID         = item.dwID     ,
			dwTabType    = item.dwTabType,
			dwIndex      = item.dwIndex  ,
			nUiId        = item.nUiId    ,
			nGenre       = item.nGenre   ,
			nSub         = item.nSub     ,
			nQuality     = item.nQuality ,
			bNeedRoll    = bNeedRoll     ,
			bDist        = bDist         ,
			bBidding     = bBidding      ,
			nStackNum    = item.bCanStack and item.nStackNum or 1,
			bSpecial     = item.nQuality == GKP_LOOT_HUANGBABA_QUALITY
				and X.GetItemIconByUIID(item.nUiId) == GKP_LOOT_HUANGBABA_ICON,
		}
		if DEBUG_LOOT then
			data.bDist = true -- !!! Debug
		end
		if item.nGenre == ITEM_GENRE.BOOK then
			data.nBookID = item.nBookID
		end
		data.szType = GetItemDataType(data)
		data.nWeight = ITEM_DATA_WEIGHT[data.szType]
		return data
	end
end

local function LootItemSorter(data1, data2)
	return data1.nWeight < data2.nWeight
end

-- 检查物品
function D.GetDoodadLootInfo(dwID)
	local me = GetClientPlayer()
	local d  = GetDoodad(dwID)
	local aItemData = {}
	local bSpecial = false
	local nMoney, szName = 0, ''
	if me and d then
		local nLootItemCount = d.GetItemListCount()
		for i = 0, nLootItemCount - 1 do
			local data = D.GetItemData(me, d, i)
			if data then
				if data.bSpecial then
					bSpecial = true
				end
				table.insert(aItemData, data)
			end
		end
		nMoney = d.GetLootMoney() or 0
		szName = d.szName
	end
	table.sort(aItemData, LootItemSorter)
	return aItemData, nMoney, szName, bSpecial
end

function D.ShowSystemLoot()
	for _, szName in ipairs({'LootList', 'GoldTeamLootList'}) do
		local frame = Station.SearchFrame(szName)
		if frame and frame:GetAbsX() == 4096 then
			frame:SetPoint('CENTER', 0, 0, 'CENTER', 0, 0)
		end
	end
end

function D.HideSystemLoot()
	for _, szName in ipairs({'LootList', 'GoldTeamLootList'}) do
		local frame = Station.SearchFrame(szName)
		if frame and frame:GetAbsX() ~= 4096 then
			frame:SetAbsPos(4096, 4096)
		end
		-- Wnd.CloseWindow(szName)
	end
end

function D.AutoSetSystemLootVisible()
	local team = GetClientTeam()
	local bCanBiddingDistribute = team and team.nLootMode == PARTY_LOOT_MODE.BIDDING
		and team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE) == UI_GetClientPlayerID()
	if D.IsEnabled() and not bCanBiddingDistribute then
		D.HideSystemLoot()
	else
		D.ShowSystemLoot()
	end
end

X.RegisterFrameCreate('LootList', 'MY_GKPLoot', function()
	HookTableFunc(arg0, 'SetPoint', D.AutoSetSystemLootVisible, { bAfterOrigin = true })
	HookTableFunc(arg0, 'SetRelPos', D.AutoSetSystemLootVisible, { bAfterOrigin = true })
	HookTableFunc(arg0, 'SetAbsPos', D.AutoSetSystemLootVisible, { bAfterOrigin = true })
	HookTableFunc(arg0, 'CorrectPos', D.AutoSetSystemLootVisible, { bAfterOrigin = true })
end)

X.RegisterFrameCreate('GoldTeamLootList', 'MY_GKPLoot', function()
	HookTableFunc(arg0, 'SetPoint', D.AutoSetSystemLootVisible, { bAfterOrigin = true })
	HookTableFunc(arg0, 'SetRelPos', D.AutoSetSystemLootVisible, { bAfterOrigin = true })
	HookTableFunc(arg0, 'SetAbsPos', D.AutoSetSystemLootVisible, { bAfterOrigin = true })
	HookTableFunc(arg0, 'CorrectPos', D.AutoSetSystemLootVisible, { bAfterOrigin = true })
end)

X.RegisterEvent('TEAM_AUTHORITY_CHANGED', 'MY_GKPLoot', D.AutoSetSystemLootVisible)

-- 摸箱子
X.RegisterEvent('OPEN_DOODAD', function()
	if not D.IsEnabled() then
		return
	end
	if arg1 ~= UI_GetClientPlayerID() then
		return
	end
	local doodad = GetDoodad(arg0)
	local nM = doodad.GetLootMoney() or 0
	if nM > 0 then
		LootMoney(arg0)
		PlaySound(SOUND.UI_SOUND, g_sound.PickupMoney)
	end
	local data = D.GetDoodadLootInfo(arg0)
	if #data == 0 then
		return D.DrawLootList(arg0, true)
	end
	--[[#DEBUG BEGIN]]
	X.Debug('MY_GKPLoot', 'Open Doodad: ' .. arg0, X.DEBUG_LEVEL.LOG)
	--[[#DEBUG END]]
	D.InsertLootList(arg0)
	D.HideSystemLoot()
end)

-- 刷新箱子
X.RegisterEvent('SYNC_LOOT_LIST', function()
	if not D.IsEnabled() then
		return
	end
	local frame = D.GetFrame()
	local wnd = D.GetDoodadWnd(frame, arg0)
	if not wnd and X.IsRestricted('MY_GKPLoot.ForceLoot') then
		local bDungeonTreasure = false
		local aItemData = D.GetDoodadLootInfo(arg0)
		for _, v in ipairs(aItemData) do
			if wstring.find(v.szName, _L['Dungeon treasure']) == 1 -- 秘境宝箱
			or v.szName == X.GetObjectName('ITEM_INFO', 5, 33011) then -- 砥砺同心礼盒
				bDungeonTreasure = true
				break
			end
		end
		if not bDungeonTreasure then
			return
		end
	end
	D.InsertLootList(arg0)
end)

X.RegisterEvent('MY_GKP_LOOT_BOSS', function()
	if not arg0 then
		MY_GKP_LOOT_BOSS = nil
		GKP_LOOT_RECENT = {}
	else
		local team = GetClientTeam()
		if team then
			for k, v in ipairs(team.GetTeamMemberList()) do
				local info = GetClientTeam().GetMemberInfo(v)
				if info.szName == arg0 then
					MY_GKP_LOOT_BOSS = v
					break
				end
			end
		end
	end
end)

function D.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nLH, nX, nY, nLFY)
	nX, nY = nPaddingX, nLFY
	ui:Append('Text', { text = _L['GKP Doodad helper'], x = nX, y = nY, font = 27 })

	nX, nY = nPaddingX + 10, nY + nLH
	nX = ui:Append('WndCheckBox', {
		x = nX, y = nY,
		text = _L['Enable MY_GKPLoot'],
		checked = O.bOn,
		oncheck = function(bChecked)
			O.bOn = bChecked
		end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	nX = ui:Append('WndCheckBox', {
		x = nX, y = nY,
		text = _L['Team dungeon'],
		checked = O.bInTeamDungeon,
		oncheck = function(bChecked)
			O.bInTeamDungeon = bChecked
			D.OutputEnable()
		end,
		tip = _L['Enable in checked map type'],
		tippostype = UI.TIP_POSITION.BOTTOM_TOP,
		autoenable = function() return O.bOn end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	nX = ui:Append('WndCheckBox', {
		x = nX, y = nY,
		text = _L['Raid dungeon'],
		checked = O.bInRaidDungeon,
		oncheck = function(bChecked)
			O.bInRaidDungeon = bChecked
			D.OutputEnable()
		end,
		tip = _L['Enable in checked map type'],
		tippostype = UI.TIP_POSITION.BOTTOM_TOP,
		autoenable = function() return O.bOn end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	nX = ui:Append('WndCheckBox', {
		x = nX, y = nY,
		text = _L['Battlefield'],
		checked = O.bInBattlefield,
		oncheck = function(bChecked)
			O.bInBattlefield = bChecked
			D.OutputEnable()
		end,
		tip = _L['Enable in checked map type'],
		tippostype = UI.TIP_POSITION.BOTTOM_TOP,
		autoenable = function() return O.bOn end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	nX = ui:Append('WndCheckBox', {
		x = nX, y = nY,
		text = _L['Other map'],
		checked = O.bInOtherMap,
		oncheck = function(bChecked)
			O.bInOtherMap = bChecked
			D.OutputEnable()
		end,
		tip = _L['Enable in checked map type'],
		tippostype = UI.TIP_POSITION.BOTTOM_TOP,
		autoenable = function() return O.bOn end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10

	nX, nY = nPaddingX + 10, nY + nLH

	nX = nX + ui:Append('WndCheckBox', {
		x = nX, y = nY,
		text = _L['Show 2nd kungfu fit icon'],
		checked = O.bShow2ndKungfuLoot,
		oncheck = function()
			O.bShow2ndKungfuLoot = not O.bShow2ndKungfuLoot
			FireUIEvent('MY_GKP_LOOT_RELOAD')
		end,
		autoenable = function() return O.bOn end,
	}):AutoWidth():Width() + 10

	nX, nY = nPaddingX + 10, nY + nLH
	nX = nX + ui:Append('WndComboBox', {
		x = nX, y = nY, w = 200,
		text = _L['Confirm when distribute'],
		lmenu = function()
			local t = {}
			table.insert(t, { szOption = _L['Category'], bDisable = true })
			for _, szKey in ipairs({
				'Huangbaba',
				'Book',
				'Pendant',
				'Outlook',
				'Pet',
				'Horse',
				'HorseEquip',
			}) do
				table.insert(t, {
					szOption = _L[szKey],
					bCheck = true,
					bChecked = O.tConfirm[szKey],
					fnAction = function()
						O.tConfirm[szKey] = not O.tConfirm[szKey]
						O.tConfirm = O.tConfirm
					end,
				})
			end
			table.insert(t, CONSTANT.MENU_DIVIDER)
			table.insert(t, { szOption = _L['Quality'], bDisable = true })
			for i, s in ipairs({
				[1] = g_tStrings.STR_WHITE,
				[2] = g_tStrings.STR_ROLLQUALITY_GREEN,
				[3] = g_tStrings.STR_ROLLQUALITY_BLUE,
				[4] = g_tStrings.STR_ROLLQUALITY_PURPLE,
				[5] = g_tStrings.STR_ROLLQUALITY_NACARAT,
			}) do
				table.insert(t, {
					szOption = _L('Reach %s', s),
					rgb = i == -1 and {255, 255, 255} or { GetItemFontColorByQuality(i) },
					bCheck = true, bMCheck = true,
					bChecked = i == O.nConfirmQuality,
					fnAction = function()
						O.nConfirmQuality = i
					end,
				})
			end
			return t
		end,
		autoenable = function() return O.bOn end,
	}):AutoWidth():Width() + 5
	nX = nX + ui:Append('WndComboBox', {
		x = nX, y = nY, w = 200,
		text = _L['Loot item filter'],
		menu = D.GetFilterMenu,
		autoenable = function() return O.bOn end,
	}):AutoWidth():Width() + 5
	nX = nX + ui:Append('WndComboBox', {
		x = nX, y = nY, w = 200,
		text = _L['Auto pickup'],
		menu = D.GetAutoPickupMenu,
		autoenable = function() return O.bOn end,
	}):AutoWidth():Width() + 5
	nLFY = nY + nLH

	return nX, nY, nLFY
end

-- Global exports
do
local settings = {
	name = 'MY_GKP_Loot',
	imports = {
		{
			fields = {
				'tConfirm',
				'tItemConfig',
			},
			root = D,
		},
	},
}
MY_GKP_Loot = X.CreateModule(settings)
end

-- Global exports
do
local settings = {
	name = 'MY_GKPLoot',
	exports = {
		{
			preset = 'UIEvent',
			fields = {
				'IsEnabled',
				'CanDialog',
				'IsItemDisplay',
				'IsItemAutoPickup',
				'GetMessageBox',
				'GetaPartyMember',
				'GetItemData',
				'GetItemBiddingMenu',
				'OnPanelActivePartial',
			},
			root = D,
		},
		{
			fields = {
				'bOn',
				'tAutoPickupQuality',
			},
			root = O,
		},
	},
	imports = {
		{
			fields = {
				'CanDialog',
				'IsItemDisplay',
				'IsItemAutoPickup',
			},
			root = D,
		},
		{
			fields = {
				'bOn',
			},
			root = O,
		},
	},
}
MY_GKPLoot = X.CreateModule(settings)
end
