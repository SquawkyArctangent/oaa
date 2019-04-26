
---------------------------------------------------------------------------

function Spawn( entityKeyValues )
	if thisEntity == nil then
		return
	end

	if IsServer() == false then
		return
	end

	thisEntity.waveAbility = thisEntity:FindAbilityByName( "boss_bullethell_wave" )

	thisEntity:SetContextThink( "BulletHellBossThink", BulletHellBossThink, 1 )
end

---------------------------------------------------------------------------

function BulletHellBossThink()
	if ( not IsValidEntity(thisEntity) ) or ( not thisEntity:IsAlive()) then
		return -1
	end

	if GameRules:IsGamePaused() == true then
		return 1
	end

	if not thisEntity.bInitialized then
		thisEntity.vInitialSpawnPos = thisEntity:GetOrigin()
		thisEntity.bInitialized = true
		thisEntity.bHasAgro = false
		thisEntity.fAgroRange = thisEntity:GetAcquisitionRange()
		thisEntity:SetIdleAcquire(false)
		thisEntity:SetAcquisitionRange(0)
	end

	local enemies = FindUnitsInRadius(
		thisEntity:GetTeamNumber(),
		thisEntity:GetOrigin(),
		nil,
		thisEntity:GetCurrentVisionRange(),
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
		FIND_CLOSEST,
		false
	)

	--local fHpPercent = (thisEntity:GetHealth() / thisEntity:GetMaxHealth()) * 100
	local hasDamageThreshold = thisEntity:GetMaxHealth() - thisEntity:GetHealth() > thisEntity.BossTier * BOSS_AGRO_FACTOR;
	local fDistanceToOrigin = ( thisEntity:GetOrigin() - thisEntity.vInitialSpawnPos ):Length2D()

	--Aggro
	if (fDistanceToOrigin < 10 and thisEntity.bHasAgro and #enemies == 0) then
		DebugPrint("Wave Boss Deaggro")
		thisEntity.bHasAgro = false
		thisEntity:SetIdleAcquire(false)
		thisEntity:SetAcquisitionRange(0)
		return 2
	elseif hasDamageThreshold and #enemies > 0 then
		if not thisEntity.bHasAgro then
			DebugPrint("Wave Boss Aggro")
			thisEntity.bHasAgro = true
			thisEntity:SetIdleAcquire(false)
			thisEntity:SetAcquisitionRange(thisEntity.fAgroRange)
		end
	end

	-- Leash
	if not thisEntity.bHasAgro or #enemies==0 or fDistanceToOrigin > BOSS_LEASH_SIZE then
		if fDistanceToOrigin > 10 then
			return RetreatHome()
		end
		return 1
	end

	if thisEntity.waveAbility ~= nil and thisEntity.waveAbility:IsFullyCastable() then
		return CastWave()
	end

	if not thisEntity:AttackReady() then
		thisEntity:Stop()
		return 0.25
	end

	local enemiesAttackable = FindUnitsInRadius(
		thisEntity:GetTeamNumber(),
		thisEntity:GetOrigin(),
		nil,
		thisEntity:Script_GetAttackRange(),--thisEntity:GetCurrentVisionRange(),
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO,
		bit.bor( DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE, DOTA_UNIT_TARGET_FLAG_NOT_ATTACK_IMMUNE ),
		FIND_CLOSEST,
		false
	)

	if #enemiesAttackable == 0 then
		thisEntity:Stop()
		return 1
	end

	return Attack(enemiesAttackable[1])
end


----------------------------------------------------------------------------------------------
function Attack( target )
	DebugPrint("Attack")
	ExecuteOrderFromTable({
		UnitIndex = thisEntity:entindex(),
		OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
		TargetIndex = target:entindex(),
		Queue = 0,
	})

	return 1.5
end

----------------------------------------------------------------------------------------------

function RetreatHome()
	DebugPrint("RetreatHome")
	ExecuteOrderFromTable({
		UnitIndex = thisEntity:entindex(),
		OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
		Position = thisEntity.vInitialSpawnPos
	})
	return 6
end

----------------------------------------------------------------------------------------------

function CastWave()
	DebugPrint("Cave Wave")
	ExecuteOrderFromTable({
		UnitIndex = thisEntity:entindex(),
		OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
		AbilityIndex = thisEntity.waveAbility:entindex(),
		Queue = false,
	})

	return thisEntity.waveAbility:GetCastPoint() + 0.25
end
