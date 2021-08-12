--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 自动砸年兽陶罐
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
local MODULE_NAME = 'MY_Taoguan'
local _L = X.LoadLangPack(PLUGIN_ROOT .. '/lang/')
--------------------------------------------------------------------------
if not X.AssertVersion(MODULE_NAME, _L[MODULE_NAME], '^9.0.0') then
	return
end
--------------------------------------------------------------------------
-- 幸运香囊 -- 下一次有一点五倍几率砸中年兽陶罐
-- 幸运锦囊 -- 下一次砸年兽陶罐失败则保留两点五成积分
-- 如意香囊 -- 下一次有两点五倍几率砸中年兽陶罐
-- 如意锦囊 -- 下一次砸年兽陶罐失败则保留一半积分
-- 寄忧谷 -- 下一次有五倍几率砸中年兽陶罐
-- 醉生 -- 下一次砸年兽陶罐失败则不损失积分

local FILTER_ITEM = {
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6072), bFilter = true }, -- 鞭炮
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6069), bFilter = true }, -- 火树银花
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6068), bFilter = true }, -- 龙凤呈祥
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6067), bFilter = true }, -- 彩云逐月
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6076), bFilter = true }, -- 熠熠生辉
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6073), bFilter = true }, -- 焰火棒
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6070), bFilter = true }, -- 窜天猴
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6077), bFilter = true }, -- 彩云逐月
	{ szName = X.GetObjectName('ITEM_INFO', 5, 8025, 1168), bFilter = true }, -- 剪纸：龙腾
	{ szName = X.GetObjectName('ITEM_INFO', 5, 8025, 1170), bFilter = true }, -- 剪纸：凤舞
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6066), bFilter = true }, -- 元宝灯
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6067), bFilter = true }, -- 桃花灯
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6024), bFilter = true }, -- 年年有鱼灯
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6048), bFilter = false }, -- 桃木牌·马
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6049), bFilter = true }, -- 桃木牌·年
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6050), bFilter = true }, -- 桃木牌·吉
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6051), bFilter = true }, -- 桃木牌·祥
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6200), bFilter = true }, -- 图样：彩云逐月
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6203), bFilter = true }, -- 图样：熠熠生辉
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6258), bFilter = false }, -- 监本印文兑换券
	{ szName = X.GetObjectName('ITEM_INFO', 5, 31599), bFilter = false }, -- 战魂佩
	{ szName = X.GetObjectName('ITEM_INFO', 5, 30692), bFilter = false }, -- 豪侠贡
	{ szName = X.GetObjectName('ITEM_INFO', 5, 20959), bFilter = false }, -- 年兽陶罐
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6027), bFilter = false }, -- 幸运香囊
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6030), bFilter = false }, -- 幸运锦囊
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6028), bFilter = false }, -- 如意香囊
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6031), bFilter = false }, -- 如意锦囊
	{ szName = X.GetObjectName('ITEM_INFO', 5, 6043), bFilter = false }, -- 锁住的月光宝盒
}
local FILTER_ITEM_DEFAULT = {}
for _, p in ipairs(FILTER_ITEM) do
	FILTER_ITEM_DEFAULT[p.szName] = p.bFilter
end

local O = X.CreateUserSettingsModule('MY_Taoguan', _L['Target'], {
	nPausePoint = { -- 停砸分数线
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Number,
		xDefaultValue = 327680,
	},
	bUseTaoguan = { -- 必要时使用背包的陶罐
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	bNoYinchuiUseJinchui = { -- 没小银锤时使用小金锤
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	nUseXiaojinchui = { -- 优先使用小金锤的分数
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Number,
		xDefaultValue = 320,
	},
	bPauseNoXiaojinchui = { -- 缺少小金锤时停砸
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	nUseXingyunXiangnang = { -- 开始吃幸运香囊的分数
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Number,
		xDefaultValue = 80,
	},
	bPauseNoXingyunXiangnang = { -- 缺少幸运香囊时停砸
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	nUseXingyunJinnang = { -- 开始吃幸运锦囊的分数
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Number,
		xDefaultValue = 80,
	},
	bPauseNoXingyunJinnang = { -- 缺少幸运锦囊时停砸
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	nUseRuyiXiangnang = { -- 开始吃如意香囊的分数
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Number,
		xDefaultValue = 80,
	},
	bPauseNoRuyiXiangnang = { -- 缺少如意香囊时停砸
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	nUseRuyiJinnang = { -- 开始吃如意锦囊的分数
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Number,
		xDefaultValue = 80,
	},
	bPauseNoRuyiJinnang = { -- 缺少如意锦囊时停砸
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = false,
	},
	nUseJiyougu = { -- 开始吃寄忧谷的分数
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Number,
		xDefaultValue = 1280,
	},
	bPauseNoJiyougu = { -- 缺少寄忧谷时停砸
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	nUseZuisheng = { -- 开始吃醉生的分数
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Number,
		xDefaultValue = 1280,
	},
	bPauseNoZuisheng = { -- 缺少醉生时停砸
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Boolean,
		xDefaultValue = true,
	},
	tFilterItem = {
		ePathType = X.PATH_TYPE.ROLE,
		szLabel = _L['MY_Taoguan'],
		xSchema = X.Schema.Map(X.Schema.String, X.Schema.Boolean),
		xDefaultValue = FILTER_ITEM_DEFAULT,
	},
})

---------------------------------------------------------------------
-- 本地函数和变量
---------------------------------------------------------------------
local TAOGUAN = X.GetItemNameByUIID(74224) -- 年兽陶罐
local XIAOJINCHUI = X.GetItemNameByUIID(65611) -- 小金锤
local XIAOYINCHUI = X.GetItemNameByUIID(65609) -- 小银锤
local MEILIANGYUQIAN = X.GetItemNameByUIID(65589) -- 梅良玉签
local XINGYUNXIANGNANG = X.GetItemNameByUIID(65578) -- 幸运香囊
local XINGYUNJINNANG = X.GetItemNameByUIID(65581) -- 幸运锦囊
local RUYIXIANGNANG = X.GetItemNameByUIID(65579) -- 如意香囊
local RUYIJINNANG = X.GetItemNameByUIID(65582) -- 如意锦囊
local JIYOUGU = X.GetItemNameByUIID(65580) -- 寄忧谷
local ZUISHENG = X.GetItemNameByUIID(65583) -- 醉生
local ITEM_CD = 1 * GLOBAL.GAME_FPS + 8 -- 吃药CD
local HAMMER_CD = 5 * GLOBAL.GAME_FPS + 8 -- 锤子CD
local MAX_POINT_POW = 16 -- 分数最高倍数（2^n）

local D = {
	bEnable = false, -- 启用状态
	nPoint = 0, -- 当前总分数
	nUseItemLFC = 0, -- 上次吃药的逻辑帧
	nUseHammerLFC = 0, -- 上次用锤子的逻辑帧
	dwDoodadID = 0, -- 自动拾取过滤的交互物件ID
	aUseItemPS = { -- 设置界面的物品使用条件
		{ szName = XIAOJINCHUI, szID = 'Xiaojinchui' },
		{ szName = XINGYUNXIANGNANG, szID = 'XingyunXiangnang' },
		{ szName = XINGYUNJINNANG, szID = 'XingyunJinnang' },
		{ szName = RUYIXIANGNANG, szID = 'RuyiXiangnang' },
		{ szName = RUYIJINNANG, szID = 'RuyiJinnang' },
		{ szName = JIYOUGU, szID = 'Jiyougu' },
		{ szName = ZUISHENG, szID = 'Zuisheng' },
	},
	aUseItemOrder = { -- 状态转移函数中物品与BUFF判断逻辑
		{
			{ szName = JIYOUGU, szID = 'Jiyougu', dwBuffID = 1660, nBuffLevel = 3 },
			{ szName = RUYIXIANGNANG, szID = 'RuyiXiangnang', dwBuffID = 1660, nBuffLevel = 2 },
			{ szName = XINGYUNXIANGNANG, szID = 'XingyunXiangnang', dwBuffID = 1660, nBuffLevel = 1 },
		},
		{
			{ szName = ZUISHENG, szID = 'Zuisheng', dwBuffID = 1661, nBuffLevel = 3 },
			{ szName = RUYIJINNANG, szID = 'RuyiJinnang', dwBuffID = 1661, nBuffLevel = 2 },
			{ szName = XINGYUNJINNANG, szID = 'XingyunJinnang', dwBuffID = 1661, nBuffLevel = 1 },
		},
	},
}

-- 使用背包物品
function D.UseBagItem(szName, bWarn)
	local me = GetClientPlayer()
	for i = 1, 6 do
		for j = 0, me.GetBoxSize(i) - 1 do
		local it = GetPlayerItem(me, i, j)
			if it and it.szName == szName then
				--[[#DEBUG BEGIN]]
				X.Debug('MY_Taoguan', 'UseItem: ' .. i .. ',' .. j .. ' ' .. szName, X.DEBUG_LEVEL.LOG)
				--[[#DEBUG END]]
				OnUseItem(i, j)
				return true
			end
		end
	end
	if bWarn then
		X.Systopmsg(_L('Auto taoguan: missing [%s]!', szName))
	end
end

-- 砸罐子状态机转移函数
function D.BreakCanStateTransfer()
	local me = GetClientPlayer()
	if not me or not D.bEnable then
		return
	end
	local nLFC = GetLogicFrameCount()
	-- 确认掉砸金蛋确认框
	X.DoMessageBox('PlayerMessageBoxCommon')
	-- 吃药还在CD则等待
	if nLFC - D.nUseItemLFC < ITEM_CD then
		return
	end
	-- 检查吃药BUFF满足情况
	for _, aItem in ipairs(D.aUseItemOrder) do
		-- 每个分组优先级顺序处理
		for _, item in ipairs(aItem) do
			-- 符合吃药分数条件
			if D.nPoint >= O['nUse' .. item.szID] then
				-- 如果已经有BUFF，即吃过药了，则跳出循环
				if X.GetBuff(me, item.dwBuffID, item.nBuffLevel) then
					break
				end
				-- 否则尝试吃药
				if D.UseBagItem(item.szName, O['bPauseNo' .. item.szID]) then
					D.nUseItemLFC = nLFC
					-- 吃成功了，等待下次状态机转移函数调用
					return
				end
				if O['bPauseNo' .. item.szID] then
					-- 吃失败了，暂停砸罐子
					D.Stop()
					return
				end
			end
		end
	end
	-- 锤子还在CD则等待
	if nLFC - D.nUseHammerLFC < HAMMER_CD then
		return
	end
	-- 寻找能砸的陶罐
	local npcTaoguan
	for _, npc in ipairs(X.GetNearNpc()) do
		if npc and npc.dwTemplateID == 6820 then
			if X.GetDistance(npc) < 4 then
				npcTaoguan = npc
				break
			end
		end
	end
	-- 没有能砸的陶罐考虑自己放一个
	if not npcTaoguan and O.bUseTaoguan then
		if D.UseBagItem(TAOGUAN) then
			D.nUseItemLFC = nLFC
		end
	end
	-- 还是没有找到罐子则等待
	if not npcTaoguan then
		return
	end
	-- 找到罐子了，设为目标
	X.SetTarget(TARGET.NPC, npcTaoguan.dwID)
	-- 需要用小金锤，砸他丫的
	if D.nPoint >= O.nUseXiaojinchui then
		if D.UseBagItem(XIAOJINCHUI, O.bPauseNoXiaojinchui) then
			-- 砸成功了，等锤子CD
			D.nUseHammerLFC = nLFC
			return
		end
		if O.bPauseNoXiaojinchui then
			-- 砸失败了，暂停砸罐子
			D.Stop()
			return
		end
	end
	-- 需要用小银锤，砸他丫的
	if D.UseBagItem(XIAOYINCHUI) then
		-- 砸成功了，等锤子CD
		D.nUseHammerLFC = nLFC
		return
	end
	-- 没有小银锤时使用小金锤？
	if O.bNoYinchuiUseJinchui and D.UseBagItem(XIAOJINCHUI) then
		-- 砸成功了，等锤子CD
		D.nUseHammerLFC = nLFC
		return
	end
	-- 没有金锤也没有银锤，凉了呀
	D.UseBagItem(XIAOYINCHUI, true)
	D.Stop()
end

-------------------------------------
-- 事件处理
-------------------------------------
function D.MonitorZP(szChannel, szMsg)
	local _, _, nP = string.find(szMsg, _L['Current total score:(%d+)'])
	if nP then
		D.nPoint = tonumber(nP)
		if D.nPoint >= O.nPausePoint then
			D.Stop()
			D.bReachLimit = true
			X.Systopmsg(_L['Auto taoguan: reach limit!'])
		end
		D.nUseHammerLFC = GetLogicFrameCount()
	end
end

function D.OnLootItem()
	if arg0 == GetClientPlayer().dwID and arg2 > 2 and GetItem(arg1).szName == MEILIANGYUQIAN then
		D.nPoint = 0
		X.Systopmsg(_L['Auto taoguan: score clear!'])
	end
end

function D.OnDoodadEnter()
	if D.bEnable or D.bReachLimit then
		local d = GetDoodad(arg0)
		if d and d.szName == TAOGUAN and d.CanDialog(GetClientPlayer())
			and X.GetDistance(d) < 4.1
		then
			D.dwDoodadID = arg0
			X.DelayCall(520, function()
				X.InteractDoodad(D.dwDoodadID)
			end)
		end
	end
end

function D.OnOpenDoodad()
	if D.bEnable or D.bReachLimit then
		local d = GetDoodad(D.dwDoodadID)
		if d and d.szName == TAOGUAN then
			local nQ, nM, me = 1, d.GetLootMoney(), GetClientPlayer()
			if nM > 0 then
				LootMoney(d.dwID)
			end
			for i = 0, 31 do
				local it, bRoll, bDist = d.GetLootItem(i, me)
				if not it then
					break
				end
				local szName = GetItemNameByItem(it)
				if it.nQuality >= nQ and not bRoll and not bDist
					and not O.tFilterItem[szName]
				then
					LootItem(d.dwID, it.dwID)
				else
					X.Systopmsg(_L('Auto taoguan: filter item [%s].', szName))
				end
			end
			local hL = Station.Lookup('Normal/LootList', 'Handle_LootList')
			if hL then
				hL:Clear()
			end
		end
		D.bReachLimit = nil
	end
end

-- 砸罐子开始（注册事件）
function D.Start()
	if D.bEnable then
		return
	end
	D.bEnable = true
	X.RegisterMsgMonitor('MSG_SYS', 'MY_Taoguan', D.MonitorZP)
	X.BreatheCall('MY_Taoguan', D.BreakCanStateTransfer)
	X.RegisterEvent('LOOT_ITEM', 'MY_Taoguan', D.OnLootItem)
	X.RegisterEvent('DOODAD_ENTER_SCENE', 'MY_Taoguan', D.OnDoodadEnter)
	X.RegisterEvent('HELP_EVENT', 'MY_Taoguan', function()
		if arg0 == 'OnOpenpanel' and arg1 == 'LOOT'
			and D.bEnable and D.dwDoodadID ~= 0
		then
			D.OnOpenDoodad()
			D.dwDoodadID = 0
		end
	end)
	X.Systopmsg(_L['Auto taoguan: on.'])
end

-- 砸罐子关闭（注销事件）
function D.Stop()
	if not D.bEnable then
		return
	end
	D.bEnable = false
	X.RegisterMsgMonitor('MSG_SYS', 'MY_Taoguan', false)
	X.BreatheCall('MY_Taoguan', false)
	X.RegisterEvent('NPC_ENTER_SCENE', 'MY_Taoguan', false)
	X.RegisterEvent('LOOT_ITEM', 'MY_Taoguan', false)
	X.RegisterEvent('DOODAD_ENTER_SCENE', 'MY_Taoguan', false)
	X.RegisterEvent('HELP_EVENT', 'MY_Taoguan', false)
	X.Systopmsg(_L['Auto taoguan: off.'])
end

-- 砸罐子开关
function D.Switch()
	if D.bEnable then
		D.Stop()
	else
		D.Start()
	end
end

-------------------------------------
-- 设置界面
-------------------------------------
local PS = {}

function PS.OnPanelActive(wnd)
	local ui = UI(wnd)
	local nPaddingX, nPaddingY = 20, 20
	local nX, nY = nPaddingX, nPaddingY

	ui:Append('Text', { text = _L['Feature setting'], x = nX, y = nY, font = 27 })

	-- 分数达到多少停砸
	nX = nPaddingX + 10
	nY = nY + 28
	nX = ui:Append('Text', { text = _L['Stop simple broken can when score reaches'], x = nX, y = nY }):AutoWidth():Pos('BOTTOMRIGHT') + 5
	nX = ui:Append('WndComboBox', {
		x = nX, y = nY, w = 100, h = 25,
		text = O.nPausePoint,
		menu = function()
			local ui = UI(this)
			local m0 = {}
			for i = 2, MAX_POINT_POW do
				local v = 10 * 2 ^ i
				table.insert(m0, { szOption = tostring(v), fnAction = function()
					O.nPausePoint = v
					ui:Text(tostring(v))
				end })
			end
			return m0
		end,
	}):Pos('BOTTOMRIGHT') + 10
	ui:Append('WndCheckBox', {
		x = nX, y = nY, w = 200,
		text = _L['Put can if needed?'],
		checked = O.bUseTaoguan,
		oncheck = function(bChecked) O.bUseTaoguan = bChecked end,
	}):AutoWidth()

	-- 没有小银锤时使用小金锤
	-- nX = X + 10
	nY = nY + 28
	ui:Append('WndCheckBox', {
		x = nX, y = nY, w = 200,
		text = _L('When no %s use %s?', XIAOYINCHUI, XIAOJINCHUI),
		checked = O.bNoYinchuiUseJinchui,
		oncheck = function(bChecked) O.bNoYinchuiUseJinchui = bChecked end,
	}):AutoWidth()

	-- 各种东西使用分数和缺少停砸
	local nMaxItemNameLen = 0
	for _, p in ipairs(D.aUseItemPS) do
		nMaxItemNameLen = math.max(nMaxItemNameLen, wstring.len(p.szName))
	end
	for _, p in ipairs(D.aUseItemPS) do
		nX = nPaddingX + 10
		nY = nY + 28
		nX = ui:Append('Text', {
			x = nX, y = nY,
			text = _L('Use %s when score reaches', p.szName .. string.rep(g_tStrings.STR_ONE_CHINESE_SPACE, nMaxItemNameLen - wstring.len(p.szName))),
		}):AutoWidth():Pos('BOTTOMRIGHT') + 5
		nX = ui:Append('WndComboBox', {
			x = nX, y = nY, w = 100, h = 25,
			text = O['nUse' .. p.szID],
			menu = function()
				local ui = UI(this)
				local m0 = {}
				for i = 2, MAX_POINT_POW - 1 do
					local v = 10 * 2 ^ i
					table.insert(m0, { szOption = tostring(v), fnAction = function()
						O['nUse' .. p.szID] = v
						ui:Text(tostring(v))
					end })
				end
				return m0
			end,
		}):Pos('BOTTOMRIGHT') + 10
		nX = ui:Append('WndCheckBox', {
			x = nX, y = nY,
			text = _L['Stop break when no item'],
			checked = O['bPauseNo' .. p.szID],
			oncheck = function(bChecked)
				O['bPauseNo' .. p.szID] = bChecked
			end,
		}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	end

	-- 拾取过滤
	nX = nPaddingX + 10
	nY = nY + 38
	nX = ui:Append('WndComboBox', {
		x = nX, y = nY, w = 150,
		text = _L['Pickup filters'],
		menu = function()
			local m0 = {}
			for _, p in ipairs(FILTER_ITEM) do
				table.insert(m0, {
					szOption = p.szName,
					bCheck = true, bChecked = O.tFilterItem[p.szName],
					fnAction = function(d, b)
						O.tFilterItem[p.szName] = b
						O.tFilterItem = O.tFilterItem
					end,
				})
			end
			for k, v in pairs(O.tFilterItem) do
				if FILTER_ITEM_DEFAULT[k] == nil then
					table.insert(m0, {
						szOption = k,
						bCheck = true, bChecked = v,
						fnAction = function(d, b)
							O.tFilterItem[k] = b
							O.tFilterItem = O.tFilterItem
						end,
						szIcon = 'ui/Image/UICommon/CommonPanel2.UITex',
						nFrame = 49,
						nMouseOverFrame = 51,
						nIconWidth = 17,
						nIconHeight = 17,
						szLayer = 'ICON_RIGHTMOST',
						fnClickIcon = function()
							O.tFilterItem[k] = nil
							O.tFilterItem = O.tFilterItem
							UI.ClosePopupMenu()
						end,
					})
				end
			end
			if #m0 > 0 then
				table.insert(m0, CONSTANT.MENU_DIVIDER)
			end
			table.insert(m0, {
				szOption = _L['Custom add'],
				fnAction = function()
					local function fnConfirm(szText)
						O.tFilterItem[szText] = true
						O.tFilterItem = O.tFilterItem
					end
					GetUserInput(_L['Please input custom name'], fnConfirm, nil, nil, nil, '', 20)
				end,
			})
			return m0
		end,
	}):AutoWidth():Pos('BOTTOMRIGHT') + 10
	ui:Append('Text', { x = nX, y = nY, text = _L['(Checked will not be picked up, if still pick please check system auto pick config)'] })

	-- 控制按钮
	nX = nPaddingX + 10
	nY = nY + 36
	nX = ui:Append('WndButton', {
		x = nX, y = nY, w = 130, h = 30,
		text = _L['Start/stop break can'],
		onclick = D.Switch,
	}):Pos('BOTTOMRIGHT') + 5
	nX = ui:Append('WndButton', {
		x = nX, y = nY, w = 130, h = 30,
		text = _L['Restore default config'],
		onclick = function()
			O('reset')
			X.SwitchTab('MY_Taoguan', true)
		end,
	}):Pos('BOTTOMRIGHT')
end
X.RegisterPanel(_L['Target'], 'MY_Taoguan', _L[MODULE_NAME], 119, PS)
