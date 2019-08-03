--------------------------------------------------------------------------------
-- Todo:
-- Adds in stage 2
-- Improve stage 3
-- All of Stage 4
-- Would we need Proximity for some spells? Static Shock/Lone Decree?

--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Queen Azshara", 2164, 2361)
if not mod then return end
mod:RegisterEnableMob(152910, 153059, 153060) -- Queen Azshara, Aethanel, Cyranus
mod.engageId = 2299
mod.respawnTime = 30

--------------------------------------------------------------------------------
-- Local
--

local stage = 1
local detonationCount = 1
local portalCount = 1
local hulkCollection = {}
local drainedSoulList = {}
local fails = 0
local hulkKillTime = 0
local burstCount = 1
local piercingCount = 1
local myrmidonCount = 1
local portalTimersMythic = {26.6, 50.3, 43, 56}
local piercingTimersMythic = {51.6, 56, 49}

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:GetLocale()
if L then
	L[299249] = "%s (Soak Orbs)"
	L[299251] = "%s (Avoid Orbs)"
	L[299254] = "%s (Hug Others)"
	L[299255] = "%s (Avoid Everyone)"
	L[299252] = "%s (Keep Moving)"
	L[299253] = "%s (Stand Still)"
	L.hulk_killed = "%s killed - %.1f sec"
	L.fails_message = "%s (%d Sanction stack fails)"
	L.reversal = "Reversal"
	L.greater_reversal = "Reversal (Greater)"
end

--------------------------------------------------------------------------------
-- Initialization
--

local arcaneBurstMarker = mod:AddMarkerOption(false, "player", 1, 303657, 1, 2, 3) -- Arcane Burst
function mod:GetOptions()
	return {
		"stages",
		"berserk",
		300074, -- Pressure Surge
		{298569, "INFOBOX"}, -- Drained Soul
		297937, -- Painful Memories
		297934, -- Longing
		297912, -- Torment
		297907, -- Cursed Heart
		298121, -- Lightning Orbs
		297972, -- Chain Lightning
		{298014, "TANK_HEALER"}, -- Cold Blast
		{298021, "TANK_HEALER"}, -- Ice Shard
		{298756, "ME_ONLY"}, -- Serrated Edge
		{301078, "SAY", "SAY_COUNTDOWN", "FLASH"}, -- Charged Spear
		-20480, -- Overzealous Hulk
		298531, -- Ground Pound
		300428, -- Infuriated
		298787, -- Arcane Orbs
		{299094, "SAY", "FLASH", "PULSE"}, -- Beckon
		{299250, "SAY"}, -- Queen's Decree
		302999, -- Arcane Vulnerability
		-20408, -- Azshara's Devoted
		-20410, -- Azshara's Indomitable
		{304475, "TANK"}, -- Arcane Jolt
		300519, -- Arcane Detonation
		297371, -- Reversal of Fortune
		{303657, "SAY", "SAY_COUNTDOWN"}, -- Arcane Burst
		arcaneBurstMarker,
		-20355, -- Loyal Myrmidon
		{300492, "SAY", "FLASH"}, -- Static Shock
		300620, -- Crystalline Shield
		297372, -- Greater Reversal of Fortune
		300768, -- Piercing Gaze
		{300743, "TANK"}, -- Void Touched
		303982, -- Nether Portal
		301431, -- Overload
		{300866, "FLASH"}, -- Essence of Azeroth
		300877,
		300478, -- Divide and Conquer
	},{
		["stages"] = "general",
		[297937] = -20250, -- Stage One: Cursed Lovers
		[298121] = -20261, -- Aethanel
		[298756] = -20266, -- Cyranus
		[-20480] = CL.adds, -- Cyranus
		[298787] = -20450, -- Queen Azshara
		[299250] = CL.intermission, -- Intermission One: Queen's Decree
		[302999] = -20323, -- Stage Two: Hearts Unleashed
		[-20355] = -20340, -- Stage Three: Song of the Tides
		[300768] = -20361, -- Stage Four: My Palace Is a Prison
		[300478] = "mythic",
	},{
		[297371] = L.reversal, -- Reversal of Fortune
		[297372] = L.greater_reversal, -- Greater Reversal of Fortune
	}
end

function mod:OnBossEnable()
	self:RegisterEvent("RAID_BOSS_WHISPER")
	self:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "boss1", "boss2", "boss3", "boss4", "boss5")
	self:Log("SPELL_DAMAGE", "PressureSurge", 300074)
	self:Log("SPELL_AURA_APPLIED", "DrainedSoulApplied", 298569)
	self:Log("SPELL_AURA_APPLIED_DOSE", "DrainedSoulApplied", 298569)
	self:Log("SPELL_AURA_REMOVED", "DrainedSoulRemoved", 298569)

	-- Stage 1
	self:Log("SPELL_CAST_START", "PainfulMemories", 297937)
	self:Log("SPELL_CAST_START", "Longing", 297934)
	self:Log("SPELL_AURA_APPLIED", "Torment", 297912)

	-- Aethane
	self:Log("SPELL_CAST_START", "LightningOrbs", 298121)
	self:Log("SPELL_CAST_START", "ChainLightning", 297972)
	self:Log("SPELL_CAST_START", "ColdBlast", 298014)
	self:Log("SPELL_AURA_APPLIED", "ColdBlastApplied", 298014)
	self:Log("SPELL_AURA_APPLIED_DOSE", "ColdBlastApplied", 298014)
	self:Log("SPELL_CAST_START", "IceShard", 298021)

	-- Cyranus
	self:Log("SPELL_AURA_APPLIED", "SerratedEdgeApplied", 298756)
	self:Log("SPELL_AURA_APPLIED_DOSE", "SerratedEdgeApplied", 298756)
	self:Log("SPELL_CAST_SUCCESS", "ChargedSpear", 301078)
	self:Log("SPELL_AURA_APPLIED", "ChargedSpearApplied", 301078)

	-- Overzealous Hulk
	self:Log("SPELL_CAST_SUCCESS", "GroundPound", 298531)
	self:Log("SPELL_AURA_APPLIED", "Infuriated", 300428)
	self:Death("HulkDeath", 153064)

	-- Queen Azshara
	self:Log("SPELL_CAST_SUCCESS", "Beckon", 299094, 302141, 303797, 303799) -- Stage 1, Stage 2, Stage 3, Stage 4

	-- Intermission
	self:Log("SPELL_CAST_START", "QueensDecree", 299250)
	self:Log("SPELL_AURA_APPLIED", "PersonalDecrees", 299249, 299251, 299254, 299255, 299252, 299253) -- Suffer!, Obey!, Stand Together!, Stand Alone!, March!, Stay!
	self:Log("SPELL_AURA_APPLIED", "Sanction", 299276) -- Sanction
	self:Log("SPELL_AURA_APPLIED_DOSE", "Sanction", 299276) -- Sanction

	-- Stage 2
	self:Log("SPELL_AURA_APPLIED", "ArcaneMasteryApplied", 300502)
	self:Log("SPELL_AURA_APPLIED", "ArcaneVulnerabilityApplied", 302999)
	self:Log("SPELL_AURA_APPLIED_DOSE", "ArcaneVulnerabilityApplied", 302999)
	self:Log("SPELL_CAST_SUCCESS", "ArcaneJolt", 304475)

	self:Log("SPELL_CAST_START", "ArcaneDetonation", 300519)
	self:Log("SPELL_AURA_APPLIED", "ArcaneBurstApplied", 303657)
	self:Log("SPELL_AURA_REMOVED", "ArcaneBurstRemoved", 303657)

	-- Stage 3
	self:Log("SPELL_AURA_APPLIED", "StaticShock", 300492)
	self:Log("SPELL_AURA_APPLIED", "CrystallineShield", 300620)

	-- Stage 4
	self:Log("SPELL_CAST_SUCCESS", "PiercingGaze", 300768)
	self:Log("SPELL_CAST_SUCCESS", "VoidTouchedSuccess", 300743)
	self:Log("SPELL_AURA_APPLIED", "VoidTouchedApplied", 300743)
	self:Log("SPELL_AURA_APPLIED_DOSE", "VoidTouchedApplied", 300743)
	self:Log("SPELL_CAST_START", "Overload", 301431)
	self:Log("SPELL_AURA_APPLIED", "EssenceofAzerothApplied", 300866)
	self:Log("SPELL_AURA_REMOVED", "EssenceofAzerothRemoved", 300866)
	self:Log("SPELL_AURA_APPLIED", "SystemShockApplied", 300877)

	-- Ground Effects
	self:Log("SPELL_AURA_APPLIED", "NetherPortalDamage", 303981) -- Nether Portal
	self:Log("SPELL_PERIODIC_DAMAGE", "NetherPortalDamage", 303981)
	self:Log("SPELL_PERIODIC_MISSED", "NetherPortalDamage", 303981)

	self:Log("SPELL_AURA_APPLIED", "GroundDamage", 297907) -- Cursed Heart
	self:Log("SPELL_PERIODIC_DAMAGE", "GroundDamage", 297907)
	self:Log("SPELL_PERIODIC_MISSED", "GroundDamage", 297907)
end

function mod:OnEngage()
	stage = 1
	portalCount = 1
	detonationCount = 1
	hulkCollection = {}
	drainedSoulList = {}
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")

	self:CDBar(297937, 14.2) -- Painful Memories
	self:CDBar(298121, 18.5) -- Lightning Orbs
	self:Bar(299094, 49.5) -- Beckon
	self:Bar(298787, self:Mythic() and 57.5 or 65) -- Arcane Orbs
	self:CDBar(-20480, self:Mythic() and 27.5 or 35, nil, "achievement_boss_nagabruteboss") -- Overzealous Hulk
	self:Berserk(840)
	self:OpenInfo(298569, self:SpellName(298569)) -- Drained Soul
	for unit in self:IterateGroup() do
		local _, _, _, tarInstanceId = UnitPosition(unit)
		local name = self:UnitName(unit)
		if name and tarInstanceId == 2164 and not self:Tank(unit) then
			drainedSoulList[name] = {0, 0, 110}
		end
	end
	self:SetInfoBarsByTable(298569, drainedSoulList, true) -- Drained Soul

	if self:Mythic() then
		self:Bar(300478, 32.5) -- Divide and Conquer
	end
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
	local unit, guid = self:GetBossId(153064) -- Overzealous Hulk
	if unit and not hulkCollection[guid] then
		hulkCollection[guid] = true
		self:Message2(-20480, "cyan", self:SpellName(-20480), "achievement_boss_nagabruteboss")
		self:PlaySound(-20480, "long")
		hulkKillTime = GetTime()
		self:CDBar(-20480, self:Mythic() and 63 or self:Easy() and 84 or 59, nil, "achievement_boss_nagabruteboss") -- Overzealous Hulk
	end
end

function mod:HulkDeath()
	local seconds = math.floor((GetTime() - hulkKillTime) * 100)/100
	self:Message2(-20480, "cyan", L.hulk_killed:format(self:SpellName(-20480), seconds), "achievement_boss_nagabruteboss")
	self:PlaySound(-20480, "info")
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(_, msg)
	if msg:find("298787", nil, true) then -- Arcane Orbs
		self:Message2(298787, "yellow")
		self:PlaySound(298787, "alert")
		self:Bar(298787, 60)
	elseif msg:find("300522", nil, true) then -- Divides
		self:Message2(300478, "orange")
		self:PlaySound(300478, "warning")
		self:Bar(300478, stage == 4 and 86 or stage == 3 and 59.9 or 65)
		self:CastBar(300478, stage == 4 and 45 or 30)
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(_, _, _, spellId)
	if spellId == 297371 then -- Reversal of Fortune
		self:PlaySound(spellId, "long")
		self:Message2(spellId, "cyan", L.reversal)
		self:CastBar(spellId, 30, L.reversal)
		self:CDBar(spellId, 80, L.reversal)
	elseif spellId == 297372 then -- Greater Reversal of Fortune
		self:PlaySound(spellId, "long")
		self:Message2(spellId, "cyan", L.greater_reversal)
		self:CastBar(spellId, 30, L.greater_reversal)
		self:CDBar(spellId, self:Mythic() and (stage == 4 and 81 or 90) or 70, L.greater_reversal)
	elseif spellId == 303629 then -- Arcane Burst
		burstCount = burstCount + 1
		self:Bar(303657, self:Mythic() and (burstCount == 3 and 60 or 45) or 70)
	elseif spellId == 302034 then -- Adjure // 2nd Intermission Start / Stage 3
		stage = 3
		self:PlaySound("stages", "long")
		self:Message2("stages", "green", CL.intermission, false)
		fails = 0

		self:ScheduleTimer("EndIntermission", 27) -- To display fails/notify stage 3 starts

		self:CancelIndomitableTimer()
		self:CancelDevotedTimer()

		self:StopBar(304475) -- Arcane Jolt
		self:StopBar(299094) -- Beckon
		self:StopBar(303657) -- Arcane Burst
		self:StopBar(L.reversal) -- Reversal of Fortune
		self:StopBar(CL.count:format(self:SpellName(300519), detonationCount)) -- Arcane Detonation
		self:StopBar(300478) -- Divide and Conquer

		detonationCount = 1
		myrmidonCount = 1

		self:Bar(299250, 4) -- Decrees
		self:StartMyrmidonTimer(30)
		self:Bar("stages", 34.3, CL.active, "achievement_boss_seawitch") -- Sisters attackable
		self:Bar(304475, self:Mythic() and 31 or 36) -- Arcane Jolt
		self:Bar(301078, 45.5) -- Charged Spear
		self:Bar(299094, 48.5) -- Beckon
		self:Bar(300519, 59.5, CL.count:format(self:SpellName(300519), detonationCount)) -- Arcane Detonation
		self:Bar(303657, self:Mythic() and 71 or 90) -- Arcane Burst
		self:Bar(297372, 80, L.greater_reversal) -- Greater Reversal of Fortune
		if self:Mythic() then
			self:Bar(300478, 44.3) -- Divide and Conquer
			self:Bar("stages", 210, CL.stage:format(4), "achievement_boss_azshara")
		end
	elseif spellId == 302860 then -- Queen Azshara (Stage 4)
		stage = 4
		self:PlaySound("stages", "long")
		self:Message2("stages", "cyan", CL.stage:format(stage), false)

		self:CancelMyrmidonTimer()
		self:StopBar(304475) -- Arcane Jolt
		self:StopBar(299094) -- Beckon
		self:StopBar(303657) -- Arcane Burst
		self:StopBar(L.greater_reversal) -- Greater Reversal of Fortune
		self:StopBar(CL.count:format(self:SpellName(300519), detonationCount)) -- Arcane Detonation
		self:StopBar(300478) -- Divide and Conquer
		self:StopBar(CL.stage:format(4))
		portalCount = 1
		piercingCount = 1

		self:Bar(300743, self:Mythic() and 12.5 or 12) -- Void Touched
		self:Bar(301431, self:Mythic() and 14.2 or 17) -- Overload
		self:Bar(303982, self:Mythic() and portalTimersMythic[portalCount] or 24) -- Nether Portal
		self:Bar(300768, self:Mythic() and 51.6 or 44) -- Piercing Gaze
		self:Bar(299094, self:Mythic() and 72.8 or 68.5) -- Beckon
		self:Bar(297372, 64, L.greater_reversal) -- Greater Reversal of Fortune
		if self:Mythic() then
			self:Bar(300478, 39.2) -- Divide and Conquer
		end
	elseif spellId == 303982 then -- Nether Portal
		self:Message2(303982, "yellow")
		self:PlaySound(303982, "alert")
		portalCount = portalCount + 1
		self:Bar(303982, self:Mythic() and portalTimersMythic[portalCount] or portalCount == 2 and 40 or portalCount == 3 and 44 or 35) -- XXX Make a Table for more data
	end
end
function mod:EndIntermission()
	self:Message2("stages", "cyan", L.fails_message:format(CL.stage:format(stage), fails), false)
	self:PlaySound("stages", "long")
end

do
	local timersTable = {}
	function mod:StartMyrmidonTimer(t)
		if myrmidonCount < 4 then -- only 3 Myrmidons spawn maximum in Mythic, more in other difficulties unconfirmed
			self:CDBar(-20355, t, nil, "inv_misc_nagamale") -- Loyal Myrmidon
			myrmidonCount = myrmidonCount + 1
			timersTable = {
				self:ScheduleTimer("Message2", t, -20355, "yellow", nil, "inv_misc_nagamale"),
				self:ScheduleTimer("PlaySound", t, -20355, "long"),
				self:ScheduleTimer("StartMyrmidonTimer", t, myrmidonCount == 3 and 50 or 60),
			}
		end
	end

	function mod:CancelMyrmidonTimer()
		for i = 1, #timersTable do
			self:CancelTimer(timersTable[i])
		end
		timersTable = {}
		self:StopBar(-20355) -- Loyal Myrmidon
	end
end

-- General
do
	local prev = 0
	function mod:PressureSurge(args)
		local t = GetTime()
		if t-prev > 2 then
			prev = t
			self:Message2(args.spellId, "orange")
			self:PlaySound(args.spellId, "alarm")
		end
	end
end

function mod:DrainedSoulApplied(args)
	if not drainedSoulList[args.destName] then
		drainedSoulList[args.destName] = {args.amount or 1, GetTime()+110, 110}
	else
		drainedSoulList[args.destName][1] = args.amount or 1
		drainedSoulList[args.destName][2] = GetTime()+110
	end
	self:SetInfoBarsByTable(args.spellId, drainedSoulList, true)
	if self:Me(args.destGUID) then
		local amount = args.amount or 1
		if amount % 2 == 0 or amount >= 7 then
			self:StackMessage(args.spellId, args.destName, amount, "blue")
			self:PlaySound(args.spellId, amount > 7 and "warning" or "alarm", nil, args.destName)
		end
	end
end

function mod:DrainedSoulRemoved(args)
	if self:Tank(args.destName) then
		drainedSoulList[args.destName] = nil
	else
		drainedSoulList[args.destName][1] = 0
		drainedSoulList[args.destName][2] = 0
	end
	self:SetInfoBarsByTable(args.spellId, drainedSoulList, true)
end

-- Stage 1
do
	local prev = 0
	function mod:PainfulMemories(args)
		local t = GetTime()
		if t-prev > 1.5 then
			prev = t
			self:Message2(args.spellId, "orange")
			self:PlaySound(args.spellId, "long")
			self:CDBar(297934, 65) -- Longing
		end
	end

	function mod:Longing(args)
		local t = GetTime()
		if t-prev > 1.5 then
			prev = t
			self:Message2(args.spellId, "orange")
			self:PlaySound(args.spellId, "long")
			self:CDBar(297937, 20) -- Painful Memories
		end
	end
end

do
	local prev = 0
	function mod:Torment(args)
		local t = GetTime()
		if t-prev > 1.5 then
			prev = t
			self:Message2(args.spellId, "red")
			self:PlaySound(args.spellId, "alarm")
		end
	end
end

-- Aethane
function mod:LightningOrbs(args)
	self:Message2(args.spellId, "cyan")
	self:PlaySound(args.spellId, "info")
	self:CDBar(args.spellId, 18.5)
end

function mod:ChainLightning(args)
	local canDo, ready = self:Interrupter(args.sourceGUID)
	if canDo then
		self:Message2(args.spellId, "orange")
		if ready then
			self:PlaySound(args.spellId, "alert")
		end
	end
end

function mod:ColdBlast(args)
	self:Message2(args.spellId, "purple")
	self:PlaySound(args.spellId, "alert")
	self:CDBar(args.spellId, 11)
end

function mod:ColdBlastApplied(args)
	local amount = args.amount or 1
	self:StackMessage(args.spellId, args.destName, amount, "purple")
	if amount == 3 then
		self:PlaySound(args.spellId, "warning", nil, args.destName)
	end
end

function mod:IceShard(args)
	self:Message2(args.spellId, "purple")
	self:PlaySound(args.spellId, "warning")
end

-- Cyranus
function mod:SerratedEdgeApplied(args)
	local amount = args.amount or 1
	self:StackMessage(args.spellId, args.destName, amount, "purple")
	self:PlaySound(args.spellId, "alert", nil, args.destName)
end

function mod:ChargedSpear(args)
	self:CDBar(args.spellId, self:Mythic() and (stage == 3 and 15 or 18) or stage == 3 and 13.5 or 40)
end

function mod:ChargedSpearApplied(args)
	self:TargetMessage2(args.spellId, "yellow", args.destName)
	self:PlaySound(args.spellId, "alert", nil, args.destName)
	if self:Me(args.destGUID) then
		self:Flash(args.spellId)
		self:Say(args.spellId)
		self:SayCountdown(args.spellId, self:Mythic() and 3 or 5)
	end
end

-- Overzealous Hulk
function mod:GroundPound(args)
	self:Message2(args.spellId, "orange")
	self:PlaySound(args.spellId, "alarm")
end

function mod:Infuriated(args)
	self:Message2(args.spellId, "cyan")
	self:PlaySound(args.spellId, "info")
end

-- Queen Azshara
function mod:Beckon(args)
	self:Message2(299094, "yellow")
	self:CDBar(299094, self:Mythic() and (stage == 1 and 45 or stage == 3 and 35 or stage == 4 and 98 or 80) or (stage > 2 and 70 or 85)) -- XXX Stage 4 unkown timer
end

function mod:RAID_BOSS_WHISPER(_, msg)
	if msg:find("299094", nil, true) then -- Beckon
		self:PersonalMessage(299094)
		self:PlaySound(299094, "Alarm")
		self:Flash(299094)
		self:Say(299094)
	end
end

-- Intermission
function mod:QueensDecree(args)
	self:Message2(args.spellId, "cyan")
	self:PlaySound(args.spellId, "long")
	self:StopBar(297937) -- Painful Memories
	self:StopBar(298014) -- Cold Blast
	self:StopBar(297934) -- Longing
	self:StopBar(298121) -- Lightning Orbs
	self:StopBar(299094) -- Beckon
	self:StopBar(298787) -- Arcane Orbs
	self:StopBar(-20480) -- Overzealous Hulk
	self:StopBar(301078) -- Charged Spear
	self:StopBar(300478) -- Divide and Conquer
	fails = 0
	self:CDBar("stages", 29.2, CL.active, "achievement_boss_azshara") -- Azshara active
	self:CDBar("stages", 36.2, CL.intermission, 299250) -- Queens Decree
end

do
	local debuffs = {}
	local comma = (GetLocale() == "zhTW" or GetLocale() == "zhCN") and "，" or ", "
	local tconcat =  table.concat
	local function announce()
		local msg = tconcat(debuffs, comma, 1, #debuffs)
		mod:PersonalMessage(299250, nil, msg)
		mod:PlaySound(299250, "alarm")
		debuffs = {}
	end

	function mod:PersonalDecrees(args)
		if self:Me(args.destGUID) then
			debuffs[#debuffs+1] = L[args.spellId]:format(args.spellName)
			if #debuffs == 1 then
				self:SimpleTimer(announce, 0.1)
			end
			if args.spellId == 299254 then -- Stand Together!
				self:Yell2(299250, args.spellName)
			end
		end
	end
end

function mod:Sanction(args)
	fails = fails+1
end

-- Stage 2
function mod:ArcaneMasteryApplied(args)
	stage = 2
	self:PlaySound("stages", "long")
	self:Message2("stages", "cyan", L.fails_message:format(CL.stage:format(stage), fails), false)
	detonationCount = 1
	burstCount = 1

	self:Bar(304475, 4) -- Arcane Jolt
	self:Bar(299094, 12.8) -- Beckon
	self:Bar(303657, self:Mythic() and 43 or 40) -- Arcane Burst
	self:Bar(297371, self:Mythic() and 55.8 or 56, L.reversal) -- Reversal of Fortune
	self:Bar(300519, 67.8, CL.count:format(self:SpellName(300519), detonationCount)) -- Arcane Detonation
	self:StartDevotedTimer(23) -- Azshara's Devoted
	self:StartIndomitableTimer(93.5) -- Azshara's Indomitable
	if self:Mythic() then
		self:Bar(300478, 33) -- Divide and Conquer
	end
end

do
	local timersTable = {}
	function mod:StartDevotedTimer(t)
		self:Bar(-20408, t, nil, "inv_misc_nagamale") -- Azshara's Devoted
		timersTable = {
			self:ScheduleTimer("Message2", t, -20408, "yellow", nil, "inv_misc_nagamale"),
			self:ScheduleTimer("PlaySound", t, -20408, "long"),
		}
	end

	function mod:CancelDevotedTimer()
		for i = 1, #timersTable do
			self:CancelTimer(timersTable[i])
		end
		timersTable = {}
		self:StopBar(-20408) -- Azshara's Devoted
	end
end

do
	local timersTable = {}
	function mod:StartIndomitableTimer(t)
		self:Bar(-20410, t, nil, "achievement_boss_nagacentaur") -- Azshara's Indomitable
		timersTable = {
			self:ScheduleTimer("Message2", t, -20410, "yellow", nil, "achievement_boss_nagacentaur"),
			self:ScheduleTimer("PlaySound", t, -20410, "long"),
		}
	end

	function mod:CancelIndomitableTimer()
		for i = 1, #timersTable do
			self:CancelTimer(timersTable[i])
		end
		timersTable = {}
		self:StopBar(-20410) -- Azshara's Indomitable
	end
end

function mod:ArcaneVulnerabilityApplied(args)
	if self:Me(args.destGUID) then
		local amount = args.amount or 1
		if amount % 5 == 0 then
			self:StackMessage(args.spellId, args.destName, amount, "blue")
			if amount > 19 then
				self:PlaySound(args.spellId, "alarm")
			end
		end
	end
end

function mod:ArcaneJolt(args)
	self:Message2(args.spellId, "cyan")
	self:PlaySound(args.spellId, "info")
	self:CDBar(args.spellId, 6.1)
end

function mod:ArcaneDetonation(args)
	self:Message2(args.spellId, "red", CL.count:format(args.spellName, detonationCount))
	self:PlaySound(args.spellId, "warning")
	self:CastBar(args.spellId, self:Mythic() and 4 or self:Heroic() and 5 or 6, CL.count:format(args.spellName, detonationCount)) -- Mythic 4s, Heroic 5s, Normal/LFR 6s
	detonationCount = detonationCount + 1
	self:CDBar(args.spellId, 75, CL.count:format(args.spellName, detonationCount))
end

do
	local playerList = mod:NewTargetList()
	function mod:ArcaneBurstApplied(args)
		playerList[#playerList+1] = args.destName
		if self:Me(args.destGUID) then
			self:Say(args.spellId)
			self:SayCountdown(args.spellId, self:Mythic() and 15 or 30)
			self:PlaySound(args.spellId, "warning")
		end
		self:TargetsMessage(args.spellId, "yellow", playerList)
		if self:GetOption(arcaneBurstMarker) then
			SetRaidTarget(args.destName, #playerList)
		end
	end

	function mod:ArcaneBurstRemoved(args)
		if self:Me(args.destGUID) then
			self:CancelSayCountdown(args.spellId)
		end
		if self:GetOption(arcaneBurstMarker) then
			SetRaidTarget(args.destName, 0)
		end
	end
end

-- Stage 3
function mod:StaticShock(args)
	self:TargetMessage2(args.spellId, "yellow", args.destName)
	if self:Me(args.destGUID) then
		self:PlaySound(args.spellId, "alert", nil, args.destName)
		self:Flash(args.spellId)
		self:Say(args.spellId)
	end
end

function mod:CrystallineShield(args)
	self:TargetMessage2(args.spellId, "yellow", args.destName)
	self:PlaySound(args.spellId, "long", nil, args.destName)
end

-- Stage 4
function mod:PiercingGaze(args)
	self:Message2(args.spellId, "orange")
	self:PlaySound(args.spellId, "long")
	piercingCount = piercingCount + 1
	self:Bar(args.spellId, self:Mythic() and piercingTimersMythic[piercingCount] or 45)
end

function mod:VoidTouchedSuccess(args)
	self:CDBar(args.spellId, 7.5)
end

function mod:VoidTouchedApplied(args)
	local amount = args.amount or 1
	self:StackMessage(args.spellId, args.destName, amount, "purple")
	self:PlaySound(args.spellId, amount > 2 and "warning" or "alert", nil, args.destName)
end

function mod:Overload(args)
	self:Message2(args.spellId, "red")
	self:PlaySound(args.spellId, "warning")
	self:CDBar(args.spellId, self:Mythic() and 55 or 45)
end

function mod:EssenceofAzerothApplied(args)
	self:TargetMessage2(args.spellId, "yellow", args.destName)
	if self:Me(args.destGUID) then
		self:PlaySound(args.spellId, "alert", nil, args.destName)
		self:Flash(args.spellId)
		self:TargetBar(args.spellId, 25, args.destName)
	end
end

function mod:EssenceofAzerothRemoved(args)
	if self:Me(args.destGUID) then
		self:StopBar(args.spellId, args.destName)
	end
end

function mod:SystemShockApplied(args)
	self:TargetMessage2(args.spellId, "cyan", args.destName)
	if self:Me(args.destGUID) then
		self:PlaySound(args.spellId, "alarm", nil, args.destName)
	end
end

do
	local prev = 0
	function mod:NetherPortalDamage(args)
		if self:Me(args.destGUID) then
			local t = args.time
			if t-prev > 2 then
				prev = t
				self:PlaySound(303982, "alarm")
				self:PersonalMessage(303982, "underyou")
			end
		end
	end
end

do
	local prev = 0
	function mod:GroundDamage(args)
		if self:Me(args.destGUID) then
			local t = args.time
			if t-prev > 2 then
				prev = t
				self:PlaySound(args.spellId, "alarm")
				self:PersonalMessage(args.spellId, "underyou")
			end
		end
	end
end
