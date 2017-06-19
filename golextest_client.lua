local contextMenu = {}

-- config
contextMenu.scanDistance = 10.0
contextMenu.controlNum = 217 -- caps lock

contextMenu.open = false
contextMenu.scanning = false
contextMenu.focusCam = nil
contextMenu.focusEntity = nil

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

local function spawnCar(spawnPoint)
	Citizen.Trace('test spawn car')

	local playerPed = GetPlayerPed(-1)
	local playerCoords = GetEntityCoords(playerPed)
	local carModel = 'banshee'
	local carHash = GetHashKey(carModel)

	Citizen.Trace(carHash)
	Citizen.Trace(playerPed)
	Citizen.Trace(playerCoords)
	--Citizen.Trace(spawnPoint)

	RequestModel(carHash)
	while not HasModelLoaded(carHash) do
		Citizen.Wait(0)
	end

    playerCar = CreateVehicle(carHash, playerCoords, 0.0, true, false)
	SetVehicleNumberPlateText(playerCar, 'GoleX')
	SetVehicleOnGroundProperly(playerCar)
	SetVehicleHasBeenOwnedByPlayer(playerCar,true)
  	SetPedIntoVehicle(playerPed, playerCar, -1)

end

AddEventHandler('playerSpawned', function(spawnPoint)

	Citizen.Trace('test trace 2')
	spawnCar(spawnPoint)
end)

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

Citizen.CreateThread(function()
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

			while contextMenu.open do
	    		if IsControlJustPressed(1, contextMenu.controlNum) then
	    			contextMenu.open = false
	    		end
				Wait(0)
			end

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
					local entityCoords = GetEntityCoords(entity)
					drawTxt(0.55,0.1,0.185,0.206, 0.40, 'Entity found: ' .. entity .. ' @ ' .. entityCoords, 255,255,255,255)
					DrawMarker(2, entityCoords.x, entityCoords.y, entityCoords.z+1.5, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 128, 0, 200, true, true, 2, false, nil, nil, false)
					--[[
					if not camVisible then
						RenderScriptCams(true, true, 1000, 1, 0)
						camVisible = true
					end
					]]
					lastValidEntity = entity
				else
					lastValidEntity = nil
				end                 

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