--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 扁平血条设置
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
local PLUGIN_NAME = 'MY_LifeBar'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_LifeBar'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
--------------------------------------------------------------------------

local Config = MY_LifeBar_Config
if not Config then
	return
end

local D = {
	Reset = MY_LifeBar.Reset,
	Repaint = MY_LifeBar.Repaint,
	IsEnabled = MY_LifeBar.IsEnabled,
	IsShielded = MY_LifeBar.IsShielded,
	UpdateShadowHandleParam = MY_LifeBar.UpdateShadowHandleParam,
}

local PS = { nPriority = 1, szRestriction = 'MY_LifeBar' }
local function LoadUI(ui)
	ui:Children('#WndTrackbar_GlobalUIScale'):Value(Config.fGlobalUIScale * 100 * X.GetUIScale())
	ui:Children('#WndTrackbar_LifeBarWidth'):Value(Config.nLifeWidth)
	ui:Children('#WndTrackbar_LifeBarHeight'):Value(Config.nLifeHeight)
	ui:Children('#WndTrackbar_LifeBarOffsetX'):Value(Config.nLifeOffsetX)
	ui:Children('#WndTrackbar_LifeBarOffsetY'):Value(Config.nLifeOffsetY)
	ui:Children('#WndTrackbar_LifeBarPadding'):Value(Config.nLifePadding)
	ui:Children('#WndTrackbar_LifeBarBorder'):Value(Config.nLifeBorder)
	ui:Children('#Shadow_LifeBarBorderRGB'):Color(Config.nLifeBorderR, Config.nLifeBorderG, Config.nLifeBorderB)
	ui:Children('#WndTrackbar_TextOffsetY'):Value(Config.nTextOffsetY)
	ui:Children('#WndTrackbar_TextLineHeight'):Value(Config.nTextLineHeight)
	ui:Children('#WndTrackbar_TextScale'):Value(Config.fTextScale * 40)
	ui:Children('#WndTrackbar_TextSpacing'):Value(Config.fTextSpacing * 10)
	ui:Children('#WndTrackbar_TitleEffectScale'):Value(Config.fTitleEffectScale * 100)
	ui:Children('#WndTrackbar_TitleEffectOffsetY'):Value(Config.nTitleEffectOffsetY)
	ui:Children('#WndTrackbar_BalloonOffsetY'):Value(Config.nBalloonOffsetY)
	ui:Children('#WndTrackbar_LifePerOffsetX'):Value(Config.nLifePerOffsetX)
	ui:Children('#WndTrackbar_LifePerOffsetY'):Value(Config.nLifePerOffsetY)
	ui:Children('#WndTrackbar_Distance'):Value(math.sqrt(Config.nDistance) / 64)
	ui:Children('#WndTrackbar_VerticalDistance'):Value(Config.nVerticalDistance / 8 / 64)
	ui:Children('#WndTrackbar_Alpha'):Value(Config.nAlpha)
	ui:Children('#WndCheckBox_IgnoreUIScale'):Check(not Config.bSystemUIScale)
	ui:Children('#WndCheckBox_ShowWhenUIHide'):Check(Config.bShowWhenUIHide)
	ui:Children('#WndCheckBox_ShowObjectID'):Check(Config.bShowObjectID)
	ui:Children('#WndCheckBox_ShowObjectIDOnlyUnnamed'):Check(Config.bShowObjectIDOnlyUnnamed)
	ui:Children('#WndCheckBox_ShowSpecialNpc'):Check(Config.bShowSpecialNpc)
	ui:Children('#WndCheckBox_ShowSpecialNpcOnlyEnemy'):Check(Config.bShowSpecialNpcOnlyEnemy)
	ui:Children('#WndCheckBox_ShowKungfu'):Check(Config.bShowKungfu)
	ui:Children('#WndCheckBox_ShowDistance'):Check(Config.bShowDistance)
	ui:Children('#WndCheckBox_ShowDistanceOnlyTarget'):Check(Config.bShowDistanceOnlyTarget)
	ui:Children('#WndCheckBox_ScreenPosSort'):Check(Config.bScreenPosSort)
	ui:Children('#WndCheckBox_MineOnTop'):Check(Config.bMineOnTop)
	ui:Children('#WndCheckBox_TargetOnTop'):Check(Config.bTargetOnTop)
end
function PS.OnPanelActive(wnd)
	local ui = UI(wnd)
	local nW, nH = ui:Size()
	local nPaddingX, nPaddingY = 10, 10
	local nX, nY = nPaddingX, nPaddingY
	local nLH = 40

	-- 开启
	nX = nX + ui:Append('WndCheckBox', {
		x = nX, y = nY, text = _L['Enable'],
		checked = MY_LifeBar.bEnabled,
		oncheck = function(bChecked)
			MY_LifeBar.bEnabled = bChecked
			D.Reset(true)
		end,
		tip = function()
			if D.IsShielded() then
				return _L['Can not use in shielded map!']
			end
		end,
		autoenable = function() return not D.IsShielded() end,
	}):AutoWidth():Width() + 5
	-- 加载旧版配置文件
	nX = nX + ui:Append('WndButton', {
		x = nX, y = nY, w = 120, h = 25,
		buttonstyle = 'FLAT',
		text = _L['Load ancient config'],
		onclick = function()
			GetUserInput(_L['Please input ancient config name:'], function(szText)
				Config('load', szText)
				X.SwitchTab('MY_LifeBar', true)
			end, nil, nil, nil, 'common')
		end,
		autoenable = function() return D.IsEnabled() end,
	}):Width() + 5
	nX = nW - 490
	nX = nX + ui:Append('WndCheckBox', {
		x = nX, y = nY, w = 155, text = _L['Auto hide system headtop'],
		checked = MY_LifeBar.bAutoHideSysHeadtop,
		oncheck = function(bChecked)
			MY_LifeBar.bAutoHideSysHeadtop = bChecked
			D.Reset(true)
		end,
	}):AutoWidth():Width() + 5
	nX = nX + ui:Append('WndCheckBox', {
		x = nX, y = nY, w = 80, text = _L['Arena'],
		checked = Config.bOnlyInArena,
		oncheck = function(bChecked)
			Config.bOnlyInArena = bChecked
			D.Reset(true)
		end,
		tip = _L['Only enable in checked map types'],
		tippostype = UI.TIP_POSITION.TOP_BOTTOM,
		autoenable = function() return D.IsEnabled() end,
	}):AutoWidth():Width() + 5
	nX = nX + ui:Append('WndCheckBox', {
		x = nX, y = nY, w = 70, text = _L['Battlefield'],
		checked = Config.bOnlyInBattleField,
		oncheck = function(bChecked)
			Config.bOnlyInBattleField = bChecked
			D.Reset(true)
		end,
		tip = _L['Only enable in checked map types'],
		tippostype = UI.TIP_POSITION.TOP_BOTTOM,
		autoenable = function() return D.IsEnabled() end,
	}):AutoWidth():Width() + 5
	nX = nX + ui:Append('WndCheckBox', {
		x = nX, y = nY, w = 70, text = _L['Dungeon'],
		checked = Config.bOnlyInDungeon,
		oncheck = function(bChecked)
			Config.bOnlyInDungeon = bChecked
			D.Reset(true)
		end,
		tip = _L['Only enable in checked map types'],
		tippostype = UI.TIP_POSITION.TOP_BOTTOM,
		autoenable = function() return D.IsEnabled() end,
	}):AutoWidth():Width() + 5
	nY = nY + nLH
	-- <hr />
	ui:Append('Image', {
		name = 'Image_Spliter',
		x = 10, y = nY, w = nW - 20, h = 1,
		image = 'UI/Image/UICommon/ScienceTreeNode.UITex|62',
	})

	nPaddingX, nPaddingY = 15, nY + 10
	nX, nY = nPaddingX + 15, nPaddingY
	nLH = 23.6

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_LifeBarWidth',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 5, 150 },
		text = function(value) return _L('Lifebar width: %s px.', value) end, -- 血条宽度
		value = Config.nLifeWidth,
		onchange = function(value)
			Config.nLifeWidth = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_LifeBarHeight',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 1, 150 },
		text = function(value) return _L('Lifebar height: %s px.', value) end, -- 血条高度
		value = Config.nLifeHeight,
		onchange = function(value)
			Config.nLifeHeight = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_LifeBarOffsetX',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { -150, 150 },
		text = function(value) return _L('Lifebar offset-x: %d px.', value) end, -- 血条水平偏移
		value = Config.nLifeOffsetX,
		onchange = function(value)
			Config.nLifeOffsetX = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_LifeBarOffsetY',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 150 },
		text = function(value) return _L('Lifebar offset-y: %d px.', value) end, -- 血条竖直偏移
		value = Config.nLifeOffsetY,
		onchange = function(value)
			Config.nLifeOffsetY = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_LifeBarPadding',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 10 },
		text = function(value) return _L('Lifebar padding: %d px.', value) end, -- 血条边框宽度
		value = Config.nLifePadding,
		onchange = function(value)
			Config.nLifePadding = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_LifeBarBorder',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 10 },
		text = function(value) return _L('Lifebar border: %d px.', value) end, -- 血条边框宽度
		value = Config.nLifeBorder,
		onchange = function(value)
			Config.nLifeBorder = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_LifePerOffsetX',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { -150, 150 },
		text = function(value) return _L('Life percentage offset-x: %d px.', value) end, -- 血量百分比水平偏移
		value = Config.nLifePerOffsetX,
		onchange = function(value)
			Config.nLifePerOffsetX = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_LifePerOffsetY',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 150 },
		text = function(value) return _L('Life percentage offset-y: %d px.', value) end, -- 血量百分比竖直偏移
		value = Config.nLifePerOffsetY,
		onchange = function(value)
			Config.nLifePerOffsetY = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_TextOffsetY',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 150 },
		text = function(value) return _L('Text offset-y: %d px.', value) end, -- 第一行字高度
		value = Config.nTextOffsetY,
		onchange = function(value)
			Config.nTextOffsetY = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_TextLineHeight',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 150 },
		text = function(value) return _L('Text line height: %d px.', value) end, -- 字行高度
		value = Config.nTextLineHeight,
		onchange = function(value)
			Config.nTextLineHeight = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_TextScale',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 200 },
		text = function(value) return _L('Text scale: %.1f%%.', value / 40 * 100) end, -- 字缩放
		value = Config.fTextScale * 40,
		onchange = function(value)
			Config.fTextScale = value / 40
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_TextSpacing',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 300 },
		text = function(value) return _L('Text spacing: %.1f.', value / 10) end, -- 字间距
		value = Config.fTextSpacing * 10,
		onchange = function(value)
			Config.fTextSpacing = value / 10
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_TitleEffectScale',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 200 },
		text = function(value) return _L('Title effect scale: %.2f%%.', value / 100) end, -- 头顶特效缩放
		value = Config.fTitleEffectScale * 100,
		onchange = function(value)
			Config.fTitleEffectScale = value / 100
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_TitleEffectOffsetY',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { -150, 150 },
		text = function(value) return _L('Title effect offset y: %d px.', value) end, -- 头顶特效间距
		value = Config.nTitleEffectOffsetY,
		onchange = function(value)
			Config.nTitleEffectOffsetY = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_BalloonOffsetY',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { -150, 150 },
		text = function(value) return _L('Balloon offset y: %d px.', value) end, -- 头顶特效间距
		value = Config.nBalloonOffsetY,
		onchange = function(value)
			Config.nBalloonOffsetY = value
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_Distance',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 300 },
		text = function(value) return value == 0 and _L['Max Distance: Unlimited.'] or _L('Max Distance: %s foot.', value) end,
		value = math.sqrt(Config.nDistance) / 64,
		onchange = function(value)
			Config.nDistance = value * value * 64 * 64
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_VerticalDistance',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 0, 300 },
		text = function(value) return value == 0 and _L['Max Vertical Distance: Unlimited.'] or _L('Max Vertical Distance: %s foot.', value) end,
		value = Config.nVerticalDistance / 8 / 64,
		onchange = function(value)
			Config.nVerticalDistance = value * 8 * 64
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_Alpha',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_PERCENT, range = { 0, 255 },
		text = function(value) return _L('Alpha: %.0f%%.', value) end, -- 透明度
		value = Config.nAlpha,
		onchange = function(value)
			Config.nAlpha = value * 255 / 100
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	ui:Append('WndTrackbar', {
		name = 'WndTrackbar_GlobalUIScale',
		x = nX, y = nY, trackbarstyle = UI.TRACKBAR_STYLE.SHOW_VALUE, range = { 1, 200 },
		text = function(value) return _L('Global UI scale: %.2f.', value / 100) end, -- 字缩放
		value = Config.fGlobalUIScale * 100 * X.GetUIScale(),
		onchange = function(value)
			Config.fGlobalUIScale = value / 100 / X.GetUIScale()
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	-- 右半边
	nPaddingX = nW - 250
	nX, nY = nPaddingX, nPaddingY
	nLH = 27

	-- 颜色设置
	ui:Append('WndComboBox', {
		x = nX, y = nY, text = _L['Color config'],
		menu = function()
			local t = {}
			local tColor = Config.Color
			-- 玩家颜色设置
			table.insert(t, { szOption = _L['Player color config'], bDisable = true } )
			for relation, cfg in pairs(tColor) do
				if cfg.Player then
					local opt = {}
					opt.szOption = _L[relation]
					opt.rgb = cfg.Player
					opt.szIcon = 'ui/Image/button/CommonButton_1.UITex'
					opt.nFrame = 69
					opt.nMouseOverFrame = 70
					opt.szLayer = 'ICON_RIGHT'
					opt.fnClickIcon = function()
						UI.OpenColorPicker(function(r, g, b)
							cfg.Player = { r, g, b }
							opt.rgb = cfg.Player
							Config.Color = tColor
						end)
					end
					table.insert(opt, {
						szOption = _L['Unified force color'],
						bCheck = true, bMCheck = true,
						bChecked = not cfg.DifferentiateForce,
						fnAction = function(_, r, g, b)
							cfg.DifferentiateForce = false
							Config.Color = tColor
						end,
						rgb = cfg.Player,
						fnChangeColor = function(_, r, g, b)
							cfg.Player = {r, g, b}
							opt.rgb = cfg.Player
							Config.Color = tColor
						end,
					})
					table.insert(opt, {
						szOption = _L['Differentiate force color'],
						bCheck = true, bMCheck = true,
						bChecked = cfg.DifferentiateForce,
						fnAction = function(_, r, g, b)
							cfg.DifferentiateForce = true
							Config.Color = tColor
						end,
					})
					table.insert(opt, { bDevide = true })
					for dwForceID, szForceTitle in pairs(g_tStrings.tForceTitle) do
						table.insert(opt, {
							szOption = szForceTitle,
							rgb = cfg[dwForceID],
							fnChangeColor = function(_, r, g, b)
								cfg[dwForceID] = { r, g, b }
								Config.Color = tColor
							end,
							fnDisable = function()
								return not cfg.DifferentiateForce
							end,
						})
					end
					table.insert(t, opt)
				end
			end
			table.insert(t, { bDevide = true } )
			-- NCP颜色设置
			table.insert(t, { szOption = _L['Npc color config'], bDisable = true } )
			for relation, cfg in pairs(tColor) do
				if cfg.Npc then
					local opt = {}
					opt.szOption = _L[relation]
					opt.rgb = cfg.Npc
					opt.szIcon = 'ui/Image/button/CommonButton_1.UITex'
					opt.nFrame = 69
					opt.nMouseOverFrame = 70
					opt.szLayer = 'ICON_RIGHT'
					opt.fnClickIcon = function()
						UI.OpenColorPicker(function(r, g, b)
							cfg.Npc = { r, g, b }
							opt.rgb = cfg.Npc
							Config.Color = tColor
						end)
					end
					table.insert(t, opt)
				end
			end
			return t
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	local function GeneBooleanPopupMenu(szKey, szPlayerTip, szNpcTip)
		local t = {}
		local tRelationCfg = Config[szKey]
		if szPlayerTip then
			table.insert(t, { szOption = szPlayerTip, bDisable = true } )
			for relation, cfg in pairs(tRelationCfg) do
				if cfg.Player then
					table.insert(t, {
						szOption = _L[relation],
						rgb = Config.Color[relation].Player,
						bCheck = true,
						bChecked = cfg.Player.bEnable,
						fnAction = function()
							cfg.Player.bEnable = not cfg.Player.bEnable
							Config[szKey] = tRelationCfg
							D.Reset()
						end,
						{
							szOption = _L['Hide when unfight'],
							bCheck = true,
							bChecked = cfg.Player.bOnlyFighting,
							fnAction = function()
								cfg.Player.bOnlyFighting = not cfg.Player.bOnlyFighting
								Config[szKey] = tRelationCfg
							end,
						},
						{
							szOption = _L['Hide when full life'],
							bCheck = true,
							bChecked = cfg.Player.bHideFullLife,
							fnAction = function()
								cfg.Player.bHideFullLife = not cfg.Player.bHideFullLife
								Config[szKey] = tRelationCfg
							end,
						},
						{
							szOption = _L['Hide in dungeon'],
							bCheck = true,
							bChecked = cfg.Player.bHideInDungeon,
							fnAction = function()
								cfg.Player.bHideInDungeon = not cfg.Player.bHideInDungeon
								Config[szKey] = tRelationCfg
							end,
						},
						{
							szOption = _L['Only target'],
							bCheck = true,
							bChecked = cfg.Player.bOnlyTarget,
							fnAction = function()
								cfg.Player.bOnlyTarget = not cfg.Player.bOnlyTarget
								Config[szKey] = tRelationCfg
							end,
						},
					})
				end
			end
		end
		if szPlayerTip and szNpcTip then
			table.insert(t, { bDevide = true })
		end
		if szNpcTip then
			table.insert(t, { szOption = szNpcTip, bDisable = true } )
			for relation, cfg in pairs(tRelationCfg) do
				if cfg.Npc then
					table.insert(t, {
						szOption = _L[relation],
						rgb = Config.Color[relation].Npc,
						bCheck = true,
						bChecked = cfg.Npc.bEnable,
						fnAction = function()
							cfg.Npc.bEnable = not cfg.Npc.bEnable
							Config[szKey] = tRelationCfg
							D.Reset()
						end,
						{
							szOption = _L['Hide when unfight'],
							bCheck = true,
							bChecked = cfg.Npc.bOnlyFighting,
							fnAction = function()
								cfg.Npc.bOnlyFighting = not cfg.Npc.bOnlyFighting
								Config[szKey] = tRelationCfg
							end,
						},
						{
							szOption = _L['Hide when full life'],
							bCheck = true,
							bChecked = cfg.Npc.bHideFullLife,
							fnAction = function()
								cfg.Npc.bHideFullLife = not cfg.Npc.bHideFullLife
								Config[szKey] = tRelationCfg
							end,
						},
						{
							szOption = _L['Hide in dungeon'],
							bCheck = true,
							bChecked = cfg.Npc.bHideInDungeon,
							fnAction = function()
								cfg.Npc.bHideInDungeon = not cfg.Npc.bHideInDungeon
								Config[szKey] = tRelationCfg
							end,
						},
						{
							szOption = _L['Only target'],
							bCheck = true,
							bChecked = cfg.Npc.bOnlyTarget,
							fnAction = function()
								cfg.Npc.bOnlyTarget = not cfg.Npc.bOnlyTarget
								Config[szKey] = tRelationCfg
							end,
						},
						{
							szOption = _L['Hide pets'],
							bCheck = true,
							bChecked = cfg.Npc.bHidePets,
							fnAction = function()
								cfg.Npc.bHidePets = not cfg.Npc.bHidePets
								Config[szKey] = tRelationCfg
							end,
						},
					})
				end
			end
		end
		return t
	end

	-- 显示名字
	ui:Append('WndComboBox', {
		x = nX, y = nY, text = _L['Name display config'],
		menu = function()
			return GeneBooleanPopupMenu('ShowName', _L['Player name display'], _L['Npc name display'])
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	-- 称号
	ui:Append('WndComboBox', {
		x = nX, y = nY, text = _L['Title display config'],
		menu = function()
			return GeneBooleanPopupMenu('ShowTitle', _L['Player title display'], _L['Npc title display'])
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	-- 帮会
	ui:Append('WndComboBox', {
		x = nX, y = nY, text = _L['Tong display config'],
		menu = function()
			return GeneBooleanPopupMenu('ShowTong', _L['Player tong display'])
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	-- 血条设置
	ui:Append('WndComboBox', {
		x = nX, y = nY, text = _L['Lifebar display config'],
		menu = function()
			local t = GeneBooleanPopupMenu('ShowLife', _L['Player lifebar display'], _L['Npc lifebar display'])
			table.insert(t, { bDevide = true })
			local t1 = {
				szOption = _L['Draw direction'],
			}
			for _, szDirection in ipairs({ 'LEFT_RIGHT', 'RIGHT_LEFT', 'TOP_BOTTOM', 'BOTTOM_TOP' }) do
				table.insert(t1, {
					szOption = _L.DIRECTION[szDirection],
					bCheck = true, bMCheck = true,
					bChecked = Config.szLifeDirection == szDirection,
					fnAction = function()
						Config.szLifeDirection = szDirection
					end,
				})
			end
			table.insert(t, t1)
			return t
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	-- 显示血量%
	ui:Append('WndComboBox', {
		x = nX, y = nY, text = _L['Lifepercentage display config'],
		menu = function()
			local t = GeneBooleanPopupMenu('ShowLifePer', _L['Player lifepercentage display'], _L['Npc lifepercentage display'])
			table.insert(t, { bDevide = true })
			table.insert(t, {
				szOption = _L['Hide decimal'],
				bCheck = true,
				bChecked = Config.bHideLifePercentageDecimal,
				fnAction = function()
					Config.bHideLifePercentageDecimal = not Config.bHideLifePercentageDecimal
				end,
			})
			return t
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	-- 显示对话泡泡
	ui:Append('WndComboBox', {
		x = nX, y = nY, text = _L['Balloon display config'],
		menu = function()
			local t = {}
			local tShowBalloon = Config.ShowBalloon
			table.insert(t, { szOption = _L['Player balloon display'], bDisable = true } )
			for relation, cfg in pairs(tShowBalloon) do
				if cfg.Player then
					table.insert(t, {
						szOption = _L[relation],
						rgb = Config.Color[relation].Player,
						bCheck = true,
						bChecked = cfg.Player.bEnable,
						fnAction = function()
							cfg.Player.bEnable = not cfg.Player.bEnable
							Config.ShowBalloon = tShowBalloon
							D.Reset()
						end,
					})
				end
			end
			table.insert(t, { bDevide = true })
			table.insert(t, { szOption = _L['Npc balloon display'], bDisable = true } )
			for relation, cfg in pairs(tShowBalloon) do
				if cfg.Npc then
					table.insert(t, {
						szOption = _L[relation],
						rgb = Config.Color[relation].Npc,
						bCheck = true,
						bChecked = cfg.Npc.bEnable,
						fnAction = function()
							cfg.Npc.bEnable = not cfg.Npc.bEnable
							Config.ShowBalloon = tShowBalloon
							D.Reset()
						end,
					})
				end
			end
			table.insert(t, { bDevide = true })
			local tBalloonChannel = Config.BalloonChannel
			table.insert(t, { szOption = _L['Balloon channel config'], bDisable = true } )
			for szMsgType, cfg in pairs(tBalloonChannel) do
				if g_tStrings.tChannelName[szMsgType] then
					local t1 = {
						szOption = _L['Balloon display time'],
						fnDisable = function() return not cfg.bEnable end,
					}
					for _, nDuring in ipairs({ 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 15000, 20000 }) do
						table.insert(t1, {
							szOption = nDuring .. 'ms',
							bCheck = true, bMCheck = true,
							bChecked = cfg.nDuring == nDuring,
							fnAction = function()
								cfg.nDuring = nDuring
								Config.BalloonChannel = tBalloonChannel
								D.Reset()
							end,
							fnDisable = function() return not cfg.bEnable end,
						})
					end
					table.insert(t, {
						szOption = g_tStrings.tChannelName[szMsgType],
						rgb = GetMsgFontColor(szMsgType, true),
						bCheck = true, bChecked = cfg.bEnable,
						fnAction = function()
							cfg.bEnable = not cfg.bEnable
							Config.BalloonChannel = tBalloonChannel
							D.Reset()
						end,
						t1,
					})
				end
			end
			return t
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	-- 当前阵营
	ui:Append('WndComboBox', {
		x = nX, y = nY, text = _L['Set current camp'],
		menu = function()
			return {{
				szOption = _L['Auto detect'],
				bCheck = true, bMCheck = true,
				bChecked = Config.nCamp == -1,
				fnAction = function()
					Config.nCamp = -1
				end,
			}, {
				szOption = g_tStrings.STR_CAMP_TITLE[CAMP.GOOD],
				bCheck = true, bMCheck = true,
				bChecked = Config.nCamp == CAMP.GOOD,
				fnAction = function()
					Config.nCamp = CAMP.GOOD
				end,
			}, {
				szOption = g_tStrings.STR_CAMP_TITLE[CAMP.EVIL],
				bCheck = true, bMCheck = true,
				bChecked = Config.nCamp == CAMP.EVIL,
				fnAction = function()
					Config.nCamp = CAMP.EVIL
				end,
			}, {
				szOption = g_tStrings.STR_CAMP_TITLE[CAMP.NEUTRAL],
				bCheck = true, bMCheck = true,
				bChecked = Config.nCamp == CAMP.NEUTRAL,
				fnAction = function()
					Config.nCamp = CAMP.NEUTRAL
				end,
			}}
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH
	nLH = 36

	ui:Append('Shadow', {
		name = 'Shadow_LifeBarBorderRGB', -- 血条边框颜色
		x = nX + 4, y = nY + 6,
		r = Config.nLifeBorderR,
		g = Config.nLifeBorderG,
		b = Config.nLifeBorderB,
		onclick = function()
			local this = this
			UI.OpenColorPicker(function(r, g, b)
				Config.nLifeBorderR = r
				Config.nLifeBorderG = g
				Config.nLifeBorderB = b
				UI(this):Color(r, g, b)
			end)
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	ui:Append('Text', { text = _L['Lifebar border color'], x = nX + 27, y = nY - 2 })

	nX = nPaddingX
	nY = nY + nLH - 10
	nX = nX + ui:Append('WndCheckBox', {
		name = 'WndCheckBox_IgnoreUIScale',
		x = nX, y = nY, text = _L['Ignore ui scale'],
		checked = not Config.bSystemUIScale,
		oncheck = function(bChecked)
			Config.bSystemUIScale = not bChecked
		end,
		autoenable = function() return D.IsEnabled() end,
	}):AutoWidth():Width()

	nX = nPaddingX
	nY = nY + nLH - 10
	nX = nX + ui:Append('WndCheckBox', {
		name = 'WndCheckBox_ShowWhenUIHide',
		x = nX, y = nY, text = _L['Show when ui hide'],
		checked = Config.bShowWhenUIHide,
		oncheck = function(bChecked)
			Config.bShowWhenUIHide = bChecked
			D.UpdateShadowHandleParam()
		end,
		autoenable = function() return D.IsEnabled() end,
	}):AutoWidth():Width()

	nX = nPaddingX
	nY = nY + nLH - 10
	nX = nX + ui:Append('WndCheckBox', {
		name = 'WndCheckBox_ShowObjectID',
		x = nX, y = nY, text = _L['Show object id'],
		checked = Config.bShowObjectID,
		oncheck = function(bChecked)
			Config.bShowObjectID = bChecked
		end,
		autoenable = function() return D.IsEnabled() end,
	}):AutoWidth():Width()

	nX = nX + ui:Append('WndCheckBox', {
		name = 'WndCheckBox_ShowObjectIDOnlyUnnamed',
		x = nX, y = nY, text = _L['Only unnamed'],
		checked = Config.bShowObjectIDOnlyUnnamed,
		oncheck = function(bChecked)
			Config.bShowObjectIDOnlyUnnamed = bChecked
		end,
		autoenable = function() return D.IsEnabled() and Config.bShowObjectID end,
	}):AutoWidth():Width()

	if not X.IsRestricted('MY_LifeBar.SpecialNpc') then
		nX = nPaddingX
		nY = nY + nLH - 10
		nX = nX + ui:Append('WndCheckBox', {
			name = 'WndCheckBox_ShowSpecialNpc',
			x = nX, y = nY, text = _L['Show special npc'],
			checked = Config.bShowSpecialNpc,
			oncheck = function(bChecked)
				Config.bShowSpecialNpc = bChecked
				D.Reset()
			end,
			tip = _L['This function has been shielded by official except in dungeon'],
			tippostype = UI.TIP_POSITION.TOP_BOTTOM,
			autoenable = function() return D.IsEnabled() end,
		}):AutoWidth():Width() + 5
		ui:Append('WndCheckBox', {
			name = 'WndCheckBox_ShowSpecialNpcOnlyEnemy',
			x = nX, y = nY, w = 'auto',
			text = _L['Only enemy'],
			checked = Config.bShowSpecialNpcOnlyEnemy,
			oncheck = function(bChecked)
				Config.bShowSpecialNpcOnlyEnemy = bChecked
				D.Reset()
			end,
			tip = _L['This function has been shielded by official except in dungeon'],
			tippostype = UI.TIP_POSITION.TOP_BOTTOM,
			autoenable = function() return D.IsEnabled() and Config.bShowSpecialNpc end,
		})
	end

	nX = nPaddingX
	nY = nY + nLH - 10
	ui:Append('WndCheckBox', {
		name = 'WndCheckBox_ShowKungfu',
		x = nX, y = nY, w = 'auto',
		text = _L['Show kungfu'],
		checked = Config.bShowKungfu,
		oncheck = function(bChecked)
			Config.bShowKungfu = bChecked
		end,
		autoenable = function() return D.IsEnabled() end,
	})

	ui:Append('WndCheckBox', {
		name = 'WndCheckBox_ShowDistance',
		x = nX + 90, y = nY, w = 'auto',
		text = _L['Show distance'],
		checked = Config.bShowDistance,
		oncheck = function(bChecked)
			Config.bShowDistance = bChecked
		end,
		autoenable = function() return D.IsEnabled() end,
	})

	ui:Append('WndButton', {
		x = nX + 180, y = nY, w = 'auto',
		buttonstyle = 'OPTION',
		menu = function()
			local m = { szOption = _L['Decimal number'] }
			for i = 0, 2 do
				table.insert(m, {
					szOption = i,
					bCheck = true, bMCheck = true,
					bChecked = Config.nDistanceDecimal == i,
					fnAction = function()
						Config.nDistanceDecimal = i
						D.Reset()
					end,
				})
			end
			return {
				m,
				{
					szOption = _L['Show distance only target'],
					bCheck = true, bChecked = Config.bShowDistanceOnlyTarget,
					fnAction = function()
						Config.bShowDistanceOnlyTarget = not Config.bShowDistanceOnlyTarget
					end,
				},
			}
		end,
		autoenable = function() return D.IsEnabled() end,
	})

	nY = nY + nLH - 10
	ui:Append('WndCheckBox', {
		name = 'WndCheckBox_ScreenPosSort',
		x = nX, y = nY, w = 'auto',
		text = _L['Sort by screen pos'],
		checked = Config.bScreenPosSort,
		oncheck = function(bChecked)
			Config.bScreenPosSort = bChecked
		end,
		autoenable = function() return D.IsEnabled() end,
	})

	nY = nY + nLH - 10
	nX = nX + ui:Append('WndCheckBox', {
		name = 'WndCheckBox_MineOnTop',
		x = nX, y = nY, w = 'auto',
		text = _L['Self always on top'],
		checked = Config.bMineOnTop,
		oncheck = function(bChecked)
			Config.bMineOnTop = bChecked
		end,
		autoenable = function() return D.IsEnabled() end,
	}):Width() + 5

	nX = nX + ui:Append('WndCheckBox', {
		name = 'WndCheckBox_TargetOnTop',
		x = nX, y = nY, w = 'auto',
		text = _L['Target always on top'],
		checked = Config.bTargetOnTop,
		oncheck = function(bChecked)
			Config.bTargetOnTop = bChecked
		end,
		autoenable = function() return D.IsEnabled() end,
	}):Width() + 5

	nX = nPaddingX

	nY = nY + nLH - 5
	ui:Append('WndButton', {
		x = nX, y = nY, w = 65,
		text = _L['Font'],
		onclick = function()
			UI.OpenFontPicker(function(nFont)
				Config.nFont = nFont
			end)
		end,
		autoenable = function() return D.IsEnabled() end,
	})

	ui:Append('WndButton', {
		x = nX + 65, y = nY, w = 125, text = _L['Reset config'],
		onclick = function()
			Config('reset')
		end,
		autoenable = function() return D.IsEnabled() end,
	})
	nY = nY + nLH

	local function onReset()
		LoadUI(ui)
	end
	X.RegisterEvent('MY_LIFEBAR_CONFIG_LOADED', 'MY_LifeBarPS', onReset)
	X.RegisterEvent('MY_LIFEBAR_CONFIG_UPDATE', 'MY_LifeBarPS', onReset)
end

function PS.OnPanelDeactive()
	X.RegisterEvent('MY_LIFEBAR_CONFIG_LOADED', 'MY_LifeBarPS')
	X.RegisterEvent('MY_LIFEBAR_CONFIG_UPDATE', 'MY_LifeBarPS')
end
X.RegisterPanel(_L['General'], 'MY_LifeBar', _L['MY_LifeBar'], 2148, PS)
