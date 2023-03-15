-- (PROTOTYPE)

--[[
Generates tables by parsing Unicode data text files.
The LUTs are for parsing grapheme cluster boundaries.

See 'generate_tables.lua' for a command line interface.

Table format: every two values represent a range of code points sharing the LUT's property.
In cases where the range is only a single value, the number appears twice.
Up to eight values (four range pairs) are printed per line.

Example:

local lut = {
	some_property = {
		0x0,0x20, 0x44,0x6d, 0xd1,0xd1,
	},
}

Note that this approach wouldn't work for all of the Unicode data files. Some of them
use a layered approach of assigning a default property to a wide range of code points,
and then specify exceptions with sub-ranges. In that case, you'd need to make a full
hash of code points, resolve the properties, and then make lists of ranges from that.
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


local lutMaker = {}


local function appendToGroup(db, field, r1, r2)

	local sub_field = db[field] or {}
	db[field] = sub_field

	if r1 and r2 then
		table.insert(sub_field, r1)
		table.insert(sub_field, r2)

	else
		table.insert(sub_field, r1)
		table.insert(sub_field, r1)
	end
end


--- Parses the Unicode data file 'GraphemeBreakProperty.txt'.
-- @param str GraphemeBreakProperty.txt as a string
-- @return A table with sub-tables for each break property enum (["CR"], ["LF"], ["Control"], ...).
function lutMaker.parseGraphemeBreakProperty(str)

	--[[
	Tested with:
	GraphemeBreakProperty.txt -- 15.0.0 (2022-04-27)
	https://www.unicode.org/Public/15.0.0/ucd/auxiliary/GraphemeBreakProperty.txt
	--]]

	local db = {}

	for line in string.gmatch(str, "\n?([^\n]+)") do

		-- Comment-only line
		if string.byte(line, 1) == 35 then -- "#"

			-- 15.0.0: Skip the @missing field for now. It's used to layer properties in other data files,
			-- but here, in 15.0.0, it just sets a default property value for every single code point.
			--[[
			-- # @missing: 0000..10FFFF; Other
			local miss1, miss2, miss_cat = string.match(line, "#%s*@missing:%s*(%x+)..(%x+);%s*(%S+)")

			-- (etc.)
			--]]

		else
			-- Single code point:
			--13440         ; Extend # Mn       EGYPTIAN HIEROGLYPH MIRROR HORIZONTALLY
			--
			-- Range of code points:
			--0600..0605    ; Prepend # Cf   [6] ARABIC NUMBER SIGN..ARABIC NUMBER MARK ABOVE

			-- Try range
			local r1, r2, cat = string.match(line, "%s*(%x+)%.%.(%x+)%s*;%s*([^%s#]+)")

			-- Try single value
			if not r1 then
				r1, cat = string.match(line, "%s*(%x+)%s*;%s*([^%s#]+)")
			end

			--print("range: ", r1, r2, cat)
			if r1 then
				r1 = tonumber(r1, 16)
			end
			if r2 then
				r2 = tonumber(r2, 16)
			end

			appendToGroup(db, cat, r1, r2)
		end
	end

	return db
end


--- Parses the Unicode data file 'emoji-data.txt'.
-- @param str emoji-data.txt as a string
-- @return A table with sub-tables for each break property enum.
function lutMaker.parseEmojiData(str)

	--[[
	Tested with:
	emoji-data.txt -- Emoji Version 15.0 (2022-08-02)
	https://www.unicode.org/Public/15.0.0/ucd/emoji/emoji-data.txt
	--]]

	local db = {}

	--[[
	Format:
	<codepoint(s)> ; <property> # <comments>
	--]]

	local db = {}

	for line in string.gmatch(str, "\n?([^\n]+)") do

		-- Single code point:
		-- 26F9          ; Emoji_Modifier_Base  # E0.7   [1] (⛹️)       person bouncing ball
		--
		-- Range of code points:
		-- 270A..270C    ; Emoji_Modifier_Base  # E0.6   [3] (✊..✌️)    raised fist..victory hand

		-- Try range
		local r1, r2, cat = string.match(line, "%s*(%x+)%.%.(%x+)%s*;%s*([^%s#]+)")

		-- Try single value
		if not r1 then
			r1, cat = string.match(line, "%s*(%x+)%s*;%s*([^%s#]+)")
		end

		--print("range: ", r1, r2, cat)
		if r1 then
			r1 = tonumber(r1, 16)
		end
		if r2 then
			r2 = tonumber(r2, 16)
		end

		if r1 then
			appendToGroup(db, cat, r1, r2)
		end
	end

	return db
end


--- Parses the Unicode data file 'GraphemeBreakTest.txt'. This file provides hundreds of boundary tests and
--	the expected breaks + continuations. For more info, have a look at UAX #29: https://unicode.org/reports/tr29/
--	and also the Unicode Grapheme Break Chart: https://www.unicode.org/Public/UCD/latest/ucd/auxiliary/GraphemeBreakTest.html
function lutMaker.parseGraphemeBreakTest(str)

	--[[
	Tested with:
	GraphemeBreakTest.txt -- 15.0.0 (2022-02-16)
	http://www.unicode.org/Public/UNIDATA/auxiliary/GraphemeBreakTest.txt
	--]]

	local line_n = 0
	local tests = {}

	for line in string.gmatch(str, "\n?([^\n]+)") do

		line_n = line_n + 1

		-- Ignore comment-only lines
		if string.sub(line, 1, 1) ~= "#" then
			local sequence = {}

			local i, j = 1, 1
			while true do
				local chunk
				i, j, chunk = string.find(line, "%s*(%S+)", i)
				if not i then
					break
				end

				if string.sub(chunk, 1, 1) == "#" then
					break

				elseif chunk == "÷" or chunk == "×" then
					table.insert(sequence, chunk)

				elseif chunk and tonumber(chunk, 16) then
					table.insert(sequence, tonumber(chunk, 16))
				end

				i = j + 1
			end
			if #sequence > 0 then
				-- Get rules from comments part of lines (in square brackets)
				local rules = {}
				local comment_part = string.match(line, "#(.*)$")
				if comment_part then
					for rule in string.gmatch(line, "%[([^%]]+)%]") do
						table.insert(rules, rule)
					end
				end
				table.insert(tests, {sequence = sequence, rules = rules, line_n = line_n})
			end
		end
	end

	return tests
end


return lutMaker
