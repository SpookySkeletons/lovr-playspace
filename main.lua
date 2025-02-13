-- Bootstrap
appName = "lovr-playspace"

-- App
hands = {"hand/right","hand/left"}
limbs = {
	"head",
	"hand/left",
	"hand/right",
	"hand/left/grip",
	"hand/right/grip",
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
json = require('json/json')

function userConfig(fileName)
	return configDirs[1] .. "/" ..fileName
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
    
    -- Default settings
    local defaults = {
        action_button = "trigger",
        check_density = 0.05,
        fade_start = 0.5,
        fade_stop = 2.0,
        grid_density = 1.0,
        grid_bottom = 0.0,
        grid_top = 3,
        color_close_corners = {0.45, 0.69, 0.79, 1.0},
        color_close_grid = {0.45, 0.69, 0.79, 0.5},
        color_far_corners = {0.45, 0.69, 0.79, 0},
        color_far_grid = {0.45, 0.69, 0.79, 0},
        points = {}
    }

    -- Helper function to read file with fallback to default
	local function loadSetting(filename, default, parser)
		print("Checking file:", filename)
		
		if not lovr.filesystem.isFile(filename) then
			print("File doesn't exist, creating:", filename)
			local valueToSave
			if type(default) == "table" then
				valueToSave = json.encode(default)
			else
				valueToSave = tostring(default)
			end
			
			local success = lovr.filesystem.write(filename, valueToSave)
			print("Write success:", success, "for", filename, "with value:", valueToSave)
			return default
		end
		
		-- File exists, try to read it
		local content = lovr.filesystem.read(filename)
		if content and parser then
			local success, value = pcall(parser, content)
			if success then return value end
		elseif content then
			return content
		end
		
		return default
	end

    -- Initialize settings with fallbacks
    settings = {
        action_button = loadSetting("action_button.txt", defaults.action_button),
        check_density = loadSetting("check_density.txt", defaults.check_density, tonumber),
        fade_start = loadSetting("fade_start.txt", defaults.fade_start, tonumber),
        fade_stop = loadSetting("fade_stop.txt", defaults.fade_stop, tonumber),
        grid_density = loadSetting("grid_density.txt", defaults.grid_density, tonumber),
        grid_bottom = loadSetting("grid_bottom.txt", defaults.grid_bottom, tonumber),
        grid_top = loadSetting("grid_top.txt", defaults.grid_top, tonumber),
        color_close_corners = loadSetting("color_close_corners.json", defaults.color_close_corners, json.decode),
        color_close_grid = loadSetting("color_close_grid.json", defaults.color_close_grid, json.decode),
        color_far_corners = loadSetting("color_far_corners.json", defaults.color_far_corners, json.decode),
        color_far_grid = loadSetting("color_far_grid.json", defaults.color_far_grid, json.decode),
        points = {}
    }

    -- Handle points.json
    local pointsPath = "points.json"
    if not lovr.filesystem.isFile(pointsPath) then
        initConfigure()
        return
    end

    -- Check for action button press
    for _, hand in ipairs(hands) do
        if lovr.headset.isDown(hand, settings.action_button) then
            initConfigure()
            return
        end
    end

    -- Load points if we haven't returned already
    local pointsContent = lovr.filesystem.read(pointsPath)
    if pointsContent then
        settings.points = json.decode(pointsContent)
    end
    
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
    local hx, hy, hz = lovr.headset.getPosition("head")
    
    for _, hand in ipairs(hands) do
        if isTracked(hand) then
            local cx, cy, cz = lovr.headset.getPosition(hand)
            
            -- Compute the direction from the controller to the headset
            local dirX = hx - cx
            local dirY = hy - cy
            local dirZ = hz - cz

            -- Compute the rotation angle to make the text face the headset
            local angle = math.atan2(dirX, dirZ)

            pass:setColor(1, 0, 0, 0.5 * saveProg)
            pass:sphere(cx, cy, cz, 0.1)
            pass:setColor(1, 1, 1, saveProg)
            
            -- Draw the text with the computed rotation
            pass:text(
                "- Press '" .. settings.action_button .. "' to add a point -\n" ..
                "- Hold '" .. settings.action_button .. "' to save -\n\n" ..
                string.format("%.2f", cx) .. "," .. string.format("%.2f", cy) .. "," .. string.format("%.2f", cz),
                cx, cy - 0.3, cz, 0.066, angle, 0, 1, 0
            )
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
			lovr.filesystem.write("config/points.json", json.encode(settings.points))
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
    local hx, hy, hz = lovr.headset.getPosition("head")

    -- Calculate the distance from the head to the perimeter
    local perimeterDistHead = getClosestDistanceToPerimeter(hx, hy, hz, settings.points)

    -- Check distance from each hand to the perimeter
    local handDistances = {perimeterDistHead}
    for _, hand in ipairs(hands) do
        if isTracked(hand) then
            local handX, handY, handZ = lovr.headset.getPosition(hand)
            local dist = getClosestDistanceToPerimeter(handX, handY, handZ, settings.points)
            table.insert(handDistances, dist)
        end
    end

    -- Take the minimum of the distances for the fade logic
    local closestDist = math.min(unpack(handDistances))

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
