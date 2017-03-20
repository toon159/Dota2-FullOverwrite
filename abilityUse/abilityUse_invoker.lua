-------------------------------------------------------------------------------
--- AUTHOR: Nostrademous
--- CONTRIBUTOR: Code is heavily based off of work done by arz_on4dt
--- GITHUB REPO: https://github.com/Nostrademous/Dota2-FullOverwrite
-------------------------------------------------------------------------------

BotsInit = require( "game/botsinit" )
local invAbility = BotsInit.CreateGeneric()

require( GetScriptDirectory().."/constants" )

local utils = require( GetScriptDirectory().."/utility" )
local gHeroVar = require( GetScriptDirectory().."/global_hero_data" )

function setHeroVar(var, value)
    local bot = GetBot()
    gHeroVar.SetVar(bot:GetPlayerID(), var, value)
end

function getHeroVar(var)
    local bot = GetBot()
    return gHeroVar.GetVar(bot:GetPlayerID(), var)
end

local abilityQ = ""
local abilityW = ""
local abilityE = ""
local abilityR = ""

local abilityTO = ""
local abilityCS = ""
local abilityAC = ""
local abilityGW = ""
local abilityEMP = ""
local abilityCM = ""
local abilityDB = ""
local abilityIW = ""
local abilitySS = ""
local abilityFS = ""

local castTODesire = 0
local castCSDesire = 0
local castACDesire = 0
local castGWDesire = 0
local castEMPDesire = 0
local castCMDesire = 0
local castDBDesire = 0
local castIWDesire = 0
local castSSDesire = 0
local castFSDesire = 0

function nukeDamageSS( bot )
    -- Check Sun Strike
    if abilitySS:IsFullyCastable() then
        local ssDmg = abilitySS:GetSpecialValueFloat("damage")
        
        local manaCostSS = abilitySS:GetManaCost()
        if abilitySS:IsHidden() then manaCostSS = manaCostSS + abilityR:GetManaCost() end
        if manaCostSS <= manaAvailable then
            manaAvailable = manaAvailable - manaCostSS
            dmgTotal = dmgTotal + ssDmg
            castTime = castTime + abilitySS:GetCastPoint()
            table.insert(comboQueue, 1, abilitySS)
        end
    end
end

function prepNukeTOCMDB( bot )
    if not (abilityTO:IsFullyCastable() and abilityCM:IsFullyCastable() and abilityDB:IsFullyCastable()) then
        setHeroVar("nukeTOCMDB", false)
        return false
    end
    
    if abilityTO:IsHidden() then
        if abilityR:IsFullyCastable() then
            invokeTornado(bot)
            return true
        end
    else
        if abilityCM:IsHidden() then
            if abilityR:IsFullyCastable() then
                invokeChaosMeteor(bot)
                return true
            end
        else
            local botModifierCount = bot:NumModifiers()
            local nQuas = 0
            local nWex = 0
            local nExort = 0
            
            for i = 0, botModifierCount-1, 1 do
                local modName = bot:GetModifierName(i)
                if modName == "modifier_invoker_wex_instance" then
                    nWex = nWex + 1
                elseif modName == "modifier_invoker_quas_instance" then
                    nQuas = nQuas + 1
                elseif modName == "modifier_invoker_exort_instance" then
                    nExort = nExort + 1
                end
                
                if (nWex + nQuas + nExort) >= 3 then break end
            end
                
            if nWex == 1 and nQuas == 1 and nExort == 1 then
                setHeroVar("nukeTOCMDB", true)
                return false
            else
                bot:ActionPush_Delay(0.01)
                gHeroVar.HeroPushUseAbility(bot, abilityQ)
                gHeroVar.HeroPushUseAbility(bot, abilityW)
                gHeroVar.HeroPushUseAbility(bot, abilityE)
                return true
            end
        end
    end
    
    return false
end

function nukeDamageTOCMDB( bot )
    local manaAvailable = bot:GetMana()
    local dmgTotal = 0
    local engageDist = 700
    
    if (abilityTO:IsFullyCastable() and  abilityCM:IsFullyCastable() and abilityDB:IsFullyCastable()) and
       (not abilityTO:IsHidden() and not abilityCM:IsHidden() and abilityR:IsFullyCastable()) and
       (manaAvailable >= (abilityTO:GetManaCost()+abilityCM:GetManaCost()+abilityR:GetManaCost()+abilityDB:GetManaCost())) then
    
        -- Tornado
        local damageTO = 70 + abilityTO:GetSpecialValueFloat("wex_damage")
        dmgTotal = dmgTotal + damageTO
    
        -- Check Chaos Meteor
        local burnDuration = 3.0
        local burnDamage = burnDuration * abilityCM:GetSpecialValueFloat("burn_dps")
        local mainDamage = abilityCM:GetSpecialValueFloat("main_damage")
        dmgTotal = dmgTotal + mainDamage + burnDamage
    
        -- Deafening Blast
        local damageDB = abilityDB:GetSpecialValueFloat("damage")
        dmgTotal = dmgTotal + damageDB
        
        engageDist = abilityTO:GetSpecialValueInt("travel_distance")
    end
    
    return dmgTotal, engageDist
end

function queueNukeTOCMDB(bot, location, engageDist)
    local dist = GetUnitToLocationDistance(bot, location)

    local liftDuration = abilityTO:GetSpecialValueFloat("lift_duration")
    local tornadoSpeed = abilityTO:GetSpecialValueInt("travel_speed")
    local cmLandTime = abilityCM:GetSpecialValueFloat("land_time")
    
    if dist < engageDist then
        bot:Action_ClearActions(true)
        --utils.AllChat("Too EZ for Arteezy")
        utils.myPrint("INVOKER TO CM DB combo!!!")

        gHeroVar.HeroQueueUseAbilityOnLocation(bot, abilityTO, location)
        gHeroVar.HeroQueueUseAbility(bot, abilityR) -- invoke DB
        bot:ActionQueue_Delay(liftDuration - cmLandTime + engageDist/tornadoSpeed - getHeroVar("AbilityDelay"))
        gHeroVar.HeroQueueUseAbilityOnLocation(bot, abilityCM, utils.VectorTowards(bot:GetLocation(), location, 400))
        bot:ActionQueue_Delay(0.6)
        gHeroVar.HeroQueueUseAbilityOnLocation(bot, abilityDB, location)
        bot:ActionQueue_Delay(0.01)
        setHeroVar("nukeTOCMDB", false)
        return true     
    end
    
    return false
end

function invAbility:AbilityUsageThink(bot)
    -- Check if we're already using an ability
    if utils.IsBusy(bot) then return true end
    
    if utils.IsCrowdControlled(bot) then return false end

    if abilityQ == "" then abilityQ = bot:GetAbilityByName( "invoker_quas" ) end
    if abilityW == "" then abilityW = bot:GetAbilityByName( "invoker_wex" ) end
    if abilityE == "" then abilityE = bot:GetAbilityByName( "invoker_exort" ) end
    if abilityR == "" then abilityR = bot:GetAbilityByName( "invoker_invoke" ) end
    if abilityTO == "" then abilityTO = bot:GetAbilityByName( "invoker_tornado" ) end
    if abilityCS == "" then abilityCS = bot:GetAbilityByName( "invoker_cold_snap" ) end
    if abilityAC == "" then abilityAC = bot:GetAbilityByName( "invoker_alacrity" ) end
    if abilityGW == "" then abilityGW = bot:GetAbilityByName( "invoker_ghost_walk" ) end
    if abilityEMP == "" then abilityEMP = bot:GetAbilityByName( "invoker_emp" ) end
    if abilityCM == "" then abilityCM = bot:GetAbilityByName( "invoker_chaos_meteor" ) end
    if abilityDB == "" then abilityDB = bot:GetAbilityByName( "invoker_deafening_blast" ) end
    if abilityIW == "" then abilityIW = bot:GetAbilityByName( "invoker_ice_wall" ) end
    if abilitySS == "" then abilitySS = bot:GetAbilityByName( "invoker_sun_strike" ) end
    if abilityFS == "" then abilityFS = bot:GetAbilityByName( "invoker_forge_spirit" ) end
    
    local nearbyEnemyHeroes = gHeroVar.GetNearbyEnemies(bot, 1200)
    local nearbyEnemyCreep  = gHeroVar.GetNearbyEnemyCreep(bot, 1200)
    local nearbyEnemyTowers = gHeroVar.GetNearbyEnemyTowers(bot, 750)

    --[[
    if abilityQ:GetLevel() >= 3 then
        if getHeroVar("nukeTOCMDB") then
            local dmg, engageDist = nukeDamageTOCMDB( bot )
            if #nearbyEnemyHeroes >= 1 then
                local locationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), engageDist, 200, 0, 0 )
                if locationAoE.count >= #nearbyEnemyHeroes - 1 then
                    if queueNukeTOCMDB(bot, locationAoE.targetloc, engageDist) then
                        return true
                    end
                end
            end
            return false
        else
            if prepNukeTOCMDB(bot) then return true end
        end
    end
    --]]
    
    -- Check if we were asked to use our global
    --[[
    local useGlobal = getHeroVar("UseGlobal")
    if useGlobal then
        local ability = useGlobal[1]
        local target = useGlobal[2]
        if ability:IsFullyCastable() then
            if ability:IsHidden() then
                if exortTrained() and abilityR:IsFullyCastable() then
                    utils.myPrint("global Sun Strike invoke")
                    invokeSunStrike(bot)
                    return true
                end
            end
            
            if not target:IsNull() and utils.IsCrowdControlled(target) then
                utils.PartyChat("Sun Strike incoming...")
                gHeroVar.HeroPushUseAbilityOnLocation(bot,  ability, target:GetLocation() )
                return true
            end
            
            if target:IsNull() then
                setHeroVar("UseGlobal", nil)
            end
        else
            setHeroVar("UseGlobal", nil)
        end
    end
    --]]
    
    castTODesire, castTOLocation = ConsiderTornado(bot)
    castEMPDesire, castEMPLocation = ConsiderEMP(bot)
    castCMDesire, castCMLocation = ConsiderChaosMeteor(bot)
    castDBDesire, castDBLocation = ConsiderDeafeningBlast(bot)
    castSSDesire, castSSLocation = ConsiderSunStrike(bot)
    castCSDesire, castCSTarget = ConsiderColdSnap(bot)
    castACDesire, castACTarget = ConsiderAlacrity(bot, nearbyEnemyCreep, nearbyEnemyTowers)
    castGWDesire = ConsiderGhostWalk(bot, nearbyEnemyHeroes)
    castIWDesire, castIWFacing = ConsiderIceWall(bot, nearbyEnemyHeroes)
    castFSDesire = ConsiderForgedSpirit(bot, nearbyEnemyHeroes, nearbyEnemyCreep, nearbyEnemyTowers)

    --[[
    print("TO "..castTODesire)
    print("EMP "..castEMPDesire)
    print("CM "..castCMDesire)
    print("DB "..castDBDesire)
    print("SS "..castSSDesire)
    print("CS "..castCSDesire)
    print("AC "..castACDesire)
    print("GW "..castGWDesire)
    print("IW "..castIWDesire)
    print("FS "..castFSDesire)
    --]]
    --if castSSDesire > 0 then utils.myPrint("\nSS "..castSSDesire.."\n") end

    if not inGhostWalk(bot) then
        -- NOTE: the castXXDesire accounts for skill being fully castable        
        if castTODesire > 0 then
            --utils.myPrint("I want to Tornado")
            if not abilityTO:IsHidden() then
                gHeroVar.HeroPushUseAbilityOnLocation(bot,  abilityTO, castTOLocation )
                return true
            elseif abilityR:IsFullyCastable() then
                bot:Action_ClearActions(true)
                invokeTornado(bot)
                gHeroVar.HeroQueueUseAbilityOnLocation(bot,  abilityTO, castTOLocation )
                return true
            end
        end
        
        if castCMDesire > 0 then
            --utils.myPrint("I want to Chaos Meteor")
            if not abilityCM:IsHidden() then
                gHeroVar.HeroPushUseAbilityOnLocation(bot,  abilityCM, castCMLocation )
                return true
            elseif abilityR:IsFullyCastable() then
                bot:Action_ClearActions(true)
                invokeChaosMeteor(bot)
                gHeroVar.HeroQueueUseAbilityOnLocation(bot,  abilityCM, castCMLocation )
                return true
            end
        end

        if castEMPDesire > 0 then
            --utils.myPrint("I want to EMP")
            if not abilityEMP:IsHidden() then
                gHeroVar.HeroPushUseAbilityOnLocation(bot,  abilityEMP, castEMPLocation )
                return true
            elseif abilityR:IsFullyCastable() then
                bot:Action_ClearActions(true)
                invokeEMP(bot)
                gHeroVar.HeroQueueUseAbilityOnLocation(bot,  abilityEMP, castEMPLocation )
                return true
            end
        end

        if castDBDesire > 0 then
            --utils.myPrint("I want to Deafening Blast")
            if not abilityDB:IsHidden() then
                gHeroVar.HeroPushUseAbilityOnLocation(bot,  abilityDB, castDBLocation )
                return true
            elseif abilityR:IsFullyCastable() then
                bot:Action_ClearActions(true)
                invokeDeafeningBlast(bot)
                gHeroVar.HeroQueueUseAbilityOnLocation(bot,  abilityDB, castDBLocation )
                return true
            end
        end

        if castCSDesire > 0 then
            --utils.myPrint("I want to Cold Snap")
            if not abilityCS:IsHidden() then
                gHeroVar.HeroPushUseAbilityOnEntity(bot,  abilityCS, castCSTarget )
                return true
            elseif abilityR:IsFullyCastable() then
                bot:Action_ClearActions(true)
                invokeColdSnap(bot)
                gHeroVar.HeroQueueUseAbilityOnEntity(bot,  abilityCS, castCSTarget )
                return true
            end
        end

        if castSSDesire > 0 then
            --utils.myPrint("I want to Sunstrike")
            if not abilitySS:IsHidden() then
                gHeroVar.HeroPushUseAbilityOnLocation(bot,  abilitySS, castSSLocation )
                return true
            elseif abilityR:IsFullyCastable() then
                bot:Action_ClearActions(true)
                invokeSunStrike(bot)
                gHeroVar.HeroQueueUseAbilityOnLocation(bot,  abilitySS, castSSLocation )
                return true
            end
        end
        
        if castACDesire > 0 then
            --utils.myPrint("I want to Alacrity")
            if not abilityAC:IsHidden() then
                gHeroVar.HeroPushUseAbilityOnEntity(bot,  abilityAC, castACTarget )
                return true
            elseif abilityR:IsFullyCastable() then
                bot:Action_ClearActions(true)
                invokeAlacrity(bot)
                gHeroVar.HeroQueueUseAbilityOnEntity(bot,  abilityAC, castACTarget )
                return true
            end
        end

        if castFSDesire > 0 then
            --utils.myPrint("I want to Forge Spirit")
            if not abilityFS:IsHidden() then
                gHeroVar.HeroPushUseAbility(bot,  abilityFS )
                return true
            elseif abilityR:IsFullyCastable() then
                bot:Action_ClearActions(true)
                invokeForgedSpirit(bot)
                gHeroVar.HeroQueueUseAbility(bot,  abilityFS )
                return true
            end
        end
        
        if castGWDesire > 0 then
            --utils.myPrint("I want to Ghost Walk")
            if not abilityGW:IsHidden() then
                bot:ActionPush_Delay( 0.25 )
                gHeroVar.HeroPushUseAbility(bot,  abilityGW )
                return true
            elseif abilityR:IsFullyCastable() then
                bot:Action_ClearActions(true)
                invokeGhostWalk(bot)
                gHeroVar.HeroQueueUseAbility(bot,  abilityGW )
                bot:ActionQueue_Delay( 0.25 )
                return true
            end
        end

        if castIWDesire > 0 then
            --utils.myPrint("I want to Ice Wall")
            if not abilityIW:IsHidden() then
                gHeroVar.HeroPushUseAbility(bot,  abilityIW )
                if castIWFacing ~= 0 then
                    local currentFacing = bot:GetFacing() -- returns 0 - 359 degrees. East is 0, North is 90
                    local desiredFacing = (currentFacing + castIWFacing) % 360
                    local myLoc = bot:GetLocation()
                    local yDisp = utils.Round(math.sin(math.rad(desiredFacing)), 0)
                    local xDisp = utils.Round(math.cos(math.rad(desiredFacing)), 0)
                    gHeroVar.HeroPushMoveToLocation(bot, utils.VectorTowards(myLoc, myLoc+Vector( xDisp, yDisp, 0 ), 50) )
                end
                return true
            elseif abilityR:IsFullyCastable() then
                bot:Action_ClearActions(true)
                invokeIceWall(bot)
                -- if we have a facing modifier, turn there first
                if castIWFacing ~= 0 then
                    local currentFacing = bot:GetFacing() -- returns 0 - 359 degrees. East is 0, North is 90
                    local desiredFacing = (currentFacing + castIWFacing) % 360
                    local myLoc = bot:GetLocation()
                    local yDisp = utils.Round(math.sin(math.rad(desiredFacing)), 0)
                    local xDisp = utils.Round(math.cos(math.rad(desiredFacing)), 0)
                    gHeroVar.HeroQueueMoveToLocation(bot, utils.VectorTowards(myLoc, myLoc+Vector( xDisp, yDisp, 0 ), 50) )
                end
                gHeroVar.HeroQueueUseAbility(bot,  abilityIW )
                return true
            end
        end
        
        -- Determine what orbs we want
        if not getHeroVar("nukeTOCMDB") then
            if ConsiderOrbs(bot) then return true end
        end
    else
        if ConsiderShowUp(bot, nearbyEnemyHeroes) then return true end
    end
    
    -- Initial invokes at low levels
    if bot:GetLevel() == 1 and abilitySS:IsHidden() then
        invokeSunStrike(bot)
        return true
    elseif bot:GetLevel() == 2 and abilityCM:IsHidden() and wexTrained() then
        tripleExortBuff(bot) -- this is first since we are pushing, not queueing
        invokeChaosMeteor(bot)
        return true
    end
    
    return false
end

function inGhostWalk(bot)
    return bot:HasModifier("modifier_invoker_ghost_walk")
end

function ConsiderShowUp(bot, nearbyEnemyHeroes)
    if inGhostWalk(bot) then
        if #nearbyEnemyHeroes <= 1 or bot:HasModifier("modifier_item_dust") then
            return tripleWexBuff(bot)
        end
    end
    
    return false
end

function quasTrained()
    return abilityQ:IsTrained()
end

function wexTrained()
    return abilityW:IsTrained()
end

function exortTrained()
    return abilityE:IsTrained()
end

function invokeTornado(bot)
    -- Make sure invoke is castable
    if not abilityR:IsFullyCastable() then
        return false
    end
    
    utils.myPrint("invoking Tornado")

    bot:ActionPush_Delay(0.01)
    gHeroVar.HeroPushUseAbility(bot,  abilityR )
    gHeroVar.HeroPushUseAbility(bot,  abilityW )
    gHeroVar.HeroPushUseAbility(bot,  abilityQ )
    gHeroVar.HeroPushUseAbility(bot,  abilityW )

    return true
end

function invokeChaosMeteor(bot)
    -- Make sure invoke is castable
    if not abilityR:IsFullyCastable() then
        return false
    end
    
    utils.myPrint("invoking Chaos Meteor")

    bot:ActionPush_Delay(0.01)
    gHeroVar.HeroPushUseAbility(bot,  abilityR )
    gHeroVar.HeroPushUseAbility(bot,  abilityE )
    gHeroVar.HeroPushUseAbility(bot,  abilityW )
    gHeroVar.HeroPushUseAbility(bot,  abilityE )

    return true
end

function invokeDeafeningBlast(bot)
    -- Make sure invoke is castable
    if not abilityR:IsFullyCastable() then
        return false
    end
    
    utils.myPrint("invoking Deafening Blast")

    bot:ActionPush_Delay(0.01)
    gHeroVar.HeroPushUseAbility(bot,  abilityR )
    gHeroVar.HeroPushUseAbility(bot,  abilityQ )
    gHeroVar.HeroPushUseAbility(bot,  abilityW )
    gHeroVar.HeroPushUseAbility(bot,  abilityE )
    
    return true
end

function invokeForgedSpirit(bot)
    -- Make sure invoke is castable
    if not abilityR:IsFullyCastable() then
        return false
    end
    
    utils.myPrint("invoking Forged Spirit")

    bot:ActionPush_Delay(0.01)
    gHeroVar.HeroPushUseAbility(bot,  abilityR )
    gHeroVar.HeroPushUseAbility(bot,  abilityE )
    gHeroVar.HeroPushUseAbility(bot,  abilityQ )
    gHeroVar.HeroPushUseAbility(bot,  abilityE )

    return true
end

function invokeIceWall(bot)
    -- Make sure invoke is castable
    if not abilityR:IsFullyCastable() then
        return false
    end

    utils.myPrint("invoking Ice Wall")

    bot:ActionPush_Delay(0.01)
    gHeroVar.HeroPushUseAbility(bot,  abilityR )
    gHeroVar.HeroPushUseAbility(bot,  abilityQ )
    gHeroVar.HeroPushUseAbility(bot,  abilityQ )
    gHeroVar.HeroPushUseAbility(bot,  abilityE )
    return true
end

function invokeEMP(bot)
    -- Make sure invoke is castable
    if not abilityR:IsFullyCastable() then
        return false
    end
    
    utils.myPrint("invoking EMP")

    bot:ActionPush_Delay(0.01)
    gHeroVar.HeroPushUseAbility(bot,  abilityR )
    gHeroVar.HeroPushUseAbility(bot,  abilityW )
    gHeroVar.HeroPushUseAbility(bot,  abilityW )
    gHeroVar.HeroPushUseAbility(bot,  abilityW )

    return true
end

function invokeColdSnap(bot)
    -- Make sure invoke is castable
    if not abilityR:IsFullyCastable() then
        return false
    end

    utils.myPrint("invoking Cold Snap")
    
    bot:ActionPush_Delay(0.01)
    gHeroVar.HeroPushUseAbility(bot,  abilityR )
    gHeroVar.HeroPushUseAbility(bot,  abilityQ )
    gHeroVar.HeroPushUseAbility(bot,  abilityQ )
    gHeroVar.HeroPushUseAbility(bot,  abilityQ )

    return true
end

function invokeSunStrike(bot)
    -- Make sure invoke is castable
    if not abilityR:IsFullyCastable() then
        return false
    end

    utils.myPrint("invoking Sun Strike")

    bot:ActionPush_Delay(0.01)
    gHeroVar.HeroPushUseAbility(bot,  abilityR )
    gHeroVar.HeroPushUseAbility(bot,  abilityE )
    gHeroVar.HeroPushUseAbility(bot,  abilityE )
    gHeroVar.HeroPushUseAbility(bot,  abilityE )

    return true
end

function invokeAlacrity(bot)
    -- Make sure invoke is castable
    if not abilityR:IsFullyCastable() then
        return false
    end

    utils.myPrint("invoking Alacrity")

    bot:ActionPush_Delay(0.01)
    gHeroVar.HeroPushUseAbility(bot,  abilityR )
    gHeroVar.HeroPushUseAbility(bot,  abilityW )
    gHeroVar.HeroPushUseAbility(bot,  abilityE )
    gHeroVar.HeroPushUseAbility(bot,  abilityW )

    return true
end

function invokeGhostWalk(bot)
    -- Make sure invoke is castable
    if not abilityR:IsFullyCastable() then
        return false
    end
    
    utils.myPrint("invoking Ghost Walk")

    bot:ActionPush_Delay(0.01)
    gHeroVar.HeroPushUseAbility(bot,  abilityR )
    gHeroVar.HeroPushUseAbility(bot,  abilityQ )
    gHeroVar.HeroPushUseAbility(bot,  abilityW )
    gHeroVar.HeroPushUseAbility(bot,  abilityQ )

    return true
end

function tripleExortBuff(bot)
    if exortTrained() then
        bot:ActionPush_Delay(0.01)
        gHeroVar.HeroPushUseAbility(bot,  abilityE )
        gHeroVar.HeroPushUseAbility(bot,  abilityE )
        gHeroVar.HeroPushUseAbility(bot,  abilityE )
        return true
    end
    return false
end

function tripleQuasBuff(bot)
    if quasTrained() then
        bot:ActionPush_Delay(0.01)
        gHeroVar.HeroPushUseAbility(bot,  abilityQ )
        gHeroVar.HeroPushUseAbility(bot,  abilityQ )
        gHeroVar.HeroPushUseAbility(bot,  abilityQ )
        return true
    end
    return false
end

function tripleWexBuff(bot)
    if wexTrained() then
        bot:ActionPush_Delay(0.01)
        gHeroVar.HeroPushUseAbility(bot,  abilityW )
        gHeroVar.HeroPushUseAbility(bot,  abilityW )
        gHeroVar.HeroPushUseAbility(bot,  abilityW )
        return true
    end
    return false
end

function ConsiderOrbs(bot)
    local botModifierCount = bot:NumModifiers()
    local nQuas = 0
    local nWex = 0
    local nExort = 0
    
    for i = 0, botModifierCount-1, 1 do
        local modName = bot:GetModifierName(i)
        if modName == "modifier_invoker_wex_instance" then
            nWex = nWex + 1
        elseif modName == "modifier_invoker_quas_instance" then
            nQuas = nQuas + 1
        elseif modName == "modifier_invoker_exort_instance" then
            nExort = nExort + 1
        end
        
        if (nWex + nQuas + nExort) >= 3 then break end
    end
    
    if getHeroVar("IsRetreating") then
        if nWex < 3 then 
            return tripleWexBuff(bot)
        end
    elseif bot:GetHealth()/bot:GetMaxHealth() < 0.75 then
        if nQuas < 3 then
            return tripleQuasBuff(bot)
        end
    else
        if nExort < 3 then
            return tripleExortBuff(bot)
        end
    end
    
    return false
end

function CanCastAlacrityOnTarget( target )
    return not target:IsMagicImmune() and not target:IsInvulnerable()
end

function CanCastColdSnapOnTarget( target )
    return target:CanBeSeen() and not target:IsMagicImmune() and not target:IsInvulnerable()
end

function CanCastDeafeningBlastOnTarget( target )
    return target:CanBeSeen() and not target:IsMagicImmune() and not target:IsInvulnerable()
end

function ConsiderTornado(bot)
    if not quasTrained() or not wexTrained() then
        return BOT_ACTION_DESIRE_NONE, {}
    end

    -- Make sure it's castable
    if not abilityTO:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, {}
    end

    -- Check for sufficient mana
    if abilityTO:IsHidden() then
        if not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_NONE, {}
        end
        if bot:GetMana() < (abilityTO:GetManaCost() + abilityR:GetManaCost()) then
            return BOT_ACTION_DESIRE_NONE, {}
        end
    end

    -- Get some of its values
    local nDistance = abilityTO:GetSpecialValueInt( "travel_distance" )
    local nSpeed = 1000
    local nCastRange = abilityTO:GetCastRange()
    
    --------------------------------------
    -- Global high-priorty usage
    --------------------------------------

    -- Check for a channeling enemy
    local nearbyEnemyHeroes = gHeroVar.GetNearbyEnemies(bot, Min(1600, nCastRange + nDistance/2.0))
    
    for _, npcEnemy in pairs( nearbyEnemyHeroes ) do
        if npcEnemy:IsChanneling() then
            if abilityCS:IsFullyCastable() and abilityTO:IsHidden() then
                return BOT_ACTION_DESIRE_NONE, {}
            else
                return BOT_ACTION_DESIRE_HIGH, npcEnemy:GetLocation()
            end
        end
    end

    --------------------------------------
    -- Mode based usage
    --------------------------------------

    --------- RETREATING -----------------------
    if getHeroVar("IsRetreating") then
        for _, npcEnemy in pairs( nearbyEnemyHeroes ) do
            if bot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and GetUnitToUnitDistance( bot, npcEnemy ) <= nDistance then
                return BOT_ACTION_DESIRE_MODERATE, npcEnemy:GetLocation()
            end
        end
    end

    --------- TEAM FIGHT --------------------------------
    if #nearbyEnemyHeroes >= 2 then
        local locationAoE = bot:FindAoELocation( true, false, bot:GetLocation(), nCastRange, nDistance, 0, 0 )
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc
        end
    end

    --------- CHASING --------------------------------
    local target = getHeroVar("Target")
    if utils.ValidTarget(target) then
        local dist = GetUnitToUnitDistance( bot, target )
        if dist < (nDistance - 200) then
            return BOT_ACTION_DESIRE_MODERATE, target:GetExtrapolatedLocation( dist/nSpeed + getHeroVar("AbilityDelay") )
        end
    end

    return BOT_ACTION_DESIRE_NONE, {}
end

function ConsiderIceWall(bot, nearbyEnemyHeroes)
    if not quasTrained() or not exortTrained() then
        return BOT_ACTION_DESIRE_NONE, 0
    end

    -- Make sure it's castable
    if  not abilityIW:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, 0
    end

    -- Check for sufficient mana
    if abilityIW:IsHidden() then
        if not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_NONE, {}
        end
        if bot:GetMana() < (abilityIW:GetManaCost() + abilityR:GetManaCost()) then
            return BOT_ACTION_DESIRE_NONE, {}
        end
    end

    -- Get some of its values
    local nCastRange = abilityIW:GetSpecialValueInt( "wall_place_distance" )
    local nLength = 80*15

    --------------------------------------
    -- Mode based usage
    --------------------------------------

    --------- RETREATING -----------------------
    if getHeroVar("IsRetreating") then
        for _, npcEnemy in pairs( nearbyEnemyHeroes ) do
            if  bot:WasRecentlyDamagedByHero( npcEnemy, 2.0 ) and GetUnitToUnitDistance(npcEnemy, bot) < 300 then
                return BOT_ACTION_DESIRE_MODERATE, 0
            end
        end
    end

    --------- CHASING --------------------------------
    local target = getHeroVar("Target")
    if utils.ValidTarget(target) then
        --FIXME: Need to check orientation
        if GetUnitToUnitDistance( bot, target ) < (nCastRange + nLength/2) then
            return BOT_ACTION_DESIRE_MODERATE, 90
        end
    end

    return BOT_ACTION_DESIRE_NONE, 0
end


function ConsiderChaosMeteor(bot)
    if not exortTrained() or not wexTrained() then
        return BOT_ACTION_DESIRE_NONE, {}
    end

    -- Make sure it's castable
    if not abilityCM:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, {}
    end

    -- Check for sufficient mana
    if abilityCM:IsHidden() then
        if not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_NONE, {}
        end
        if bot:GetMana() < (abilityCM:GetManaCost() + abilityR:GetManaCost()) then
            return BOT_ACTION_DESIRE_NONE, {}
        end
    end

    -- Get some of its values
    local nCastRange = abilityCM:GetCastRange()
    local nDelay = 1.35 + getHeroVar("AbilityDelay") -- 0.05 cast point, 1.3 land time
    local nTravelDistance = abilityCM:GetSpecialValueInt("travel_distance")
    local nRadius = abilityCM:GetSpecialValueInt("area_of_effect")

    --------------------------------------
    -- Mode based usage
    --------------------------------------
    
    --------- TEAM FIGHT -----------------------------
    local nearbyEnemyHeroes = gHeroVar.GetNearbyEnemies(bot, Min(1600, nCastRange))
    if #nearbyEnemyHeroes >= 2 then
        local locationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nTravelDistance, nDelay, 0 )
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc
        end
    end

    return BOT_ACTION_DESIRE_NONE, {}
end


function ConsiderSunStrike(bot)
    if not exortTrained() then
        return BOT_ACTION_DESIRE_NONE, {}
    end

    -- Make sure it's castable
    if not abilitySS:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, {}
    end

    -- Check for sufficient mana
    if abilitySS:IsHidden() then
        if not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_NONE, {}
        end
        if bot:GetMana() < (abilitySS:GetManaCost() + abilityR:GetManaCost()) then
            return BOT_ACTION_DESIRE_NONE, {}
        end
    end

    -- Get some of its values
    local nRadius = 175
    local nDelay = 1.75 + getHeroVar("AbilityDelay") -- 0.05 cast point, 1.7 delay
    local nDamage = abilitySS:GetSpecialValueFloat("damage")

    --------------------------------------
    -- Global Usage
    --------------------------------------
    local globalEnemies = GetUnitList(UNIT_LIST_ENEMY_HEROES)
    for _, enemy in pairs(globalEnemies) do
        if enemy:GetHealth() <= nDamage then
            --if utils.IsCrowdControlled(enemy) then
            --    return BOT_ACTION_DESIRE_MODERATE, enemy:GetLocation()
            --else
                --utils.myPrint("nDelay: ", nDelay, ", loc: ", tostring(enemy:GetExtrapolatedLocation( nDelay )))
                return BOT_ACTION_DESIRE_MODERATE, enemy:GetExtrapolatedLocation( nDelay )
            --end
        end
    end

    --------- CHASING --------------------------------
    local target = getHeroVar("Target")
    if utils.ValidTarget(target) and target:GetHealth()/target:GetMaxHealth() <= 0.5 then
        --if utils.IsCrowdControlled(target) then
        --    return BOT_ACTION_DESIRE_MODERATE, target:GetLocation()
        --else
            return BOT_ACTION_DESIRE_MODERATE, target:GetExtrapolatedLocation( nDelay )
        --end
    end

    return BOT_ACTION_DESIRE_NONE, {}
end

function ConsiderDeafeningBlast(bot)
    if not quasTrained() or  not wexTrained() or not exortTrained() then
        return BOT_ACTION_DESIRE_NONE, {}
    end

    -- Make sure it's castable
    if not abilityDB:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, {}
    end
    
    -- Check for sufficient mana
    if abilityDB:IsHidden() then
        if not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_NONE, {}
        end
        if bot:GetMana() < (abilityDB:GetManaCost() + abilityR:GetManaCost()) then
            return BOT_ACTION_DESIRE_NONE, {}
        end
    end

    -- Get some of its values
    local nCastRange = abilityDB:GetSpecialValueInt("radius_start")
    local nRadius = abilityDB:GetSpecialValueInt("travel_distance")
    local nDamage = abilityDB:GetSpecialValueInt("damage")

    --------------------------------------
    -- Mode based usage
    --------------------------------------
    
    --------- TEAM FIGHT -----------------------------
    local nearbyEnemyHeroes = gHeroVar.GetNearbyEnemies(bot, Min(1600, nCastRange))
    if #nearbyEnemyHeroes >= 2 then
        local locationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius, 0, 0 )
        if locationAoE.count >= 2 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc
        end
    end

    return BOT_ACTION_DESIRE_NONE, {}
end

function ConsiderEMP(bot)
    if not wexTrained() then
        return BOT_ACTION_DESIRE_NONE, {}
    end

    -- Make sure it's castable
    if not abilityEMP:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, {}
    end
    
    -- Check for sufficient mana
    if abilityEMP:IsHidden() then
        if not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_NONE, {}
        end
        if bot:GetMana() < (abilityEMP:GetManaCost() + abilityR:GetManaCost()) then
            return BOT_ACTION_DESIRE_NONE, {}
        end
    end

    -- Get some of its values
    local nCastRange = abilityEMP:GetCastRange()
    local nRadius = abilityEMP:GetSpecialValueInt( "area_of_effect" )
    local nBurn = abilityEMP:GetSpecialValueInt( "mana_burned" )
    local nPDamage = abilityEMP:GetSpecialValueInt( "damage_per_mana_pct" )

    --------------------------------------
    -- Mode based usage
    --------------------------------------
    
    --------- TEAM FIGHT -----------------------------
    local nearbyEnemyHeroes = gHeroVar.GetNearbyEnemies(bot, Min(1600, nCastRange + nRadius))
    if #nearbyEnemyHeroes >= 3 then
        local locationAoE = bot:FindAoELocation( true, true, bot:GetLocation(), nCastRange, nRadius, 2.95 + getHeroVar("AbilityDelay"), 0 )
        if locationAoE.count >= 3 then
            return BOT_ACTION_DESIRE_HIGH, locationAoE.targetloc
        end
    end

    --------- CHASING --------------------------------
    local target = getHeroVar("Target")
    if utils.ValidTarget(target) then
        if target:HasModifier("modifier_invoker_tornado") and 
            target:GetMana() > 600 and
            GetUnitToUnitDistance( target, bot ) < (nCastRange - (nRadius / 2)) then
            return BOT_ACTION_DESIRE_MODERATE, target:GetLocation()
        end
    end

    return BOT_ACTION_DESIRE_NONE, {}
end

function ConsiderGhostWalk(bot, nearbyEnemyHeroes)
    if not quasTrained() or not wexTrained() then
        return BOT_ACTION_DESIRE_NONE
    end

    -- Make sure it's castable
    if not abilityGW:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE
    end
    
    -- Check for sufficient mana
    if abilityGW:IsHidden() then
        if not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_NONE
        end
        if bot:GetMana() < (abilityGW:GetManaCost() + abilityR:GetManaCost()) then
            return BOT_ACTION_DESIRE_NONE
        end
    end

    -- WE ARE RETREATNG AND THEY ARE ON US
    if getHeroVar("IsRetreating") then
        for _, npcEnemy in pairs( nearbyEnemyHeroes ) do
            if bot:WasRecentlyDamagedByHero( npcEnemy, 1.0 ) or GetUnitToUnitDistance( npcEnemy, bot ) < 600 then
                return BOT_ACTION_DESIRE_HIGH
            end
        end
    end
    
    -- We are roaming
    local me = getHeroVar("Self")
    if me:getCurrentMode():GetName() == "roam" then
        local target = getHeroVar("RoamTarget")
        if utils.ValidTarget(target) then
            local dist = GetUnitToUnitDistance(bot, target)
            if dist < 3200 then
                return BOT_ACTION_DESIRE_MODERATE
            end
        end
    end

    return BOT_ACTION_DESIRE_NONE
end

function ConsiderColdSnap(bot)
    if not quasTrained() then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    -- Make sure it's castable
    if not abilityCS:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil
    end
    
    -- Check for sufficient mana
    if abilityCS:IsHidden() then
        if not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_NONE, nil
        end
        if bot:GetMana() < (abilityCS:GetManaCost() + abilityR:GetManaCost()) then
            return BOT_ACTION_DESIRE_NONE, nil
        end
    end

    -- Get some of its values
    local nCastRange = abilityCS:GetCastRange()

    --------------------------------------
    -- Global high-priorty usage
    --------------------------------------

    -- Check for a channeling enemy
    local nearbyEnemyHeroes = gHeroVar.GetNearbyEnemies(bot, Min(1600, nCastRange))
    for _, npcEnemy in pairs( nearbyEnemyHeroes ) do
        if npcEnemy:IsChanneling() then
            if abilityTO:IsFullyCastable() and not abilityTO:IsHidden() then
                return BOT_ACTION_DESIRE_NONE, nil
            else
                return BOT_ACTION_DESIRE_HIGH, npcEnemy
            end
        end
    end

    -- If we're going after someone
    local target = getHeroVar("Target")
    if utils.ValidTarget(target) then
        if GetUnitToUnitDistance( target, bot ) < nCastRange and CanCastColdSnapOnTarget(target) then
            return BOT_ACTION_DESIRE_HIGH, target
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil
end

function ConsiderAlacrity(bot, nearbyEnemyCreep, nearbyEnemyTowers)
    if not wexTrained() or not exortTrained() then
        return BOT_ACTION_DESIRE_NONE, nil
    end

    -- Make sure it's castable
    if not abilityAC:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE, nil
    end
    
    -- Check for sufficient mana
    if abilityAC:IsHidden() then
        if not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_NONE, nil
        end
        if bot:GetMana() < (abilityAC:GetManaCost() + abilityR:GetManaCost()) then
            return BOT_ACTION_DESIRE_NONE, nil
        end
    end

    --------------------------------------
    -- Global high-priorty usage
    --------------------------------------
    local manaRatio = bot:GetMana()/bot:GetMaxMana()
    
    -- If we're pushing or defending a lane and can hit 4+ creeps, go for it
    if manaRatio > 0.6 and (getHeroVar("ShouldDefend") or getHeroVar("ShouldPush")) then
        if #nearbyEnemyCreep >= 3 or #nearbyEnemyTowers > 0 then
            return BOT_ACTION_DESIRE_LOW, bot
        end
    end

    --------- CHASING --------------------------------
    local target = getHeroVar("Target")
    if utils.ValidTarget(target) then
        return BOT_ACTION_DESIRE_MODERATE, bot
    end

    --------- ROSHAN --------------------------------
    local me = getHeroVar("Self")
    if me:getCurrentMode():GetName() == "roshan" then
        local npcTarget = bot:GetTarget()
        if utils.NotNilOrDead(npcTarget) then
            return BOT_ACTION_DESIRE_LOW, bot
        end
    end

    return BOT_ACTION_DESIRE_NONE, nil
end

function ConsiderForgedSpirit(bot, nearbyEnemyHeroes, nearbyEnemyCreep, nearbyEnemyTowers)
    if not quasTrained() or not exortTrained() then
        return BOT_ACTION_DESIRE_NONE
    end

    -- Make sure it's castable
    if not abilityFS:IsFullyCastable() then
        return BOT_ACTION_DESIRE_NONE
    end
    
    -- Check for sufficient mana
    if abilityFS:IsHidden() then
        if not abilityR:IsFullyCastable() then
            return BOT_ACTION_DESIRE_NONE
        end
        if bot:GetMana() < (abilityFS:GetManaCost() + abilityR:GetManaCost()) then
            return BOT_ACTION_DESIRE_NONE
        end
    end

    --------- ROSHAN --------------------------------
    local me = getHeroVar("Self")
    if me:getCurrentMode():GetName() == "roshan" then
        local npcTarget = bot:GetTarget()
        if utils.NotNilOrDead(npcTarget) then
            return BOT_ACTION_DESIRE_LOW
        end
    end

    --------------------------------------
    -- Global high-priorty usage
    --------------------------------------
    local manaRatio = bot:GetMana()/bot:GetMaxMana()
    
    -- If we're pushing or defending a lane, go for it
    local me = getHeroVar("Self")
    if manaRatio > 0.4 and (me:getCurrentMode():GetName() == "pushlane" or 
        me:getCurrentMode():GetName() == "defendlane") then
        if #nearbyEnemyHeroes > 0 or #nearbyEnemyCreep >= 3 or #nearbyEnemyTowers > 0 then
            return BOT_ACTION_DESIRE_MODERATE
        end
    end

    --------- CHASING --------------------------------
    local target = getHeroVar("Target")
    if utils.ValidTarget(target) then
        return BOT_ACTION_DESIRE_MODERATE
    end

    return BOT_ACTION_DESIRE_NONE
end

return invAbility
