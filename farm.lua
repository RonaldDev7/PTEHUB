-- VARIABLES
local Workspace = game:GetService("Workspace")
local FarmeablesFolder = Workspace:WaitForChild("Farmeables")
local MyPetsFolder = Workspace:WaitForChild("MyPets")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("NetworkEvents")
local SetPetsTasks = Network:WaitForChild("SET_PETS_TASKS")

local AUTO_FARM = true
local FARM_DELAY = 12

local TARGET_PRIORITY = {
    "Crystal01",
    "roca",
    "arbusto"
}

print("pepe9")
-- AREA DE FARMEO (EDITA ESTOS VALORES)
local AREA_MIN = Vector3.new(1055.5316, 0, 4464.6293)
local AREA_MAX = Vector3.new(-48, 0, 5332.3471)

-- LISTA DE PETS Y VARIABLES

local PET_IDS = {
    "345965",
    "345966",
    "346042",
    "345969",
    "345968",
    "345967"
}

-- TRACKING
local PetAssignments = {}   -- petId -> targetId
local BusyTargets = {}      -- targetId -> petId

-- PAYLOAD
local function buildFarmPayload(targetId)
    local payload = {}

    for _, petId in ipairs(PET_IDS) do
        payload[petId] = {
            task = "farm",
            target_id = tostring(targetId)
        }
    end

    return payload
end


-- CONTROLAR REMOTE
local function sendPetsToFarm(targetId)
    local data = buildFarmPayload(targetId)
    SetPetsTasks:FireServer(data)
end

-- OBTENER FARMEABLES DISPONIBLES
local function getAvailableFarmables()
    local list = {}

    for _, obj in ipairs(FarmeablesFolder:GetChildren()) do
        if obj:IsA("Model") then
            table.insert(list, obj.Name)
        end
    end

    return list
end

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function getFarmableType(model)
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("MeshPart") then
            for _, typeName in ipairs(TARGET_PRIORITY) do
                if obj.Name == typeName then
                    return typeName
                end
            end
        end
    end
    return nil
end

local function isInsideArea(pos)
    return pos.X >= math.min(AREA_MIN.X, AREA_MAX.X)
        and pos.X <= math.max(AREA_MIN.X, AREA_MAX.X)
        and pos.Z >= math.min(AREA_MIN.Z, AREA_MAX.Z)
        and pos.Z <= math.max(AREA_MIN.Z, AREA_MAX.Z)
end

local function getPetPosition(petId)
    for _, pet in ipairs(MyPetsFolder:GetChildren()) do
        if pet.PrimaryPart then
            return pet.PrimaryPart.Position
        end
    end
    return nil
end

local function getBestFarmableForPet(petId)
    local petPos = getPetPosition(petId)
    if not petPos then return nil end

    -- recorrer por PRIORIDAD DE TIPO
    for _, priorityType in ipairs(TARGET_PRIORITY) do
        local closest
        local shortest = math.huge

        for _, model in ipairs(FarmeablesFolder:GetChildren()) do
            if not model:IsA("Model") or not model.PrimaryPart then continue end
            if BusyTargets[model.Name] then continue end
            if not isInsideArea(model.PrimaryPart.Position) then continue end

            local farmType = getFarmableType(model)
            if farmType ~= priorityType then continue end

            local dist = (model.PrimaryPart.Position - petPos).Magnitude
            if dist < shortest then
                shortest = dist
                closest = model
            end
        end

        -- si encontró uno de este tipo, YA NO BUSCA MÁS
        if closest then
            return closest
        end
    end

    return nil
end

local function getClosestFreeFarmableForPet()
    local hrp = getHRP()
    local closest
    local shortest = math.huge

    for _, model in ipairs(FarmeablesFolder:GetChildren()) do
        if model:IsA("Model") and model.PrimaryPart then

            if not getFarmableType(model) then continue end
            if not isInsideArea(model.PrimaryPart.Position) then continue end
            if BusyTargets[model.Name] then continue end

            local dist = (model.PrimaryPart.Position - hrp.Position).Magnitude
            if dist < shortest then
                shortest = dist
                closest = model
            end
        end
    end

    return closest
end

local function farmableExists(targetId)
    return FarmeablesFolder:FindFirstChild(tostring(targetId)) ~= nil
end

local function getFreeFarmables()
    local list = {}

    for _, model in ipairs(FarmeablesFolder:GetChildren()) do
        if model:IsA("Model") and model.PrimaryPart then
            if not getFarmableType(model) then
                continue
            end

            if not isInsideArea(model.PrimaryPart.Position) then
                continue
            end

            if not BusyTargets[model.Name] then
                table.insert(list, model)
            end
        end
    end

    return list
end

local function getClosestFreeFarmable()
    local hrp = getHRP()
    local closest
    local shortest = math.huge

    for _, model in ipairs(FarmeablesFolder:GetChildren()) do
        if model:IsA("Model") and model.PrimaryPart then

            -- tipo correcto
            if not getFarmableType(model) then
                continue
            end

            -- dentro del área
            if not isInsideArea(model.PrimaryPart.Position) then
                continue
            end

            -- que no esté ocupado
            if BusyTargets[model.Name] then
                continue
            end

            local dist = (model.PrimaryPart.Position - hrp.Position).Magnitude
            if dist < shortest then
                shortest = dist
                closest = model
            end
        end
    end

    return closest
end

local function assignPetToFarmable(petId, model)
    PetAssignments[petId] = model.Name
    BusyTargets[model.Name] = petId

    local payload = {
        [petId] = {
            task = "farm",
            target_id = model.Name
        }
    }

    SetPetsTasks:FireServer(payload)
end

local function watchFarmable(petId, targetId)
    task.spawn(function()
        while AUTO_FARM and farmableExists(targetId) do
            task.wait()
        end

        -- liberar target
        BusyTargets[targetId] = nil
        PetAssignments[petId] = nil

        -- ASIGNAR NUEVO TARGET INMEDIATO
        task.wait() -- 1 frame
    end)
end

-- LOOP
task.spawn(function()
    while true do
        if not AUTO_FARM then
            task.wait()
            continue
        end

        local freeFarmables = getFreeFarmables()

        for _, pet in ipairs(MyPetsFolder:GetChildren()) do
            local petId = pet.Name
            if not PetAssignments[petId] then
                local target = getBestFarmableForPet(petId)
                if target then
                    assignPetToFarmable(petId, target)
                    watchFarmable(petId, target.Name)
                end
            end
        end


        task.wait()
    end
end)

