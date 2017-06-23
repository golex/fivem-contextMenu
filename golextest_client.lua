local contextMenu = {}

-- config
contextMenu.scanDistance = 10.0
contextMenu.controlNum = 217 -- caps lock

-- enum
contextMenu.entityTypes = {}
contextMenu.entityTypes.vehicle = 0
contextMenu.entityTypes.ped = 1
contextMenu.entityTypes.player = 2
contextMenu.entityTypes.all = 3

-- meta
contextMenu.open = false
contextMenu.scanning = false
contextMenu.focusCam = nil
contextMenu.focusEntity = nil
contextMenu.buttons = {}
contextMenu.orderedSections = {}

-- for testing
contextMenu.pedIsCuffed = false
contextMenu.vehIsLocked = false


local function drawTxt(x,y ,width,height,scale, text, r,g,b,a)
    SetTextFont(0)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextDropShadow(0, 0, 0, 0,255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x - width/2, y - height/2 + 0.005)
end

local function drawMarker(entity)
	local entityCoords = GetEntityCoords(entity)
	DrawMarker(2, entityCoords.x, entityCoords.y, entityCoords.z+1.5, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 128, 0, 200, true, true, 2, false, nil, nil, false)
end

local function getEntityType(entity)
	local typeString = "Nothing"
	if IsEntityAPed(entity) then
		if IsPedAPlayer(entity) then
			typeString = "Player"
		else
			typeString = "Pedestrian"
		end
	elseif IsEntityAVehicle(entity) then
		typeString = "Vehicle"
	end
	return typeString
end

-- returns entity looked at by this client's gameplay camera, if any
local function getCurrentTargetEntity()
	local ped = GetPlayerPed(-1)
    local playerCoords = GetEntityCoords(ped)
    local camCoords = GetGameplayCamCoord()
    local dist = contextMenu.scanDistance

    -- get gameplay camera forward vector
    local rot = GetGameplayCamRot(0)
    local dirX = -Sin(rot.z)
    local dirY = Cos(rot.z)
    local dirZ = Sin(rot.x)

    -- normalize
    local mag = Vmag(dirX, dirY, dirZ)
    dirX = dirX / mag
    dirY = dirY / mag
    dirZ = dirZ / mag

	-- start ray cast from where camera ray intersects with player so we don't target stuff behind player ped
	local cameraDist = Vdist(playerCoords.x, playerCoords.y, playerCoords.z, camCoords.x, camCoords.y, camCoords.z) * 0.95

	-- need to figure out if there are some vector math helpers...
	local startCoordsX = camCoords.x + dirX * cameraDist
	local startCoordsY = camCoords.y + dirY * cameraDist
	local startCoordsZ = camCoords.z + dirZ * cameraDist
	local checkCoordsX = startCoordsX + dirX * dist
	local checkCoordsY = startCoordsY + dirY * dist
	local checkCoordsZ = startCoordsZ + dirZ * dist

	--[[
	drawTxt(0.55,0.14,0.185,0.206, 0.40, camCoords, 255,255,255,255)
	drawTxt(0.55,0.18,0.185,0.206, 0.40, 'vector3('..dirX..','..dirY..','..dirZ..')', 255,255,255,255)
	drawTxt(0.55,0.22,0.185,0.206, 0.40, 'vector3('..checkCoordsX..','..checkCoordsY..','..checkCoordsZ..')', 255,255,255,255)

	DrawLine(startCoordsX, startCoordsY, startCoordsZ, checkCoordsX, checkCoordsY, checkCoordsZ, 255, 0, 0, 255)
	]]

	-- this would ideally be a cone/frustrum, if it feels too finnicky could approximate one with a couple of cascading capsule/box checks
    local rayHandle = StartShapeTestCapsule(startCoordsX, startCoordsY, startCoordsZ, checkCoordsX, checkCoordsY, checkCoordsZ, 0.75, 14, ped, 0)
    local _, _, _, _, entityHandle = GetRaycastResult(rayHandle)

    return entityHandle
end

-- UI
local function populateContextMenu()
	-- this method will go through the list of buttons and find all relevant ones and sent it to the UI in an event
	local sortedButtons = {}

	for i, button in ipairs(contextMenu.buttons) do
		local visible = true

		-- check entity type
		local validEntity = true
		if( button.entityType ~= contextMenu.entityTypes.all) then
			if( IsEntityAVehicle(contextMenu.focusEntity) and button.entityType ~= contextMenu.entityTypes.vehicle) then
				validEntity = false
			end
			if( IsEntityAPed(contextMenu.focusEntity) and button.entityType ~= contextMenu.entityTypes.ped) then
				validEntity = false
			end
			if( IsPedAPlayer(contextMenu.focusEntity) and button.entityType ~= contextMenu.entityTypes.player) then
				validEntity = false
			end
		end
		visible = visible and validEntity

		-- check visiblecallback
		if visible and button.visibleCallback ~= nil then
			visible = button.visibleCallback(contextMenu.focusEntity)
		end

		-- add to sorted list
		if visible then
			if sortedButtons[button.section] == nil then
				sortedButtons[button.section] = {}
			end
			table.insert(sortedButtons[button.section], button)
		end
 	end

    SendNUIMessage({
    	type = 'contextMenu',
        command = 'clear'
    })

    -- add sections of buttons based on the order they were added initially
	for i, section in ipairs(contextMenu.orderedSections) do
		local buttons = sortedButtons[section]
		if buttons ~= nil then
		    SendNUIMessage({
		    	type = 'contextMenu',
		        command = 'addSection',
		        title = section
		    })

			for _, button in ipairs(buttons) do
			    SendNUIMessage({
			    	type = 'contextMenu',
			        command = 'addButton',
			        title = button.title,
			        icon = button.icon,
			        delay = button.delay,
			        id = button.id
			    })
			end
		end
	end
end

local function openContextMenu()
	local typeString = getEntityType(contextMenu.focusEntity)
	local name = "Local"
	if IsEntityAVehicle(contextMenu.focusEntity) then
		local vehModel = GetEntityModel(contextMenu.focusEntity)
		local vehModelName = GetDisplayNameFromVehicleModel(vehModel)
		name = GetLabelText(vehModelName)
	elseif IsPedAPlayer(contextMenu.focusEntity) then
		name = "Player"
	end
    SendNUIMessage({
    	type = 'contextMenu',
        command = 'open',
        title = name,
        subtitle = typeString,
    })
	SetNuiFocus(true)
end

local function closeContextMenu()
    SendNUIMessage({
    	type = 'contextMenu',
        command = 'close'
    })
	SetNuiFocus(false)
end

local function handleMouseInput()
    DisableControlAction(0, 1, contextMenu.open) -- LookLeftRight
    DisableControlAction(0, 2, contextMenu.open) -- LookUpDown
    DisableControlAction(0, 142, contextMenu.open) -- MeleeAttackAlternate
    DisableControlAction(0, 106, contextMenu.open) -- VehicleMouseControlOverride

    if IsDisabledControlJustReleased(0, 142) then -- MeleeAttackAlternate
        SendNUIMessage({
    		type = 'contextMenu',
            command = "click"
        })
    end
end

RegisterNUICallback('closeContextMenu', function(data, cb)
    contextMenu.open = false

    cb('ok')
end)

RegisterNUICallback('contextMenuButtonClicked', function(data, cb)
    Citizen.Trace('button clicked ' .. data.id)
    
    -- trigger callback
    local button = contextMenu.buttons[data.id]
    if button ~= nil then
    	button.clickedCallback(contextMenu.focusEntity)
    end

    -- refresh UI
    populateContextMenu()

    cb('ok')
end)

-- exports
function addContextMenuButton(title, icon, section, entityType, clickedCallback, visibleCallback)
	local button = {}
	button.title = title
	button.icon = icon
	button.section = section
	button.entityType = entityType
	button.clickedCallback = clickedCallback
	button.visibleCallback = visibleCallback
	button.delay = 0.4
	button.id = #contextMenu.buttons + 1
	table.insert(contextMenu.buttons, button)

	-- add section to list if needed
	local newSection = true
	for _, s in ipairs(contextMenu.orderedSections) do
		if s == section then
			newSection = false
		end
	end
	if newSection then
		table.insert(contextMenu.orderedSections, section)
	end
end

-- main thread
Citizen.CreateThread(function()
	SetNuiFocus(false)

	-- demo buttons
	addContextMenuButton("Cuff", "cuff.png", "Cop", contextMenu.entityTypes.ped, 
		function(_) 
			contextMenu.pedIsCuffed = true
		end, 
		function(_) 
			return not contextMenu.pedIsCuffed 
		end)
	addContextMenuButton("Uncuff", "cuff.png", "Cop", contextMenu.entityTypes.ped, 
		function(_)
			contextMenu.pedIsCuffed = false
		end, 
		function(_) 
			return contextMenu.pedIsCuffed 
		end)
	addContextMenuButton("Retrieve ID", "star.png", "Cop", contextMenu.entityTypes.ped, function() end,  
		function(_) 
			return contextMenu.pedIsCuffed 
		end)
	addContextMenuButton("Search", "star.png", "Cop", contextMenu.entityTypes.ped, function() end,  
		function(_) 
			return contextMenu.pedIsCuffed 
		end)
	addContextMenuButton("Escort", "star.png", "Cop", contextMenu.entityTypes.ped, function() end,  
		function(_) 
			return contextMenu.pedIsCuffed 
		end)
	addContextMenuButton("Arrest", "star.png", "Cop", contextMenu.entityTypes.ped, function() end,  
		function(_) 
			return contextMenu.pedIsCuffed 
		end)
	addContextMenuButton("Frisk", "star.png", "Cop", contextMenu.entityTypes.ped, function() end, nil)
	addContextMenuButton("Impound", "cuff.png", "Cop", contextMenu.entityTypes.vehicle, function() end, nil)

	addContextMenuButton("Lock", "exclamation.png", "Misc", contextMenu.entityTypes.vehicle, 
		function(_)
			contextMenu.vehIsLocked = true
	 	end,  
		function(_) 
			return not contextMenu.vehIsLocked 
		end)
	addContextMenuButton("Unlock", "exclamation.png", "Misc", contextMenu.entityTypes.vehicle, 
		function(_) 
			contextMenu.vehIsLocked = false
		end,  
		function(_) 
			return contextMenu.vehIsLocked 
		end)
	addContextMenuButton("Repair", "exclamation.png", "Misc", contextMenu.entityTypes.vehicle, function() end, nil)
	addContextMenuButton("Emote", "exclamation.png", "Misc", contextMenu.entityTypes.all, function() end, nil)

	while true do
		Wait(0)

    	if contextMenu.open then
			local ped = GetPlayerPed(-1)

    		-- create focus camera
			contextMenu.focusCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
			AttachCamToEntity(contextMenu.focusCam, ped, 0.0, 0.0, 1.0, true)
			SetCamRot(contextMenu.focusCam, 0, 0, 0)
			SetCamFov(contextMenu.focusCam, GetGameplayCamFov() + 10)
			PointCamAtEntity(contextMenu.focusCam, contextMenu.focusEntity, 0.0, 0.0, 0.0, true);
			RenderScriptCams(true, true, 700, 1, 0)

    		Citizen.Trace('OPEN MENU')

			-- open UI
			populateContextMenu()
			openContextMenu()

			while contextMenu.open do
				drawMarker(contextMenu.focusEntity)
	            handleMouseInput()
	    		if IsControlJustPressed(1, contextMenu.controlNum) then
	    			contextMenu.open = false
	    		end
				Wait(0)
			end

    		Citizen.Trace('CLOSE MENU')

			-- close UI
			closeContextMenu()

			-- tear down focus camera
			RenderScriptCams(false, true, 200, 1, 0)
			DestroyCam(contextMenu.focusCam, false)
			contextMenu.focusCam = nil
    	elseif contextMenu.scanning then
    		-- init scanning
    		contextMenu.focusEntity = nil
    		local lastValidEntity = nil
			while IsControlPressed(1, contextMenu.controlNum) do
				-- find entity
				local entity = getCurrentTargetEntity()
				if DoesEntityExist(entity) then
					--Citizen.Trace(entity)
					drawMarker(entity)
					lastValidEntity = entity
				else
					lastValidEntity = nil
				end             
				drawTxt(0.48,0.1,0.185,0.206, 0.35, 'Interact with: ' .. getEntityType(entity), 255,255,255,255)    

				Wait(0)
		   	end

		   	contextMenu.scanning = false
		   	if DoesEntityExist(lastValidEntity) then
		   		contextMenu.focusEntity = lastValidEntity
		   		contextMenu.open = true
		   	end
    	else
    		if IsControlJustPressed(1, contextMenu.controlNum) then
    			Citizen.Trace('START SCAN')
    			contextMenu.scanning = true
    		end
    	end
	 end  
end)