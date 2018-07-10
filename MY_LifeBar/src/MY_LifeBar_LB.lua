---------------------------------------------------
-- @Author: Emil Zhai (root@derzh.com)
-- @Date:   2018-03-19 12:50:01
-- @Last Modified by:   Emil Zhai (root@derzh.com)
-- @Last Modified time: 2018-07-10 17:14:59
---------------------------------------------------
-----------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
-----------------------------------------------------------------------------------------
local setmetatable = setmetatable
local ipairs, pairs, next, pcall = ipairs, pairs, next, pcall
local sub, len, format, rep = string.sub, string.len, string.format, string.rep
local find, byte, char, gsub = string.find, string.byte, string.char, string.gsub
local type, tonumber, tostring = type, tonumber, tostring
local floor, min, max, ceil = math.floor, math.min, math.max, math.ceil
local huge, pi, sin, cos, tan = math.huge, math.pi, math.sin, math.cos, math.tan
local insert, remove, concat, sort = table.insert, table.remove, table.concat, table.sort
local pack, unpack = table.pack or function(...) return {...} end, table.unpack or unpack
-- jx3 apis caching
local wsub, wlen, wfind = wstring.sub, wstring.len, wstring.find
local GetTime, GetLogicFrameCount = GetTime, GetLogicFrameCount
local GetClientPlayer, GetPlayer, GetNpc = GetClientPlayer, GetPlayer, GetNpc
local GetClientTeam, UI_GetClientPlayerID = GetClientTeam, UI_GetClientPlayerID
local IsNil, IsNumber, IsFunction = MY.IsNil, MY.IsNumber, MY.IsFunction
local IsBoolean, IsString, IsTable = MY.IsBoolean, MY.IsString, MY.IsTable
-----------------------------------------------------------------------------------------
local LB = class()
local HP = MY_LifeBar_HP
local CACHE = setmetatable({}, { __mode = 'v' })
local _L = MY.LoadLangPack(MY.GetAddonInfo().szRoot .. 'MY_LifeBar/lang/')

local function InitConfigData(self)
	-- 配色
	self.r = 0
	self.g = 0
	self.b = 0
	self.a = 0
	self.cfx = nil
	self.font = 10
	self.priority = 0
	self.priority_invalid = false
	-- 倒计时/名字/帮会/称号部分
	self.cd_visible = true
	self.cd_text = ''
	self.name_visible = true
	self.name_text = ''
	self.kungfu_visible = true
	self.kungfu_text = ''
	self.distance_visible = true
	self.distance = ''
	self.distance_fmt = ''
	self.tong_visible = true
	self.tong_text = ''
	self.title_visible = true
	self.title_text = ''
	self.texts_y = 100
	self.texts_height = 20
	self.texts_scale = 1
	self.texts_spacing = 1
	self.texts_invalid = true
	self.texts_lines = 0
	-- 血量部分
	self.life = 1
	self.max_life = 1
	-- 血量数值部分
	self.life_text_visible = true
	self.life_text_x = 0
	self.life_text_y = 42
	self.life_text_fmt = ''
	self.life_text_invalid = true
	-- 血条部分
	self.life_bar_visible = true
	self.life_bar_x = 0
	self.life_bar_y = 0
	self.life_bar_w = 0
	self.life_bar_h = 0
	self.life_bar_padding = 0
	self.life_bar_direction = 'LEFT_RIGHT'
	self.life_bar_invalid = true
	self.life_bar_border = 0
	self.life_bar_border_r = 0
	self.life_bar_border_g = 0
	self.life_bar_border_b = 0
	self.life_bar_border_invalid = true
	-- 标记
	self.mark = nil
	self.mark_invalid = true
end

-- 构造函数
function LB:ctor(dwType, dwID)
	self.type = dwType
	self.id = dwID
	self.hp = HP(dwType, dwID)
	InitConfigData(self)
	return self
end

-- 创建UI
function LB:Create()
	if not self.hp.handle then
		self.hp:Create()
		self:SetInvalid('texts', true)
		self:SetInvalid('priority', true)
		self:SetInvalid('life_text', true)
		self:SetInvalid('life_bar', true)
		self:SetInvalid('life_bar_border', true)
	end
	return self
end

-- 删除UI
function LB:Remove()
	self.hp:Remove()
	return self
end

function LB:SetInvalid(key, force)
	if force or self[key .. '_visible'] ~= false then
		self[key .. '_invalid'] = true
	end
	return self
end

-- 重绘无效区域
function LB:Paint(force)
	if self.hp.handle then
		self:DrawLifeBorder(force)
		self:DrawLife(force)
		self:DrawTexts(force)
		self:ApplyMark()
		self:ApplyPriority()
	end
	return self
end

function LB:SetColor(r, g, b, a)
	if self.r ~= r or self.g ~= g
	or self.b ~= b or self.a ~= a then
		self.r = r
		self.g = g
		self.b = b
		self.a = a
		self:SetInvalid('life_bar')
		self:SetInvalid('life_text')
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetMark(mark)
	if self.mark ~= mark then
		self.mark = mark
		self:SetInvalid('mark', true)
	end
	return self
end

function LB:ApplyMark()
	if self.mark_invalid then
		self.hp:SetMark(self.mark, self.texts_y + self.texts_height * self.texts_lines)
		self.mark_invalid = false
	end
	return self
end

function LB:SetPriority(priority)
	if self.priority ~= priority then
		self.priority = priority
		self:SetInvalid('priority', true)
	end
	return self
end

function LB:ApplyPriority()
	if self.priority_invalid then
		self.hp:SetPriority(self.priority)
		self.priority_invalid = false
	end
	return self
end

function LB:SetColorFx(cfx)
	if self.cfx ~= cfx then
		self.cfx = cfx
		self:SetInvalid('life_bar')
		self:SetInvalid('life_text')
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetFont(font)
	if self.font ~= font then
		self.font = font
		self:SetInvalid('life_text')
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetTextsPos(y, height)
	if self.texts_y ~= y or self.texts_height ~= height then
		self.texts_y = y
		self.texts_height = height
		self:SetInvalid('mark', true)
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetTextsScale(scale)
	if self.texts_scale ~= scale then
		self.texts_scale = scale
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetTextsSpacing(spacing)
	if self.texts_spacing ~= spacing then
		self.texts_spacing = spacing
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetNameVisible(visible)
	if self.name_visible ~= visible then
		self.name_visible = visible
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetCD(text)
	if self.cd_text ~= text then
		self.cd_text = text
		self:SetInvalid('texts', true)
		self:SetInvalid('life_bar', true)
		self:SetInvalid('life_bar_border', true)
	end
	return self
end

function LB:SetName(text)
	if self.name_text ~= text then
		self.name_text = text
		self:SetInvalid('texts', true)
		self:SetInvalid('life_bar', true)
		self:SetInvalid('life_bar_border', true)
	end
	return self
end

function LB:SetDistanceVisible(visible)
	if self.distance_visible ~= visible then
		self.distance_visible = visible
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetDistance(distance)
	if self.distance ~= distance then
		self.distance = distance
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetDistanceFmt(fmt)
	if self.distance_fmt ~= fmt then
		self.distance_fmt = fmt
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetKungfuVisible(visible)
	if self.kungfu_visible ~= visible then
		self.kungfu_visible = visible
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetKungfu(text)
	if self.kungfu_text ~= text then
		self.kungfu_text = text
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetTitleVisible(visible)
	if self.title_visible ~= visible then
		self.title_visible = visible
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetTitle(text)
	if self.title_text ~= text then
		self.title_text = text
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetTongVisible(visible)
	if self.tong_visible ~= visible then
		self.tong_visible = visible
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:SetTong(text)
	if self.tong_text ~= text then
		self.tong_text = text
		self:SetInvalid('texts', true)
	end
	return self
end

function LB:DrawTexts(force)
	if self.texts_invalid or force then
		local aTexts = {}
		local r, g, b, a, f = self.r, self.g, self.b, self.a, self.font
		if self.cfx then
			r, g, b, a = self.cfx(r, g, b, a)
		end
		if self.tong_visible and self.tong_text ~= '' then
			insert(aTexts, '[' .. self.tong_text .. ']')
		end
		if self.title_visible and self.title_text ~= '' then
			insert(aTexts, '<' .. self.title_text .. '>')
		end
		local text = ''
		if self.name_visible then
			if self.name_text and self.name_text ~= '' then
				text = text .. self.name_text
			end
			if self.kungfu_visible and self.kungfu_text and self.kungfu_text ~= '' then
				if text ~= '' then
					text = text .. _L.STR_SPLIT_DOT
				end
				text = text .. self.kungfu_text
			end
			if self.distance_visible and self.distance and self.distance ~= 0 then
				if text ~= '' then
					text = text .. _L.STR_SPLIT_DOT
				end
				text = text .. self.distance_fmt:format(self.distance)
			end
			insert(aTexts, text)
		end
		if self.cd_visible and self.cd_text ~= '' then
			insert(aTexts, self.cd_text)
		end
		self.hp:DrawTexts(aTexts, self.texts_y, self.texts_height, r, g, b, a, f, self.texts_spacing, self.texts_scale)
		-- 刷新与文本行数有关的东西
		local texts_lines = #aTexts
		if self.texts_lines ~= texts_lines then
			self.texts_lines = texts_lines
			self:SetInvalid('mark', true)
		end
		self.texts_invalid = false
	end
	return self
end

-- 设置血量
function LB:SetLife(life, max_life)
	if self.life ~= life or self.max_life ~= max_life then
		self.life = life
		self.max_life = max_life
		self:SetInvalid('life_bar')
		self:SetInvalid('life_text')
	end
	return self
end

function LB:SetLifeBarVisible(life_bar_visible)
	if self.life_bar_visible ~= life_bar_visible then
		self.life_bar_visible = life_bar_visible
		self:SetInvalid('life_bar', true)
		self:SetInvalid('life_bar_border', true)
	end
	return self
end

function LB:SetLifeBar(x, y, w, h, padding)
	if self.life_bar_x ~= x or self.life_bar_y ~= y or self.life_bar_w ~= w or self.life_bar_h ~= h or self.life_bar_padding ~= padding then
		self.life_bar_x = x
		self.life_bar_y = y
		self.life_bar_w = w
		self.life_bar_h = h
		self.life_bar_padding = padding
		self:SetInvalid('life_bar', true)
	end
	return self
end

function LB:SetLifeBarBorder(n, r, g, b)
	if self.life_bar_border ~= n or self.life_bar_border_r ~= r or self.life_bar_border_g ~= g or self.life_bar_border_b ~= b then
		self.life_bar_border = n
		self.life_bar_border_r = r
		self.life_bar_border_g = g
		self.life_bar_border_b = b
		self:SetInvalid('life_bar_border', true)
	end
	return self
end

function LB:SetLifeTextVisible(life_text_visible)
	if self.life_text_visible ~= life_text_visible then
		self.life_text_visible = life_text_visible
		self:SetInvalid('life_text', true)
	end
	return self
end

function LB:SetLifeText(x, y, fmt)
	if self.life_text_x ~= x or self.life_text_y ~= y or self.life_text_fmt ~= fmt then
		self.life_text_x = x
		self.life_text_y = y
		self.life_text_fmt = fmt
		self:SetInvalid('life_text', true)
	end
	return self
end

-- 血条边框
function LB:DrawLifeBorder(force)
	if self.life_bar_border_invalid or force then
		if self.life_bar_visible then
			self.hp:DrawLifeBorder(self.life_bar_w, self.life_bar_h, self.life_bar_x, self.life_bar_y, self.life_bar_border, self.life_bar_border_r, self.life_bar_border_g, self.life_bar_border_b, self.a)
		else
			self.hp:ClearLifeBorder()
		end
		self.life_bar_border_invalid = false
	end
	return self
end

function LB:DrawLife(force)
	if self.life_bar_invalid or self.life_bar_border_invalid or self.life_text_invalid or force then
		local r, g, b, a, f = self.r, self.g, self.b, self.a, self.font
		if self.cfx then
			r, g, b, a = self.cfx(r, g, b, a)
		end
		if self.life_bar_invalid or force then
			if self.life_bar_visible then
				self.hp:DrawLifeBar(self.life_bar_w, self.life_bar_h, self.life_bar_x, self.life_bar_y, self.life_bar_padding, r, g, b, a, self.life / self.max_life, self.life_bar_direction)
			else
				self.hp:ClearLifeBar()
			end
			self.life_bar_invalid = false
		end
		if self.life_text_invalid or force then
			if self.life_text_visible then
				self.hp:DrawLifeText(self.life_text_fmt:format(100 * self.life / self.max_life), self.life_text_x, self.life_text_y, r, g, b, a, f, self.texts_spacing, self.texts_scale)
			else
				self.hp:ClearLifeText()
			end
			self.life_text_invalid = false
		end
	end
	return self
end

function MY_LifeBar_LB(dwType, dwID)
	if dwType == 'clear' then
		CACHE = {}
		HP('clear')
	else
		local szName = dwType .. '_' .. dwID
		if not CACHE[szName] then
			CACHE[szName] = LB.new(dwType, dwID)
		end
		return CACHE[szName]
	end
end
