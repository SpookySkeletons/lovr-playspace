-- Bootstrap
appName = "lovr-playspace"
mainScriptPath = (debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"):sub(1,-2)
package.path = mainScriptPath.. "/lib/?.lua;" ..mainScriptPath.. "/lib/?/_main.lua;" ..package.path

-- App
hands = {"hand/right","hand/left"}
limbs = {
	"head",
	"hand/left",
	"hand/right",
	"hand/left/point",
	"hand/right/point",
	"elbow/left",
	"elbow/right",
	"shoulder/left",
	"shoulder/right",
	"chest",
	"waist",
	"knee/left",
	"knee/right",
	"foot/left",
	"foot/right"
}

configDirs = {}
json = require("json")

function platformConfig()
	if os.getenv("HOME") ~= nil then
		return os.getenv("HOME") .. "/.config"
	end
	
	return os.getenv("APPDATA")
end

function fileExists(fileName)
	local file = io.open(fileName,"rb")
	if file == nil then return false end
	file:close()
	return true
end

function getConfigFile(fileName)
	for _,path in ipairs(configDirs) do
		if fileExists(path .. "/" .. fileName) then
			return path .. "/" .. fileName
		end
	end
end

function userConfig(fileName)
	return configDirs[1] .. "/" ..fileName
end

function fileWrite(fileName,content)
	local file = io.open(fileName,"wb")
	file:write(content)
	file:close()
end

function readFile(fileName)
	local file = io.open(fileName,"rb")
	content = file:read("*all")
	file:close()
	return content
end

function getDistanceBetweenPoints3D(x1,y1,z1,x2,y2,z2)
	return (((x2-x1)*(x2-x1)) + ((y2-y1)*(y2-y1)) + ((z2-z1)*(z2-z1))) / 2
end

-- This could be optimized by using a proper algorithm or determining which point of the line is closer to x,y,z first
function getLineDistance(x,y,z,point1,point2)
	local lx1 = point1[1]
	local ly1 = 0
	local lz1 = point1[2]
	local lx2 = point2[1]
	local ly2 = 0
	local lz2 = point2[2]
	
	local d = getDistanceBetweenPoints3D(lx1,ly1,lz1,lx2,ly2,lz2)
	local dx = (lx2 - lx1) / d
	local dy = (ly2 - ly1) / d
	local dz = (lz2 - lz1) / d
	local cx1 = lx1
	local cy1 = ly1
	local cz1 = lz1
	local lowestDist = 9999
	
	while cx1 < lx1 do
		local dist = getDistanceBetweenPoints3D(x,y,z,cx1,cy1,cz1)
		if dist < lowestDist then
			lowestDist = dist
		else
			return lowestDist
		end
		cx1 = cx1 + (dx * settings.check_density)
		cy1 = cy1 + (dy * settings.check_density)
		cz1 = cz1 + (dz * settings.check_density)
	end
	
	return lowestDist
end

function getButton(method,button,devices)
	for _,device in ipairs(devices) do
		if method(device,button) == true then return device end
	end
end

function isTracked(device)
	local x,y,z = lovr.headset.getPosition(device)
	if x == 0.0 and y == 0.0 and z == 0.0 then return false end
	return true
end

function drawSinglePointGrid(pass,point1,point2,cornerColor,miscColor)
	local _,hy,_ = lovr.headset.getPosition("head")	
	local lx1 = point1[1]
	local ly1 = hy
	local lz1 = point1[2]
	local lx2 = point2[1]
	local ly2 = hy
	local lz2 = point2[2]
	
	local d = getDistanceBetweenPoints3D(lx1,ly1,lz1,lx2,ly2,lz2)
	local dx = (lx2 - lx1) / d
	local dy = (ly2 - ly1) / d
	local dz = (lz2 - lz1) / d
	
	pass:setColor(unpack(miscColor))
	local drawY = settings.grid_top
	while drawY >= settings.grid_bottom do
		pass:line({
			lx1,drawY,lz1,
			lx2,drawY,lz2
		})
		drawY = drawY - settings.grid_density
	end
	
	pass:setColor(unpack(cornerColor))
	pass:line({
		lx1,settings.grid_bottom,lz1,
		lx1,settings.grid_top,lz1
	})
	
	pass:line({
		lx1,settings.grid_bottom,lz1,
		lx2,settings.grid_bottom,lz2
	})
	
	pass:line({
		lx1,settings.grid_top,lz1,
		lx2,settings.grid_top,lz2
	})
end

function drawPointGrid(pass,points,cornerColor,miscColor)
	local index = 2
	local length = #points
	if length < 1 then return end
	while index <= length do
		drawSinglePointGrid(pass,points[index - 1],points[index],cornerColor,miscColor)
		index = index + 1
	end
	drawSinglePointGrid(pass,points[length],points[1],cornerColor,miscColor)
end

function lovr.load()
	lovr.graphics.setBackgroundColor(0.0, 0.0, 0.0, 0.0)
	--table.insert(configDirs,platformConfig() .. "/" .. appName)
	table.insert(configDirs,mainScriptPath .. "/config")
	
	settings = {}
	settings.action_button = readFile(getConfigFile("action_button.txt"))
	settings.check_density = tonumber(readFile(getConfigFile("check_density.txt")))
	settings.fade_start = tonumber(readFile(getConfigFile("fade_start.txt")))
	settings.fade_stop = tonumber(readFile(getConfigFile("fade_stop.txt")))
	settings.grid_density = tonumber(readFile(getConfigFile("grid_density.txt")))
	settings.grid_bottom = tonumber(readFile(getConfigFile("grid_bottom.txt")))
	settings.grid_top = tonumber(readFile(getConfigFile("grid_top.txt")))
	settings.color_close_corners = json.decode(readFile(getConfigFile("color_close_corners.json")))
	settings.color_close_grid = json.decode(readFile(getConfigFile("color_close_grid.json")))
	settings.color_far_corners = json.decode(readFile(getConfigFile("color_far_corners.json")))
	settings.color_far_grid = json.decode(readFile(getConfigFile("color_far_grid.json")))
	settings.points = {}
	
	--[[if not lovr.filesystem.isDirectory(configDirs[1]) then
		fileWrite(userConfig("action_button.txt"),readFile(getConfigFile("action_button.txt")))
		fileWrite(userConfig("check_density.txt"),readFile(getConfigFile("check_density.txt")))
		fileWrite(userConfig("fade_start.txt"),readFile(getConfigFile("fade_start.txt")))
		fileWrite(userConfig("fade_stop.txt"),readFile(getConfigFile("fade_stop.txt")))
		fileWrite(userConfig("grid_density.txt"),readFile(getConfigFile("grid_density.txt")))
		fileWrite(userConfig("grid_bottom.txt"),readFile(getConfigFile("grid_bottom.txt")))
		fileWrite(userConfig("grid_top.txt"),readFile(getConfigFile("grid_top.txt")))
		fileWrite(userConfig("color_close_corners.json"),readFile(getConfigFile("color_close_corners.json")))
		fileWrite(userConfig("color_close_grid.json"),readFile(getConfigFile("color_close_grid.json")))
		fileWrite(userConfig("color_far_corners.json"),readFile(getConfigFile("color_far_corners.json")))
		fileWrite(userConfig("color_far_grid.json"),readFile(getConfigFile("color_far_grid.json")))
		initConfigure()
		return
	end]]--
	
	if getConfigFile("points.json") == nil then
		initConfigure()
		return
	end
	
	for _,hand in ipairs(hands) do
		if lovr.headset.isDown(hand,settings.action_button) then
			initConfigure()
			return
		end
	end
	
	settings.points = json.decode(readFile(getConfigFile("points.json")))
	mode = modeDraw
end

function initConfigure()
	saveProg = 1.0
	
	lovr.update = function(dt)
		deltaTime = dt
	end
	
	mode = modeConfigure
end

function deinitConfigure()
	saveProg = nil
	lovr.update = nil
	deltaTime = nil
	mode = modeDraw
end

function modeConfigure(pass)
	local _,hy,_ = lovr.headset.getPosition("head")	
	
	for _,hand in ipairs(hands) do
		if isTracked(hand .. "/point") then
			local x,y,z = lovr.headset.getPosition(hand .. "/point")
			pass:setColor(1,0,0,0.5 * saveProg)
			pass:sphere(x,y,z,0.1)
			pass:setColor(1,1,1,saveProg)
			pass:text(
				"- Press '" ..settings.action_button.. "' to add a point -\n" ..
				"- Hold '" ..settings.action_button.. "' to save -\n\n" ..
				string.format("%.2f",x) .. "," .. string.format("%.2f",y) .. "," .. string.format("%.2f",z)
			,x,y - 0.3,z,0.066)
		end
	end
	
	local inputDev = getButton(lovr.headset.wasReleased,settings.action_button,hands)
	if inputDev ~= nil and isTracked(inputDev) then
		local hx,_,hz = lovr.headset.getPosition(inputDev)
		table.insert(settings.points,{hx,hz})
	end
	
	inputDev = getButton(lovr.headset.isDown,settings.action_button,hands)
	if inputDev ~= nil then
		saveProg = saveProg - (deltaTime / 3)
		if saveProg <= 0 then
			fileWrite(userConfig("points.json"),json.encode(settings.points))
			deinitConfigure()
			modeDraw(pass)
			return
		end
	else
		saveProg = 1.0
	end
	
	pass:setColor(1,0,0,0.5)
	for _,point in ipairs(settings.points) do
		pass:sphere(point[1],1.5,point[2],0.1)
	end
	
	modeDraw(pass)
end

function modeDraw(pass)
	local x,y,z = lovr.headset.getPosition("head")
	local lowestDist = 9999	
	local index = 2
	local length = #settings.points
	if length < 1 then return end
	while index <= length do
		local dist = getLineDistance(x,y,z,settings.points[index - 1],settings.points[index])
		if dist < lowestDist then lowestDist = dist end
		index = index + 1
	end
	
	lowestDist = (lowestDist - settings.fade_stop) / (settings.fade_start - settings.fade_stop)
	if lowestDist < 0 then lowestDist = 0 end
	if lowestDist > 1 then lowestDist = 1 end
	
	local cdr=settings.color_close_corners[1] - settings.color_far_corners[1]
	cdr = settings.color_far_corners[1] + (cdr * lowestDist)
	local cdg=settings.color_close_corners[2] - settings.color_far_corners[2]
	cdg = settings.color_far_corners[2] + (cdg * lowestDist)
	local cdb=settings.color_close_corners[3] - settings.color_far_corners[3]
	cdb = settings.color_far_corners[3] + (cdb * lowestDist)
	local cda=settings.color_close_corners[4] - settings.color_far_corners[4]
	cda = settings.color_far_corners[4] + (cda * lowestDist)
	
	local gdr=settings.color_close_grid[1] - settings.color_far_grid[1]
	gdr = settings.color_far_grid[1] + (gdr * lowestDist)
	local gdg=settings.color_close_grid[2] - settings.color_far_grid[2]
	gdg = settings.color_far_grid[2] + (gdg * lowestDist)
	local gdb=settings.color_close_grid[3] - settings.color_far_grid[3]
	gdb = settings.color_far_grid[3] + (gdb * lowestDist)
	local gda=settings.color_close_grid[4] - settings.color_far_grid[4]
	gda = settings.color_far_grid[4] + (gda * lowestDist)
	
	drawPointGrid(pass,settings.points,{cdr,cdg,cdb,cda},{gdr,gdg,gdb,gda})
end

function lovr.draw(pass)
	mode(pass)
end