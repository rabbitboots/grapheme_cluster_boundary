local major = love.getVersion()

function love.conf(t)
	t.window.resizable = true
	t.window.title = "(Prototype) Grapheme Boundary Test (LÖVE " .. major .. ")"
end
