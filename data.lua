
--I just need some indestructible belts.
local belt = table.deepcopy(data.raw["transport-belt"]["transport-belt"])

belt.name = "belt-foot-permanent-belt"
belt.speed = 15 / 480
belt.max_health = 69420
belt.flags = {"placeable-neutral", "not-deconstructable", "not-selectable-in-game"}
belt.next_upgrade = nil
belt.circuit_wire_max_distance = nil
belt.circuit_connector = nil
belt.map_color = {0.3,0.3,0.3}

local animations = belt.belt_animation_set.animation_set
animations.tint = {0.3,0.3,0.3}

data.extend({belt})


--Make belt immunity shoes not work, because lol
data.extend({
    {
        type = "equipment-category",
        name = "belt-foot-no-immunity",
    }
})
local immunity_equip = data.raw["belt-immunity-equipment"]["belt-immunity-equipment"]
immunity_equip.categories = {"belt-foot-no-immunity"}