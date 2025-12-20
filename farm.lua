-- VARIABLES
local Workspace = game:GetService("Workspace")
local FarmeablesFolder = Workspace:WaitForChild("Farmeables")
local MyPetsFolder = Workspace:WaitForChild("MyPets")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("NetworkEvents")
local SetPetsTasks = Network:WaitForChild("SET_PETS_TASKS")

local AUTO_FARM = true
local FARM_DELAY = 12

local TARGET_TYPE = "arbusto" -- coins / chest / arbusto

-- AREA DE FARMEO (EDITA ESTOS VALORES)
local AREA_MIN = Vector3.new(823.2489, 0, 4504.2797)
local AREA_MAX = Vector3.new(29.9689, 0, 5258.977)

-- LISTA DE PETS Y VARIABLES

local PET_IDS = {
    "7183",
    "7606",
    "7605",
    "7090",
    "6980",
    "7607"
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

local function getPetPositionByIndex(index)
    local petModel = MyPetsFolder:GetChildren()[index]
    if not petModel then return nil end

    local centerAttachment = petModel:FindFirstChild("Center", true)
    if centerAttachment and centerAttachment:IsA("Attachment") then
        return centerAttachment.WorldPosition
    end

    return nil
end

local function farmableHasType(model, typeName)
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("MeshPart") and obj.Name == typeName then
            return true
        end
    end
    return false
end

local function isInsideArea(pos)
    return pos.X >= math.min(AREA_MIN.X, AREA_MAX.X)
        and pos.X <= math.max(AREA_MIN.X, AREA_MAX.X)
        and pos.Z >= math.min(AREA_MIN.Z, AREA_MAX.Z)
        and pos.Z <= math.max(AREA_MIN.Z, AREA_MAX.Z)
end

local function getClosestFreeFarmableForPet(petId)
    local petPos = getPetPositionByIndex(table.find(PET_IDS, petId))
    if not petPos then return nil end

    local closest
    local shortest = math.huge

    for _, model in ipairs(FarmeablesFolder:GetChildren()) do
        if model:IsA("Model") and model.PrimaryPart then

            -- tipo correcto
            if not farmableHasType(model, TARGET_TYPE) then
                continue
            end

            -- dentro del área
            if not isInsideArea(model.PrimaryPart.Position) then
                continue
            end

            -- libre
            if BusyTargets[model.Name] then
                continue
            end

            local dist = (model.PrimaryPart.Position - petPos).Magnitude
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
            if not farmableHasType(model, TARGET_TYPE) then
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
            if not farmableHasType(model, TARGET_TYPE) then
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
            task.wait(0.4)
        end

        -- Liberar
        BusyTargets[targetId] = nil
        PetAssignments[petId] = nil
    end)
end

-- LOOP
task.spawn(function()
    while true do
        if not AUTO_FARM then
            task.wait(0.5)
            continue
        end

        local freeFarmables = getFreeFarmables()

        for _, petId in ipairs(PET_IDS) do
            if not PetAssignments[petId] then
                local target = getClosestFreeFarmableForPet(petId)
                if target then
                    assignPetToFarmable(petId, target)
                    watchFarmable(petId, target.Name)
                end
            end
        end


        task.wait(0.5)
    end
end)
