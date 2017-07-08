function getHeliControllerIndexByOwner(p)
	if global.heliControllers then
		for i, curController in ipairs(global.heliControllers) do
			if curController.owner == p then
				return i
			end
		end
	end
end

function getHeliControllerByOwner(p)
	local i = getHeliControllerIndexByowner(p)
	if i then return global.heliControllers[i] end
end

heliController = 
{
	new = function(player, heli, targetPosition)
		local obj = 
		{
			valid = true,

			owner = player,
			driver = game.surfaces[1].create_entity{name = "player", force = player.force, position = player.position},
			heli = heli,
			targetPos = targetPosition,

			curState = heliController.getUp,
			stateChanged = true,
		}

		heli.baseEnt.passenger = obj.driver

		return setmetatable(obj, {__index = heliController})
	end,

	destroy = function(self)
		self.valid = false
	end,

	OnTick = function(self)
		local old = self.curState
		self:curState()

		if old == self.curState then
			self.stateChanged = false
		else
			self.stateChanged = true
		end
	end,

	changeState = function(self, newState)
		self.curState = newState
	end,

	setRidingState = function(self, acc, dir)
		if not acc then
			acc = self.driver.riding_state.acceleration
		end

		if not dir then
			dir = self.driver.riding_state.direction
		end

		self.driver.riding_state = {acceleration = acc, direction = dir}
	end,

	holdSpeed = function(self, speed)
		local dir = self.driver.riding_state.direction

		if math.abs(1 - (self.heli.baseEnt.speed / speed)) < 0.05 then
			self.heli.baseEnt.speed = speed
		else

			if self.heli.baseEnt.speed > speed then
				self:setRidingState(defines.riding.acceleration.braking)
			else
				self:setRidingState(defines.riding.acceleration.accelerating)
			end
		end
	end,

	getTargetOrientation = function(self)
		local curPos = self.heli.baseEnt.position

		local vec = {x = self.targetPos.x - curPos.x, y = curPos.y - self.targetPos.y}
		local len = math.sqrt(vec.x ^ 2 + vec.y ^ 2)

		vec.x = vec.x / len
		vec.y = vec.y / len


		local angle = math.atan2(vec.y, vec.x)
		self.targetOrient = 1.25 - (angle / (2 * math.pi))
		if self.targetOrient > 1 then self.targetOrient = self.targetOrient - 1 end
	end,

	getSteeringToTargetOrientation = function(self)
		local curOrient = self.heli.baseEnt.orientation

		if math.abs(self.targetOrient - curOrient) < 0.02 then
			return defines.riding.direction.straight
		else
			local deltaLeft = 0
			local deltaRight = 0

			if self.targetOrient < curOrient then
				deltaLeft = curOrient - self.targetOrient
				deltaRight = 1 - curOrient + self.targetOrient
			else
				deltaLeft = curOrient + 1 - self.targetOrient
				deltaRight = self.targetOrient - curOrient
			end

			if deltaLeft < deltaRight then
				return defines.riding.direction.left
			else
				return defines.riding.direction.right
			end
		end
	end,

	------------- states ---------------
	getUp = function(self)
		if not self.heli.goUp then
			self.heli:OnUp()
		elseif self.heli.height >= 5 then
			self:changeState(self.orientToTarget)
		end
	end,

	orientToTarget = function(self)
		if self.stateChanged then
			self.targetOrientation = self:getTargetOrientation()
		else
			local dir = self:getSteeringToTargetOrientation()

			self:setRidingState(defines.riding.acceleration.nothing, dir)

			if dir == defines.riding.direction.straight then
				self:changeState(self.moveToTarget)
			end
		end
	end,

	moveToTarget = function(self)
		local dist = getDistance(self.heli.baseEnt.position, self.targetPos)

		if self.stateChanged then
			self.updateOrientationCooldown = 30
		end
		--printA(self.heli.baseEnt.speed)

		self.updateOrientationCooldown = self.updateOrientationCooldown - 1
		if self.updateOrientationCooldown <  3 then
			if self.updateOrientationCooldown == 0 then
				self.updateOrientationCooldown = 30
			end

			self.targetOrientation = self:getTargetOrientation()
			self:setRidingState(nil, self:getSteeringToTargetOrientation())
		else
			self.driver.riding_state.direction = defines.riding.direction.straight
		end

		if dist < 150 then
			self:holdSpeed(dist/100 - 0.025)

			if dist <= 4 and self.heli.baseEnt.speed == 0 then
				self:setRidingState(defines.riding.acceleration.braking)
				self:changeState(self.land)
			end
			--printA("hold" , dist/150 - 0.025)
		else
			--local dir = self.driver.riding_state.direction
			--printA("accelerate")
			self:setRidingState(defines.riding.acceleration.accelerating)
		end
	end,

	land = function(self)
		self.heli:OnDown()
		self.driver.destroy()
		self:destroy()
	end,
	------------------------------------
}