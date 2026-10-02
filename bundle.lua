--[[
    PROJECT: RAGE CLIENT INSTRUMENTATION SUITE
    Distribution: Standalone Single-Script Loadstring
    Styling: Aggressive Crimson & Obsidian
]]

-- Environment Safety Check
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- Global State Definition
local State = {
    Aimbot = {
        Enabled = true,
        TargetPart = "Head",
        FOV = 160,
        Smoothness = 0.25,
        Priority = "ScreenDistance",
        TeamCheck = true,
        VisibilityCheck = false,
        Prediction = 0.135,
        MaxDistance = 1500,
        IgnoreDead = true,
        LockIndicator = true,
    },
    Combat = {
        SilentAim = true,
        Triggerbot = false,
        AutoFire = false,
        TriggerDelay = 0.02,
        TriggerCrosshairRadius = 15,
    },
    Visuals = {
        Enabled = true,
        Boxes = true,
        Skeleton = true,
        Names = true,
        Distance = true,
        HealthBars = true,
        Tracers = true,
        TracerOrigin = "Bottom",
        TeamCheck = true,
        VisibilityCheck = false,
        Crosshair = true,
        CrosshairSize = 10,
        CrosshairGap = 4,
        FOVIndicator = true,
    },
    Character = {
        SpeedEnabled = false,
        SpeedValue = 48,
        JumpEnabled = false,
        JumpValue = 85,
        InfiniteJump = false,
        NoClip = false,
        Fly = false,
        FlySpeed = 50,
    },
    UI = {
        Visible = true,
        Keybind = Enum.KeyCode.RightShift,
    },
    Runtime = {
        CurrentTarget = nil,
    }
}

-- Theme Tokens
local Theme = {
    Background = Color3.fromRGB(10, 10, 12),
    Sidebar = Color3.fromRGB(14, 14, 18),
    Card = Color3.fromRGB(18, 18, 24),
    Border = Color3.fromRGB(35, 12, 16),
    BorderActive = Color3.fromRGB(229, 9, 20),
    Accent = Color3.fromRGB(229, 9, 20),
    AccentGlow = Color3.fromRGB(255, 30, 39),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(160, 160, 170),
    Success = Color3.fromRGB(46, 204, 113),
    FontTitle = Enum.Font.GothamBold,
    FontNormal = Enum.Font.GothamMedium,
    FontCode = Enum.Font.Code,
}

-- Math & Projection Engine
local Projection = {}
function Projection.GetCamera()
    return Workspace.CurrentCamera or Camera
end

function Projection.WorldToScreen(worldPos)
    local cam = Projection.GetCamera()
    if not cam then return Vector2.new(0, 0), false, 0 end
    local screenPoint, onScreen = cam:WorldToViewportPoint(worldPos)
    return Vector2.new(screenPoint.X, screenPoint.Y), onScreen, screenPoint.Z
end

function Projection.IsVisible(origin, targetPart, ignoreList)
    if not origin or not targetPart then return false end
    local params = RaycastParams.new()
    params.FilterType = RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreList or {Projection.GetCamera(), Players.LocalPlayer.Character}
    params.IgnoreWater = true
    
    local dir = (targetPart.Position - origin)
    local result = Workspace:Raycast(origin, dir, params)
    if not result then return true end
    return result.Instance:IsDescendantOf(targetPart.Parent)
end

function Projection.CalculateLead(targetPart, prediction)
    if not targetPart then return Vector3.zero end
    local velocity = Vector3.zero
    if targetPart:IsA("BasePart") then
        velocity = targetPart.AssemblyLinearVelocity or targetPart.Velocity or Vector3.zero
    end
    return targetPart.Position + (velocity * (prediction or 0.135))
end

function Projection.GetBoundingBox(character)
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if not hrp then return nil end

    local cam = Projection.GetCamera()
    local cframe, size = character:GetBoundingBox()
    
    local topPos = cframe.Position + Vector3.new(0, size.Y / 2, 0)
    local bottomPos = cframe.Position - Vector3.new(0, size.Y / 2, 0)
    
    local topScreen, topVisible = Projection.WorldToScreen(topPos)
    local bottomScreen, bottomVisible = Projection.WorldToScreen(bottomPos)
    
    if not topVisible and not bottomVisible then return nil end

    local height = math.abs(bottomScreen.Y - topScreen.Y)
    local width = height * 0.62
    local center = (topScreen + bottomScreen) / 2
    local topLeft = Vector2.new(center.X - (width / 2), topScreen.Y)

    return {
        TopLeft = topLeft,
        Width = width,
        Height = height,
        Center = center,
        OnScreen = topVisible or bottomVisible
    }
end

function Projection.GetSkeletonJoints(character)
    if not character then return {} end
    local isR15 = character:FindFirstChild("UpperTorso") ~= nil
    local bones = {}

    local function linePair(p1Name, p2Name)
        local part1 = character:FindFirstChild(p1Name)
        local part2 = character:FindFirstChild(p2Name)
        if part1 and part2 then
            local pos1, vis1 = Projection.WorldToScreen(part1.Position)
            local pos2, vis2 = Projection.WorldToScreen(part2.Position)
            if vis1 or vis2 then
                table.insert(bones, {pos1, pos2})
            end
        end
    end

    if isR15 then
        linePair("Head", "UpperTorso")
        linePair("UpperTorso", "LowerTorso")
        linePair("UpperTorso", "LeftUpperArm")
        linePair("LeftUpperArm", "LeftLowerArm")
        linePair("LeftLowerArm", "LeftHand")
        linePair("UpperTorso", "RightUpperArm")
        linePair("RightUpperArm", "RightLowerArm")
        linePair("RightLowerArm", "RightHand")
        linePair("LowerTorso", "LeftUpperLeg")
        linePair("LeftUpperLeg", "LeftLowerLeg")
        linePair("LeftLowerLeg", "LeftFoot")
        linePair("LowerTorso", "RightUpperLeg")
        linePair("RightUpperLeg", "RightLowerLeg")
        linePair("RightLowerLeg", "RightFoot")
    else
        linePair("Head", "Torso")
        linePair("Torso", "Left Arm")
        linePair("Torso", "Right Arm")
        linePair("Torso", "Left Leg")
        linePair("Torso", "Right Leg")
    end
    return bones
end

-- Entity Selector
local Target = {}
function Target.IsAlive(player)
    if not player or not player.Character then return false end
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

function Target.IsTeammate(player, localPlayer)
    if not player or not localPlayer then return false end
    if player.Team and localPlayer.Team then return player.Team == localPlayer.Team end
    if player.Neutral or localPlayer.Neutral then return false end
    return player.TeamColor == localPlayer.TeamColor
end

function Target.GetTargetPart(character, partName)
    if not character then return nil end
    local part = character:FindFirstChild(partName)
    if part then return part end
    return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
end

function Target.FindBestTarget()
    local lp = Players.LocalPlayer
    if not lp or not lp.Character then return nil end

    local cam = Projection.GetCamera()
    local mousePos = UserInputService:GetMouseLocation()
    local bestTarget = nil
    local bestScore = math.huge
    local cfg = State.Aimbot

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= lp and Target.IsAlive(player) then
            if not (cfg.TeamCheck and Target.IsTeammate(player, lp)) then
                local char = player.Character
                local part = Target.GetTargetPart(char, cfg.TargetPart)
                
                if part then
                    local screenPos, onScreen = Projection.WorldToScreen(part.Position)
                    local worldDist = (lp.Character:FindFirstChild("HumanoidRootPart") and (lp.Character.HumanoidRootPart.Position - part.Position).Magnitude) or 0

                    if worldDist <= cfg.MaxDistance then
                        local screenDist = (mousePos - screenPos).Magnitude
                        if screenDist <= cfg.FOV and onScreen then
                            local visible = true
                            if cfg.VisibilityCheck then
                                visible = Projection.IsVisible(cam.CFrame.Position, part, {cam, lp.Character})
                            end

                            if visible then
                                local score = screenDist
                                if cfg.Priority == "WorldDistance" then
                                    score = worldDist
                                elseif cfg.Priority == "LowestHealth" then
                                    local hum = char:FindFirstChildOfClass("Humanoid")
                                    score = hum and hum.Health or 100
                                end

                                if score < bestScore then
                                    bestScore = score
                                    bestTarget = {
                                        Player = player,
                                        Character = char,
                                        Part = part,
                                        ScreenPos = screenPos,
                                        WorldDistance = worldDist,
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- Input Synthesis & Metamethod Redirection
local mousemoverel = mousemoverel or (Input and Input.MouseMoveRel) or function(x, y)
    local vim = game:GetService("VirtualInputManager")
    if vim then
        local current = UserInputService:GetMouseLocation()
        vim:SendMouseMoveEvent(current.X + x, current.Y + y, game)
    end
end

local function setupMetamethodHooks()
    local hookmeta = hookmetamethod or (hookfunction and function(obj, method, func)
        local mt = getrawmetatable(obj)
        setreadonly(mt, false)
        local old = mt[method]
        mt[method] = func
        setreadonly(mt, true)
        return old
    end)
    local getnamecall = getnamecallmethod or get_namecall_method
    local check_caller = checkcaller or function() return false end
    local new_cclosure = newcclosure or function(f) return f end

    if hookmeta and getrawmetatable then
        local gameMeta = getrawmetatable(game)
        if gameMeta then
            local oldNamecall
            oldNamecall = hookmeta(game, "__namecall", new_cclosure(function(self, ...)
                local method = getnamecall and getnamecall()
                local args = {...}
                if not check_caller() and State.Combat.SilentAim and State.Runtime.CurrentTarget then
                    local targetPart = State.Runtime.CurrentTarget.Part
                    if targetPart then
                        local leadPos = Projection.CalculateLead(targetPart, State.Aimbot.Prediction)
                        if method == "Raycast" or method == "raycast" then
                            if typeof(args[2]) == "Vector3" then
                                local origin = args[1]
                                args[2] = (leadPos - origin).Unit * args[2].Magnitude
                                return oldNamecall(self, unpack(args))
                            end
                        elseif method == "FindPartOnRay" or method == "findPartOnRay" then
                            if typeof(args[1]) == "Ray" then
                                local ray = args[1]
                                args[1] = Ray.new(ray.Origin, (leadPos - ray.Origin).Unit * ray.Direction.Magnitude)
                                return oldNamecall(self, unpack(args))
                            end
                        end
                    end
                end
                return oldNamecall(self, ...)
            end))
        end

        local lp = Players.LocalPlayer
        if lp then
            local mouse = lp:GetMouse()
            local mouseMeta = getrawmetatable(mouse)
            if mouseMeta then
                local oldIndex
                oldIndex = hookmeta(mouse, "__index", new_cclosure(function(self, prop)
                    if not check_caller() and State.Combat.SilentAim and State.Runtime.CurrentTarget then
                        local targetPart = State.Runtime.CurrentTarget.Part
                        if targetPart then
                            local leadPos = Projection.CalculateLead(targetPart, State.Aimbot.Prediction)
                            if prop == "Hit" then return CFrame.new(leadPos)
                            elseif prop == "Target" then return targetPart end
                        end
                    end
                    return oldIndex(self, prop)
                end))
            end
        end
    end
end
setupMetamethodHooks()

-- Aiming & Triggerbot loop
local lastTriggerFire = 0
RunService.RenderStepped:Connect(function()
    local target = Target.FindBestTarget()
    State.Runtime.CurrentTarget = target

    local aimCfg = State.Aimbot
    local combatCfg = State.Combat

    if aimCfg.Enabled and target and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local mousePos = UserInputService:GetMouseLocation()
        local predictedPos = Projection.CalculateLead(target.Part, aimCfg.Prediction)
        local targetScreenPos, onScreen = Projection.WorldToScreen(predictedPos)

        if onScreen then
            local delta = targetScreenPos - mousePos
            local smoothFactor = math.clamp(1 - aimCfg.Smoothness, 0.05, 1.0)
            local moveX = delta.X * smoothFactor
            local moveY = delta.Y * smoothFactor
            if math.abs(moveX) > 0.1 or math.abs(moveY) > 0.1 then
                mousemoverel(moveX, moveY)
            end
        end
    end

    if combatCfg.Triggerbot or combatCfg.AutoFire then
        local now = tick()
        if target and (now - lastTriggerFire) > combatCfg.TriggerDelay then
            local mousePos = UserInputService:GetMouseLocation()
            local screenDist = (mousePos - target.ScreenPos).Magnitude
            if screenDist <= combatCfg.TriggerCrosshairRadius or combatCfg.AutoFire then
                lastTriggerFire = now
                if mouse1click then mouse1click()
                elseif mouse1press and mouse1release then
                    mouse1press()
                    task.wait(0.01)
                    mouse1release()
                end
            end
        end
    end
end)

-- Character & Physics Modifiers
local flyBodyVelocity = nil
local flyBodyGyro = nil

RunService.Stepped:Connect(function()
    if State.Character.NoClip then
        local lp = Players.LocalPlayer
        if lp and lp.Character then
            for _, part in ipairs(lp.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if State.Character.InfiniteJump then
        local lp = Players.LocalPlayer
        if lp and lp.Character then
            local hum = lp.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    local lp = Players.LocalPlayer
    if not lp or not lp.Character then return end
    local hum = lp.Character:FindFirstChildOfClass("Humanoid")
    local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
    local cam = Workspace.CurrentCamera
    local cCfg = State.Character

    if hum then
        if cCfg.SpeedEnabled then hum.WalkSpeed = cCfg.SpeedValue end
        if cCfg.JumpEnabled then
            if hum.UseJumpPower then hum.JumpPower = cCfg.JumpValue
            else hum.JumpHeight = cCfg.JumpValue / 3 end
        end
    end

    if cCfg.Fly and hrp and cam then
        if not flyBodyVelocity then
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flyBodyVelocity.Parent = hrp
        end
        if not flyBodyGyro then
            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            flyBodyGyro.P = 10000
            flyBodyGyro.Parent = hrp
        end
        flyBodyGyro.CFrame = cam.CFrame
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + (cam.CFrame.LookVector) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - (cam.CFrame.LookVector) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - (cam.CFrame.RightVector) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + (cam.CFrame.RightVector) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0, 1, 0) end

        if moveDir.Magnitude > 0 then
            flyBodyVelocity.Velocity = moveDir.Unit * cCfg.FlySpeed
        else
            flyBodyVelocity.Velocity = Vector3.zero
        end
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
    end
end)

-- Drawing Subsystem Initialization
local drawingPool = {}
local function createDrawing(drawType)
    if Drawing and Drawing.new then
        local obj = Drawing.new(drawType)
        obj.Visible = false
        return obj
    end
    return nil
end

local fovCircle = createDrawing("Circle")
if fovCircle then
    fovCircle.Thickness = 1.5
    fovCircle.NumSides = 48
    fovCircle.Filled = false
    fovCircle.Color = Theme.Accent
    fovCircle.Transparency = 0.85
end

local crosshairLines = {}
for i = 1, 4 do
    local line = createDrawing("Line")
    if line then
        line.Thickness = 1.5
        line.Color = Theme.AccentGlow
        table.insert(crosshairLines, line)
    end
end

local lockIndicator = createDrawing("Text")
if lockIndicator then
    lockIndicator.Size = 14
    lockIndicator.Center = true
    lockIndicator.Outline = true
    lockIndicator.Color = Theme.AccentGlow
    lockIndicator.Font = 2
end

local function getEntry(player)
    if not drawingPool[player] then
        drawingPool[player] = {
            BoxOutline = createDrawing("Square"),
            Box = createDrawing("Square"),
            HealthBarBackground = createDrawing("Square"),
            HealthBar = createDrawing("Square"),
            Name = createDrawing("Text"),
            Distance = createDrawing("Text"),
            Tracer = createDrawing("Line"),
            Skeletons = {},
        }
        local entry = drawingPool[player]
        if entry.Box then entry.Box.Filled = false entry.Box.Thickness = 1.2 entry.Box.Color = Theme.Accent end
        if entry.BoxOutline then entry.BoxOutline.Filled = false entry.BoxOutline.Thickness = 2.4 entry.BoxOutline.Color = Color3.fromRGB(0, 0, 0) end
        if entry.HealthBarBackground then entry.HealthBarBackground.Filled = true entry.HealthBarBackground.Color = Color3.fromRGB(15, 15, 18) end
        if entry.HealthBar then entry.HealthBar.Filled = true entry.HealthBar.Color = Theme.Success end
        if entry.Name then entry.Name.Size = 13 entry.Name.Center = true entry.Name.Outline = true entry.Name.Color = Theme.Text entry.Name.Font = 2 end
        if entry.Distance then entry.Distance.Size = 11 entry.Distance.Center = true entry.Distance.Outline = true entry.Distance.Color = Theme.SubText entry.Distance.Font = 2 end
        if entry.Tracer then entry.Tracer.Thickness = 1.2 entry.Tracer.Color = Theme.Accent end
        for i = 1, 15 do
            local boneLine = createDrawing("Line")
            if boneLine then
                boneLine.Thickness = 1.2
                boneLine.Color = Color3.fromRGB(255, 255, 255)
                table.insert(entry.Skeletons, boneLine)
            end
        end
    end
    return drawingPool[player]
end

local function hideEntry(entry)
    if not entry then return end
    if entry.Box then entry.Box.Visible = false end
    if entry.BoxOutline then entry.BoxOutline.Visible = false end
    if entry.HealthBar then entry.HealthBar.Visible = false end
    if entry.HealthBarBackground then entry.HealthBarBackground.Visible = false end
    if entry.Name then entry.Name.Visible = false end
    if entry.Distance then entry.Distance.Visible = false end
    if entry.Tracer then entry.Tracer.Visible = false end
    if entry.Skeletons then for _, b in ipairs(entry.Skeletons) do b.Visible = false end end
end

Players.PlayerRemoving:Connect(function(player)
    local entry = drawingPool[player]
    if entry then
        hideEntry(entry)
        for _, v in pairs(entry) do
            if typeof(v) == "table" then
                for _, sub in ipairs(v) do if sub.Remove then sub:Remove() end end
            elseif v and v.Remove then v:Remove() end
        end
        drawingPool[player] = nil
    end
end)

RunService.RenderStepped:Connect(function()
    local vCfg = State.Visuals
    local aCfg = State.Aimbot
    local lp = Players.LocalPlayer
    local cam = Projection.GetCamera()
    if not cam then return end

    local mousePos = UserInputService:GetMouseLocation()
    local viewport = cam.ViewportSize

    if fovCircle then
        if aCfg.Enabled and vCfg.FOVIndicator then
            fovCircle.Position = mousePos
            fovCircle.Radius = aCfg.FOV
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end

    if #crosshairLines == 4 then
        if vCfg.Crosshair then
            local size = vCfg.CrosshairSize
            local gap = vCfg.CrosshairGap
            local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
            crosshairLines[1].From = Vector2.new(center.X, center.Y - gap)
            crosshairLines[1].To = Vector2.new(center.X, center.Y - gap - size)
            crosshairLines[2].From = Vector2.new(center.X, center.Y + gap)
            crosshairLines[2].To = Vector2.new(center.X, center.Y + gap + size)
            crosshairLines[3].From = Vector2.new(center.X - gap, center.Y)
            crosshairLines[3].To = Vector2.new(center.X - gap - size, center.Y)
            crosshairLines[4].From = Vector2.new(center.X + gap, center.Y)
            crosshairLines[4].To = Vector2.new(center.X + gap + size, center.Y)
            for _, l in ipairs(crosshairLines) do l.Visible = true end
        else
            for _, l in ipairs(crosshairLines) do l.Visible = false end
        end
    end

    if lockIndicator then
        local currTarget = State.Runtime.CurrentTarget
        if aCfg.LockIndicator and currTarget and currTarget.ScreenPos then
            lockIndicator.Position = Vector2.new(currTarget.ScreenPos.X, currTarget.ScreenPos.Y - 26)
            lockIndicator.Text = "LOCKED // " .. string.upper(currTarget.Player.DisplayName or currTarget.Player.Name)
            lockIndicator.Visible = true
        else
            lockIndicator.Visible = false
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local entry = getEntry(player)
        if not vCfg.Enabled or player == lp or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            hideEntry(entry)
        else
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local isTeammate = (player.Team and lp.Team and player.Team == lp.Team)

            if (vCfg.TeamCheck and isTeammate) or not hum or hum.Health <= 0 then
                hideEntry(entry)
            else
                local boxData = Projection.GetBoundingBox(char)
                if not boxData or not boxData.OnScreen then
                    hideEntry(entry)
                else
                    if vCfg.Boxes then
                        entry.Box.Position = boxData.TopLeft
                        entry.Box.Size = Vector2.new(boxData.Width, boxData.Height)
                        entry.Box.Visible = true
                        entry.BoxOutline.Position = boxData.TopLeft - Vector2.new(1, 1)
                        entry.BoxOutline.Size = Vector2.new(boxData.Width + 2, boxData.Height + 2)
                        entry.BoxOutline.Visible = true
                    else
                        entry.Box.Visible = false
                        entry.BoxOutline.Visible = false
                    end

                    if vCfg.HealthBars then
                        local healthPct = math.clamp(hum.Health / (hum.MaxHealth > 0 and hum.MaxHealth or 100), 0, 1)
                        local barHeight = boxData.Height * healthPct
                        local barWidth = 3
                        local barOffset = 5
                        entry.HealthBarBackground.Position = Vector2.new(boxData.TopLeft.X - barOffset - barWidth, boxData.TopLeft.Y)
                        entry.HealthBarBackground.Size = Vector2.new(barWidth, boxData.Height)
                        entry.HealthBarBackground.Visible = true
                        entry.HealthBar.Position = Vector2.new(boxData.TopLeft.X - barOffset - barWidth, boxData.TopLeft.Y + (boxData.Height - barHeight))
                        entry.HealthBar.Size = Vector2.new(barWidth, barHeight)
                        entry.HealthBar.Color = Color3.fromHSV(healthPct * 0.33, 0.9, 0.9)
                        entry.HealthBar.Visible = true
                    else
                        entry.HealthBar.Visible = false
                        entry.HealthBarBackground.Visible = false
                    end

                    if vCfg.Names then
                        entry.Name.Position = Vector2.new(boxData.Center.X, boxData.TopLeft.Y - 16)
                        entry.Name.Text = player.DisplayName or player.Name
                        entry.Name.Visible = true
                    else
                        entry.Name.Visible = false
                    end

                    if vCfg.Distance and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                        local distStuds = math.floor((lp.Character.HumanoidRootPart.Position - hrp.Position).Magnitude)
                        entry.Distance.Position = Vector2.new(boxData.Center.X, boxData.TopLeft.Y + boxData.Height + 3)
                        entry.Distance.Text = "[" .. distStuds .. "m]"
                        entry.Distance.Visible = true
                    else
                        entry.Distance.Visible = false
                    end

                    if vCfg.Tracers then
                        local origin = Vector2.new(viewport.X / 2, viewport.Y)
                        if vCfg.TracerOrigin == "Center" then origin = Vector2.new(viewport.X / 2, viewport.Y / 2)
                        elseif vCfg.TracerOrigin == "Mouse" then origin = mousePos end
                        entry.Tracer.From = origin
                        entry.Tracer.To = Vector2.new(boxData.Center.X, boxData.TopLeft.Y + boxData.Height)
                        entry.Tracer.Visible = true
                    else
                        entry.Tracer.Visible = false
                    end

                    if vCfg.Skeleton then
                        local bones = Projection.GetSkeletonJoints(char)
                        for i, boneLine in ipairs(entry.Skeletons) do
                            if bones[i] then
                                boneLine.From = bones[i][1]
                                boneLine.To = bones[i][2]
                                boneLine.Visible = true
                            else
                                boneLine.Visible = false
                            end
                        end
                    else
                        for _, boneLine in ipairs(entry.Skeletons) do boneLine.Visible = false end
                    end
                end
            end
        end
    end
end)

-- UI Construction
local parent = nil
if gethui then parent = gethui()
elseif syn and syn.protect_gui then
    local sg = Instance.new("ScreenGui")
    syn.protect_gui(sg)
    sg.Parent = CoreGui
    parent = sg
else
    pcall(function() parent = CoreGui end)
    if not parent then parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RageInstrumentation"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = parent

local banner = Instance.new("Frame")
banner.Size = UDim2.new(0, 240, 0, 32)
banner.Position = UDim2.new(0.5, -120, 0, 16)
banner.BackgroundColor3 = Theme.Background
banner.BorderSizePixel = 0
banner.Parent = screenGui

local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 6)
bannerCorner.Parent = banner

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Theme.Accent
bannerStroke.Thickness = 1.5
bannerStroke.Parent = banner

local bannerText = Instance.new("TextLabel")
bannerText.Size = UDim2.new(1, 0, 1, 0)
bannerText.BackgroundTransparency = 1
bannerText.Font = Theme.FontTitle
bannerText.Text = "⚡ RAGE ACTIVE // SYS.OK"
bannerText.TextColor3 = Theme.AccentGlow
bannerText.TextSize = 12
bannerText.Parent = banner

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 580, 0, 420)
main.Position = UDim2.new(0.5, -290, 0.5, -210)
main.BackgroundColor3 = Theme.Background
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Theme.BorderActive
mainStroke.Thickness = 1.5
mainStroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = Theme.Sidebar
header.BorderSizePixel = 0
header.Parent = main

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(0, 200, 1, 0)
headerTitle.Position = UDim2.new(0, 16, 0, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Font = Theme.FontTitle
headerTitle.Text = "PROJECT // RAGE"
headerTitle.TextColor3 = Theme.AccentGlow
headerTitle.TextSize = 15
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = header

local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, -44)
sidebar.Position = UDim2.new(0, 0, 0, 44)
sidebar.BackgroundColor3 = Theme.Sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sideList = Instance.new("UIListLayout")
sideList.Padding = UDim.new(0, 4)
sideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideList.Parent = sidebar

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 10)
sidePad.Parent = sidebar

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -140, 1, -54)
contentArea.Position = UDim2.new(0, 135, 0, 49)
contentArea.BackgroundTransparency = 1
contentArea.Parent = main

local pages = {}
local tabButtons = {}
local tabs = {"TARGETING", "COMBAT", "VISUALS", "MOVEMENT"}

for _, tabName in ipairs(tabs) do
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.Accent
    page.CanvasSize = UDim2.new(0, 0, 0, 650)
    page.Visible = false
    page.Parent = contentArea

    local pageList = Instance.new("UIListLayout")
    pageList.Padding = UDim.new(0, 8)
    pageList.Parent = page

    local pagePad = Instance.new("UIPadding")
    pagePad.PaddingRight = UDim.new(0, 10)
    pagePad.PaddingTop = UDim.new(0, 4)
    pagePad.Parent = page

    pages[tabName] = page

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    btn.Font = Theme.FontNormal
    btn.Text = tabName
    btn.TextColor3 = Theme.SubText
    btn.TextSize = 12
    btn.Parent = sidebar

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 5)
    bCorner.Parent = btn

    tabButtons[tabName] = btn

    btn.MouseButton1Click:Connect(function()
        for name, p in pairs(pages) do p.Visible = (name == tabName) end
        for name, b in pairs(tabButtons) do
            local active = (name == tabName)
            b.BackgroundColor3 = active and Theme.Accent or Color3.fromRGB(20, 20, 26)
            b.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Theme.SubText
        end
    end)
end

pages["TARGETING"].Visible = true
tabButtons["TARGETING"].BackgroundColor3 = Theme.Accent
tabButtons["TARGETING"].TextColor3 = Color3.fromRGB(255, 255, 255)

local function createToggle(parent, labelText, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 36)
    frame.BackgroundColor3 = Theme.Card
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Border
    stroke.Thickness = 1
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Theme.FontNormal
    label.Text = labelText
    label.TextColor3 = Theme.Text
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 42, 0, 20)
    switch.Position = UDim2.new(1, -52, 0.5, -10)
    switch.BackgroundColor3 = defaultValue and Theme.Accent or Color3.fromRGB(28, 28, 35)
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.Parent = frame

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultValue and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = switch

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local state = defaultValue
    switch.MouseButton1Click:Connect(function()
        state = not state
        local targetColor = state and Theme.Accent or Color3.fromRGB(28, 28, 35)
        local targetPos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        local strokeColor = state and Theme.BorderActive or Theme.Border

        TweenService:Create(switch, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = targetPos}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Color = strokeColor}):Play()
        if callback then callback(state) end
    end)
    return frame
end

local function createSlider(parent, labelText, minVal, maxVal, defaultVal, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 50)
    frame.BackgroundColor3 = Theme.Card
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Border
    stroke.Thickness = 1
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 0, 24)
    label.Position = UDim2.new(0, 12, 0, 4)
    label.BackgroundTransparency = 1
    label.Font = Theme.FontNormal
    label.Text = labelText
    label.TextColor3 = Theme.Text
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0, 60, 0, 24)
    valLabel.Position = UDim2.new(1, -72, 0, 4)
    valLabel.BackgroundTransparency = 1
    valLabel.Font = Theme.FontCode
    valLabel.Text = tostring(defaultVal)
    valLabel.TextColor3 = Theme.AccentGlow
    valLabel.TextSize = 12
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = frame

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -24, 0, 6)
    barBg.Position = UDim2.new(0, 12, 0, 34)
    barBg.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    barBg.BorderSizePixel = 0
    barBg.Parent = frame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = barBg

    local fillPct = (defaultVal - minVal) / (maxVal - minVal)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp(fillPct, 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = barBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local dragging = false
    local function updateValue(inputX)
        local rel = math.clamp((inputX - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
        local value = minVal + ((maxVal - minVal) * rel)
        if (maxVal - minVal) > 10 then
            value = math.floor(value + 0.5)
            valLabel.Text = tostring(value)
        else
            value = math.floor(value * 100) / 100
            valLabel.Text = string.format("%.2f", value)
        end
        fill.Size = UDim2.new(rel, 0, 1, 0)
        if callback then callback(value) end
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateValue(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then updateValue(input.Position.X) end
    end)
    return frame
end

local function createDropdown(parent, labelText, options, defaultOption, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 38)
    frame.BackgroundColor3 = Theme.Card
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Border
    stroke.Thickness = 1
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Font = Theme.FontNormal
    label.Text = labelText
    label.TextColor3 = Theme.Text
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.45, 0, 0, 24)
    btn.Position = UDim2.new(0.52, 0, 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    btn.Text = defaultOption
    btn.TextColor3 = Theme.AccentGlow
    btn.Font = Theme.FontCode
    btn.TextSize = 11
    btn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = btn

    local currentIndex = 1
    for i, opt in ipairs(options) do
        if opt == defaultOption then currentIndex = i break end
    end

    btn.MouseButton1Click:Connect(function()
        currentIndex = (currentIndex % #options) + 1
        local newOpt = options[currentIndex]
        btn.Text = newOpt
        if callback then callback(newOpt) end
    end)
    return frame
end

-- Hook up pages
local tP = pages["TARGETING"]
createToggle(tP, "Direct Cursor Lock", State.Aimbot.Enabled, function(v) State.Aimbot.Enabled = v end)
createDropdown(tP, "Target Part", {"Head", "HumanoidRootPart", "UpperTorso"}, State.Aimbot.TargetPart, function(v) State.Aimbot.TargetPart = v end)
createDropdown(tP, "Target Priority", {"ScreenDistance", "WorldDistance", "LowestHealth"}, State.Aimbot.Priority, function(v) State.Aimbot.Priority = v end)
createSlider(tP, "Field Of View", 30, 450, State.Aimbot.FOV, function(v) State.Aimbot.FOV = v end)
createSlider(tP, "Cursor Smoothness", 0, 0.95, State.Aimbot.Smoothness, function(v) State.Aimbot.Smoothness = v end)
createSlider(tP, "Lead Prediction", 0, 0.5, State.Aimbot.Prediction, function(v) State.Aimbot.Prediction = v end)
createSlider(tP, "Max Distance (m)", 100, 3000, State.Aimbot.MaxDistance, function(v) State.Aimbot.MaxDistance = v end)
createToggle(tP, "Team Check", State.Aimbot.TeamCheck, function(v) State.Aimbot.TeamCheck = v end)
createToggle(tP, "Wall Visibility Gate", State.Aimbot.VisibilityCheck, function(v) State.Aimbot.VisibilityCheck = v end)
createToggle(tP, "Lock HUD Indicator", State.Aimbot.LockIndicator, function(v) State.Aimbot.LockIndicator = v end)

local cP = pages["COMBAT"]
createToggle(cP, "Silent Metamethod Redirection", State.Combat.SilentAim, function(v) State.Combat.SilentAim = v end)
createToggle(cP, "Trigger Crosshair Intersect", State.Combat.Triggerbot, function(v) State.Combat.Triggerbot = v end)
createToggle(cP, "Continuous Auto-Fire", State.Combat.AutoFire, function(v) State.Combat.AutoFire = v end)
createSlider(cP, "Trigger Delay (s)", 0.01, 0.5, State.Combat.TriggerDelay, function(v) State.Combat.TriggerDelay = v end)
createSlider(cP, "Trigger Radius", 5, 50, State.Combat.TriggerCrosshairRadius, function(v) State.Combat.TriggerCrosshairRadius = v end)

local vP = pages["VISUALS"]
createToggle(vP, "Master Visuals Switch", State.Visuals.Enabled, function(v) State.Visuals.Enabled = v end)
createToggle(vP, "Bounding Boxes", State.Visuals.Boxes, function(v) State.Visuals.Boxes = v end)
createToggle(vP, "Bone Skeletons", State.Visuals.Skeleton, function(v) State.Visuals.Skeleton = v end)
createToggle(vP, "Player Names", State.Visuals.Names, function(v) State.Visuals.Names = v end)
createToggle(vP, "Distance Studs", State.Visuals.Distance, function(v) State.Visuals.Distance = v end)
createToggle(vP, "Dynamic Health Bars", State.Visuals.HealthBars, function(v) State.Visuals.HealthBars = v end)
createToggle(vP, "Tracer Vectors", State.Visuals.Tracers, function(v) State.Visuals.Tracers = v end)
createDropdown(vP, "Tracer Origin", {"Bottom", "Center", "Mouse"}, State.Visuals.TracerOrigin, function(v) State.Visuals.TracerOrigin = v end)
createToggle(vP, "Crosshair Center", State.Visuals.Crosshair, function(v) State.Visuals.Crosshair = v end)
createToggle(vP, "FOV Circle Overlay", State.Visuals.FOVIndicator, function(v) State.Visuals.FOVIndicator = v end)
createToggle(vP, "Ignore Friendly Team", State.Visuals.TeamCheck, function(v) State.Visuals.TeamCheck = v end)

local mP = pages["MOVEMENT"]
createToggle(mP, "WalkSpeed Modifier", State.Character.SpeedEnabled, function(v) State.Character.SpeedEnabled = v end)
createSlider(mP, "WalkSpeed Value", 16, 200, State.Character.SpeedValue, function(v) State.Character.SpeedValue = v end)
createToggle(mP, "Jump Power Modifier", State.Character.JumpEnabled, function(v) State.Character.JumpEnabled = v end)
createSlider(mP, "Jump Power Value", 50, 300, State.Character.JumpValue, function(v) State.Character.JumpValue = v end)
createToggle(mP, "Infinite Air Jump", State.Character.InfiniteJump, function(v) State.Character.InfiniteJump = v end)
createToggle(mP, "Collider Noclip", State.Character.NoClip, function(v) State.Character.NoClip = v end)
createToggle(mP, "Omni Flight Mode", State.Character.Fly, function(v) State.Character.Fly = v end)
createSlider(mP, "Flight Velocity", 20, 250, State.Character.FlySpeed, function(v) State.Character.FlySpeed = v end)

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == State.UI.Keybind then
        main.Visible = not main.Visible
    end
end)
