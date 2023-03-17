**NOTE:** This is a prototype.

# grapheme\_cluster\_boundary

Provides functions to detect the boundaries of grapheme clusters in Unicode strings. It uses the simplified algorithm from the Unicode [Grapheme Break Chart](https://www.unicode.org/Public/UCD/latest/ucd/auxiliary/GraphemeBreakTest.html) page, which is based on the [algorithm in UAX #29](https://unicode.org/reports/tr29/#Grapheme_Cluster_Boundaries).

The intended environment is [LÖVE](https://github.com/love2d/love), versions 11.4 or 12.0-development.

Note that this does not provide 100% coverage of all graphemes / ligatures in all languages. See [UAX #29, Section 6.5, Tailoring](https://unicode.org/reports/tr29/#Tailoring) for more info.


## What's This For?

One common use case is placement of a text cursor, which should (usually) move to the boundaries between grapheme clusters.

I also have a couple of edge cases related to measuring text.


## Example

`main.lua` runs every test in the Unicode data file `GraphemeBreakTest.txt`. If there is any difference between expected and actual results, it should raise an error.

For integration into a project, the files you need are `g_bound.lua` and `lut.lua`. Everything else is just for testing or producing the look-up tables.


```lua
local utf8 = require("utf8") -- From Lua 5.3, bundled with LÖVE
local gBound = require("path.to.g_bound")

local str = "foo👶👶🏻👶🏼👶🏽👶🏾👶🏿bar"

local clusters = {}
local r = 1
for p, c in utf8.codes(str) do
	local breaking, next_pos = gBound.checkBreak(str, p)
	if breaking then
		table.insert(clusters, string.sub(str, r, next_pos - 1))
		r = next_pos
	end
end

for i, chunk in ipairs(clusters) do
	print(i, chunk)
end

-- Output:
--[[
1	f
2	o
3	o
4	👶
5	👶🏻
6	👶🏼
7	👶🏽
8	👶🏾
9	👶🏿
10	b
11	a
12	r
--]]
```


## Experimental Tailoring Support

For the third argument of `gBound.checkBreak()`, you may pass a sequence of functions to implement custom rules for tailoring. Functions are run in order between the built-in rules 0.3 and 3.0. The function signature is `function(str, a, b, pos)`, where `str` is the string being checked, `a` is the first code point, `b` is the second code point, and `pos` is the byte index of `a` within `str`.

The tailoring functions return `true` to indicate that there should be a break (`÷`), `false` to indicate that there should *not* be a break (`×`), or `nil` to continue with further tests.

`main.lua` implements the three example tailorings shown in [UAX #29 Table 1a. Sample Grapheme Clusters](https://unicode.org/reports/tr29/#Table_Sample_Grapheme_Clusters), in demo page 3.


## License

The files in `res` are 3rd party (fonts and Unicode data), and contain their own licenses (Open Font License; Unicode license for Data Files and Software). The rest of this package is covered by the MIT License:

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
