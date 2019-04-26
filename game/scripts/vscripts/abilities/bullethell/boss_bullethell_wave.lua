boss_bullethell_wave = class( AbilityBaseClass )

LinkLuaModifier( "modifier_boss_bullethell_wave_raze_thinker", "abilities/bullethell/boss_bullethell_wave.lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_boss_bullethell_wave_pattern_grid", "abilities/bullethell/boss_bullethell_wave.lua", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_boss_bullethell_wave_pattern_vacuum", "abilities/bullethell/boss_bullethell_wave.lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------

boss_bullethell_wave.patternTable = {
	{
		name = "modifier_boss_bullethell_wave_pattern_grid",
		castAnim = ACT_DOTA_RAZE_3,
	},
}

--------------------------------------------------------------------------------

function boss_bullethell_wave:GetCooldown( level )
	local cdBase = self.BaseClass.GetCooldown( self, level )

	return cdBase / ( self:GetRank( "rank_cooldown_min", "rank_cooldown_max" ) * 0.01 )
end

--------------------------------------------------------------------------------

function boss_bullethell_wave:GetCastAnimation()
	local patternData = self.patternType

	if patternData then
		local anim = patternData.castAnim

		if anim then
			return anim
		end
	end

	return ACT_DOTA_CAST_ABILITY_6
end

--------------------------------------------------------------------------------

function boss_bullethell_wave:CastFilterResult()
	self.patternType = self.patternTable[RandomInt( 1, #self.patternTable )]
	return UF_SUCCESS
end

--------------------------------------------------------------------------------

function boss_bullethell_wave:GetRank( rankMinKV, rankMaxKV )
	local caster = self:GetCaster()
	local healthPercent = caster:GetHealthPercent() * 0.01
	local rankMin = self:GetSpecialValueFor( rankMinKV )
	local rankMax = self:GetSpecialValueFor( rankMaxKV )
	local rankDiff = rankMax - rankMin

	local rankReal = rankMin + ( ( 1.0 - healthPercent ) * rankDiff )

	return rankReal
end

--------------------------------------------------------------------------------

function boss_bullethell_wave:DoRaze( origin, soundUnit )
	local caster = self:GetCaster()

	local units = FindUnitsInRadius(
		caster:GetTeamNumber(),
		origin,
		nil,
		self:GetSpecialValueFor( "raze_radius" ),
		self:GetAbilityTargetTeam(),
		self:GetAbilityTargetType(),
		self:GetAbilityTargetFlags(),
		FIND_ANY_ORDER,
		false
	)

	local part = ParticleManager:CreateParticle( "particles/units/heroes/hero_nevermore/nevermore_shadowraze.vpcf", PATTACH_WORLDORIGIN, nil )
	ParticleManager:SetParticleControl( part, 0, origin )
	ParticleManager:ReleaseParticleIndex( part )

	if soundUnit then
		soundUnit:EmitSound( "Hero_Nevermore.Shadowraze" )
	end

	local damage = self:GetSpecialValueFor( "damage" )
	local damageType = self:GetAbilityDamageType()

	for _, target in pairs( units ) do
		ApplyDamage( {
			victim = target,
			attacker = caster,
			damage = damage,
			damage_type = damageType,
			damage_flags = DOTA_DAMAGE_FLAG_NONE,
			ability = self,
		} )
	end
end

--------------------------------------------------------------------------------

function boss_bullethell_wave:OnSpellStart()
	local caster = self:GetCaster()
	local pattern = self.patternType
	local modName = pattern.name

	if modName then
	-- create the pattern modifier
		caster:AddNewModifier( caster, self, modName, {
			duration = self:GetSpecialValueFor( "pattern_duration" ),
		} )
	end
end

--------------------------------------------------------------------------------

modifier_boss_bullethell_wave_raze_thinker = class( ModifierBaseClass )

--------------------------------------------------------------------------------

function modifier_boss_bullethell_wave_raze_thinker:IsDebuff()
	return false
end

function modifier_boss_bullethell_wave_raze_thinker:IsHidden()
	return false
end

function modifier_boss_bullethell_wave_raze_thinker:IsPurgable()
	return false
end

--------------------------------------------------------------------------------

if IsServer() then
	function modifier_boss_bullethell_wave_raze_thinker:OnCreated( event )
		local spell = self:GetAbility()
		local parent = self:GetParent()

		-- get necessary data
		local speed = event.speed
		local angle = event.angle
		self.vel = Vector( math.cos( angle ), math.sin( angle ), 0 ) * speed
		self.density = spell:GetRank( "rank_density_min", "rank_density_max" )
		self.interval = spell:GetSpecialValueFor( "raze_interval" )
		self.distance = event.distance
		self.originStart = parent:GetOrigin()

		-- do first raze
		spell:DoRaze( self.originStart, parent )

		-- start thinking
		self:StartIntervalThink( self.interval )
	end

--------------------------------------------------------------------------------

	function modifier_boss_bullethell_wave_raze_thinker:OnDestroy( event )
		-- thinker npcs don't clean themselves up
		UTIL_Remove( self:GetParent() )
	end

--------------------------------------------------------------------------------

	function modifier_boss_bullethell_wave_raze_thinker:OnIntervalThink()
		local caster = self:GetCaster()

		-- projectiles don't persist after boss died
		if not IsValidEntity( caster ) or not caster:IsAlive() then
			return self:Destroy()
		end

		local parent = self:GetParent()
		local spell = self:GetAbility()
		local originParent = parent:GetOrigin()

		-- calculate the new origin
		local originNew = originParent + ( self.vel * self.interval )
		
		-- check if we're past our max distances
		-- if so, destroy this
		local distanceTotal = ( originNew - self.originStart ):Length2D()

		if distanceTotal >= self.distance then
			return self:Destroy()
		end

		-- move the thinker npc before we do a raze so we don't have to calculate
		-- ground height ourselves
		parent:SetOrigin( originNew )

		-- raze
		spell:DoRaze( parent:GetOrigin(), parent )
	end
end

--------------------------------------------------------------------------------

modifier_boss_bullethell_wave_pattern_grid = class( ModifierBaseClass )

--------------------------------------------------------------------------------

function modifier_boss_bullethell_wave_pattern_grid:IsDebuff()
	return false
end

function modifier_boss_bullethell_wave_pattern_grid:IsHidden()
	return true
end

function modifier_boss_bullethell_wave_pattern_grid:IsPurgable()
	return false
end

function modifier_boss_bullethell_wave_pattern_grid:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE
end

--------------------------------------------------------------------------------

if IsServer() then
	function modifier_boss_bullethell_wave_pattern_grid:OnCreated( event )
		local parent = self:GetParent()
		local spell = self:GetAbility()

		self.arenaWidth = spell:GetSpecialValueFor( "grid_arena_width" )
		self.arenaHeight = spell:GetSpecialValueFor( "arena_radius" )
		self.density = spell:GetRank( "rank_density_min", "rank_density_max" )
		self.interval = spell:GetSpecialValueFor( "grid_wave_delay" ) / ( self.density * 0.01 )
		self.waveCount = spell:GetSpecialValueFor( "grid_wave_count" )
		self.originHome = vInitialSpawnPos

		-- in case ai didn't start
		if not self.originHome then
			self.originHome = parent:GetOrigin()
		end

		-- do first interval
		self:OnIntervalThink()

		-- start thinking
		self:StartIntervalThink( self.interval )
	end

--------------------------------------------------------------------------------

	function modifier_boss_bullethell_wave_pattern_grid:OnIntervalThink()
		-- make as many waves as we'll need
		for i = 1, self.waveCount do
			self:DoWave()
		end
	end

--------------------------------------------------------------------------------

	function modifier_boss_bullethell_wave_pattern_grid:DoWave()
		local spell = self:GetAbility()
		local parent = self:GetParent()
		-- there's probably a smarter way to do this, but
		-- i wrote ^ when i was effectively using a switch statement
		-- even though this could easily just be trigged out
		-- by using multiplying x by arenaWidth and y by arenaHeight
		-- atan btw
		local side = RandomInt( 0, 3 )
		local angleOffset = ( side / 2.0 ) * math.pi
		local offset = Vector( math.cos( angleOffset ) * self.arenaWidth, math.sin( angleOffset ) * self.arenaHeight, 0 )
		print( offset )
		-- randomize x and y offset if they're 0
		-- this is a weird solution but it probably has to do with decimal imprecision
		-- ( as to why we can't just check for == 0 )
		if side == 1 or side == 3 then
			offset.x = RandomFloat( -self.arenaWidth, self.arenaWidth )
		else
			offset.y = RandomFloat( -self.arenaHeight, self.arenaHeight )
		end
		print( offset )
		local origin = self.originHome + offset
		local distance = offset:Length2D() * 2.0
		local angleWave = angleOffset + math.pi
		local speed = spell:GetSpecialValueFor( "wave_speed" )

		-- make the thinker
		CreateModifierThinker( parent, spell, "modifier_boss_bullethell_wave_raze_thinker", {
			speed = speed,
			angle = angleWave,
			distance = distance,
		}, origin, parent:GetTeamNumber(), false )
	end
end
