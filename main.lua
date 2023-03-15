-- (PROTOTYPE)

--[[
Grapheme cluster break routines.

For the implementation, see 'g_bound.lua'.
For the property look-up tables, see 'lut.lua'.

Missing glyphs:
	* I couldn't find a .ttf version of Noto KR on Google Fonts. Many of the grapheme-break 
	  tests involve Hangul (for example, anything with U+1100 or U+1160).
--]]

--[[
MIT License

Copyright (c) 2023 RBTS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]


love.keyboard.setKeyRepeat(true)


local gBound = require("g_bound")


-- Helps with instructions and displaying results
local quickPrint = require("lib.quick_print.quick_print")
local qp = quickPrint.new()


local utf8 = require("utf8")


local lutMaker = require("lut_maker")


-- Make one big font object via fallbacks

local demo_font
local demo_font_sz = 24
local demo_default_font = love.graphics.newFont(15)
local demo_instructions_font = love.graphics.newFont(14)
do
	local f1 = love.graphics.newFont("res/font/NotoSans-Regular.ttf", demo_font_sz)
	local f2 = love.graphics.newFont("res/font/NotoSansSymbols-Regular.ttf", demo_font_sz)
	local f3 = love.graphics.newFont("res/font/NotoSansSymbols2-Regular.ttf", demo_font_sz)
	local f4 = love.graphics.newFont("res/font/NotoEmoji-Regular.ttf", demo_font_sz)
	local f5 = love.graphics.newFont("res/font/NotoSansArabic-Regular.ttf", demo_font_sz)

	--print("hasGlyphs", f5:hasGlyphs(0x660000))

	f1:setFallbacks(f2, f3, f4, f5)
	demo_font = f1
end


-- Pages (states) for the demo.
-- Page 1: Show results of GraphemeBreakTest.txt
-- Page 2: Split a few example strings by their boundaries.
local demo_pages = {}
local demo_i = 1

local disp = {} -- holds test and result strings for page 1
local disp_n = {} -- holds line numbers for disp, so you can look up the tests in the original text file.


-- Setup page 2
local p2_str = {
	"Hamburger", -- (U+0048) ...
	"g̈houle", -- (U+0067 U+0308) (U+0048) ...
	"👩‍🦲🧑‍🦲👨‍🦲", -- (U+1F468 U+200D U+1F9B2) (U+1F469 U+200D U+1F9B2) (U+1F9D1 U+200D U+1F9B2)
	"🏴!", -- (U+1F3F4) (U+0021)
	"🇨🇦#", -- (U+1F1E8 U+1F1E6) (U+0023)
	"#🇦🇶", -- (U+1F1E6 U+1F1F6) (U+0023)
}

-- Break page 2 strings into clusters
local p2_split = {}
for i, str in ipairs(p2_str) do
	local seq = {}
	local p1 = 1
	for p, c in utf8.codes(str) do
		local breaking, new_pos, reason = gBound.checkBreak(str, p)
		if breaking then
			table.insert(seq, string.sub(str, p1, new_pos - 1))
			p1 = new_pos
		end
	end

	table.insert(p2_split, seq)
end


for i, seq in ipairs(p2_split) do
	io.write(i .. ": |")
	for j, chunk in ipairs(seq) do
		io.write(chunk)
		io.write("|")
	end
	io.write("\n")
end

--[[
👨‍🦲 ==
👨		U+1F468
(ZWJ)	U+200D
🦲		U+1F9B2

👩‍🦲 ==
👩		U+1F469
(ZWJ)	U+200D
🦲		U+1F9B2

🧑‍🦲 ==
🧑		U+1F9D1
(ZWJ)	U+200D
🦲		U+1F9B2
--]]


local function testBreak(str)

	local result = {}

	-- gBound.checkBreak can return the rule string used as its third value,
	-- but this is commented out by default.
	local rules = {}

	local i = 0 -- Rule 0.2
	while i <= #str do
		local breaking, new_pos, reason = gBound.checkBreak(str, i)
		local sub_str = string.sub(str, i, new_pos - 1)

		if reason ~= nil then
			table.insert(rules, reason)
		end

		--print("i", i, "new_pos", new_pos, "#str", #str, breaking and "÷" or "×", "reason", reason)

		if i > 0 then
			local to_num = utf8.codepoint(str, i)
			if to_num then
				table.insert(result, to_num)
			end
		end
		i = new_pos
		if breaking then
			table.insert(result, "÷")

		else
			table.insert(result, "×")
		end
	end

	return result, rules
end


local love_major = love.getVersion()
local function wrapOpenRead(path)

	local file, err
	if love_major == 12 then
		file, err = love.filesystem.openFile(path, "r")
		if not file then
			error("open file '" .. tostring(path) .. "' failed: " .. err)
		end

	else
		file = love.filesystem.newFile(path)
		local ok
		ok, err = file:open("r")
		if not ok then
			error("open file '" .. tostring(path) .. "' failed: " .. err)
		end
	end

	local str
	str, err = file:read()
	if not str then
		file:close()
		error("read file  '" .. tostring(path) .. "' failed: " .. err)
	end
	file:close()

	return str
end


local test_str = wrapOpenRead("res/GraphemeBreakTest-2022-02-26.txt")
local demo_tests = lutMaker.parseGraphemeBreakTest(test_str)


local function makeStringFromTest(sequence)

	local tmp = {}
	for i, chunk in ipairs(sequence) do
		if type(chunk) == "number" then
			table.insert(tmp, utf8.char(chunk))
		end
	end

	local str = table.concat(tmp)
	return str
end


local function makeInfoStringFromTest(sequence)

	local tmp = {}
	for i, chunk in ipairs(sequence) do
		if type(chunk) == "number" then
			table.insert(tmp, string.format("%x ", chunk))

		else
			table.insert(tmp, chunk .. " ")
		end
	end

	local str = table.concat(tmp)
	return str
end

--assertCompare(test.sequence, test.rules, result, res_rules)
local function assertCompare(seq1, rul1, seq2, rul2)

	if #seq1 ~= #seq2 then
		error("test and result sequence sizes do not match.")
	end

	for i, chunk in ipairs(seq1) do
		if seq2[i] ~= chunk then
			error("test result mismatch.")
		end
	end

	-- Rules are returned as value 3 by gBound.checkBreak(), but it is
	-- commented out by default.
	if #rul2 > 0 then
		-- Uncomment to test tripping the rule comparison test.
		--rul2[#rul2] = "foobar"

		--[[
		print(#rul1, #rul2)
		for i, chunk in ipairs(rul1) do
			print("", i, chunk)
		end
		for i, chunk in ipairs(rul2) do
			print("", i, chunk)
		end
		--]]

		if #rul1 ~= #rul2 then
			error("test and result rule list sizes do not match.")
		end

		for i, str in ipairs(rul1) do
			if str ~= rul2[i] then
				error("test and result rule mismatch.")
			end
		end
	end
end


local function runBoundaryTests(tests)

	local results = {}

	for t, test in ipairs(tests) do
		local test_str = makeStringFromTest(test.sequence)
		local info_str = makeInfoStringFromTest(test.sequence)
		io.write("test #" .. tostring(t) .. ": |" .. test_str .. "|\n" .. info_str)
		io.write("\n")
		local result, res_rules = testBreak(test_str)
		local info_res = makeInfoStringFromTest(result)
		io.write(info_res)
		io.write("\n")

		assertCompare(test.sequence, test.rules, result, res_rules)
		table.insert(results, result)
	end

	return results
end


local demo_results = runBoundaryTests(demo_tests)

local demo_offset_y = 1


function love.keypressed(kc, sc)

	if kc == "escape" then
		love.event.quit()

	elseif kc == "1" or kc == "2" then
		demo_i = tonumber(kc)

	elseif demo_i == 1 then
		if kc == "up" then
			demo_offset_y = math.max(1, demo_offset_y - 1)

		elseif kc == "down" then
			demo_offset_y = math.min(#disp, demo_offset_y + 1)

		elseif kc == "pageup" then
			demo_offset_y = math.max(1, demo_offset_y - 10)

		elseif kc == "pagedown" then
			demo_offset_y = math.min(#disp, demo_offset_y + 10)

		elseif kc == "home" then
			demo_offset_y = 1

		elseif kc == "end" then
			demo_offset_y = #disp
		end
	end
end


function love.update(dt)
	--
end


-- Page 1: populate display list
for i, test in ipairs(demo_tests) do
	table.insert(disp, {
		test = test,
		result = demo_results[i],
		res_inf = makeInfoStringFromTest(demo_results[i]),
		res_str = makeStringFromTest(test.sequence),
	})
	disp_n[i] = test.line_n
end


local c1 = {0.55, 0.55, 0.55, 1.00}
local c2 = {1.00, 1.00, 1.00, 1.00}


function love.draw()

	love.graphics.setFont(demo_font)
	qp:setOrigin(0, 0)
	qp:reset()
	local win_w = love.graphics.getWidth()
	local win_h = love.graphics.getHeight()
	local font_h = demo_font:getHeight()

	if demo_i == 1 then
		if #disp == 0 then
			qp:print("(No tests to view.)")

		else

			-- Draw the left side, then dim the right side, then draw the right.
			for i = demo_offset_y, #disp do
				local entry = disp[i]
				love.graphics.setColor(c1)
				qp:write(disp_n[i], ": ")
				love.graphics.setColor(c2)
				qp:write(entry.res_inf)
				qp:down()

				if qp.y > win_h + font_h then 
					break
				end
			end

			love.graphics.setColor(0.0, 0.0, 0.0, 0.8)
			love.graphics.rectangle(
				"fill",
				math.floor(win_w/2),
				0,
				win_w/2 + 1,
				win_h
				)
			love.graphics.setColor(1,1,1,1)

			qp:setXOrigin(math.floor(win_w / 2))
			qp:reset()

			for i = demo_offset_y, #disp do
				local entry = disp[i]

				love.graphics.setColor(c1)
				qp:write("|")
				love.graphics.setColor(c2)
				qp:write(entry.res_str)
				love.graphics.setColor(c1)
				qp:write("|")
				love.graphics.setColor(c2)
				qp:down()

				if qp.y > win_h + font_h then 
					break
				end
			end
		end

	elseif demo_i == 2 then
		for i, str in ipairs(p2_str) do
			qp:write(str)
			qp:setXPosition(math.floor(win_w/2))

			love.graphics.setColor(c1)
			qp:write("|")
			love.graphics.setColor(c2)
			for j, chunk in ipairs(p2_split[i]) do
				qp:write(chunk)
				love.graphics.setColor(c1)
				qp:write("|")
				love.graphics.setColor(c2)
			end
			qp:down()
		end
	end

	-- UI
	love.graphics.setFont(demo_instructions_font)
	local inst_h = demo_instructions_font:getHeight()
	qp:setOrigin(0, win_h - inst_h)
	qp:reset()
	love.graphics.setColor(0, 0, 0, 0.9)
	love.graphics.rectangle("fill", 0, math.floor(win_h - inst_h*1.125), win_w, inst_h + 11)
	love.graphics.setColor(1, 1, 1, 1)
	qp:write("Demo Page (1,2): ", demo_i, "\t")
	if demo_i == 1 then
		qp:write("Up/Down/PgUp/PgDn/Home/End: Scroll\t")
	end
	qp:write("Esc: quit")
end


