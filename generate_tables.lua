-- (PROTOTYPE)

--[[
This is a command line interface for lut_maker.lua.

Tested on:
	Windows 10 + Lua 5.1
	Fedora 37 + Lua 5.4
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


local REQ_PATH = ... and (...):match("(.-)[^%.]+$") or ""

local lutMaker = require(REQ_PATH .. "lut_maker")


local function printUsage()
	print("Usage: lua generate_tables.lua [--grapheme-breaks path/to/graphemebreaks.txt] [--ext-pict path/to/extpict.txt] [--output saved.lua]")
	print("")
	print("Options:")
	print("")
	print("--grapheme-breaks <path>  The location of 'GraphemeBreakProperty.txt' to parse breaking categories.")
	print("--ext-pict <path>         Specify the location of 'emoji-data.txt' to parse 'Extended_Pictographic'.")
	print("--output <path>           A file to write the tables to. If not provided, output will be printed to")
	print("                          the terminal.")
end


-- Options
local path_grapheme_breaks = false
local path_ext_pict = false
local path_output = false


-- Parse arguments
if #arg < 1 then
	printUsage()
	return 0

else
	local i = 1
	while i <= #arg do
		local chunk = arg[i]
		if chunk == "--grapheme-breaks" then
			path_grapheme_breaks = arg[i + 1]
			i = i + 2

		elseif chunk == "--ext-pict" then
			path_ext_pict = arg[i + 1]
			i = i + 2

		elseif chunk == "--output" then
			path_output = arg[i + 1]
			i = i + 2

		elseif chunk == "--help" then
			printUsage()
			return 0

		else
			print("Unknown option: " .. arg[i] .. "\n")
			printUsage()
			return -1
		end
	end
end


local function wrapOpenRead(path)

	local file, err = io.open(path, "r")
	if not file then
		error("open file '" .. tostring(path) .. "' failed: " .. err)

	else
		local str
		str, err = file:read("*a")
		if not str then
			error("read file  '" .. tostring(path) .. "' failed: " .. err)
		end
		file:close()

		return str
	end
end


local function stringValueGroup(temp, db, id)

	local row_pairs = 0

	table.insert(temp, "\t[\"" .. id .. "\"] = {\n\t\t")

	local sub_db = db[id]
	for i = 1, #sub_db, 2 do
		row_pairs = row_pairs + 1
		table.insert(temp, string.format("0x%x,0x%x, ", sub_db[i], sub_db[i + 1]))

		if row_pairs >= 4 then
			row_pairs = 0
			table.insert(temp, ("\n\t\t"))
		end
	end
	if row_pairs > 0 then
		table.insert(temp, ("\n\t"))
	end
	table.insert(temp, ("},\n"))
end


local temp = { [[
-- Generated by lut_maker.lua / generate_tables.lua from the Unicode data files.

-- Every pair of values represents a range. Single values are duplicated, such
-- that reading them as 'code_point >= r1 and code_point <= r2' can be used for
-- both ranges and lone numbers.

local lut = {}

]]
}


if path_grapheme_breaks then

	local str = wrapOpenRead(path_grapheme_breaks)
	local db = lutMaker.parseGraphemeBreakProperty(str)

	table.insert(temp, "lut.grapheme_breaks = {\n")

	stringValueGroup(temp, db, "CR")
	stringValueGroup(temp, db, "LF")
	stringValueGroup(temp, db, "Control")
	stringValueGroup(temp, db, "Extend")
	stringValueGroup(temp, db, "ZWJ")
	stringValueGroup(temp, db, "Regional_Indicator")
	stringValueGroup(temp, db, "Prepend")
	stringValueGroup(temp, db, "SpacingMark")
	stringValueGroup(temp, db, "L")
	stringValueGroup(temp, db, "V")
	stringValueGroup(temp, db, "T")
	stringValueGroup(temp, db, "LV")
	stringValueGroup(temp, db, "LVT")

	table.insert(temp, "}\n")
end


if path_ext_pict then

	local str = wrapOpenRead(path_ext_pict)
	local db = lutMaker.parseEmojiData(str)

	table.insert(temp, "lut.emoji_data = {\n")

	-- For now, we only care about the 'Extended_Pictographic' property.
	stringValueGroup(temp, db, "Extended_Pictographic")

	table.insert(temp, "}\n")
end


table.insert(temp, "\nreturn lut")


local out_str = table.concat(temp)


if path_output then
	local f_out, err = io.open(path_output, "w")
	if not f_out then
		error("Couldn't open output path '" .. tostring(output_path) .. "' for writing: " .. err)
	end

	f_out:write(out_str)
	f_out:close()

else
	print(out_str)
end

return 0

