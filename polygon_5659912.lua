_DEBUG = false
--global stuffs
local mp_friendlyfire = cvar.mp_friendlyfire
local fire_max_time =  7.03125--2/64 ticks longer than 7 sec)
--ui
local nade_esp_group = ui.find("Visuals", "World", "World ESP")
local enable = nade_esp_group:switch("Molotov Polygon", false)
local group = enable:create()
local only_enemy = group:switch("Only Enemy", false)
local clr = group:color_picker("Color", color(255, 0, 0, 155))
local distance = group:slider("Distance to show", 500, 1000, 650, nil, function(v) return v == 500 and 'Default' or v end)
local outline = group:combo("Outline", "None", "Line", ui.get_icon('triangle-exclamation').." Glow")
local outline_clr = group:color_picker("Outline Color", color(255, 0, 0, 225))
local outline_thickness = group:slider("Outline Thickness", 1, 10, 2, nil, function(v) return v == 1 and 'Default' or v end)

outline:tooltip('Use [Line] for better performance!')

--utils
function math.ticks_to_time(ticks)
    return globals.tickinterval * ticks
end

function math.lerp(a, b, t)
    return a + (b - a) * t
end

--gift wrapping sort
local function ccw(a, b, c)
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
end

local function is_left(a, b)
    return a.x < b.x or (a.x == b.x and a.y < b.y)
end

local function gift_wrapping(v)
    local hull = {}

    if #v < 3 then
        return hull
    end

    -- Move the leftmost Vector to the beginning of our vector.
    -- It will be the first Vector in our convex hull.
    local left_most_index = 1
    for i = 2, #v do
        if is_left(v[i], v[left_most_index]) then
            left_most_index = i
        end
    end
    v[1], v[left_most_index] = v[left_most_index], v[1]

    -- Repeatedly find the first ccw Vector from our last hull Vector
    -- and put it at the front of our array.
    -- Stop when we see our first Vector again.
    repeat
        table.insert(hull, v[1])
        local next_index = 2
        for i = 3, #v do
            if ccw(v[1], v[i], v[next_index]) < 0 then
                next_index = i
            end
        end
        v[1], v[next_index] = v[next_index], v[1]
    until v[1].x == hull[1].x and v[1].y == hull[1].y

    return hull
end

local function get_circumference(points)
    local new_points = {}

    for i = 1, #points do
        local pos = points[i]
        
        for j = 0, 3 do
            local p = j * (360 / 4) * (math.pi / 200)
            table.insert(new_points, pos + vector(math.cos(p) * 60, math.sin(p) * 60, 0))

            if _DEBUG == true then
                render.circle_outline((pos + vector(math.cos(p) * 60, math.sin(p) * 60, 0)):to_screen(), color(255, 0, 0), 3.0, 0, 1.0)
            end
        end
    end

    return new_points
end

local function draw_polygon(points, alpha)
    local poly_clr = clr:get()
    poly_clr.a = poly_clr.a * (alpha / 100)
    local poly_line_clr = outline_clr:get()
    poly_line_clr.a = poly_line_clr.a * (alpha / 100)

    local hull = gift_wrapping(get_circumference(points))
    local screen_pos = {}
    for i = 1, #hull do
        --print(hull[i]:unpack())
        table.insert(screen_pos, hull[i]:to_screen())
    end

    -- draw it
    if #screen_pos <= 3 then return end
 
    render.poly(poly_clr, table.unpack(screen_pos))

    if (outline:get() == 'Line') then
        render.poly_line(poly_line_clr, table.unpack(screen_pos))
        render.poly_line(poly_line_clr, screen_pos[1], screen_pos[#screen_pos])
    end
end 

local function on_draw(ctx)
    if enable:get() == false then return end

    local me = entity.get_local_player()
    if me == nil then return end
    -- actully main loop lol
    entity.get_entities("CInferno", true, function(ent)
        if ent == nil then return end
        local owner_handle = ent.m_hOwnerEntity
        local owner = entity.get(owner_handle)
        if owner == nil then return end
        
        local alpha_value = (ent.m_vecOrigin:dist(me.m_vecOrigin) > distance:get()) and math.lerp(100, 0, 1) or math.lerp(0, 100, 1) 
        
        -- only do enemy molotov
        if not owner:is_enemy() and owner ~= me and only_enemy:get() then return end

        local points = {}
        for i = 1, ent.m_fireCount do
            if ( ent.m_bFireIsBurning[i]) then
                table.insert(points, ent.m_vecOrigin + vector(ent.m_fireXDelta[i], ent.m_fireYDelta[i], ent.m_fireZDelta[i]))
            end
        end

        draw_polygon(points, alpha_value)
    end)
end

local function on_glow(ctx)
    local me = entity.get_local_player()
    if me == nil then return end

    -- actully main loop lol
    entity.get_entities("CInferno", true, function(ent)
        if ent == nil then return end
        local owner_handle = ent.m_hOwnerEntity
        local owner = entity.get(owner_handle)
        if owner == nil then return end
        
        local alpha_value = (ent.m_vecOrigin:dist(me.m_vecOrigin) > distance:get()) and math.lerp(100, 0, 4) or math.lerp(0, 100, 4) 
        
        -- only do enemy molotov
        if not owner:is_enemy() and owner ~= me and only_enemy:get() then return end

        local points = {}
        for i = 1, ent.m_fireCount do
            if ( ent.m_bFireIsBurning[i]) then
                table.insert(points, ent.m_vecOrigin + vector(ent.m_fireXDelta[i], ent.m_fireYDelta[i], ent.m_fireZDelta[i]))
            end
        end

        local line_clr = outline_clr:get()
        line_clr.a = line_clr.a * (alpha_value / 100)
    
        local hull = gift_wrapping(get_circumference(points))
        local prev = vector(0 , 0)
        for i = 1, #hull do
            if prev.x ~= 0 and prev.y ~= 0 and i > 2 then
                ctx:render(prev, hull[i], outline_thickness:get() / 100, 'lgw', line_clr)
            end
            prev = hull[i]
        end

        -- table doesnt include this so we manually draw it lol...
        if #hull > 3 then
            ctx:render(hull[1], hull[#hull], outline_thickness:get() / 100, 'lgw', line_clr)
        end
    end)
end

enable:set_callback(function(self)
    if self then
        events.render:set(on_draw)
    else
        events.render:unset(on_draw)
    end
end, true)

outline:set_callback(function(self)
    outline_thickness:visibility(self:get() ~= 'None')
    outline_clr:visibility(self:get() ~= 'None')
    
    if self:get() ~= 'Line' and self:get() ~= 'None' then
        events.render_glow:set(on_glow)
    else
        events.render_glow:unset(on_glow)
    end
end, true)