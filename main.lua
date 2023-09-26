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

function getDistanceBetweenPoints3D(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x2 - x1)^2 + (z2 - z1)^2)
end

function getLineDistance(x, _, z, point1, point2)  -- Notice the underscore for y
    -- Vector from point1 to point2
    local dx = point2[1] - point1[1]
    local dz = point2[2] - point1[2]
    
    -- Vector from point1 to the given point (x, y, z)
    local px = x - point1[1]
    local pz = z - point1[2]

    -- Dot product
    local dot = px * dx + pz * dz
    local len_sq = dx * dx + dz * dz
    local param = -1
    if len_sq ~= 0 then  -- in case of 0 length line
        param = dot / len_sq
    end

    local xx, zz

    if param < 0 then
        xx = point1[1]
        zz = point1[2]
    elseif param > 1 then
        xx = point2[1]
        zz = point2[2]
    else
        xx = point1[1] + param * dx
        zz = point1[2] + param * dz
    end

    local dx_ = x - xx
    local dz_ = z - zz
    return math.sqrt(dx_ * dx_ + dz_ * dz_)
end



function getClosestDistanceToPerimeter(x, y, z, points)
    local lowestDist = 9999
    local length = #points
    for i = 1, length do
        local point1 = points[i]
        local point2 = points[(i % length) + 1]
        local dist = getLineDistance(x, y, z, point1, point2)
        if dist < lowestDist then
            lowestDist = dist
        end
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

function drawSinglePointGrid(pass, point1, point2, cornerColor, miscColor)
    local _, hy, _ = lovr.headset.getPosition("head")
    local lx1 = point1[1]
    local ly1 = hy
    local lz1 = point1[2]
    local lx2 = point2[1]
    local ly2 = hy
    local lz2 = point2[2]

    -- For the grid lines
    pass:setColor(unpack(miscColor))
    local drawY = settings.grid_top
    while drawY >= settings.grid_bottom do
        pass:line({
            lx1, drawY, lz1,
            lx2, drawY, lz2
        })
        drawY = drawY - settings.grid_density
    end

    -- For the perimeter lines
    pass:setColor(unpack(cornerColor))
    pass:line({
        lx1, settings.grid_bottom, lz1,
        lx1, settings.grid_top, lz1
    })

    pass:line({
        lx1, settings.grid_bottom, lz1,
        lx2, settings.grid_bottom, lz2
    })

    pass:line({
        lx1, settings.grid_top, lz1,
        lx2, settings.grid_top, lz2
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
    local x, y, z = lovr.headset.getPosition("head")
    local closestDist = getClosestDistanceToPerimeter(x, y, z, settings.points)

    -- Update the fade logic based on the closest distance
    closestDist = (closestDist - settings.fade_stop) / (settings.fade_start - settings.fade_stop)
    closestDist = math.max(0, math.min(1, closestDist))

    local function interpolateColor(startColor, endColor)
        return {
            startColor[1] + (endColor[1] - startColor[1]) * closestDist,
            startColor[2] + (endColor[2] - startColor[2]) * closestDist,
            startColor[3] + (endColor[3] - startColor[3]) * closestDist,
            startColor[4] + (endColor[4] - startColor[4]) * closestDist
        }
    end

	local cornerColor = interpolateColor(settings.color_far_corners, settings.color_close_corners)
	local gridColor = interpolateColor(settings.color_far_grid, settings.color_close_grid)	
    
    drawPointGrid(pass, settings.points, cornerColor, gridColor)
end

function lovr.draw(pass)
	mode(pass)
end