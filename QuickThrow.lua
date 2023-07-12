-- Register the behaviour
behaviour("QuickThrow")

function QuickThrow:Awake()
	self.gameObject.name = "QuickThrow"

	self.weaponReturnListeners = {}
end

function QuickThrow:Start()
	-- Run when behaviour is created
	GameEvents.onActorSpawn.AddListener(self,"onActorSpawn")
	GameEvents.onActorDied.AddListener(self,"onActorDied")

	self.QuickSlotKey1 = string.lower(self.script.mutator.GetConfigurationString("QuickSlotKey1"))
	self.QuickSlotKey2 = string.lower(self.script.mutator.GetConfigurationString("QuickSlotKey2"))
	self.QuickSlotKey3 = string.lower(self.script.mutator.GetConfigurationString("QuickSlotKey3"))
	self.toggleThrowMode = string.lower(self.script.mutator.GetConfigurationString("toggleThrowMode"))
	self.ShowHUD = self.script.mutator.GetConfigurationBool("ShowHUD")
	self.ThrowSpeed = self.script.mutator.GetConfigurationFloat("ThrowSpeed")
	self.updateDisplayPerFrame = self.script.mutator.GetConfigurationBool("updateDisplayPerFrame")

	self.targets.Slot1GO.SetActive(false)
	self.targets.Slot2GO.SetActive(false)
	self.targets.Slot3GO.SetActive(false)

	self.longThrow = false

	self:init()

	self.slots = {}
	self.txtCounts = {}
	self.sprites = {}
	self.keyBindTxts = {}
	self.keybinds = {}

	self.slots[0] = self.targets.Slot1GO
	self.slots[1] = self.targets.Slot2GO
	self.slots[2] = self.targets.Slot3GO

	self.txtCounts[0] = self.targets.Slot1Count
	self.txtCounts[1] = self.targets.Slot2Count
	self.txtCounts[2] = self.targets.Slot3Count

	self.sprites[0] = self.targets.Slot1Sprite
	self.sprites[1] = self.targets.Slot2Sprite
	self.sprites[2] = self.targets.Slot3Sprite

	self.keyBindTxts[0] = self.targets.Slot1KeyBind
	self.keyBindTxts[1] = self.targets.Slot2KeyBind
	self.keyBindTxts[2] = self.targets.Slot3KeyBind

	self.keybinds[0] = self.QuickSlotKey1
	self.keybinds[1] = self.QuickSlotKey2
	self.keybinds[2] = self.QuickSlotKey3

	self.throwModeText = self.targets.ThrowModeText

	self.targets.Canvas.SetActive(false)

	self.HotReloadKey = self.script.mutator.GetConfigurationString("HotReloadKey")

	--Compat
	self.hasCheckedForCompat = false
	self.playerVoice = nil
	self.enhancedHealth = nil
	self.isLocked = false


	local blackListString = self.script.mutator.GetConfigurationString("BlackList") .. ",THUMPER,C4"
	self.blackList = {}
	local blackListCount = 1
	for word in string.gmatch(blackListString, '([^,]+)') do
		print("<color=red>[Quick Throw] Added to black list: " .. word .. "</color>")
		self.blackList[blackListCount] = string.lower(word)
		blackListCount = blackListCount + 1
	end

	local tagsToAllow = self.script.mutator.GetConfigurationString("Tags")
	self.tags = {}
	local tagCount = 1
	for word in string.gmatch(tagsToAllow, '([^,]+)') do
		print("<color=green>[Quick Throw] Added to tags: " .. word .. "</color>")
		self.tags[tagCount] = string.lower(word)
		tagCount = tagCount + 1
	end

	local whiteListString = self.script.mutator.GetConfigurationString("WhiteList") .. ",Armor,Stim Shot,Bandage"
	self.whiteList = {}
	local whiteListCount = 1
	for word in string.gmatch(whiteListString, '([^,]+)') do
		print("<color=green>[Quick Throw] Added to white list: " .. word .. "</color>")
		self.whiteList[whiteListCount] = string.lower(word)
		whiteListCount = whiteListCount + 1
	end
	
	self.doLoadOutCheck = true
	self.script.AddValueMonitor("monitorHUDVisibility", "onHUDVisibilityChange")
	self.script.StartCoroutine(self:FindLoadoutChanger())
	
	self.URM = GameObject.find("RecoilPrefab(Clone)")
	self.isUsingURM = (self.URM ~= nil)

	if (self.isUsingURM) then
		self.URM = self.URM.gameObject.GetComponent(ScriptedBehaviour).self
		print("Using URM")
	else
		print("Not using URM")
	end

	

	print("<color=aqua>[Quick Throw] Initialized v2.0.0</color>")
end

function QuickThrow:init()
	self.throwableCount = 0
	self.isThrowing = false
	self.throwables = {}
	self.throwableToUse = nil
	self.curthrowable = nil

	self.lastActiveWeapon = nil
	self.lastActiveWeaponIndex = 0
	self.lastActiveWeaponAmmo = 0
	self.lastActiveWeaponMaxAmmo = 0
	self.lastActiveWeaponAmmoReserve = 0
	self.lastActiveWeaponMaxReserve = 0
	self.lastActiveWeaponAltWeaponData = {}

	self.timer = 0

	self.cooldown = false

	self.hasThrown = false
	self.wasInterrupted = false
	self.isSpawnUiOpen = false
end

function QuickThrow:Update()
	-- Run every frame

	if(Input.GetKeyDown(string.lower(self.HotReloadKey)) and self.isThrowing == false) then
		self:evaluateLoadout()
	end
	
	if(self.hasCheckedForCompat) then
		if (SpawnUi.isOpen and self.isSpawnUiOpen == false) then
			self.isSpawnUiOpen = true
			for i = 0, 2, 1 do
				self.slots[i].SetActive(false)
			end
		elseif (SpawnUi.isOpen == false and self.isSpawnUiOpen and not Player.actor.isDead and #self.throwables > 0) then
			self.isSpawnUiOpen = false
			for i = 0, #self.throwables, 1 do
				self.slots[#self.throwables-i].SetActive(self.ShowHUD)
			end
		end
	end

	if(SpawnUi.isOpen == false and self.isThrowing == false and Player.actor.isFallenOver == false and Player.actor.isInWater == false and self.throwableCount > 0 and Player.actor.isSprinting == false and not self.isLocked) then
		if Input.GetKeyDown(self.QuickSlotKey1) then
			self:Throw(0)
		elseif Input.GetKeyDown(self.QuickSlotKey2) and self.throwableCount > 1 then
			self:Throw(1)
		elseif Input.GetKeyDown(self.QuickSlotKey3) and self.throwableCount > 2 then
			self:Throw(2)
		end
	end

	if Input.GetKeyDown(self.toggleThrowMode) then
		self.longThrow = not self.longThrow
		self.throwModeText.gameObject.SetActive(self.longThrow)
	end

	if(self.hasThrown and self.isThrowing) then
		self.timer = self.timer + (0.1 * Time.deltaTime)
	end

	if self.timer >= 0.025 and self.cooldown == true and not self.wasInterrupted then
		--print("<color=yellow>[Quick Throw] Return 1 (ignore this if everything is working fine)</color>")
		self:ReturnWeapon(true)
	elseif (self.wasInterrupted and self.isThrowing and Player.actor.isFallenOver == false) then
		self:ReturnWeapon(true)
	elseif (Player.actor.activeWeapon ~= self.curthrowable) and self.isThrowing  then
		--print("<color=yellow>[Quick Throw] Return 2 (ignore this if everything is working fine)</color>")
		self:ReturnWeapon(false)
	elseif ((Player.actor.isFallenOver or Player.actor.isInWater) and self.isThrowing) then
		self.wasInterrupted = true
	end

	if(self.throwableCount > 0 and (Player.actor.isResupplyingAmmo or self.updateDisplayPerFrame) and self.ShowHUD and not self.isLocked) then
		self:UpdateDisplay()
	end
end

function QuickThrow:UpdateDisplay()
	for i = 0, #self.throwables, 1 do
		if self.throwables[i].spareAmmo > 0 then
			self.txtCounts[#self.throwables-i].color = Color.white
			self.txtCounts[#self.throwables-i].text = self.throwables[i].ammo + self.throwables[i].spareAmmo
		else
			if(self.throwables[i].ammo > 0) then
				self.txtCounts[#self.throwables-i].color = Color.white
				self.txtCounts[#self.throwables-i].text = self.throwables[i].ammo
			else
				self.txtCounts[#self.throwables-i].color = Color.red
				self.txtCounts[#self.throwables-i].text = 0
			end
		end
	end
end

function QuickThrow:Throw(index)
	self.throwableToUse = nil
	if(self.throwables[index].spareAmmo > 0 or self.throwables[index].ammo > 0) or self.throwables[index].weaponEntry.name == "Armor" then
		self.throwableToUse = self.throwables[index]
	end
	if(self.throwableToUse and self.throwableToUse ~= Player.actor.activeWeapon) then

		self.hasThrown = false

		self.lastActiveWeapon = Player.actor.activeWeapon.weaponEntry
		self.lastActiveWeaponIndex = Player.actor.activeWeapon.slot
		self.lastActiveWeaponMaxAmmo = Player.actor.activeWeapon.maxAmmo
		self.lastActiveWeaponAmmo = Player.actor.activeWeapon.ammo
		self.lastActiveWeaponAmmoReserve = Player.actor.activeWeapon.spareAmmo
		self.lastActiveWeaponMaxReserve = Player.actor.activeWeapon.maxSpareAmmo
		
		self.lastActiveWeaponAltWeaponData = {}
		for i = 1, #Player.actor.activeWeapon.alternativeWeapons, 1 do
			local altWeaponData = {}
			altWeaponData.ammo = Player.actor.activeWeapon.alternativeWeapons[i].ammo
			altWeaponData.spareAmmo = Player.actor.activeWeapon.alternativeWeapons[i].spareAmmo
			self.lastActiveWeaponAltWeaponData[i] = altWeaponData
		end

		local isAiming = Player.actor.activeWeapon.isAiming

		Player.actor.EquipNewWeaponEntry(self.throwableToUse.weaponEntry, self.lastActiveWeaponIndex, true)
		if self.enhancedHealth and Player.actor.activeWeapon.weaponEntry.name == "Bandage" then
			self.enhancedHealth.self:addBandageListener(Player.actor.activeWeapon)
		end
		Player.actor.activeWeapon.spareAmmo = -1
		Player.actor.activeWeapon.maxSpareAmmo = -1
		if self.enhancedHealth and self.enhancedHealth.self.doQuickAnim and Player.actor.activeWeapon.weaponEntry.name == "Stim Shot" then
			Player.actor.activeWeapon.animator.SetTrigger("quickThrow")
		else
			self.script.StartCoroutine(self:UseUnholsterTimeDelay())
		end
		self.timer = 0
		self.isThrowing = true;
		self.cooldown = true
		self.curthrowable = Player.actor.activeWeapon
		self.curthrowable.onFire.AddListener(self,"onFire")

		if(self.globalVarsScript) then
			self.globalVarsScript.disableFirstDraw = true
		end
	end
end

function QuickThrow:UseUnholsterTimeDelay()
	return function()
		coroutine.yield(WaitForSeconds(Player.actor.activeWeapon.unholsterTime/2.5))
		if (Player.actor.activeWeapon == self.curthrowable) then
			Player.actor.activeWeapon.animator.speed = self.ThrowSpeed
			Player.actor.activeWeapon.animator.SetTrigger("throw")
			if isAiming or self.longThrow then
				Player.actor.activeWeapon.animator.SetBool("aim", true)
			end
		end
	end
end

function QuickThrow:ReturnWeapon(forceEquip)
	if self.curthrowable == nil then return end
	
	print("<color=yellow>[Quick Throw] returning weapon: " .. self.lastActiveWeapon.name .. " to slot " .. self.lastActiveWeaponIndex .. "</color>")
	 
	local returnedWeapon = Player.actor.EquipNewWeaponEntry(self.lastActiveWeapon, self.lastActiveWeaponIndex, forceEquip)

	Player.actor.weaponSlots[self.lastActiveWeaponIndex+1].maxAmmo = self.lastActiveWeaponMaxAmmo
	Player.actor.weaponSlots[self.lastActiveWeaponIndex+1].ammo = self.lastActiveWeaponAmmo
	Player.actor.weaponSlots[self.lastActiveWeaponIndex+1].maxSpareAmmo = self.lastActiveWeaponMaxReserve
	Player.actor.weaponSlots[self.lastActiveWeaponIndex+1].spareAmmo = self.lastActiveWeaponAmmoReserve
	
	
	self.script.StartCoroutine(self:ApplyAltWeaponAmmo(self.lastActiveWeaponIndex))

	if forceEquip then
		if returnedWeapon then
			returnedWeapon.animator.SetTrigger("unholster")
		end
	end

	if self.enhancedHealth and returnedWeapon.weaponEntry.name == "Bandage" then
		self.enhancedHealth.self:addBandageListener(Player.actor.activeWeapon)
	end

	if self.playerVoice then
		self.playerVoice.self:FindGrenades()
	end

	if self.lastActiveWeaponIndex > 1 then
		self:evaluateLoadout()
	end
	
	if self.isUsingURM then
		self.URM:AssignWeaponStats(returnedWeapon)
	end
	
	self.isThrowing = false
	self.cooldown = false
	self.curthrowable = nil
	self.hasThrown = false
	self.wasInterrupted = false

	self:InvokeWeaponReturnEvent(returnedWeapon)
end

function QuickThrow:ApplyAltWeaponAmmo(index)
	return function()
		coroutine.yield(WaitForSeconds(0.5))
		if(self.lastActiveWeaponIndex ~= index) then
			return
		end
		for i = 1, #Player.actor.weaponSlots[self.lastActiveWeaponIndex+1].alternativeWeapons, 1 do
			Player.actor.weaponSlots[self.lastActiveWeaponIndex+1].alternativeWeapons[i].ammo = self.lastActiveWeaponAltWeaponData[i].ammo
			Player.actor.weaponSlots[self.lastActiveWeaponIndex+1].alternativeWeapons[i].spareAmmo = self.lastActiveWeaponAltWeaponData[i].spareAmmo
		end
	end
end

function QuickThrow:isValidWeapon(weapon)
	for i, name in pairs(self.blackList) do
		if string.lower(weapon.weaponEntry.name) == name then 
			print("<color=red>[Quick Throw] " .. weapon.weaponEntry.name .. " is black listed.</color>") 
			return false
		end
	end
	for i, name in pairs(self.whiteList) do
		if string.lower(weapon.weaponEntry.name) == name then 
			print("<color=green>[Quick Throw] " .. weapon.weaponEntry.name .. " is whitelisted listed.</color>") 
			return true
		end
	end
	for y, tag in pairs(weapon.weaponEntry.tags) do
		print("<color=yellow>[Quick Throw] " .. weapon.weaponEntry.name .. " has tag " .. tag .. "</color>")
		for x, t in pairs(self.tags) do
			if t == string.lower(tag) then 
				return true 
			end
		end
	end
	return false
end

function QuickThrow:onFire()
	print("<color=green>[Quick Throw] Throw!</color>")
	if self.playerVoice then
		self.playerVoice.self:onThrow(self.throwableToUse.weaponEntry)
	end

	Player.actor.activeWeapon.ammo = 0

	self.hasThrown = true

	if(self.throwableToUse.spareAmmo > 0) then
		self.throwableToUse.spareAmmo = self.throwableToUse.spareAmmo - 1
	else
		self.throwableToUse.ammo = 0
	end

	self:UpdateDisplay()
end

function QuickThrow:onStandardThrow()
	self:UpdateDisplay()
end

function QuickThrow:onActorDied(actor,source,isSilent)
	if(actor.isPlayer) then
		--for i, throwable in pairs(self.throwables) do
		--	throwable.onFire.RemoveListener(self,"onStandardThrow")
		--end
		self:init()
		self.slots[0].SetActive(false)
		self.slots[1].SetActive(false)
		self.slots[2].SetActive(false)
		self.targets.Canvas.SetActive(false)

		if(self.globalVarsScript) then
			self.globalVarsScript.disableFirstDraw = false
		end
	end
end

function QuickThrow:checkForCompat()
	if self.playerVoice == nil then
		local playerVoiceObj = self.gameObject.Find("PlayerVoice")
		if playerVoiceObj then
			self.playerVoice = playerVoiceObj.GetComponent(ScriptedBehaviour)
			print("<color=green>[Quick Throw] Found player voice object.</color>")
		else
			print("<color=red>[Quick Throw] No player voice object found.</color>")
		end
	end

	if self.enhancedHealth == nil then
		local enhancedHealthObj = self.gameObject.Find("EnhancedHealth")
		if enhancedHealthObj then
			self.enhancedHealth = enhancedHealthObj.GetComponent(ScriptedBehaviour)
			print("<color=green>[Quick Throw] Found enhanced health object.</color>")
		else
			print("<color=red>[Quick Throw] No enhanced health object found.</color>")
		end
	end

	self.hasCheckedForCompat = true
end

function QuickThrow:evaluateLoadout()

	self.slots[0].SetActive(false)
	self.slots[1].SetActive(false)
	self.slots[2].SetActive(false)

	self.throwableCount = 0
	self.throwables = {}
	for i, weapon in pairs(Player.actor.weaponSlots) do
		if(self:isValidWeapon(weapon)) then
			weapon.onFire.AddListener(self,"onStandardThrow");
			self.throwables[self.throwableCount] = weapon
			self.throwableCount = self.throwableCount + 1
		end
	end
	if(self.throwableCount > 0) then
		for i = 0, #self.throwables, 1 do
			self.slots[#self.throwables-i].SetActive(self.ShowHUD)
			self.sprites[#self.throwables-i].sprite = self.throwables[i].uiSprite
			if string.find(self.keybinds[i], "mouse") then
				local num = nil
				for word in string.gmatch(self.keybinds[i], '%S+') do
					num = word
				end
				if num then
					self.keyBindTxts[#self.throwables-i].text = "M" .. num
					self.keyBindTxts[#self.throwables-i].fontSize = 10
				end
			else
				self.keyBindTxts[#self.throwables-i].text = self.keybinds[i]
				self.keyBindTxts[#self.throwables-i].fontSize = 14
			end
			self:UpdateDisplay()
		end
	end
end

function QuickThrow:FindLoadoutChanger()
	return function()
		coroutine.yield(WaitForSeconds(0.15))
		local loadOutChangerObj = self.gameObject.Find("LoadoutChangeScript(Clone)")
		if loadOutChangerObj then
			self.loadoutChanger = loadOutChangerObj.GetComponent(ScriptedBehaviour)
			self.loadoutChanger.self.button.GetComponent(Button).onClick.AddListener(self,"onOverlayClicked")
			print("<color=aqua>[Quick Throw] Loadout Changer mutator found.</color>")
		else
			print("<color=red>[Quick Throw] Loadout Changer mutator not found.</color>")
		end
	end
end

function QuickThrow:FindExtasConfigs()
	return function()
		if(self.globalVarsGameObject == nil) then
			coroutine.yield(WaitForSeconds(1.5))
			self.globalVarsGameObject = GameObject.Find("PPBGlobalVarss(Clone)")
			if(self.globalVarsGameObject) then
				self.globalVarsScript = ScriptedBehaviour.GetScript(self.globalVarsGameObject.gameObject)
				print(tostring(self.globalVarsScript.disableFirstDraw))
			end
		end
	end
end

function QuickThrow:onOverlayClicked()
	if not Player.actor.isDead then
		self.script.StartCoroutine(self:delayedEvaluate())
	end
end

function QuickThrow:delayedEvaluate()
	return function()
		coroutine.yield(WaitForSeconds(0.1))
		self:evaluateLoadout()
	end
end

function QuickThrow:doDelayedEvaluate()
	self.script.StartCoroutine(self:delayedEvaluate())
end

function QuickThrow:onActorSpawn(actor)
	if actor.isPlayer then
		self:init()
		self.targets.Canvas.SetActive(GameManager.hudPlayerEnabled)
		if(self.hasCheckedForCompat == false) then
			self:checkForCompat()
		end
		self:evaluateLoadout()
		if(self.globalVarsGameObject == nil) then
			self.script.StartCoroutine(self:FindExtasConfigs())
		end
	end
end

function QuickThrow:monitorHUDVisibility()
	return GameManager.hudPlayerEnabled
end

function QuickThrow:onHUDVisibilityChange()
	self.targets.Canvas.SetActive(not Player.actor.isDead and GameManager.hudPlayerEnabled)
end

function QuickThrow:ReplaceHUD(newHUD)
	self.slots = {}
	self.txtCounts = {}
	self.sprites = {}
	self.keyBindTxts = {}

	self.slots[0] = newHUD.slots[0]
	self.slots[1] = newHUD.slots[1]
	self.slots[2] = newHUD.slots[2]

	self.txtCounts[0] = newHUD.txtCounts[0]
	self.txtCounts[1] = newHUD.txtCounts[1]
	self.txtCounts[2] = newHUD.txtCounts[2]

	self.sprites[0] = newHUD.sprites[0]
	self.sprites[1] = newHUD.sprites[1]
	self.sprites[2] = newHUD.sprites[2]

	self.keyBindTxts[0] = newHUD.keyBindTxts[0]
	self.keyBindTxts[1] = newHUD.keyBindTxts[1]
	self.keyBindTxts[2] = newHUD.keyBindTxts[2]

	self.throwModeText = newHUD.throwModeText
end

function QuickThrow:SubscribeToWeaponReturnEvent(owner,func)
	self.weaponReturnListeners[owner] = func
end

function QuickThrow:UnsubscribeToWeaponReturnEvent(owner)
	self.weaponReturnListeners[owner] = nil
end

function QuickThrow:InvokeWeaponReturnEvent(weapon)
	for owner, func in pairs(self.weaponReturnListeners) do
		func(weapon)
	end
end