--Place indestructible belts under the player.
local lib = require("__belt-foot__.lib")
local BELT_NAME = "belt-foot-permanent-belt"
local belt_collision_mask = prototypes.entity[BELT_NAME].collision_mask.layers
local MAX_BELT_CHECKS_PER_UPDATE = 50

local types_not_to_mine_list = {"character", "car", "spider-vehicle",
    "combat-robot", "construction-robot", "logistic-robot", "resource",
    "segmented-unit", "unit-spawner", "unit"}
local types_not_to_mine = {}
for _, entry in pairs(types_not_to_mine_list) do
    types_not_to_mine[entry] = true
end



--Try to mine the given entity when placed by the given player_index
local function try_mine(entity, player_index)
    if entity.type == "entity-ghost" then entity.mine()
    else --Must mine real entity
        local player = player_index and game.get_player(player_index)
        if player and player.character then player.mine_entity(entity, true) 
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
    player = player or game.players[1]
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

    --Keep track
    storage.placed_belts = storage.placed_belts or {}
    storage.placed_belts[new_entity] = {surface = surface, player = player, position = position, direction = direction}
end

local function clear_spot(player, position, surface)
    player = player or game.players[1]
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
                try_mine(entity, player.index)
            end
        end
    end
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
    clear_spot(player, position, surface)

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

--Recheck belts, and re-place if needed
local function check_belt(entry, entity)
    if not entry or not entry.surface then return end

    --Belt totally destroyed or teleported
    if not entity or not entity.valid 
        or entity.surface ~= entry.surface
        or entity.position[1] ~= entry.position[1] 
        or entity.position[2] ~= entry.position[2] then
        local player = entry.player or game.players[1]
        clear_spot(player, entry.position, entry.surface)
        place_belt(entry.surface, entry.position, player, entry.direction)
        storage.placed_belts[entity] = nil
        return
    end

    --Belt rotated
    if entity.direction ~= entry.direction then
        entity.direction = entry.direction
    end
end

--Iterate through our placed belts in chunks to make sure they are where they are supposed to be.
local function belt_check_update()
    storage.placed_belts = storage.placed_belts or {}

    --Index of the last chunk where we ended iteration
    storage.check_index = lib.for_n_of(storage.placed_belts, storage.check_index,
        MAX_BELT_CHECKS_PER_UPDATE, check_belt)
end



script.on_nth_tick(1, function()
    belt_check_update()
    place_all_belts()
end)
script.on_init(function() storage.placed_belts = storage.placed_belts or {} end)
