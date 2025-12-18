-- SERVICES
--========================
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local Network = ReplicatedStorage:WaitForChild("NetworkEvents")
local PurchasePetball = Network:WaitForChild("PURCHASE_PETBALL")

local ClientHeartbeat = player:FindFirstChild("ClientHeartbeat")

--========================
-- GUI PARENT SAFE
--========================
local parentGui = CoreGui
pcall(function()
	if gethui then parentGui = gethui() end
end)

pcall(function()
	parentGui.PetTrainerHub:Destroy()
end)

--========================
-- CONFIG
--========================
local AUTO_OPEN = false
local BUY_DELAY = 3
local OPEN_AMOUNT = 1-- cantidad de petballs a abrir por ciclo

local PETBALLS = {
	["Outer Village"]     = 0,
	["Autumnal Park"]     = 1,
	["Greenleaf Town"]    = 2,
	["Haunted Graveyard"] = 3,
	["Capital City"]      = 4
}

local selectedPetballName = "Outer Village"
local selectedPetballId = PETBALLS[selectedPetballName]

-- AUTO FARM CONFIG
local AUTO_FARM = false
local FARM_DELAY = 12

local Workspace = game:GetService("Workspace")
local FarmeablesFolder = Workspace:WaitForChild("Farmeables")

local SetPetsTasks = Network:WaitForChild("SET_PETS_TASKS")

local PET_IDS = {
	"7183","7606","7605","7090","6980","7607"
}

--========================
-- THEME
--========================
local THEME = {
	BG = Color3.fromRGB(54, 19, 84),        -- #361354
	PANEL = Color3.fromRGB(32, 8, 46),      -- #20082E
	BUTTON = Color3.fromRGB(21, 19, 84),    -- #151354
	ACCENT = Color3.fromRGB(137, 31, 194),  -- #891FC2

	ACTIVE = Color3.fromRGB(88, 194, 31),   -- #58C21F
	INACTIVE = Color3.fromRGB(158, 27, 52), -- #9E1B34

	TEXT = Color3.fromRGB(240, 240, 240),
	SUBTEXT = Color3.fromRGB(200, 200, 200),

	-- SIDEBAR (PALETA PERSONALIZADA)
	SIDEBAR_IDLE   = Color3.fromRGB(32, 8, 46),   -- #20082E
	SIDEBAR_HOVER  = Color3.fromRGB(54, 19, 84),  -- #361354
	SIDEBAR_ACTIVE = Color3.fromRGB(137, 31, 194) -- #891FC2


}

local function applyTheme()
	-- Sidebar buttons
	teleportTab.BackgroundColor3 = THEME.SIDEBAR_IDLE
	autoTab.BackgroundColor3 = THEME.SIDEBAR_IDLE
	autoBuyTab.BackgroundColor3 = THEME.SIDEBAR_IDLE

	-- Toggles
	autoToggle.BackgroundColor3 = AUTO_OPEN and THEME.ACTIVE or THEME.INACTIVE
	autoBuyToggle.BackgroundColor3 = AUTO_BUY and THEME.ACTIVE or THEME.INACTIVE

	-- Status dots
	autoDot.BackgroundColor3 = autoEnabled and THEME.ACTIVE or THEME.INACTIVE
	autoBuyDot.BackgroundColor3 = autoBuyEnabled and THEME.ACTIVE or THEME.INACTIVE
end

--========================
-- TELEPORTS
--========================
local Teleports = {
	Capital = CFrame.new(1129.5,91.2,-465.7),
	Autumn = CFrame.new(719.4,82.4,12.8),
	Tienda = CFrame.new(79.4,83.0,122.2),
	Pueblo = CFrame.new(672.4,82.7,-322.3),
	Cementerio = CFrame.new(737.9,82.8,-745.2)
}

local function getHRP()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("HumanoidRootPart")
end

--========================
-- FORCE PET ENTITY REFRESH (CRÍTICO)
--========================
local function ForcePetEntityRefresh()
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local original = hrp.CFrame

	-- micro re-stream (no visible)
	hrp.CFrame = original + Vector3.new(0, 0.15, 0)
	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()
	hrp.CFrame = original
end
--========================
-- DRAG FUNCTION
--========================
local function makeDraggable(obj)
	local dragging, dragStart, startPos

	obj.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = i.Position
			startPos = obj.Position
		end
	end)

	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
		or i.UserInputType == Enum.UserInputType.Touch) then
			local delta = i.Position - dragStart
			obj.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

--========================
-- TWEEN HELPER
--========================
local function tween(obj, props, time)
	TweenService:Create(
		obj,
		TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

--========================
-- HOVER FX
--========================
local function addHover(btn, normal, hover)
	btn.MouseEnter:Connect(function()
		tween(btn, {BackgroundColor3 = hover}, 0.12)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, {BackgroundColor3 = normal}, 0.12)
	end)
end

--========================
-- UI SHADOW
--========================
local function addShadow(parent, transparency)
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 2)
	shadow.Size = UDim2.new(1, 24, 1, 24)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://1316045217"
	shadow.ImageTransparency = transparency or 0.65
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 118, 118)
	shadow.Parent = parent
end

--========================
-- UI HOVER EFFECT
--========================
local function applyHover(button, normalColor, hoverColor)
	button.MouseEnter:Connect(function()
		tweenColor(button, hoverColor)
	end)

	button.MouseLeave:Connect(function()
		tweenColor(button, normalColor)
	end)
end

--========================
-- UI TWEEN COLOR
--========================
local function tweenColor(obj, targetColor, speed)
	local tween = TweenService:Create(
		obj,
		TweenInfo.new(speed or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundColor3 = targetColor}
	)
	tween:Play()
end

--========================
-- DOT PULSE EFFECT
--========================
local function pulseDot(dot)
	task.spawn(function()
		while dot:GetAttribute("Active") do
			tween(dot, {Size = UDim2.new(0,12,0,12)}, 0.25)
			task.wait(0.25)
			tween(dot, {Size = UDim2.new(0,10,0,10)}, 0.25)
			task.wait(0.25)
		end
	end)
end

--========================
-- GUI ROOT
--========================
local gui = Instance.new("ScreenGui", parentGui)
gui.Name = "PetTrainerHub"
gui.ResetOnSpawn = false

--========================
-- TOGGLE BUTTON (≡)
--========================
local toggleBtn = Instance.new("TextButton", gui)
toggleBtn.Size = UDim2.new(0,40,0,40)
toggleBtn.Position = UDim2.new(0,15,0.5,-20)
toggleBtn.Text = "≡"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 20
toggleBtn.TextColor3 = Color3.new(1,1,1)
toggleBtn.BackgroundColor3 = Color3.fromRGB(25,25,25)
toggleBtn.BorderSizePixel = 0
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,10)

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Parent = toggleBtn
toggleStroke.Thickness = 1
toggleStroke.Color = Color3.fromRGB(65,65,65)

makeDraggable(toggleBtn)

--========================
-- MAIN FRAME
--========================
local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0,430,0,310)
main.Position = UDim2.new(0.5,-215,0.5,-155)
main.BackgroundColor3 = THEME.BG
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0,14)

makeDraggable(main)
addShadow(main, 0.6)

-- Border suave main
local mainStroke = Instance.new("UIStroke")
mainStroke.Parent = main
mainStroke.Thickness = 1
mainStroke.Color = Color3.fromRGB(55,55,55)

toggleBtn.MouseButton1Click:Connect(function()
	if main.Visible then
		tween(main, {Size = UDim2.new(0,430,0,0)}, 0.18)
		task.delay(0.18, function()
			main.Visible = false
		end)
	else
		main.Size = UDim2.new(0,430,0,0)
		main.Visible = true
		tween(main, {Size = UDim2.new(0,430,0,310)}, 0.22)
	end
end)

--========================
-- SIDEBAR
--========================
local sidebar = Instance.new("Frame", main)
sidebar.Size = UDim2.new(0,120,1,0)
sidebar.BackgroundColor3 = THEME.PANEL
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0,14)

local function sidebarButton(text, y)
	local b = Instance.new("TextButton", sidebar)
	b.Size = UDim2.new(1,-10,0,38)
	b.Position = UDim2.new(0,5,0,y)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.new(1,1,1)
	b.BackgroundColor3 = THEME.SIDEBAR_IDLE
	b.BorderSizePixel = 0
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)

	b.MouseEnter:Connect(function()
		if currentTab ~= b then
			tweenColor(b, THEME.SIDEBAR_HOVER)
		end
	end)

	b.MouseLeave:Connect(function()
		if currentTab ~= b then
			tweenColor(b, THEME.SIDEBAR_IDLE)
		end
	end)

	return b
end

local teleportTab = sidebarButton("Teleport", 12)
local autoTab = sidebarButton("Auto Open", 58)
local autoBuyTab = sidebarButton("Auto Buy", 104)
local autoFarmTab = sidebarButton("Auto Farm", 150)
local currentTab = teleportTab

local function setActiveTab(active)
	currentTab = active

	for _,btn in pairs({teleportTab, autoTab, autoBuyTab, autoFarmTab}) do
		btn.BackgroundColor3 = THEME.SIDEBAR_IDLE
	end
	active.BackgroundColor3 = THEME.SIDEBAR_ACTIVE
end

setActiveTab(teleportTab)

--========================
-- CONTENT FRAMES
--========================
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1,-130,1,-10)
content.Position = UDim2.new(0,125,0,5)
content.BackgroundTransparency = 1

local teleportFrame = Instance.new("Frame", content)
teleportFrame.Size = UDim2.new(1,0,1,0)
teleportFrame.BackgroundTransparency = 1

local autoFrame = Instance.new("Frame", content)
autoFrame.Size = UDim2.new(1,0,1,0)
autoFrame.BackgroundTransparency = 1
autoFrame.Visible = false

local autoBuyFrame = Instance.new("Frame", content)
autoBuyFrame.Size = UDim2.new(1,0,1,0)
autoBuyFrame.BackgroundTransparency = 1
autoBuyFrame.Visible = false

local autoFarmFrame = Instance.new("Frame", content)
autoFarmFrame.Size = UDim2.new(1,0,1,0)
autoFarmFrame.BackgroundTransparency = 1
autoFarmFrame.Visible = false

teleportTab.MouseButton1Click:Connect(function()
	setActiveTab(teleportTab)
	teleportFrame.Visible = true
	autoFrame.Visible = false
	autoBuyFrame.Visible = false
	autoFarmFrame.Visible = false

	applyTheme()
end)

autoTab.MouseButton1Click:Connect(function()
	setActiveTab(autoTab)
	teleportFrame.Visible = false
	autoFrame.Visible = true
	autoBuyFrame.Visible = false
	autoFarmFrame.Visible = false

	applyTheme()
end)

autoBuyTab.MouseButton1Click:Connect(function()
	setActiveTab(autoBuyTab)
	teleportFrame.Visible = false
	autoFrame.Visible = false
	autoBuyFrame.Visible = true
	autoFarmFrame.Visible = false

	applyTheme()
end)

autoFarmTab.MouseButton1Click:Connect(function()
	setActiveTab(autoFarmTab)
	teleportFrame.Visible = false
	autoFrame.Visible = false
	autoBuyFrame.Visible = false
	autoFarmFrame.Visible = true

	applyTheme()
end)

--========================
-- TELEPORT BUTTONS
--========================
local ty = 10
for name,cf in pairs(Teleports) do
	local b = Instance.new("TextButton", teleportFrame)
	b.Size = UDim2.new(0,220,0,38)
	b.Position = UDim2.new(0,10,0,ty)
	b.Text = name
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = Color3.new(1,1,1)
	b.BackgroundColor3 = THEME.BUTTON
	b.BorderSizePixel = 0
	Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)

	b.MouseButton1Click:Connect(function()
		getHRP().CFrame = cf
	end)

	ty += 44
end

--========================
-- AUTO OPEN UI
--========================
local autoToggle = Instance.new("TextButton", autoFrame)
autoToggle.Size = UDim2.new(0,220,0,40)
autoToggle.Position = UDim2.new(0,10,0,10)
autoToggle.Text = "Auto Open: OFF"
autoToggle.Font = Enum.Font.GothamBold
autoToggle.TextSize = 15
autoToggle.TextColor3 = Color3.new(1,1,1)
autoToggle.BackgroundColor3 = THEME.INACTIVE
Instance.new("UICorner", autoToggle).CornerRadius = UDim.new(0,8)

autoToggle.ClipsDescendants = false

--========================
-- AUTO OPEN INDICATOR DOT
--========================
local autoDot = Instance.new("Frame", autoToggle)
autoDot.Size = UDim2.new(0,10,0,10)
autoDot.Position = UDim2.new(1,-16,0.5,-5)
autoDot.BackgroundColor3 = THEME.INACTIVE
autoDot.BorderSizePixel = 0
autoDot.ZIndex = 5
autoToggle.ZIndex = 1
Instance.new("UICorner", autoDot).CornerRadius = UDim.new(1,0)

local dotStroke = Instance.new("UIStroke", autoDot)
dotStroke.Thickness = 1
dotStroke.Color = Color3.fromRGB(40,40,40)

local autoOpenStroke = Instance.new("UIStroke")
autoOpenStroke.Parent = autoToggle
autoOpenStroke.Thickness = 1
autoOpenStroke.Color = Color3.fromRGB(65,65,65)

autoToggle.MouseButton1Click:Connect(function()
	AUTO_OPEN = not AUTO_OPEN
	autoToggle.Text = "Auto Open: "..(AUTO_OPEN and "ON" or "OFF")

	tweenColor(
		autoToggle,
		AUTO_OPEN and THEME.ACTIVE or THEME.INACTIVE,
		0.2
	)

	autoDot.BackgroundColor3 = AUTO_OPEN and THEME.ACTIVE or THEME.INACTIVE

	autoDot:SetAttribute("Active", AUTO_OPEN)

	if AUTO_OPEN then
		pulseDot(autoDot)
	end
end)

-- HOVER AUTO OPEN (RESPETA ESTADO)
autoToggle.MouseEnter:Connect(function()
	if not AUTO_OPEN then
		tweenColor(autoToggle, THEME.SIDEBAR_HOVER, 0.12)
	end
end)

autoToggle.MouseLeave:Connect(function()
	tweenColor(
		autoToggle,
		AUTO_OPEN and THEME.ACTIVE or THEME.INACTIVE,
		0.12
	)
end)

--========================
-- OPEN AMOUNT LABEL
--========================
local amountLabel = Instance.new("TextLabel", autoFrame)
amountLabel.Size = UDim2.new(0,220,0,20)
amountLabel.Position = UDim2.new(0,10,0,115)
amountLabel.Text = "Cantidad a abrir:"
amountLabel.Font = Enum.Font.Gotham
amountLabel.TextSize = 13
amountLabel.TextColor3 = THEME.SUBTEXT
amountLabel.BackgroundTransparency = 1
amountLabel.TextXAlignment = Enum.TextXAlignment.Left

--========================
-- OPEN AMOUNT INPUT
--========================
local amountBox = Instance.new("TextBox", autoFrame)
amountBox.Size = UDim2.new(0,220,0,36)
amountBox.Position = UDim2.new(0,10,0,140)
amountBox.Text = tostring(OPEN_AMOUNT)
amountBox.PlaceholderText = "Ej: 1, 10, 100..."
amountBox.Font = Enum.Font.Gotham
amountBox.TextSize = 14
amountBox.TextColor3 = THEME.TEXT
amountBox.BackgroundColor3 = Color3.fromRGB(45,45,45)
amountBox.ClearTextOnFocus = false
amountBox.BorderSizePixel = 0
Instance.new("UICorner", amountBox).CornerRadius = UDim.new(0,8)

--========================
-- AUTO BUY UI
--========================
local AUTO_BUY = false

local autoBuyTitle = Instance.new("TextLabel", autoBuyFrame)
autoBuyTitle.Size = UDim2.new(0,220,0,40)
autoBuyTitle.Position = UDim2.new(0,10,0,10)
autoBuyTitle.Text = "🛒 Auto Buy (Tickets)"
autoBuyTitle.Font = Enum.Font.GothamBold
autoBuyTitle.TextSize = 16
autoBuyTitle.TextColor3 = THEME.TEXT
autoBuyTitle.BackgroundTransparency = 1
autoBuyTitle.TextXAlignment = Enum.TextXAlignment.Left

local autoBuyToggle = Instance.new("TextButton", autoBuyFrame)
autoBuyToggle.Size = UDim2.new(0,220,0,40)
autoBuyToggle.Position = UDim2.new(0,10,0,60)
autoBuyToggle.Text = "Auto Buy: OFF"
autoBuyToggle.Font = Enum.Font.GothamBold
autoBuyToggle.TextSize = 15
autoBuyToggle.TextColor3 = Color3.new(1,1,1)
autoBuyToggle.BackgroundColor3 = THEME.INACTIVE
autoBuyToggle.BorderSizePixel = 0
Instance.new("UICorner", autoBuyToggle).CornerRadius = UDim.new(0,8)

autoBuyToggle.ClipsDescendants = false

--========================
-- AUTO FARM UI
--========================
local autoFarmToggle = Instance.new("TextButton", autoFarmFrame)
autoFarmToggle.Size = UDim2.new(0,220,0,40)
autoFarmToggle.Position = UDim2.new(0,10,0,10)
autoFarmToggle.Text = "Auto Farm: OFF"
autoFarmToggle.Font = Enum.Font.GothamBold
autoFarmToggle.TextSize = 15
autoFarmToggle.TextColor3 = Color3.new(1,1,1)
autoFarmToggle.BackgroundColor3 = THEME.INACTIVE
autoFarmToggle.BorderSizePixel = 0
Instance.new("UICorner", autoFarmToggle).CornerRadius = UDim.new(0,8)

local autoFarmDot = Instance.new("Frame", autoFarmToggle)
autoFarmDot.Size = UDim2.new(0,10,0,10)
autoFarmDot.Position = UDim2.new(1,-16,0.5,-5)
autoFarmDot.BackgroundColor3 = THEME.INACTIVE
autoFarmDot.BorderSizePixel = 0
Instance.new("UICorner", autoFarmDot).CornerRadius = UDim.new(1,0)
-- 👇 ESTE ES EL BORDE QUE FALTABA
local autoFarmDot = Instance.new("Frame", autoFarmToggle)

autoFarmDotStroke.Thickness = 1
autoFarmDotStroke.Color = Color3.fromRGB(40,40,40)

autoFarmToggle.MouseButton1Click:Connect(function()
	AUTO_FARM = not AUTO_FARM
	autoFarmToggle.Text = "Auto Farm: "..(AUTO_FARM and "ON" or "OFF")

	tweenColor(
		autoFarmToggle,
		AUTO_FARM and THEME.ACTIVE or THEME.INACTIVE,
		0.2
	)

	autoFarmDot.BackgroundColor3 = AUTO_FARM and THEME.ACTIVE or THEME.INACTIVE
	autoFarmDot:SetAttribute("Active", AUTO_FARM)

	if AUTO_FARM then
		pulseDot(autoFarmDot)
	end
end)

--========================
-- AUTO BUY INDICATOR DOT
--========================
local autoBuyDot = Instance.new("Frame", autoBuyToggle)
autoBuyDot.Size = UDim2.new(0,10,0,10)
autoBuyDot.Position = UDim2.new(1,-16,0.5,-5)
autoBuyDot.BackgroundColor3 = THEME.INACTIVE
autoBuyDot.BorderSizePixel = 0
autoBuyDot.ZIndex = 5
autoBuyToggle.ZIndex = 1
Instance.new("UICorner", autoBuyDot).CornerRadius = UDim.new(1,0)

local autoBuyDotStroke = Instance.new("UIStroke", autoBuyDot)
autoBuyDotStroke.Thickness = 1
autoBuyDotStroke.Color = Color3.fromRGB(40,40,40)

local autoBuyStroke = Instance.new("UIStroke")
autoBuyStroke.Parent = autoBuyToggle
autoBuyStroke.Thickness = 1
autoBuyStroke.Color = Color3.fromRGB(65,65,65)

local autoBuyStatus = Instance.new("TextLabel", autoBuyFrame)
autoBuyStatus.Size = UDim2.new(0,220,0,30)
autoBuyStatus.Position = UDim2.new(0,10,0,110)
autoBuyStatus.Text = "Estado: Inactivo"
autoBuyStatus.Font = Enum.Font.Gotham
autoBuyStatus.TextSize = 13
autoBuyStatus.TextColor3 = THEME.SUBTEXT
autoBuyStatus.BackgroundTransparency = 1
autoBuyStatus.TextXAlignment = Enum.TextXAlignment.Left

--========================
-- DROPDOWN BUTTON
--========================
local petballLabel = Instance.new("TextLabel", autoFrame)
petballLabel.Size = UDim2.new(0,220,0,20)
petballLabel.Position = UDim2.new(0,10,0,45)
petballLabel.Text = "Petball"
petballLabel.Font = Enum.Font.Gotham
petballLabel.TextSize = 13
petballLabel.TextColor3 = Color3.fromRGB(200,200,200)
petballLabel.BackgroundTransparency = 1
petballLabel.TextXAlignment = Enum.TextXAlignment.Left

local dropdown = Instance.new("TextButton", autoFrame)
dropdown.Size = UDim2.new(0,220,0,34)
dropdown.Position = UDim2.new(0,10,0,70)
dropdown.Text = "Petball: "..selectedPetballName
dropdown.Font = Enum.Font.Gotham
dropdown.TextSize = 14
dropdown.TextColor3 = THEME.TEXT
dropdown.BackgroundColor3 = Color3.fromRGB(45,45,45)
Instance.new("UICorner", dropdown).CornerRadius = UDim.new(0,8)

addHover(
	dropdown,
	Color3.fromRGB(45,45,45),
	Color3.fromRGB(70,70,70)
)

local dropdownStroke = Instance.new("UIStroke")
dropdownStroke.Parent = dropdown
dropdownStroke.Thickness = 1
dropdownStroke.Color = Color3.fromRGB(65,65,65)

--========================
-- DROPDOWN OPTIONS
--========================
local dropdownOpen = false
local dropdownButtons = {}

local oy = 98
for name,id in pairs(PETBALLS) do
	local opt = Instance.new("TextButton", autoFrame)
	opt.Size = UDim2.new(0,220,0,24)
	opt.Position = UDim2.new(0,10,0,oy)
	opt.Text = name
	opt.Font = Enum.Font.Gotham
	opt.TextSize = 13
	opt.TextColor3 = Color3.new(1,1,1)
	opt.BackgroundColor3 = Color3.fromRGB(60,60,60)
	opt.Visible = false
	Instance.new("UICorner", opt).CornerRadius = UDim.new(0,6)

	opt.MouseButton1Click:Connect(function()
		selectedPetballName = name
		selectedPetballId = id
		dropdown.Text = "Petball: "..name
		dropdownOpen = false
		for _,b in pairs(dropdownButtons) do
			b.Visible = false
		end
	end)

	table.insert(dropdownButtons, opt)
	oy += 22
end

dropdown.MouseButton1Click:Connect(function()
	dropdownOpen = not dropdownOpen
	for _,b in pairs(dropdownButtons) do
		b.Visible = dropdownOpen
	end
end)

--========================
-- OPEN AMOUNT LOGIC
--========================
amountBox.FocusLost:Connect(function(enterPressed)
	local n = tonumber(amountBox.Text)

	if n and n >= 1 then
		OPEN_AMOUNT = math.clamp(math.floor(n), 1, 1000)
		amountBox.Text = tostring(OPEN_AMOUNT)
	else
		amountBox.Text = tostring(OPEN_AMOUNT)
	end
end)

--========================
-- AUTO OPEN LOOP (FIXED)
--========================
task.spawn(function()
	while true do
		if AUTO_OPEN then
			pcall(function()
				PurchasePetball:InvokeServer(selectedPetballId, 1, OPEN_AMOUNT)
			end)

			task.wait(BUY_DELAY) -- delay fijo
		else
			task.wait(0.4)
		end
	end
end)

--========================
-- AUTO BUY LOGICA
--========================
local BuyRemote = ReplicatedStorage:WaitForChild("NetworkEvents"):WaitForChild("PURCHASE_SHOP_STOCK")

local function buyAllTickets()
	for _,item in ipairs(require(ReplicatedStorage:WaitForChild("ShopStock"))) do
		if AUTO_BUY and item.resource and item.ticket_price and item.ticket_price > 0 then
			pcall(function()
				BuyRemote:InvokeServer(item.resource, 1)
			end)
			task.wait(0.25)
		end
	end
end

autoBuyToggle.BackgroundColor3 = THEME.INACTIVE

autoBuyToggle.MouseButton1Click:Connect(function()
	AUTO_BUY = not AUTO_BUY
	autoBuyToggle.Text = "Auto Buy: "..(AUTO_BUY and "ON" or "OFF")
	autoBuyStatus.Text = AUTO_BUY and "Comprando con tickets..." or "Estado: Inactivo"

	tweenColor(
		autoBuyToggle,
		AUTO_BUY and THEME.ACTIVE or THEME.INACTIVE,
		0.2
	)

	if AUTO_BUY then
		task.spawn(function()
			while AUTO_BUY do
				buyAllTickets()
				task.wait(5)
			end
		end)
	end

	autoBuyDot.BackgroundColor3 = AUTO_BUY and THEME.ACTIVE or THEME.INACTIVE

	autoBuyDot:SetAttribute("Active", AUTO_BUY)

	if AUTO_BUY then
		pulseDot(autoBuyDot)
	end
end)

-- HOVER AUTO BUY (RESPETA ESTADO)
autoBuyToggle.MouseEnter:Connect(function()
	if not AUTO_BUY then
		tweenColor(autoBuyToggle, THEME.SIDEBAR_HOVER, 0.12)
	end
end)

autoBuyToggle.MouseLeave:Connect(function()
	tweenColor(
		autoBuyToggle,
		AUTO_BUY and THEME.ACTIVE or THEME.INACTIVE,
		0.12
	)
end)
