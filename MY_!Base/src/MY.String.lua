--------------------------------------------------------
-- This file is part of the JX3 Mingyi Plugin.
-- @link     : https://jx3.derzh.com/
-- @desc     : 字符串处理
-- @author   : 茗伊 @双梦镇 @追风蹑影
-- @modifier : Emil Zhai (root@derzh.com)
-- @copyright: Copyright (c) 2013 EMZ Kingsoft Co., Ltd.
--------------------------------------------------------
-------------------------------------------------------------------------------------------------------------
-- these global functions are accessed all the time by the event handler
-- so caching them is worth the effort
-------------------------------------------------------------------------------------------------------------
local setmetatable = setmetatable
local ipairs, pairs, next, pcall = ipairs, pairs, next, pcall
local sub, len, format, rep = string.sub, string.len, string.format, string.rep
local find, byte, char, gsub = string.find, string.byte, string.char, string.gsub
local type, tonumber, tostring = type, tonumber, tostring
local huge, pi, random, abs = math.huge, math.pi, math.random, math.abs
local min, max, floor, ceil = math.min, math.max, math.floor, math.ceil
local pow, sqrt, sin, cos, tan, atan = math.pow, math.sqrt, math.sin, math.cos, math.tan, math.atan
local insert, remove, concat, sort = table.insert, table.remove, table.concat, table.sort
local pack, unpack = table.pack or function(...) return {...} end, table.unpack or unpack
-- jx3 apis caching
local wsub, wlen, wfind = wstring.sub, wstring.len, wstring.find
local GetTime, GetLogicFrameCount = GetTime, GetLogicFrameCount
local GetClientTeam, UI_GetClientPlayerID = GetClientTeam, UI_GetClientPlayerID
local GetClientPlayer, GetPlayer, GetNpc, IsPlayer = GetClientPlayer, GetPlayer, GetNpc, IsPlayer
local LIB = MY
local UI, DEBUG_LEVEL, PATH_TYPE = LIB.UI, LIB.DEBUG_LEVEL, LIB.PATH_TYPE
local var2str, str2var, clone, empty, ipairs_r = LIB.var2str, LIB.str2var, LIB.clone, LIB.empty, LIB.ipairs_r
local spairs, spairs_r, sipairs, sipairs_r = LIB.spairs, LIB.spairs_r, LIB.sipairs, LIB.sipairs_r
local GetPatch, ApplyPatch, FullClone = LIB.GetPatch, LIB.ApplyPatch, LIB.FullClone
local Get, Set, RandomChild, GetTraceback = LIB.Get, LIB.Set, LIB.RandomChild, LIB.GetTraceback
local IsArray, IsDictionary, IsEquals = LIB.IsArray, LIB.IsDictionary, LIB.IsEquals
local IsNil, IsBoolean, IsNumber, IsFunction = LIB.IsNil, LIB.IsBoolean, LIB.IsNumber, LIB.IsFunction
local IsEmpty, IsString, IsTable, IsUserdata = LIB.IsEmpty, LIB.IsString, LIB.IsTable, LIB.IsUserdata
local MENU_DIVIDER, EMPTY_TABLE, XML_LINE_BREAKER = LIB.MENU_DIVIDER, LIB.EMPTY_TABLE, LIB.XML_LINE_BREAKER
-------------------------------------------------------------------------------------------------------------
local AnsiToUTF8 = AnsiToUTF8 or ansi_to_utf8
local UrlEncodeString, UrlDecodeString = UrlEncode, UrlDecode
--------------------------------------------
-- 本地函数和变量
--------------------------------------------

-- 分隔字符串
-- (table) LIB.SplitString(string szText, table aSpliter, bool bIgnoreEmptyPart)
-- (table) LIB.SplitString(string szText, string szSpliter, bool bIgnoreEmptyPart)
-- szText           原始字符串
-- szSpliter        分隔符
-- aSpliter         多个分隔符
-- bIgnoreEmptyPart 是否忽略空字符串，即'123;234;'被';'分成{'123','234'}还是{'123','234',''}
-- nMaxPart         最多分成几份，即'1;2;3;4'被';'分隔时，如果最多三份则得到{'1','2','3;4'}
function LIB.SplitString(szText, aSpliter, bIgnoreEmptyPart, nMaxPart)
	if IsString(aSpliter) then
		aSpliter = {aSpliter}
	end
	local nOff, aResult, szPart = 1, {}
	while true do
		local nEnd, szEnd
		if not nMaxPart or nMaxPart > #aResult + 1 then
			for _, szSpliter in ipairs(aSpliter) do
				local nPos = StringFindW(szText, szSpliter, nOff)
				if nPos and (not nEnd or nPos < nEnd) then
					nEnd, szEnd = nPos, szSpliter
				end
			end
		end
		if not nEnd then
			szPart = sub(szText, nOff, len(szText))
			if not bIgnoreEmptyPart or szPart ~= '' then
				insert(aResult, szPart)
			end
			break
		else
			szPart = sub(szText, nOff, nEnd - 1)
			if not bIgnoreEmptyPart or szPart ~= '' then
				insert(aResult, szPart)
			end
			nOff = nEnd + len(szEnd)
		end
	end
	return aResult
end

function LIB.EscapeString(s)
	return (gsub(s, '([%(%)%.%%%+%-%*%?%[%^%$%]])', '%%%1'))
end

function LIB.TrimString(szText)
	if not szText or szText == '' then
		return ''
	end
	return (gsub(szText, '^%s*(.-)%s*$', '%1'))
end

function LIB.StringLenW(str)
	return wlen(str)
end

function LIB.StringSubW(str,s,e)
	if s < 0 then
		s = wlen(str) + s
	end
	if e < 0 then
		e = wlen(str) + e
	end
	return wsub(str, s, e)
end

function LIB.EncryptString(szText)
	return szText:gsub('.', function (c) return format ('%02X', (byte(c) + 13) % 256) end):gsub(' ', '+')
end

function LIB.SimpleEncryptString(szText)
	local a = {szText:byte(1, #szText)}
	for i, v in ipairs(a) do
		a[i] = char((v + 13) % 256)
	end
	return (LIB.Base64Encode(concat(a)):gsub('/', '-'):gsub('+', '_'):gsub('=', '.'))
end

function LIB.SimpleDecryptString(szCipher)
	local szBin = LIB.Base64Decode((szCipher:gsub('-', '/'):gsub('_', '+'):gsub('%.', '=')))
	if not szBin then
		return
	end
	local a = {szBin:byte(1, #szBin)}
	for i, v in ipairs(a) do
		a[i] = char((v - 13 + 256) % 256)
	end
	return concat(a)
end

local function EncodePostData(data, t, prefix)
	if type(data) == 'table' then
		local first = true
		for k, v in pairs(data) do
			if first then
				first = false
			else
				insert(t, '&')
			end
			if prefix == '' then
				EncodePostData(v, t, k)
			else
				EncodePostData(v, t, prefix .. '[' .. k .. ']')
			end
		end
	else
		if prefix ~= '' then
			insert(t, prefix)
			insert(t, '=')
		end
		insert(t, data)
	end
end

function LIB.EncodePostData(data)
	local t = {}
	EncodePostData(data, t, '')
	local text = concat(t)
	return text
end

local function ConvertToUTF8(data)
	if type(data) == 'table' then
		local t = {}
		for k, v in pairs(data) do
			if type(k) == 'string' then
				t[ConvertToUTF8(k)] = ConvertToUTF8(v)
			else
				t[k] = ConvertToUTF8(v)
			end
		end
		return t
	elseif type(data) == 'string' then
		return AnsiToUTF8(data)
	else
		return data
	end
end
LIB.ConvertToUTF8 = ConvertToUTF8

local function ConvertToAnsi(data)
	if type(data) == 'table' then
		local t = {}
		for k, v in pairs(data) do
			if type(k) == 'string' then
				t[ConvertToAnsi(k)] = ConvertToAnsi(v)
			else
				t[k] = ConvertToAnsi(v)
			end
		end
		return t
	elseif type(data) == 'string' then
		return UTF8ToAnsi(data)
	else
		return data
	end
end
LIB.ConvertToAnsi = ConvertToAnsi

if not UrlEncodeString then
function UrlEncodeString(szText)
	return szText:gsub('([^0-9a-zA-Z ])', function (c) return format ('%%%02X', byte(c)) end):gsub(' ', '+')
end
end

if not UrlDecodeString then
function UrlDecodeString(szText)
	return szText:gsub('+', ' '):gsub('%%(%x%x)', function(h) return char(tonumber(h, 16)) end)
end
end

local function UrlEncode(data)
	if type(data) == 'table' then
		local t = {}
		for k, v in pairs(data) do
			if type(k == 'string') then
				t[UrlEncodeString(k)] = UrlEncode(v)
			else
				t[k] = UrlEncode(v)
			end
		end
		return t
	elseif type(data) == 'string' then
		return UrlEncodeString(data)
	else
		return data
	end
end
LIB.UrlEncode = UrlEncode

local function UrlDecode(data)
	if type(data) == 'table' then
		local t = {}
		for k, v in pairs(data) do
			if type(k == 'string') then
				t[UrlDecodeString(k)] = UrlDecode(v)
			else
				t[k] = UrlDecode(v)
			end
		end
		return t
	elseif type(data) == 'string' then
		return UrlDecodeString(data)
	else
		return data
	end
end
LIB.UrlDecode = UrlDecode

local m_simpleMatchCache = setmetatable({}, { __mode = 'v' })
function LIB.StringSimpleMatch(szText, szFind, bDistinctCase, bDistinctEnEm, bIgnoreSpace)
	if not bDistinctCase then
		szFind = StringLowerW(szFind)
		szText = StringLowerW(szText)
	end
	if not bDistinctEnEm then
		szText = StringEnerW(szText)
	end
	if bIgnoreSpace then
		szFind = StringReplaceW(szFind, ' ', '')
		szFind = StringReplaceW(szFind, g_tStrings.STR_ONE_CHINESE_SPACE, '')
		szText = StringReplaceW(szText, ' ', '')
		szText = StringReplaceW(szText, g_tStrings.STR_ONE_CHINESE_SPACE, '')
	end
	local me = GetClientPlayer()
	if me then
		szFind = szFind:gsub('$zj', me.szName)
		local szTongName = ''
		local tong = GetTongClient()
		if tong and me.dwTongID ~= 0 then
			szTongName = tong.ApplyGetTongName(me.dwTongID) or ''
		end
		szFind = szFind:gsub('$bh', szTongName)
		szFind = szFind:gsub('$gh', szTongName)
	end
	local tFind = m_simpleMatchCache[szFind]
	if not tFind then
		tFind = {}
		for _, szKeywordsLine in ipairs(LIB.SplitString(szFind, ';', true)) do
			local tKeyWordsLine = {}
			for _, szKeywords in ipairs(LIB.SplitString(szKeywordsLine, ',', true)) do
				local tKeyWords = {}
				for _, szKeyword in ipairs(LIB.SplitString(szKeywords, '|', true)) do
					local bNegative = szKeyword:sub(1, 1) == '!'
					if bNegative then
						szKeyword = szKeyword:sub(2)
					end
					if not bDistinctEnEm then
						szKeyword = StringEnerW(szKeyword)
					end
					insert(tKeyWords, { szKeyword = szKeyword, bNegative = bNegative })
				end
				insert(tKeyWordsLine, tKeyWords)
			end
			insert(tFind, tKeyWordsLine)
		end
		m_simpleMatchCache[szFind] = tFind
	end
	-- 10|十人,血战天策|XZTC,!小铁被吃了,!开宴黑铁;大战
	local bKeyWordsLine = false
	for _, tKeyWordsLine in ipairs(tFind) do         -- 符合一个即可
		-- 10|十人,血战天策|XZTC,!小铁被吃了,!开宴黑铁
		local bKeyWords = true
		for _, tKeyWords in ipairs(tKeyWordsLine) do -- 必须全部符合
			-- 10|十人
			local bKeyWord = false
			for _, info in ipairs(tKeyWords) do      -- 符合一个即可
				-- szKeyword = LIB.EscapeString(szKeyword) -- 用了wstring还Escape个捷豹
				if info.bNegative then               -- !小铁被吃了
					if not wfind(szText, info.szKeyword) then
						bKeyWord = true
					end
				else                                                    -- 十人   -- 10
					if wfind(szText, info.szKeyword) then
						bKeyWord = true
					end
				end
				if bKeyWord then
					break
				end
			end
			bKeyWords = bKeyWords and bKeyWord
			if not bKeyWords then
				break
			end
		end
		bKeyWordsLine = bKeyWordsLine or bKeyWords
		if bKeyWordsLine then
			break
		end
	end
	return bKeyWordsLine
end
