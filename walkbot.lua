RunScript("walkbot_mesh.lua");

-- Mesh Walkbot by ShadyRetard
local RESET_TIMEOUT = 30;
local RETARGET_TIMEOUT = 150;
local STUCK_TIMEOUT = 100;
local MESHWALK_MAX_DISTANCE = 300;
local STUCK_SPEED_MAX = 10;
local SHOT_TIMEOUT = 20;
local COMMAND_TIMEOUT = 100;
local AIMBOT_TIMEOUT = 30;

local WALKBOT_ENABLE_CB = gui.Checkbox(gui.Reference("MISC", "AUTOMATION", "Movement"), "WALKBOT_ENABLE_CB", "Enable Walkbot", false);
local WALKBOT_DRAWING_CB = gui.Checkbox(gui.Reference("MISC", "AUTOMATION", "Movement"), "WALKBOT_DRAWING_CB", "Walkbot Drawing", false);
local WALKBOT_TARGET_CB = gui.Checkbox(gui.Reference("MISC", "AUTOMATION", "Movement"), "WALKBOT_TARGET_CB", "Walkbot Target Enemies", false);

local last_command = globals.TickCount();
local aimbot_target_change_time = globals.TickCount();
local last_target_time = globals.TickCount();
local speed_slow_since = globals.TickCount();
local last_reset = globals.TickCount();
local last_shot = globals.TickCount();
local aimbot_target;
local is_shooting;

local next_target;
local path_to_follow;
local current_index;

function drawEventHandler()
    if (WALKBOT_ENABLE_CB:GetValue() == false) then
        return
    end

    if (WALKBOT_DRAWING_CB:GetValue() == false) then
        return;
    end

    if (path_to_follow == nil) then
        return;
    end

    local me = entities.GetLocalPlayer();
    if (me == nil) then
        return;
    end

    local my_x, my_y, my_z = me:GetAbsOrigin();
    for i=1, #path_to_follow do
        local mx, my = client.WorldToScreen(path_to_follow[i].x, path_to_follow[i].y, path_to_follow[i].z);

        if (mx ~= nil and my ~= nil and i >= current_index) then
            draw.Color(255,255,255,255);
            draw.Text(mx, my+10, i);
            draw.Color(255,0,0,255);
            draw.FilledRect(mx-4, my-4, mx+4, my+4);


            -- Also draw lines in between the rectangles
            if (i < #path_to_follow) then
                local m2x, m2y = client.WorldToScreen(path_to_follow[i+1].x, path_to_follow[i+1].y, path_to_follow[i+1].z);
                draw.Line(mx, my, m2x, m2y);
            end
        end
    end
end

function moveEventHandler(cmd)
    if (WALKBOT_ENABLE_CB:GetValue() == false) then
        return;
    end

    local map = getActiveMap();
    local me = entities.GetLocalPlayer();

    if (map == nil or me == nil) then
        last_shot = nil;
        is_shooting = false;
        last_command = nil;
        path_to_follow = nil;
        current_index = nil;
        last_reset = nil;
        next_target = nil;
        return;
    end

    if (last_reset ~= nil and last_reset > globals.TickCount()) then
        last_reset = globals.TickCount();
    end

    if (last_command ~= nil and last_command > globals.TickCount()) then
        last_command = globals.TickCount();
    end

    if (last_shot ~= nil and last_shot > globals.TickCount()) then
        last_shot = globals.TickCount();
    end

    local my_x, my_y, my_z = me:GetAbsOrigin();

    if (is_shooting and (last_shot == nil or globals.TickCount() - last_shot > SHOT_TIMEOUT)) then
        is_shooting = false;
    elseif (is_shooting) then
        -- We're shooting, stand still and let the aimbot do its thing
        return;
    end

    if (aimbot_target ~= nil and globals.TickCount() - aimbot_target_change_time < AIMBOT_TIMEOUT) then
        return;
    elseif(aimbot_target ~= nil) then
        aimbot_target = nil;
    end

    if (not me:IsAlive()) then
        -- If we're not on a team yet, quickly join a random team so we can start
        if (me:GetTeamNumber() == 0 and (last_command == nil or globals.TickCount() - last_command > COMMAND_TIMEOUT)) then
            local rnd = math.random(0, 1);

            -- 0=CT,1=SPECTATOR,2=T
            if (rnd == 1) then
                rnd = 2
            end

            client.Command("jointeam " .. rnd, true);
            last_command = globals.TickCount();
        end

        path_to_follow = nil;
        current_index = nil;
        return;
    end

    -- If we've been stopped for a while, let's try to get unstuck
    if (speed_slow_since ~= nil) then
        if (globals.TickCount() - speed_slow_since > STUCK_TIMEOUT) then
            path_to_follow = nil;
            current_index = nil;
            speed_slow_since = nil;
        elseif (globals.TickCount() - speed_slow_since > 60) then
            -- Crouch and shoot (in case there is a vent)
            cmd:SetButtons(4);
            cmd:SetButtons(1);
        elseif (globals.TickCount() - speed_slow_since > 20) then
            -- Jump
            cmd:SetButtons(2);
        elseif (globals.TickCount() - speed_slow_since > 10) then
            cmd:SetSideMove(250);
        end
    end

    if (WALKBOT_TARGET_CB:GetValue() == true and (last_target_time == nil or globals.TickCount() - last_target_time > RETARGET_TIMEOUT)) then
        local enemy = getClosestPlayer(my_x, my_y, my_z);
        if (enemy ~= nil) then
            local ex, ey, ez = enemy:GetAbsOrigin();
            path_to_follow = nil;
            current_index = nil;
            last_target_time = globals.TickCount();
            next_target = getClosestMesh(ex, ey, ez, map);
        end
    end

    -- If we currently don't have a target, get the closest mesh
    if (path_to_follow == nil and (last_reset == nil or globals.TickCount() - last_reset > RESET_TIMEOUT)) then
        last_reset = globals.TickCount();
        local start_point = getClosestMesh(my_x, my_y, my_z, map);
        local end_point;
        if (next_target ~= nil) then
            end_point = next_target;
            next_target = nil;
        else
            end_point = map['nodes'][math.random(1, #map['nodes'])];
        end
        path_to_follow = path(start_point, end_point, map['nodes'], map['edges'], false);

        if (path_to_follow == nil) then
            return;
        end
    elseif (path_to_follow == nil) then
        return;
    end

    -- Start the path
    if (current_index == nil) then
        current_index = 1;

        -- Path ended, reset and retrieve a new path
    elseif (current_index == #path_to_follow) then
        current_index = nil;
        path_to_follow = nil;
        return;
    end

    local vx = me:GetPropFloat('localdata', 'm_vecVelocity[0]');
    local vy = me:GetPropFloat('localdata', 'm_vecVelocity[1]');
    local speed = math.floor(math.min(10000, math.sqrt(vx * vx + vy * vy) + 0.5));

    if (speed < STUCK_SPEED_MAX) then
        if (speed_slow_since == nil) then
            speed_slow_since = globals.TickCount();
            return;
        end

        if (globals.TickCount() - speed_slow_since > STUCK_TIMEOUT) then
            current_index = nil;
            path_to_follow = nil;
            return;
        end
    else
        speed_slow_since = nil;
    end

    local target = path_to_follow[current_index];
    if (target == nil) then
        current_index = nil;
        path_to_follow = nil;
        return;
    end

    local distance = getDistanceToTarget(my_x, my_y, 0, target["x"], target["y"], 0);

    -- We're close enough to the center of the mesh, pick the next target for 'smoothing' reasons
    if (distance < 25) then
        current_index = current_index + 1;
        return;
    end

    cmd:SetForwardMove(250);
    cmd:SetSideMove(0);
    -- Calculating the angle from the current target (absolute position)
    local wa_x, wa_y, wa_z = getAngle(my_x, my_y, my_z, target["x"], target["y"], target["z"]);
    doMovement(wa_x, wa_y, wa_z, cmd);
end

function aimbotTargetHandler(ent)
    if (ent ~= nil) then
        aimbot_target_change_time = globals.TickCount();
        aimbot_target = ent;
    end
end

function gameEventHandler(event)
    local self_pid = client.GetLocalPlayerIndex();
    local self = entities.GetLocalPlayer();

    if (self_pid == nil or self == nil) then
        return;
    end

    if (event:GetName() == "round_start") then
        is_shooting = false;
        speed_slow_since = nil;
        path_to_follow = nil;
        current_index = nil;
    end

    if (event:GetName() == "player_death") then
        local victim_pid = client.GetPlayerIndexByUserID(event:GetInt('userid'));

        if (aimbot_target ~= nil and aimbot_target:GetIndex() == victim_pid) then
            aimbot_target = nil;
        end
    end


    if (event:GetName() == "weapon_fire") then
        local shooter_pid = client.GetPlayerIndexByUserID(event:GetInt('userid'));
        local shooter = entities.GetByUserID(event:GetInt('userid'));

        if (shooter == nil) then
            return;
        end

        if (shooter_pid == self_pid) then
            is_shooting = true;
            last_shot = globals.TickCount();
        end
    end
end

function getClosestMesh(my_x, my_y, my_z, map)
    local closestMesh;
    local closestDistance;
    local nodes = map["nodes"];

    for k, v in pairs(nodes) do
        if (v ~= nil) then
            local distance = getDistanceToTarget(my_x, my_y, my_z, v["x"], v["y"], v["z"]);
            -- We don't want to go back to the last target
            if (closestDistance == nil or distance < closestDistance) then
                closestDistance = distance;
                closestMesh = v;
            end
        end
    end

    return closestMesh;
end

function getClosestPlayer(my_x, my_y, my_z)
    local closestPlayer;
    local closestDistance = 1000000; -- Arbitrary high number
    local players = entities.FindByClass("CCSPlayer");
    local self = entities.GetLocalPlayer();

    if (self == nil) then
        return;
    end

    for i = 1, #players do
        local player = players[i]
        -- We don't want to target ourselves or dead players
        if (player:GetIndex() ~= client.GetLocalPlayerIndex() and player:IsAlive() and player:GetTeamNumber() ~= self:GetTeamNumber()) then
            -- Find the closest player
            local px, py, pz = player:GetAbsOrigin();
            local distance = getDistanceToTarget(my_x, my_y, my_z, px, py, pz);
            if (distance < closestDistance) then
                closestDistance = distance;
                closestPlayer = player;
            end
        end
    end

    if (closestDistance == 1000000 or closestPlayer == nil) then
        return;
    end;

    return closestPlayer;
end

function getActiveMap()
    local map_name = client.GetConVar("host_map");

    if (map_name == nil) then
        return;
    end

    return maps[map_name];
end

callbacks.Register("Draw", "walkbot_draw_event", drawEventHandler);
callbacks.Register("FireGameEvent", "walkbot_game_event", gameEventHandler);
callbacks.Register("CreateMove", "walkbot_move", moveEventHandler);
callbacks.Register("AimbotTarget", "walkbot_aimbot_target", aimbotTargetHandler);

-- Movements and calculations
function doMovement(wa_x, wa_y, wa_z, cmd)
    cmd:SetViewAngles(wa_x, wa_y, wa_z);
    local va_x, va_y, va_z = cmd:GetViewAngles();
    local d_v;
    local f1, f2;

    if (wa_y < 0.) then
        f1 = 360.0 + wa_y;
    else
        f1 = wa_y;
    end

    if (va_y < 0.0) then
        f2 = 360.0 + va_y;
    else
        f2 = va_y;
    end

    if (f2 < f1) then
        d_v = math.abs(f2 - f1);
    else
        d_v = 360.0 - math.abs(f1 - f2);
    end

    d_v = 360.0 - d_v;
    cmd:SetForwardMove(math.cos(d_v * (math.pi / 180)) * cmd:GetForwardMove() + math.cos((d_v + 90.) * (math.pi / 180)) * cmd:GetSideMove());
    cmd:SetSideMove(math.sin(d_v * (math.pi / 180)) * cmd:GetForwardMove() + math.sin((d_v + 90.) * (math.pi / 180)) * cmd:GetSideMove());
end

function vectorAngles(d_x, d_y, d_z)
    local t_x;
    local t_y;
    local t_z;
    if (d_x == 0 and d_y == 0) then
        if (d_z > 0) then
            t_x = 270;
        else
            t_x = 90;
        end
        t_y = 0;
    else
        t_x = math.atan(-d_z, math.sqrt(d_x ^ 2 + d_y ^ 2)) * -180 / math.pi;
        t_y = math.atan(d_y, d_x) * 180 / math.pi;

        if (t_y > 90) then
            t_y = t_y - 180;
        elseif (t_y < 90) then
            t_y = t_y + 180;
        elseif (t_y == 90) then
            t_y = 0;
        end
    end

    t_z = 0;

    return t_x, t_y, t_z;
end

function normalizeAngles(a_x, a_y, a_z)
    while (a_x > 89.0) do
        a_x = a_x - 180.;
    end

    while (a_x < -89.0) do
        a_x = a_x + 180.;
    end

    while (a_y > 180.) do
        a_y = a_y - 360;
    end

    while (a_y < -180.) do
        a_y = a_y + 360;
    end

    return a_x, a_y, a_z;
end

function getAngle(my_x, my_y, my_z, t_x, t_y, t_z)
    local d_x = my_x - t_x;
    local d_y = my_y - t_y;
    local d_z = my_z - t_z;

    local va_x, va_y, va_z = vectorAngles(d_x, d_y, d_z);
    return normalizeAngles(va_x, va_y, va_z);
end

function getDistanceToTarget(my_x, my_y, my_z, t_x, t_y, t_z)
    local dx = my_x - t_x;
    local dy = my_y - t_y;
    local dz = my_z - t_z;
    return math.sqrt(dx^2 + dy^2 + dz^2);
end

local INF = 1 / 0;
local cachedPaths;

function dist(x1, y1, z1, x2, y2, z2)
    local dx = x1 - x2;
    local dy = y1 - y2;
    local dz = z1 - z2;

    return math.sqrt(dx^2 + dy^2 + dz^2);
end

function dist_between(nodeA, nodeB)
    return dist(nodeA.x, nodeA.y, nodeA.z, nodeB.x, nodeB.y, nodeB.z)
end

function heuristic_cost_estimate(nodeA, nodeB)
    return dist(nodeA.x, nodeA.y, nodeA.z, nodeB.x, nodeB.y, nodeB.z)
end

function lowest_f_score(set, f_score)
    local lowest, bestNode = INF, nil
    for _, node in ipairs(set) do
        local score = f_score[node]
        if score < lowest then
            lowest, bestNode = score, node
        end
    end
    return bestNode
end

function neighbor_nodes(theNode, nodes, edges)
    local neighbors = {}

    local neighbor_ids = edges[theNode.id];

    for _, node in ipairs(nodes) do
        if (neighbor_ids ~= nil and #neighbor_ids > 0 and not not_in(neighbor_ids, node.id)) then
            table.insert(neighbors, node);
        end
    end
    return neighbors
end

function not_in(set, theNode)
    for _, node in ipairs(set) do
        if node == theNode then return false end
    end
    return true
end

function remove_node(set, theNode)
    for i, node in ipairs(set) do
        if node == theNode then
            set[i] = set[#set]
            set[#set] = nil
            break
        end
    end
end

function unwind_path(flat_path, map, current_node)
    if map[current_node] then
        table.insert(flat_path, 1, map[current_node])
        return unwind_path(flat_path, map, map[current_node])
    else
        return flat_path
    end
end

function a_star(start, goal, nodes, edges)
    local closedset = {}
    local openset = { start }
    local came_from = {}

    local g_score, f_score = {}, {}
    g_score[start] = 0
    f_score[start] = g_score[start] + heuristic_cost_estimate(start, goal)

    while #openset > 0 do

        local current = lowest_f_score(openset, f_score)
        if current == goal then
            local path = unwind_path({}, came_from, goal)
            table.insert(path, goal)
            return path
        end

        remove_node(openset, current)
        table.insert(closedset, current)

        local neighbors = neighbor_nodes(current, nodes, edges)

        for _, neighbor in ipairs(neighbors) do
            if not_in(closedset, neighbor) then

                local tentative_g_score = g_score[current] + dist_between(current, neighbor)

                if not_in(openset, neighbor) or tentative_g_score < g_score[neighbor] then
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g_score
                    f_score[neighbor] = g_score[neighbor] + heuristic_cost_estimate(neighbor, goal)
                    if not_in(openset, neighbor) then
                        table.insert(openset, neighbor)
                    end
                end
            end
        end
    end
    return nil -- no valid path
end
function clear_cached_paths()
    cachedPaths = nil
end

function distance(x1, y1, z1, x2, y2, z2)
    return dist(x1, y1, z1, x2, y2, z2);
end

function path(start, goal, nodes, edges, ignore_cache)

    if not cachedPaths then cachedPaths = {} end
    if not cachedPaths[start] then
        cachedPaths[start] = {}
    elseif cachedPaths[start][goal] and not ignore_cache then
        return cachedPaths[start][goal]
    end

    local resPath = a_star(start, goal, nodes, edges)
    if not cachedPaths[start][goal] and not ignore_cache then
        cachedPaths[start][goal] = resPath
    end

    return resPath
end