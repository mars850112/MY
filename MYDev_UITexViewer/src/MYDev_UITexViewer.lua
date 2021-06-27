--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 开发者工具
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
local HUGE, PI, random, randomseed = math.huge, math.pi, math.random, math.randomseed
local min, max, floor, ceil, abs = math.min, math.max, math.floor, math.ceil, math.abs
local mod, modf, pow, sqrt = math['mod'] or math['fmod'], math.modf, math.pow, math.sqrt
local sin, cos, tan, atan, atan2 = math.sin, math.cos, math.tan, math.atan, math.atan2
local insert, remove, concat = table.insert, table.remove, table.concat
local pack, unpack = table['pack'] or function(...) return {...} end, table['unpack'] or unpack
local sort, getn = table.sort, table['getn'] or function(t) return #t end
-- jx3 apis caching
local wlen, wfind, wgsub, wlower = wstring.len, StringFindW, StringReplaceW, StringLowerW
local GetTime, GetLogicFrameCount, GetCurrentTime = GetTime, GetLogicFrameCount, GetCurrentTime
local GetClientTeam, UI_GetClientPlayerID = GetClientTeam, UI_GetClientPlayerID
local GetClientPlayer, GetPlayer, GetNpc, IsPlayer = GetClientPlayer, GetPlayer, GetNpc, IsPlayer
-- lib apis caching
local LIB = MY
local UI, GLOBAL, CONSTANT = LIB.UI, LIB.GLOBAL, LIB.CONSTANT
local PACKET_INFO, DEBUG_LEVEL, PATH_TYPE = LIB.PACKET_INFO, LIB.DEBUG_LEVEL, LIB.PATH_TYPE
local wsub, count_c, lodash = LIB.wsub, LIB.count_c, LIB.lodash
local pairs_c, ipairs_c, ipairs_r = LIB.pairs_c, LIB.ipairs_c, LIB.ipairs_r
local spairs, spairs_r, sipairs, sipairs_r = LIB.spairs, LIB.spairs_r, LIB.sipairs, LIB.sipairs_r
local IsNil, IsEmpty, IsEquals, IsString = LIB.IsNil, LIB.IsEmpty, LIB.IsEquals, LIB.IsString
local IsBoolean, IsNumber, IsHugeNumber = LIB.IsBoolean, LIB.IsNumber, LIB.IsHugeNumber
local IsTable, IsArray, IsDictionary = LIB.IsTable, LIB.IsArray, LIB.IsDictionary
local IsFunction, IsUserdata, IsElement = LIB.IsFunction, LIB.IsUserdata, LIB.IsElement
local EncodeLUAData, DecodeLUAData, Schema = LIB.EncodeLUAData, LIB.DecodeLUAData, LIB.Schema
local GetTraceback, RandomChild, GetGameAPI = LIB.GetTraceback, LIB.RandomChild, LIB.GetGameAPI
local Get, Set, Clone, GetPatch, ApplyPatch = LIB.Get, LIB.Set, LIB.Clone, LIB.GetPatch, LIB.ApplyPatch
local IIf, CallWithThis, SafeCallWithThis = LIB.IIf, LIB.CallWithThis, LIB.SafeCallWithThis
local Call, XpCall, SafeCall, NSFormatString = LIB.Call, LIB.XpCall, LIB.SafeCall, LIB.NSFormatString
-------------------------------------------------------------------------------------------------------
local PLUGIN_NAME = 'MYDev_UITexViewer'
local PLUGIN_ROOT = PACKET_INFO.ROOT .. PLUGIN_NAME
local MODULE_NAME = 'MYDev_UITexViewer'
local _L = LIB.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not LIB.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^4.0.0') then
	return
end
--------------------------------------------------------------------------
local O = LIB.CreateUserSettingsModule('MYDev_UITexViewer', {
	szUITexPath = {
		ePathType = PATH_TYPE.ROLE,
		xSchema = Schema.String,
		xDefaultValue = '',
	},
})
local _Cache = {}
MYDev_UITexViewer = {}

_Cache.OnPanelActive = function(wnd)
    local ui = UI(wnd)
    local w, h = ui:Size()
    local x, y = 20, 20

    _Cache.tUITexList = LIB.LoadLUAData(PACKET_INFO.ROOT .. 'MYDev_UITexViewer/data/data.jx3dat') or {}

    local uiBoard = ui:Append('WndScrollHandleBox', 'WndScrollHandleBox_ImageList')
      :HandleStyle(3):Pos(x, y+25):Size(w-21, h - 70)

    local uiEdit = ui:Append('WndEditBox', 'WndEdit_Copy')
      :Pos(x, h-30):Size(w-20, 25):Multiline(true)

    ui:Append('WndAutocomplete', 'WndAutocomplete_UITexPath')
      :Pos(x, y):Size(w-20, 25):Text(O.szUITexPath)
      :Change(function(szText)
        local tInfo = KG_Table.Load(szText .. '.txt', {
        -- 图片文件帧信息表的表头名字
            {f = 'i', t = 'nFrame' },             -- 图片帧 ID
            {f = 'i', t = 'nLeft'  },             -- 帧位置: 距离左侧像素(X位置)
            {f = 'i', t = 'nTop'   },             -- 帧位置: 距离顶端像素(Y位置)
            {f = 'i', t = 'nWidth' },             -- 帧宽度
            {f = 'i', t = 'nHeight'},             -- 帧高度
            {f = 's', t = 'szFile' },             -- 帧来源文件(无作用)
        }, FILE_OPEN_MODE.NORMAL)
        if not tInfo then
            return
        end

        O.szUITexPath = szText
        uiBoard:Clear()
        for i = 0, 256 do
            local tLine = tInfo:Search(i)
            if not tLine then
                break
            end

            if tLine.nWidth ~= 0 and tLine.nHeight ~= 0 then
                uiBoard:Append('<image>eventid=277 name="Image_'..i..'"</image>')
                  :Image(szText .. '.UITex', tLine.nFrame)
                  :Size(tLine.nWidth, tLine.nHeight)
                  :Alpha(220)
                  :Hover(function(bIn) UI(this):Alpha((bIn and 255) or 220) end)
                  :Tip(szText .. '.UITex#' .. i .. '\n' .. tLine.nWidth .. 'x' .. tLine.nHeight .. '\n' .. _L['(left click to generate xml)'], UI.TIP_POSITION.TOP_BOTTOM)
                  :Click(function() uiEdit:Text('<image>w='..tLine.nWidth..' h='..tLine.nHeight..' path="' .. szText .. '.UITex" frame=' .. i ..'</image>') end)
            end
        end
      end)
      :Click(function(nButton)
        if IsPopupMenuOpened() then
            UI(this):Autocomplete('close')
        else
            UI(this):Autocomplete('search', '')
        end
      end)
      :Autocomplete('option', 'maxOption', 20)
      :Autocomplete('option', 'source', _Cache.tUITexList)
      :Change()
end

_Cache.OnPanelDeactive = function(wnd)
    _Cache.tUITexList = nil
    collectgarbage('collect')
end

LIB.RegisterPanel(_L['Development'], 'Dev_UITexViewer', _L['UITexViewer'], 'ui/Image/UICommon/BattleFiled.UITex|7', {
    OnPanelActive = _Cache.OnPanelActive, OnPanelDeactive = _Cache.OnPanelDeactive
})
