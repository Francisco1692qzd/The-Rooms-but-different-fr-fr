-- ============================================
-- CAMERA SHAKER - Direct Script Version
-- Just run this and it works immediately
-- ============================================

-- Create the CameraShaker object directly
local CameraShaker = {}
CameraShaker.__index = CameraShaker

-- ============================================
-- CameraShakeInstance Class
-- ============================================
local CameraShakeInstance = {}
CameraShakeInstance.__index = CameraShakeInstance

CameraShakeInstance.CameraShakeState = {
	FadingIn = 0;
	FadingOut = 1;
	Sustained = 2;
	Inactive = 3;
}

function CameraShakeInstance.new(magnitude, roughness, fadeInTime, fadeOutTime)
	fadeInTime = fadeInTime or 0
	fadeOutTime = fadeOutTime or 0
	
	local self = setmetatable({
		Magnitude = magnitude;
		Roughness = roughness;
		PositionInfluence = Vector3.new(0, 0, 0);
		RotationInfluence = Vector3.new(0, 0, 0);
		DeleteOnInactive = true;
		roughMod = 1;
		magnMod = 1;
		fadeOutDuration = fadeOutTime;
		fadeInDuration = fadeInTime;
		sustain = (fadeInTime > 0);
		currentFadeTime = (fadeInTime > 0 and 0 or 1);
		tick = Random.new():NextNumber(-100, 100);
		_camShakeInstance = true;
	}, CameraShakeInstance)
	
	return self
end

function CameraShakeInstance:UpdateShake(dt)
	local _tick = self.tick
	local currentFadeTime = self.currentFadeTime
	
	local offset = Vector3.new(
		math.noise(_tick, 0) * 0.5,
		math.noise(0, _tick) * 0.5,
		math.noise(_tick, _tick) * 0.5
	)
	
	if self.fadeInDuration > 0 and self.sustain then
		if currentFadeTime < 1 then
			currentFadeTime = currentFadeTime + (dt / self.fadeInDuration)
		elseif self.fadeOutDuration > 0 then
			self.sustain = false
		end
	end
	
	if not self.sustain then
		currentFadeTime = currentFadeTime - (dt / self.fadeOutDuration)
	end
	
	if self.sustain then
		self.tick = _tick + (dt * self.Roughness * self.roughMod)
	else
		self.tick = _tick + (dt * self.Roughness * self.roughMod * currentFadeTime)
	end
	
	self.currentFadeTime = currentFadeTime
	
	return offset * self.Magnitude * self.magnMod * currentFadeTime
end

function CameraShakeInstance:StartFadeOut(fadeOutTime)
	if fadeOutTime == 0 then
		self.currentFadeTime = 0
	end
	self.fadeOutDuration = fadeOutTime
	self.fadeInDuration = 0
	self.sustain = false
end

function CameraShakeInstance:StartFadeIn(fadeInTime)
	if fadeInTime == 0 then
		self.currentFadeTime = 1
	end
	self.fadeInDuration = fadeInTime or self.fadeInDuration
	self.fadeOutDuration = 0
	self.sustain = true
end

function CameraShakeInstance:GetState()
	if self:IsFadingIn() then
		return CameraShakeInstance.CameraShakeState.FadingIn
	elseif self:IsFadingOut() then
		return CameraShakeInstance.CameraShakeState.FadingOut
	elseif self:IsShaking() then
		return CameraShakeInstance.CameraShakeState.Sustained
	else
		return CameraShakeInstance.CameraShakeState.Inactive
	end
end

function CameraShakeInstance:IsShaking()
	return (self.currentFadeTime > 0 or self.sustain)
end

function CameraShakeInstance:IsFadingOut()
	return ((not self.sustain) and self.currentFadeTime > 0)
end

function CameraShakeInstance:IsFadingIn()
	return (self.currentFadeTime < 1 and self.sustain and self.fadeInDuration > 0)
end

-- ============================================
-- Presets
-- ============================================
local function getPreset(name)
	local presets = {
		Bump = function()
			local c = CameraShakeInstance.new(2.5, 4, 0.1, 0.75)
			c.PositionInfluence = Vector3.new(0.15, 0.15, 0.15)
			c.RotationInfluence = Vector3.new(1, 1, 1)
			return c
		end;
		
		Explosion = function()
			local c = CameraShakeInstance.new(5, 10, 0, 1.5)
			c.PositionInfluence = Vector3.new(0.25, 0.25, 0.25)
			c.RotationInfluence = Vector3.new(4, 1, 1)
			return c
		end;
		
		Earthquake = function()
			local c = CameraShakeInstance.new(0.6, 3.5, 2, 10)
			c.PositionInfluence = Vector3.new(0.25, 0.25, 0.25)
			c.RotationInfluence = Vector3.new(1, 1, 4)
			return c
		end;
		
		BadTrip = function()
			local c = CameraShakeInstance.new(10, 0.15, 5, 10)
			c.PositionInfluence = Vector3.new(0, 0, 0.15)
			c.RotationInfluence = Vector3.new(2, 1, 4)
			return c
		end;
		
		HandheldCamera = function()
			local c = CameraShakeInstance.new(1, 0.25, 5, 10)
			c.PositionInfluence = Vector3.new(0, 0, 0)
			c.RotationInfluence = Vector3.new(1, 0.5, 0.5)
			return c
		end;
		
		Vibration = function()
			local c = CameraShakeInstance.new(0.4, 20, 2, 2)
			c.PositionInfluence = Vector3.new(0, 0.15, 0)
			c.RotationInfluence = Vector3.new(1.25, 0, 4)
			return c
		end;
		
		RoughDriving = function()
			local c = CameraShakeInstance.new(1, 2, 1, 1)
			c.PositionInfluence = Vector3.new(0, 0, 0)
			c.RotationInfluence = Vector3.new(1, 1, 1)
			return c
		end;
	}
	
	local f = presets[name]
	if f then
		return f()
	end
	return nil
end

-- ============================================
-- Main CameraShaker Class
-- ============================================
function CameraShaker.new(renderPriority, callback)
	local self = setmetatable({
		_running = false;
		_renderName = "CameraShaker";
		_renderPriority = renderPriority or 1000;
		_camShakeInstances = {};
		_removeInstances = {};
		_callback = callback;
	}, CameraShaker)
	
	return self
end

function CameraShaker:Start()
	if self._running then return end
	self._running = true
	
	local selfRef = self
	game:GetService("RunService"):BindToRenderStep(self._renderName, self._renderPriority, function(dt)
		local cf = selfRef:Update(dt)
		if selfRef._callback then
			selfRef._callback(cf)
		end
	end)
end

function CameraShaker:Stop()
	if not self._running then return end
	game:GetService("RunService"):UnbindFromRenderStep(self._renderName)
	self._running = false
end

function CameraShaker:StopSustained(duration)
	for _,c in pairs(self._camShakeInstances) do
		if c.fadeOutDuration == 0 then
			c:StartFadeOut(duration or c.fadeInDuration)
		end
	end
end

function CameraShaker:Update(dt)
	local posAddShake = Vector3.new(0, 0, 0)
	local rotAddShake = Vector3.new(0, 0, 0)
	
	local instances = self._camShakeInstances
	self._removeInstances = {}
	
	for i = 1,#instances do
		local c = instances[i]
		local state = c:GetState()
		
		if state == CameraShakeInstance.CameraShakeState.Inactive and c.DeleteOnInactive then
			table.insert(self._removeInstances, i)
		elseif state ~= CameraShakeInstance.CameraShakeState.Inactive then
			local shake = c:UpdateShake(dt)
			posAddShake = posAddShake + (shake * c.PositionInfluence)
			rotAddShake = rotAddShake + (shake * c.RotationInfluence)
		end
	end
	
	for i = #self._removeInstances,1,-1 do
		local instIndex = self._removeInstances[i]
		table.remove(instances, instIndex)
	end
	
	return CFrame.new(posAddShake) * 
			CFrame.Angles(0, math.rad(rotAddShake.Y), 0) * 
			CFrame.Angles(math.rad(rotAddShake.X), 0, math.rad(rotAddShake.Z))
end

function CameraShaker:Shake(shakeInstance)
	if not (type(shakeInstance) == "table" and shakeInstance._camShakeInstance) then
		error("ShakeInstance must be of type CameraShakeInstance")
	end
	table.insert(self._camShakeInstances, shakeInstance)
	return shakeInstance
end

function CameraShaker:ShakeSustain(shakeInstance)
	if not (type(shakeInstance) == "table" and shakeInstance._camShakeInstance) then
		error("ShakeInstance must be of type CameraShakeInstance")
	end
	table.insert(self._camShakeInstances, shakeInstance)
	shakeInstance:StartFadeIn(shakeInstance.fadeInDuration)
	return shakeInstance
end

function CameraShaker:ShakeOnce(magnitude, roughness, fadeInTime, fadeOutTime, posInfluence, rotInfluence)
	local shakeInstance = CameraShakeInstance.new(magnitude, roughness, fadeInTime, fadeOutTime)
	shakeInstance.PositionInfluence = posInfluence or Vector3.new(0, 0, 0)
	shakeInstance.RotationInfluence = rotInfluence or Vector3.new(1, 1, 1)
	table.insert(self._camShakeInstances, shakeInstance)
	return shakeInstance
end

function CameraShaker:StartShake(magnitude, roughness, fadeInTime, posInfluence, rotInfluence)
	local shakeInstance = CameraShakeInstance.new(magnitude, roughness, fadeInTime)
	shakeInstance.PositionInfluence = posInfluence or Vector3.new(0, 0, 0)
	shakeInstance.RotationInfluence = rotInfluence or Vector3.new(1, 1, 1)
	shakeInstance:StartFadeIn(fadeInTime or 0)
	table.insert(self._camShakeInstances, shakeInstance)
	return shakeInstance
end

-- ============================================
-- ACTUALLY USE IT NOW
-- ============================================

print("🎥 Starting Camera Shaker...")

-- Get the camera
local camera = workspace.CurrentCamera
if not camera then
	warn("No camera found! Waiting...")
	task.wait(1)
	camera = workspace.CurrentCamera
end

-- Create the shaker
local shaker = CameraShaker.new(1000, function(shakeCFrame)
	if camera then
		camera.CFrame = camera.CFrame * shakeCFrame
	end
end)

-- Start shaking
shaker:Start()
print("✅ Camera Shaker is running!")

-- ============================================
-- COMMANDS YOU CAN USE:
-- ============================================

--[[
-- SHAKE ONCE (Quick shake)
shaker:ShakeOnce(3, 1, 0.2, 1.5)

-- USE PRESETS
shaker:Shake(getPreset("Explosion"))
shaker:Shake(getPreset("Earthquake"))
shaker:Shake(getPreset("Bump"))

-- SUSTAINED SHAKE (Keeps going)
local quake = getPreset("Earthquake")
shaker:ShakeSustain(quake)

-- STOP SUSTAINED
shaker:StopSustained(1)

-- STOP EVERYTHING
shaker:Stop()
--]]

-- ============================================
-- DEMO: Different shakes every 2 seconds
-- ============================================

--[[
local presetsList = {"Explosion", "Earthquake", "Bump", "Vibration", "HandheldCamera", "RoughDriving"}
local index = 1

game:GetService("RunService").Heartbeat:Connect(function()
	if not shaker._running then return end
end)

-- Demo loop
task.spawn(function()
	while shaker._running do
		local presetName = presetsList[index]
		print("💥 Shaking with:", presetName)
		shaker:Shake(getPreset(presetName))
		
		index = index + 1
		if index > #presetsList then
			index = 1
		end
		
		task.wait(2)
	end
end)

print("🎬 Demo running! Changing shake every 2 seconds.")
print("🛑 To stop: shaker:Stop()")
--]]
