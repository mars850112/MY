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
local ipairs, pairs, next, pcall, select = ipairs, pairs, next, pcall, select
local string, math, table = string, math, table
-- lib apis caching
local X = MY
local UI, GLOBAL, CONSTANT, wstring, lodash = X.UI, X.GLOBAL, X.CONSTANT, X.wstring, X.lodash
-------------------------------------------------------------------------------------------------------
local PLUGIN_NAME = 'MY_TeamTools'
local PLUGIN_ROOT = X.PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MY_TeamTools'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
X.RegisterRestriction('MY_WorldMark', { ['*'] = true, intl = false })
--------------------------------------------------------------------------
local PS = { nPriority = 0 }
function PS.OnPanelActive(wnd)
	local ui = UI(wnd)
	local nPaddingX, nPaddingY = 20, 30
	local nX, nY, nLFY = nPaddingX, nPaddingY, nPaddingY
	local nW, nH = ui:Size()
	local nLH = 25

	ui:Append('WndButton', {
		x = nW - 165, y = nY, w = 150, h = 38,
		text = _L['Open Panel'],
		buttonstyle = 'SKEUOMORPHISM_LACE_BORDER',
		onclick = MY_TeamTools.Open,
	})

	nY = nY + ui:Append('Text', { x = nX, y = nY, text = _L['MY_TeamTools'], font = 27 }):Height() + 5
	nX = nPaddingX + 10
	nX = nX + ui:Append('WndCheckBox', {
		x = nX, y = nY,
		checked = MY_TeamNotice.bEnable,
		text = _L['Team Message'],
		oncheck = function(bChecked)
			MY_TeamNotice.bEnable = bChecked
		end,
	}):AutoWidth():Width() + 5

	nX = nX + ui:Append('WndCheckBox', {
		x = nX, y = nY,
		checked = MY_CharInfo.bEnable,
		text = _L['Allow view charinfo'],
		oncheck = function(bChecked)
			MY_CharInfo.bEnable = bChecked
		end,
	}):AutoWidth():Width() + 5

	if not X.IsRestricted('MY_WorldMark') then
		nX = nX + ui:Append('WndCheckBox', {
			x = nX, y = nY,
			checked = MY_WorldMark.bEnable,
			text = _L['World mark enhance'],
			oncheck = function(bChecked)
				MY_WorldMark.bEnable = bChecked
				MY_WorldMark.CheckEnable()
			end,
		}):AutoWidth():Width() + 5
	end

	nLFY = nY + nLH
	nX, nY, nLFY = MY_CombatLogs.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nLH, nX, nY, nLFY)

	nX = nPaddingX
	nY = nY + 30
	nY = nY + ui:Append('Text', { x = nX, y = nY, text = _L['Party Request'], font = 27 }):Height() + 5
	nX = nPaddingX + 10
	nX, nY = MY_PartyRequest.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nX, nY)
	nX, nY = MY_RideRequest.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nX, nY)
	nX, nY = MY_EvokeRequest.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nX, nY)
	nX, nY = MY_SocialRequest.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nX, nY)
	nX, nY = MY_TeamRestore.OnPanelActivePartial(ui, nPaddingX, nPaddingY, nW, nH, nX, nY)
end
X.RegisterPanel(_L['Raid'], 'MY_TeamTools', _L['MY_TeamTools'], 5962, PS)
