-- language: Luau, file: vd_hub.lua, target: Roblox Android executor with gethui/loadstring
-- single-file hub: mobile UI, combat/move/anims/esp/misc. client-authoritative features work;
-- combat remotes are game-specific and named below — wire the real ones the game uses.

--========== 0. services ==========
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local StarterGui   = game:GetService("StarterGui")
local Lighting     = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace    = game:GetService("Workspace")

local LP = Players.LocalPlayer
local function notif(t,x) pcall(function() StarterGui:SetCore("SendNotification",{Title=t,Text=x,Duration=3}) end) end
local IS_MOBILE = UIS.TouchEnabled

--========== 1. ui mini-lib ==========
local C = {
    bg=Color3.fromRGB(18,18,22), panel=Color3.fromRGB(28,28,34),
    acc=Color3.fromRGB(0,200,255), acc2=Color3.fromRGB(255,60,120),
    txt=Color3.fromRGB(235,235,240), dim=Color3.fromRGB(150,150,160),
    stroke=Color3.fromRGB(55,55,65), off=Color3.fromRGB(70,70,80)
}
local function corner(p,r) local u=Instance.new("UICorner"); u.CornerRadius=UDim.new(0,r or 6); u.Parent=p end
local function stroke(p,c,t) local s=Instance.new("UIStroke"); s.Color=c or C.stroke; s.Thickness=t or 1; s.Parent=p end
local function lbl(p,t,sz,col,bold)
    local l=Instance.new("TextLabel"); l.BackgroundTransparency=1
    l.Size=sz or UDim2.new(1,0,0,18); l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.Text=t; l.TextColor3=col or C.txt; l.TextSize=13; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=p; return l
end
local function draggable(frame, handle)
    handle = handle or frame
    local dragging, ds, sp
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; ds=i.Position; sp=frame.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            local d=i.Position-ds
            frame.Position=UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
        end
    end)
end

local function Toggle(parent, text, default, cb)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,34)
    row.BackgroundColor3=C.panel; row.BackgroundTransparency=0.3; row.BorderSizePixel=0; row.Parent=parent
    corner(row,6)
    local l=lbl(row,text,UDim2.new(1,-56,1,0)); l.Position=UDim2.new(0,10,0,0)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(0,40,0,20); b.Position=UDim2.new(1,-50,0.5,-10)
    b.BackgroundColor3=default and C.acc or C.off; b.Text=""; b.AutoButtonColor=false; b.BorderSizePixel=0; b.Parent=row
    corner(b,10)
    local k=Instance.new("Frame"); k.Size=UDim2.new(0,16,0,16)
    k.Position=default and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
    k.BackgroundColor3=Color3.fromRGB(240,240,240); k.Parent=b; corner(k,8)
    local s=default
    b.MouseButton1Click:Connect(function()
        s=not s
        b.BackgroundColor3 = s and C.acc or C.off
        TweenService:Create(k,TweenInfo.new(0.14),{Position = s and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)}):Play()
        if cb then task.spawn(cb, s) end
    end)
    return row
end

local function Button(parent, text, cb, danger)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,32)
    b.BackgroundColor3 = danger and C.acc2 or C.acc
    b.Text=text; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=13
    b.BorderSizePixel=0; b.Parent=parent; corner(b,6)
    b.MouseButton1Click:Connect(function() if cb then task.spawn(cb) end end)
    return b
end

local function Slider(parent, text, min, max, default, cb)
    local h=Instance.new("Frame"); h.Size=UDim2.new(1,0,0,50)
    h.BackgroundColor3=C.panel; h.BackgroundTransparency=0.3; h.BorderSizePixel=0; h.Parent=parent
    corner(h,6)
    lbl(h,text,UDim2.new(1,-60,0,20)).Position=UDim2.new(0,10,0,4)
    local v=lbl(h,tostring(default),UDim2.new(0,60,0,20),C.acc,true)
    v.TextXAlignment=Enum.TextXAlignment.Right; v.Position=UDim2.new(1,-60,0,4)
    local bar=Instance.new("Frame"); bar.Size=UDim2.new(1,-20,0,6); bar.Position=UDim2.new(0,10,0,34)
    bar.BackgroundColor3=C.off; bar.BorderSizePixel=0; bar.Parent=h; corner(bar,3)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new((default-min)/(max-min),0,1,0)
    fill.BackgroundColor3=C.acc; fill.BorderSizePixel=0; fill.Parent=bar; corner(fill,3)
    local dragging=false
    bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
        local rel=math.clamp((i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
        local val=min+(max-min)*rel
        if max-min >= 10 then val=math.floor(val+0.5) end
        fill.Size=UDim2.new(rel,0,1,0); v.Text=string.format("%.1f",val)
        if cb then task.spawn(cb,val) end
    end)
    return h
end

local function Input(parent, placeholder, cb)
    local h=Instance.new("Frame"); h.Size=UDim2.new(1,0,0,34)
    h.BackgroundColor3=C.panel; h.BackgroundTransparency=0.3; h.BorderSizePixel=0; h.Parent=parent
    corner(h,6)
    local b=Instance.new("TextBox"); b.Size=UDim2.new(1,-16,1,-8); b.Position=UDim2.new(0,8,0,4)
    b.BackgroundColor3=C.off; b.Text=""; b.PlaceholderText=placeholder
    b.TextColor3=C.txt; b.PlaceholderColor3=C.dim; b.Font=Enum.Font.Gotham; b.TextSize=13
    b.ClearTextOnFocus=false; b.BorderSizePixel=0; b.Parent=h; corner(b,4)
    b.FocusLost:Connect(function() if cb then task.spawn(cb, b.Text) end end)
    return h
end

--========== 2. window + toggle ==========
local gui = Instance.new("ScreenGui")
gui.Name="VD_Hub"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
if gethui then pcall(function() gui.Parent=gethui() end) end
if not gui.Parent then pcall(function() gui.Parent=game:GetService("CoreGui") end) end
if not gui.Parent then gui.Parent=LP:WaitForChild("PlayerGui") end

local conns = {}
local function track(c) table.insert(conns,c); return c end

local toggle=Instance.new("TextButton")
toggle.Size=UDim2.new(0, IS_MOBILE and 56 or 48, 0, IS_MOBILE and 56 or 48)
toggle.Position=UDim2.new(0,20,0.5,-28)
toggle.BackgroundColor3=C.acc; toggle.Text="VD"; toggle.TextColor3=Color3.new(1,1,1)
toggle.Font=Enum.Font.GothamBold; toggle.TextSize=17; toggle.AutoButtonColor=false; toggle.BorderSizePixel=0
toggle.Parent=gui; corner(toggle,IS_MOBILE and 28 or 24); stroke(toggle,Color3.fromRGB(0,140,180),2)
draggable(toggle)

local main=Instance.new("Frame")
local ww, wh = IS_MOBILE and 320 or 440, IS_MOBILE and 400 or 440
main.Size=UDim2.new(0,ww,0,wh)
main.Position=UDim2.new(0.5,-ww/2,0.5,-wh/2)
main.BackgroundColor3=C.bg; main.BorderSizePixel=0; main.ClipsDescendants=true; main.Visible=false
main.Parent=gui; corner(main,10); stroke(main,C.stroke,1)

local tb=Instance.new("Frame"); tb.Size=UDim2.new(1,0,0,36); tb.BackgroundColor3=C.panel; tb.BorderSizePixel=0; tb.Parent=main
corner(tb,10); draggable(main, tb)
local ttl=lbl(tb,"VIOLENCE DISTRICT · mobile",UDim2.new(1,-80,1,0),C.txt,true); ttl.Position=UDim2.new(0,12,0,0)
local cls=Instance.new("TextButton"); cls.Size=UDim2.new(0,26,0,26); cls.Position=UDim2.new(1,-34,0.5,-13)
cls.BackgroundColor3=C.acc2; cls.Text="×"; cls.TextColor3=Color3.new(1,1,1); cls.Font=Enum.Font.GothamBold; cls.TextSize=16
cls.BorderSizePixel=0; cls.Parent=tb; corner(cls,5)

local tabBar=Instance.new("Frame"); tabBar.Size=UDim2.new(1,0,0,32); tabBar.Position=UDim2.new(0,0,0,36)
tabBar.BackgroundColor3=C.bg; tabBar.BorderSizePixel=0; tabBar.Parent=main
local tl=Instance.new("UIListLayout"); tl.FillDirection=Enum.FillDirection.Horizontal; tl.Padding=UDim.new(0,2); tl.Parent=tabBar
local tp=Instance.new("UIPadding"); tp.PaddingLeft=UDim.new(0,4); tp.PaddingTop=UDim.new(0,4); tp.Parent=tabBar

local scroll=Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,-16,1,-80); scroll.Position=UDim2.new(0,8,0,72)
scroll.BackgroundColor3=C.bg; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=4
scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.ScrollBarImageColor3=C.acc; scroll.Parent=main
local cl=Instance.new("UIListLayout"); cl.Padding=UDim.new(0,6); cl.Parent=scroll
cl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize=UDim2.new(0,0,0,cl.AbsoluteContentSize.Y+8)
end)

local uiOpen=false
local function setOpen(v)
    uiOpen=v
    if v then
        main.Visible=true
        main.Size=UDim2.new(0,ww-20,0,wh-20)
        TweenService:Create(main,TweenInfo.new(0.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.new(0,ww,0,wh)}):Play()
    else
        local t=TweenService:Create(main,TweenInfo.new(0.14),{Size=UDim2.new(0,ww-20,0,wh-20)})
        t:Play(); t.Completed:Connect(function() main.Visible=false end)
    end
end
toggle.MouseButton1Click:Connect(function() setOpen(not uiOpen) end)
cls.MouseButton1Click:Connect(function() setOpen(false) end)

--========== 3. tabs ==========
local tabs={}
local function addTab(icon, name)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(0,58,0,24); b.BackgroundColor3=Color3.fromRGB(40,40,48)
    b.Text=icon.." "..name; b.TextColor3=C.dim; b.Font=Enum.Font.Gotham; b.TextSize=11
    b.BorderSizePixel=0; b.Parent=tabBar; corner(b,5)
    local page=Instance.new("Frame"); page.Size=UDim2.new(1,0,0,0); page.AutomaticSize=Enum.AutomaticSize.Y
    page.BackgroundTransparency=1; page.Parent=scroll; page.Visible=false
    local pl=Instance.new("UIListLayout"); pl.Padding=UDim.new(0,6); pl.Parent=page
    tabs[name]={button=b, page=page}
    b.MouseButton1Click:Connect(function()
        for _,t in pairs(tabs) do
            t.page.Visible=false; t.button.BackgroundColor3=Color3.fromRGB(40,40,48); t.button.TextColor3=C.dim
        end
        page.Visible=true; b.BackgroundColor3=C.acc; b.TextColor3=Color3.new(1,1,1)
    end)
    return page
end
local pCombat=addTab("⚔","combat")
local pMove  =addTab("🏃","move")
local pAnim  =addTab("🎭","anim")
local pEsp   =addTab("👁","esp")
local pMisc  =addTab("⚙","misc")
pCombat.Visible=true; tabs["combat"].button.BackgroundColor3=C.acc; tabs["combat"].button.TextColor3=Color3.new(1,1,1)

--========== 4. state ==========
local S = {
    killAura=false, kaRange=15, kaRemote="",
    autoParry=false, parryRemote="",
    hitbox=false, hitboxSize=6,
    aimlock=false,
    walk=16, jump=50, infJump=false, noclip=false, fly=false, flySpeed=60,
    animLoop=false, animSpeed=1,
    espBox=false, espName=false, espDist=false, chams=false, chamColor=Color3.fromRGB(255,60,120),
    fpsBoost=false,
}

local function getChar() return LP.Character or LP.CharacterAdded:Wait() end
local function getHum() local c=LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c=LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end

--========== 5. COMBAT ==========
-- KILL AURA: fires the game's own combat remote at targets in range.
-- generic names won't hit Violence District — put the real remote name in the input box,
-- and it fires as <remote>:FireServer(target) from ReplicatedStorage. args vary per game.
local function findRemote(name)
    if name=="" then return nil end
    for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
        if d:IsA("RemoteEvent") and d.Name==name then return d end
    end
    return nil
end

track(task.spawn(function()
    while task.wait(0.12) do
        if S.killAura then
            local myRoot=getRoot(); if not myRoot then continue end
            local rem=findRemote(S.kaRemote)
            if not rem then continue end
            for _, p in ipairs(Players:GetPlayers()) do
                if p~=LP then
                    local c=p.Character
                    local h=c and c:FindFirstChildOfClass("Humanoid")
                    local r=c and c:FindFirstChild("HumanoidRootPart")
                    if h and h.Health>0 and r and (r.Position-myRoot.Position).Magnitude<=S.kaRange then
                        pcall(function() rem:FireServer(p) end)
                        pcall(function() rem:FireServer(r) end)
                    end
                end
            end
        end
    end
end))

-- AUTO-PARRY: fires the game's parry/block remote on a short pulse. same story — name it.
track(task.spawn(function()
    while task.wait(0.06) do
        if S.autoParry and S.parryRemote~="" then
            local rem=findRemote(S.parryRemote)
            if rem then
                pcall(function() rem:FireServer(true) end)
                pcall(function() rem:FireServer() end)
            end
        end
    end
end))

-- HITBOX EXPANDER: visual + local-touch expansion. Server raycasts use real position, so this
-- widens local collision shapes only — useful against games that trust client hit detection.
local hitboxTracked={}
local function restoreHitboxes()
    for part, size in pairs(hitboxTracked) do pcall(function() part.Size=size end) end
    hitboxTracked={}
end
track(task.spawn(function()
    while task.wait(0.25) do
        if S.hitbox then
            for _, p in ipairs(Players:GetPlayers()) do
                if p~=LP then
                    local c=p.Character; if not c then continue end
                    for _, part in ipairs(c:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then
                            if not hitboxTracked[part] then hitboxTracked[part]=part.Size end
                            local s=S.hitboxSize
                            part.Size=Vector3.new(s,s,s); part.CanCollide=false
                        end
                    end
                end
            end
        elseif next(hitboxTracked) then
            restoreHitboxes()
        end
    end
end))

-- AIMLOCK: camera hold on nearest player in range.
track(RunService.RenderStepped:Connect(function()
    if S.aimlock then
        local cam=Workspace.CurrentCamera; local myRoot=getRoot()
        if cam and myRoot then
            local best, bd = nil, 500
            for _, p in ipairs(Players:GetPlayers()) do
                if p~=LP then
                    local c=p.Character
                    local h=c and c:FindFirstChildOfClass("Humanoid")
                    local r=c and c:FindFirstChild("HumanoidRootPart")
                    if h and h.Health>0 and r then
                        local d=(r.Position-myRoot.Position).Magnitude
                        if d<bd then best,bd=r,d end
                    end
                end
            end
            if best then
                cam.CFrame = CFrame.new(cam.CFrame.Position, best.Position + Vector3.new(0,2,0))
            end
        end
    end
end))

-- combat tab widgets
Slider(pCombat, "kill aura range", 5, 80, 15, function(v) S.kaRange=v end)
Toggle(pCombat, "kill aura (needs remote name)", false, function(v) S.killAura=v end)
Input(pCombat, "kill remote name (e.g. 'Attack')", function(v) S.kaRemote=v end)
Toggle(pCombat, "auto-parry / block", false, function(v) S.autoParry=v end)
Input(pCombat, "parry remote name", function(v) S.parryRemote=v end)
Slider(pCombat, "hitbox expander size", 2, 20, 6, function(v) S.hitboxSize=v end)
Toggle(pCombat, "hitbox expander (local)", false, function(v) S.hitbox=v end)
Toggle(pCombat, "aimlock (camera)", false, function(v) S.aimlock=v end)

--========== 6. MOVE ==========
local flyBody
local function startFly()
    local root=getRoot(); if not root then return end
    flyBody = Instance.new("BodyVelocity")
    flyBody.MaxForce=Vector3.new(1e5,1e5,1e5)
    flyBody.Velocity=Vector3.zero
    flyBody.Parent=root
end
local function stopFly()
    if flyBody then flyBody:Destroy(); flyBody=nil end
end

-- walkspeed / jump power keep alive
track(task.spawn(function()
    while task.wait(0.3) do
        local hum=getHum()
        if hum then
            if S.walk~=16 then hum.WalkSpeed=S.walk end
            if S.jump~=50 then hum.JumpPower=S.jump; hum.UseJumpPower=true end
        end
    end
end))

-- infinite jump
track(UIS.JumpRequest:Connect(function()
    if S.infJump then
        local hum=getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

-- noclip
track(RunService.Stepped:Connect(function()
    if S.noclip and LP.Character then
        for _, part in ipairs(LP.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide=false end
        end
    end
end))

-- fly — camera-relative via BodyVelocity on HRP
local function flyStep(dt)
    if not S.fly then return end
    local root=getRoot(); local cam=Workspace.CurrentCamera
    if not root or not cam then return end
    if not flyBody then startFly() return end
    local moveDir=Vector3.zero
    if IS_MOBILE then
        -- mobile: tap the joystick direction (thumbstick) — use player's Humanoid.MoveDirection
        local hum=getHum()
        if hum and hum.MoveDirection.Magnitude>0 then moveDir=hum.MoveDirection end
        -- up/down handled by two floating buttons created below
        moveDir = moveDir + (Workspace.CurrentCamera.CFrame.LookVector * (S.flyUp or 0))
    else
        local k=UIS:GetKeysPressed()
        for _, key in ipairs(k) do
            if key.KeyCode==Enum.KeyCode.W then moveDir=moveDir+cam.CFrame.LookVector end
            if key.KeyCode==Enum.KeyCode.S then moveDir=moveDir-cam.CFrame.LookVector end
            if key.KeyCode==Enum.KeyCode.A then moveDir=moveDir-cam.CFrame.RightVector*-1 end
            if key.KeyCode==Enum.KeyCode.D then moveDir=moveDir+cam.CFrame.RightVector end
            if key.KeyCode==Enum.KeyCode.Space then moveDir=moveDir+Vector3.new(0,1,0) end
        end
    end
    if moveDir.Magnitude>0 then
        flyBody.Velocity = moveDir.Unit * S.flySpeed
    else
        flyBody.Velocity = Vector3.zero
    end
end
track(RunService.RenderStepped:Connect(flyStep))
-- mobile fly up/down mini buttons
local flyUpBtn = Instance.new("TextButton")
flyUpBtn.Size=UDim2.new(0,56,0,56); flyUpBtn.Position=UDim2.new(1,-80,1,-150)
flyUpBtn.BackgroundColor3=C.acc; flyUpBtn.Text="↑"; flyUpBtn.TextColor3=Color3.new(1,1,1)
flyUpBtn.Font=Enum.Font.GothamBold; flyUpBtn.TextSize=24; flyUpBtn.Visible=false; flyUpBtn.Parent=gui; corner(flyUpBtn,28)
local flyDownBtn = flyUpBtn:Clone(); flyDownBtn.Text="↓"; flyDownBtn.Position=UDim2.new(1,-80,1,-80); flyDownBtn.Parent=gui
flyUpBtn.MouseButton1Down:Connect(function() S.flyUp=1 end)
flyUpBtn.MouseButton1Up:Connect(function() S.flyUp=0 end)
flyDownBtn.MouseButton1Down:Connect(function() S.flyUp=-1 end)
flyDownBtn.MouseButton1Up:Connect(function() S.flyUp=0 end)

Slider(pMove, "walk speed", 16, 200, 16, function(v) S.walk=v end)
Slider(pMove, "jump power", 50, 300, 50, function(v) S.jump=v end)
Toggle(pMove, "infinite jump", false, function(v) S.infJump=v end)
Toggle(pMove, "noclip", false, function(v) S.noclip=v end)
Toggle(pMove, "fly", false, function(v)
    S.fly=v
    flyUpBtn.Visible=v; flyDownBtn.Visible=v
    if not v then stopFly() end
end)
Slider(pMove, "fly speed", 20, 300, 60, function(v) S.flySpeed=v end)

--========== 7. ANIM ==========
-- plays animation IDs on your character. presets are well-known public Roblox library IDs;
-- "custom" input accepts any ID. loop + speed are wired.
local animTrack
local animator
local function getAnimator()
    local hum=getHum()
    if hum then
        animator = hum:FindFirstChildOfClass("Animator")
        if not animator then animator=Instance.new("Animator"); animator.Parent=hum end
    end
    return animator
end
local function playAnim(id)
    local anim=Instance.new("Animation")
    anim.AnimationId="rbxassetid://"..tostring(id)
    local a=getAnimator(); if not a then return end
    if animTrack then pcall(function() animTrack:Stop() end) end
    local ok,t = pcall(function() return a:LoadAnimation(anim) end)
    if ok and t then
        t.Looped=S.animLoop
        t:Play()
        t:AdjustSpeed(S.animSpeed)
        animTrack=t
    else
        notif("anim", "load failed for id "..id)
    end
end

local presets = {
    {"dance", 507771019},
    {"wave", 507770239},
    {"point", 507770453},
    {"laugh", 507770818},
    {"zombie", 616163682},
    {"ninja", 507771019},
}
for _, pr in ipairs(presets) do
    Button(pAnim, "▶ "..pr[1], function() playAnim(pr[2]) end)
end
Input(pAnim, "custom animation ID", function(v) if tonumber(v) then playAnim(tonumber(v)) end end)
Toggle(pAnim, "loop animations", false, function(v) S.animLoop=v; if animTrack then animTrack.Looped=v end end)
Slider(pAnim, "animation speed", 0.2, 3, 1, function(v) S.animSpeed=v; if animTrack then animTrack:AdjustSpeed(v) end end)
Button(pAnim, "stop animation", function() if animTrack then animTrack:Stop() end end)

--========== 8. ESP ==========
-- Boxes + names via BillboardGui frames (works on any executor).
-- Distance label via BillboardGui. Chams via Highlight (this is the clean one).
local espGui = Instance.new("ScreenGui"); espGui.Name="VD_ESP"; espGui.ResetOnSpawn=false
espGui.IgnoreGuiInset=true
if gethui then pcall(function() espGui.Parent=gethui() end) end
if not espGui.Parent then pcall(function() espGui.Parent=game:GetService("CoreGui") end) end
if not espGui.Parent then espGui.Parent=LP:WaitForChild("PlayerGui") end

local espTrack = {}  -- [player] = {billboard, highlight, nameLbl, distLbl}

local function makeBillboard(part)
    local bb=Instance.new("BillboardGui")
    bb.Size=UDim2.new(0,80,0,80); bb.StudsOffset=Vector3.new(0,3,0)
    bb.AlwaysOnTop=true; bb.Adornee=part; bb.Parent=espGui
    return bb
end

local function addEsp(p)
    if p==LP or espTrack[p] then return end
    local c=p.Character; if not c then return end
    local head=c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
    if not head then return end
    local bb=makeBillboard(head)
    local nameLbl=lbl(bb,"",UDim2.new(1,0,0,14),C.acc,true)
    nameLbl.TextSize=11; nameLbl.TextXAlignment=Enum.TextXAlignment.Center
    nameLbl.Position=UDim2.new(0,0,0,-14); nameLbl.Text=p.Name
    local distLbl=lbl(bb,"",UDim2.new(1,0,0,12),C.txt)
    distLbl.TextSize=10; distLbl.TextXAlignment=Enum.TextXAlignment.Center
    distLbl.Position=UDim2.new(0,0,1,2)
    local hl=Instance.new("Highlight"); hl.FillColor=S.chamColor
    hl.FillTransparency=0.5; hl.OutlineColor=S.chamColor; hl.OutlineTransparency=0
    hl.Adornee=c; hl.Enabled=false; hl.Parent=espGui
    espTrack[p]={bb=bb, hl=hl, nameLbl=nameLbl, distLbl=distLbl}
end

local function remEsp(p)
    local e=espTrack[p]; if not e then return end
    pcall(function() e.bb:Destroy(); e.hl:Destroy() end)
    espTrack[p]=nil
end

track(Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() task.wait(1); if S.espBox or S.espName or S.chams then addEsp(p) end end)
end))
track(Players.PlayerRemoving:Connect(remEsp))
for _,p in ipairs(Players:GetPlayers()) do addEsp(p) end

track(RunService.RenderStepped:Connect(function()
    local myRoot=getRoot()
    for p, e in pairs(espTrack) do
        if not p.Character or not p.Character.Parent then remEsp(p) continue end
        local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not root then e.bb.Enabled=false; e.hl.Enabled=false continue end
        e.bb.Enabled = S.espName or S.espDist
        e.hl.Enabled = S.chams
        e.hl.FillColor = S.chamColor; e.hl.OutlineColor = S.chamColor
        e.nameLbl.Visible = S.espName
        e.distLbl.Visible = S.espDist and myRoot ~= nil
        if S.espDist and myRoot then
            e.distLbl.Text = math.floor((root.Position-myRoot.Position).Magnitude).."m"
        end
    end
end))

Toggle(pEsp, "ESP names", false, function(v) S.espName=v; if v then for _,p in ipairs(Players:GetPlayers()) do addEsp(p) end end end)
Toggle(pEsp, "ESP distance", false, function(v) S.espDist=v end)
Toggle(pEsp, "chams / highlight", false, function(v) S.chams=v; if v then for _,p in ipairs(Players:GetPlayers()) do addEsp(p) end end end)
Input(pEsp, "cham color (r,g,b)", function(v)
    local r,g,b = v:match("(%d+)[,%s]+(%d+)[,%s]+(%d+)")
    if r then S.chamColor=Color3.fromRGB(tonumber(r),tonumber(g),tonumber(b)) end
end)

--========== 9. MISC ==========
-- FPS booster / texture remover: reduces global lighting + removes casted shadows + kills decals.
-- reversible — originals cached.
local fpsCache={}
local function fpsOn()
    if next(fpsCache) then return end
    fpsCache.Shadow = Lighting.GlobalShadows
    Lighting.GlobalShadows = false
    fpsCache.Quality = Lighting.EnvironmentDiffuseScale or 1
    pcall(function() Lighting.EnvironmentDiffuseScale = 0.1 end)
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("Decal") or inst:IsA("Texture") then
            if inst.Transparency < 1 then fpsCache[inst]=inst.Transparency; inst.Transparency=1 end
        elseif inst:IsA("BasePart") and inst.CastShadow then
            fpsCache[inst]=true; inst.CastShadow=false
        end
    end
end
local function fpsOff()
    if not next(fpsCache) then return end
    for k,v in pairs(fpsCache) do
        if k==Lighting then Lighting.GlobalShadows=v
        elseif k:IsA("Decal") or k:IsA("Texture") then k.Transparency=v
        elseif k:IsA("BasePart") then k.CastShadow=true end
    end
    fpsCache={}
    pcall(function() Lighting.GlobalShadows=true end)
end
Toggle(pMisc, "fps booster / texture remover", false, function(v) if v then fpsOn() else fpsOff() end end)

Button(pMisc, "server hop (random)", function()
    local servers = {}
    local ok, pages = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
    end)
    if not ok or not pages or not pages.data then notif("hop","failed") return end
    for _, sv in ipairs(pages.data) do
        if sv.playing < sv.maxPlayers and sv.id ~= game.JobId then table.insert(servers, sv.id) end
    end
    if #servers==0 then notif("hop","no open servers") return end
    TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(#servers)])
end)

Button(pMisc, "rejoin", function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
end)

Button(pMisc, "destroy gui (wipe everything)", function()
    fpsOff()
    restoreHitboxes()
    if flyBody then flyBody:Destroy() end
    if animTrack then pcall(function() animTrack:Stop() end) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns={}
    for p,_ in pairs(espTrack) do remEsp(p) end
    if flyUpBtn then flyUpBtn:Destroy() end
    if flyDownBtn then flyDownBtn:Destroy() end
    gui:Destroy(); espGui:Destroy()
    notif("VD", "wiped")
end, true)

-- first-boot notice
notif("VD loaded", IS_MOBILE and "tap VD button" or "tap VD button")
