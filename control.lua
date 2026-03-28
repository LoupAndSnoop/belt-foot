--Place indestructible belts under the player.
local BELT_NAME = "belt-foot-permanent-belt"
local belt_collision_mask = prototypes.entity[BELT_NAME].collision_mask.layers

local types_not_to_mine_list = {"character", "car", "spider-vehicle",
    "combat-robot", "construction-robot", "logistic-robot", "resource"}
local types_not_to_mine = {}
for _, entry in pairs(types_not_to_mine_list) do
    types_not_to_mine[entry] = true
end



--Try to mine the given entity when placed by the given player_index
local function try_mine(entity, player_index)
    if entity.type == "entity-ghost" then entity.mine()
    else --Must mine real entity
        if player_index then game.get_player(player_index).mine_entity(entity, true) 
        else --Not placed by a player, so try to spill on the floor.
            local item = entity.prototype.items_to_place_this and entity.prototype.items_to_place_this[1]
            if item then --Only spill if something actually places this item.
                entity.surface.spill_item_stack {
                    position = entity.position,
                    stack = item,
                    enable_looted = true,
                    force = entity.force_index,
                    allow_belts = false
                }
            end
            entity.destroy()
        end
    end
end


--Place a permanent belt here, no questions asked
local function place_belt(surface, position, player, direction)
    local new_entity = surface.create_entity {
        name = BELT_NAME,
        position = position,
        direction = direction,
        force = game.forces.neutral,
        raise_built = false,
        player = player,
        preserve_ghosts_and_corpses = false,
    }
    if not new_entity or not new_entity.valid then return end

    new_entity.destructible = false
    new_entity.minable = false
    new_entity.rotatable = false
    new_entity.operable = false
    player.play_sound{path="utility/build_medium", position=player.position, volume_modifier=0.7}
end


--On an event triggered by a building action, check to see if we need to do an entity swap. If so, then do it!
local try_place_belt = function(player_index, character)
    if not character or not character.valid then return end

    local surface = character.surface
    if surface.platform then return end --Don't mess with space platforms

    local player = player_index and game.get_player(player_index)
    if not player then return end

    --Check for an existing item there.
    local current = surface.find_entity(BELT_NAME, character.position)
    if current and current.valid then return end --Already have a belt.

    local position = character.position
    local belt_direction = character.direction

    --Skip if in train.
    if character.vehicle and character.vehicle.valid and
        character.vehicle.type == "locomotive" then return end
    
    --[[Don't go putting crap on water
    if not surface.can_place_entity{name=BELT_NAME,
        position=position,
        build_check_type=defines.build_check_type.script,
        force= neutral_force} then return end]]

    --Mine materials in the way
    local position_center = {math.floor(position.x) + 0.5, math.floor(position.y) + 0.5}
    local check_wipe = surface.find_entities_filtered{
        position = position_center,
        collision_mask = belt_collision_mask,
    }
    for _, entity in pairs(check_wipe) do
        if entity and entity.valid and entity.name ~= BELT_NAME then
            local true_type = (entity.type == "entity-ghost") and entity.ghost_type or entity.type
            if entity.type == "transport-belt" then --Non-ghost, lock it in.
                belt_direction = entity.direction
                entity.create_build_effect_smoke()
                player.play_sound{path="utility/axe_mining_stone", position=player.position, volume_modifier=1}
                entity.destroy()
            elseif not types_not_to_mine[true_type] then
                entity.create_build_effect_smoke()
                player.play_sound{path="utility/axe_mining_stone", position=player.position, volume_modifier=1}
                try_mine(entity, player_index)
            end   
        end
    end

    --Actually make the belt
    place_belt(surface, position, player, belt_direction)
end

--Place belts for all characters.
local function place_all_belts()
    for player_index, player in pairs(game.players) do
        local character = player.character
        if character then
            try_place_belt(player_index, character)
        end
    end
end


script.on_nth_tick(1, place_all_belts)
