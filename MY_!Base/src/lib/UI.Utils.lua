--------------------------------------------------------
-- This file is part of the JX3 Plugin Project.
-- @desc     : 界面工具库
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

function UI.GetTreePath(raw)
	local tTreePath = {}
	if X.IsTable(raw) and raw.GetTreePath then
		table.insert(tTreePath, (raw:GetTreePath()):sub(1, -2))
		while(raw and raw:GetType():sub(1, 3) ~= 'Wnd') do
			local szName = raw:GetName()
			if not szName or szName == '' then
				table.insert(tTreePath, 2, raw:GetIndex())
			else
				table.insert(tTreePath, 2, szName)
			end
			raw = raw:GetParent()
		end
	else
		table.insert(tTreePath, tostring(raw))
	end
	return table.concat(tTreePath, '/')
end

do
local ui, cache
function UI.GetTempElement(szType)
	if not X.IsString(szType) then
		return
	end
	local szKey = nil
	local nPos = StringFindW(szType, '.')
	if nPos then
		szKey = string.sub(szType, nPos + 1)
		szType = string.sub(szType, 1, nPos - 1)
	end
	if not X.IsString(szKey) then
		szKey = 'Default'
	end
	if not cache or not ui or ui:Count() == 0 then
		cache = {}
		ui = UI.CreateFrame(X.NSFormatString('{$NS}#TempElement'), { empty = true }):Hide()
	end
	local szName = szType .. '_' .. szKey
	local raw = cache[szName]
	if not raw then
		raw = ui:Append(szType, {
			name = szName,
		})[1]
		cache[szName] = raw
	end
	return raw
end
end

function UI.ScrollIntoView(el, scrollY, nOffsetY, scrollX, nOffsetX)
	local elParent, nParentW, nParentH = el:GetParent()
	local nX, nY = el:GetAbsX() - elParent:GetAbsX(), el:GetAbsY() - elParent:GetAbsY()
	if elParent:GetType() == 'WndContainer' then
		nParentW, nParentH = elParent:GetAllContentSize()
	else
		nParentW, nParentH = elParent:GetAllItemSize()
	end
	if nOffsetY then
		nY = nY + nOffsetY
	end
	if scrollY then
		scrollY:SetScrollPos(nY / nParentH * scrollY:GetStepCount())
	end
	if nOffsetX then
		nX = nX + nOffsetX
	end
	if scrollX then
		scrollX:SetScrollPos(nX / nParentW * scrollX:GetStepCount())
	end
end

function UI.LookupFrame(szName)
	for _, v in ipairs(UI.LAYER_LIST) do
		local frame = Station.Lookup(v .. '/' .. szName)
		if frame then
			return frame
		end
	end
end

do
local ITEM_COUNT = {}
local HOOK_BEFORE = setmetatable({}, { __mode = 'v' })
local HOOK_AFTER = setmetatable({}, { __mode = 'v' })

function UI.HookHandleAppend(hList, fnOnAppendItem)
	-- 注销旧的 HOOK 函数
	if HOOK_BEFORE[hList] then
		UnhookTableFunc(hList, 'AppendItemFromIni'   , HOOK_BEFORE[hList])
		UnhookTableFunc(hList, 'AppendItemFromData'  , HOOK_BEFORE[hList])
		UnhookTableFunc(hList, 'AppendItemFromString', HOOK_BEFORE[hList])
	end
	if HOOK_AFTER[hList] then
		UnhookTableFunc(hList, 'AppendItemFromIni'   , HOOK_AFTER[hList])
		UnhookTableFunc(hList, 'AppendItemFromData'  , HOOK_AFTER[hList])
		UnhookTableFunc(hList, 'AppendItemFromString', HOOK_AFTER[hList])
	end

	-- 生成新的 HOOK 函数
	local function BeforeAppendItem(hList)
		ITEM_COUNT[hList] = hList:GetItemCount()
	end
	HOOK_BEFORE[hList] = BeforeAppendItem

	local function AfterAppendItem(hList)
		local nCount = ITEM_COUNT[hList]
		if not nCount then
			return
		end
		ITEM_COUNT[hList] = nil
		for i = nCount, hList:GetItemCount() - 1 do
			local hItem = hList:Lookup(i)
			fnOnAppendItem(hList, hItem)
		end
	end
	HOOK_AFTER[hList] = AfterAppendItem

	-- 应用 HOOK 函数
	ITEM_COUNT[hList] = 0
	AfterAppendItem(hList)
	HookTableFunc(hList, 'AppendItemFromIni'   , BeforeAppendItem, { bAfterOrigin = false })
	HookTableFunc(hList, 'AppendItemFromIni'   , AfterAppendItem , { bAfterOrigin = true  })
	HookTableFunc(hList, 'AppendItemFromData'  , BeforeAppendItem, { bAfterOrigin = false })
	HookTableFunc(hList, 'AppendItemFromData'  , AfterAppendItem , { bAfterOrigin = true  })
	HookTableFunc(hList, 'AppendItemFromString', BeforeAppendItem, { bAfterOrigin = false })
	HookTableFunc(hList, 'AppendItemFromString', AfterAppendItem , { bAfterOrigin = true  })
end
end

do
local ITEM_COUNT = {}
local HOOK_BEFORE = setmetatable({}, { __mode = 'v' })
local HOOK_AFTER = setmetatable({}, { __mode = 'v' })

function UI.HookContainerAppend(hList, fnOnAppendContent)
	-- 注销旧的 HOOK 函数
	if HOOK_BEFORE[hList] then
		UnhookTableFunc(hList, 'AppendContentFromIni'   , HOOK_BEFORE[hList])
	end
	if HOOK_AFTER[hList] then
		UnhookTableFunc(hList, 'AppendContentFromIni'   , HOOK_AFTER[hList])
	end

	-- 生成新的 HOOK 函数
	local function BeforeAppendContent(hList)
		ITEM_COUNT[hList] = hList:GetAllContentCount()
	end
	HOOK_BEFORE[hList] = BeforeAppendContent

	local function AfterAppendContent(hList)
		local nCount = ITEM_COUNT[hList]
		if not nCount then
			return
		end
		ITEM_COUNT[hList] = nil
		for i = nCount, hList:GetAllContentCount() - 1 do
			local hContent = hList:LookupContent(i)
			fnOnAppendContent(hList, hContent)
		end
	end
	HOOK_AFTER[hList] = AfterAppendContent

	-- 应用 HOOK 函数
	ITEM_COUNT[hList] = 0
	AfterAppendContent(hList)
	HookTableFunc(hList, 'AppendContentFromIni'   , BeforeAppendContent, { bAfterOrigin = false })
	HookTableFunc(hList, 'AppendContentFromIni'   , AfterAppendContent , { bAfterOrigin = true  })
end
end

-- FORMAT_WMSG_RET
function UI.FormatWMsgRet(stop, callFrame)
	local ret = 0
	if stop then
		ret = ret + 1 --01
	end
	if callFrame then
		ret = ret + 2 --10
	end
	return ret
end

UI.UpdateItemInfoBoxObject = _G.UpdateItemInfoBoxObject or UpdataItemInfoBoxObject
