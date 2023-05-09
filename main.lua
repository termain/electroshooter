local go = {}
local cc = {} --constants
cc.ke = 1000--8.9875517923e9 --coulomb constant
cc.max_charge = 1.0
cc.max_bullet_velocity = 200.0
cc.min_bullet_velocity = 10.0
cc.bullet_charge_time = 2.0
cc.bullet_charge_rate = (cc.max_bullet_velocity-cc.min_bullet_velocity)/
                         cc.bullet_charge_time
cc.max_player_charge = 10.0

--love2d version specific constants
cc.version = {}
cc.version.major, cc.version.minor, cc.version.revision = love.getVersion()
cc.cs = 1.0/255.0
cc.left_mouse_button = 1
cc.right_mouse_button = 2

if cc.version.major < 11 then
    cc.cs = 1.0
end

if cc.version.major == 0 and cc.version.minor < 10 then
    cc.left_mouse_button = 'l'
    cc.right_mouse_button = 'r'
end


go.bullets = {}
go.enemies = {}

function normalize_color( color )
	return { cc.cs*color[1],cc.cs*color[2],cc.cs*color[3] }
end

function nothing()
end

function charge_to_color( charge )
    if charge < 0 then
        return {0,0,255}
    end
    if charge > 0 then
        return {255,0,0}
    end
    return {255,255,255}
end

function create_regular_enemy( name, xx, charge )
    local enemy     = {}
    enemy.name      = name
    enemy.r         = xx --2D Location
    enemy.charge    = charge
    enemy.draw      = draw_enemy
    enemy.update    = nothing
    enemy.active    = true
    enemy.hitbox    = {36, 36}
    enemy.on_hit    = deactivate_enemy
    enemy.linewidth = 1
    enemy.color     = normalize_color( {192,192,192} )
    return enemy
end

function create_shield_enemy( name, xx, charge )
    local enemy = create_regular_enemy( name, xx, charge )
    enemy.on_hit = nothing
    enemy.hitbox = {36,72}
    enemy.color     = normalize_color( {255,215,0} )
    return enemy
end

function create_half_shield_enemy( name, xx )
    local enemy = create_shield_enemy( name, xx, 0 )
    enemy.on_hit = half_shield_hit
    enemy.front_color = normalize_color( {255,215,0} )
    enemy.color = normalize_color( {192,192,192} )
    enemy.draw = draw_half_shield_enemy
    enemy.charge = 0
    return enemy
end

function create_bullet( name, xx, vv, mass, charge )
    local bullet    = {}
    bullet.name     = name
    bullet.r        = xx
    bullet.v        = vv
    bullet.charge   = charge
    bullet.draw     = nothing
    bullet.update   = update_bullet
    bullet.mass     = mass
    bullet.age      = 0.0
    bullet.lifetime = 10.0
    bullet.active   = false
    return bullet
end   

function draw_enemy( enemy )
    local hbx=enemy.hitbox[1]
    local hby=enemy.hitbox[2]
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(enemy.linewidth)
    --love.graphics.setColor( charge_to_color( enemy.charge ) )
    love.graphics.setColor(enemy.color)
    love.graphics.rectangle("line",enemy.r[1]-hbx/2,enemy.r[2]-hby/2, hbx,hby)
    love.graphics.setLineWidth(lw)
    local charge_string = string.format("%.2f", enemy.charge)
    love.graphics.printf(enemy.name..":"..charge_string,
                         enemy.r[1]-hbx/2,enemy.r[2]-hby/2,hbx-4, "center")
end

function draw_half_shield_enemy( enemy )
    local hbx=enemy.hitbox[1]
    local hby=enemy.hitbox[2]
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(enemy.linewidth) 
    love.graphics.setColor(enemy.front_color)
    love.graphics.line(enemy.r[1],enemy.r[2]+hby/2,
                      enemy.r[1]-hbx/2,enemy.r[2]+hby/2,
                      enemy.r[1]-hbx/2,enemy.r[2]-hby/2,
                      enemy.r[1],enemy.r[2]-hby/2 )  
    love.graphics.setColor(enemy.color)
    love.graphics.line(enemy.r[1],enemy.r[2]+hby/2,
                      enemy.r[1]+hbx/2,enemy.r[2]+hby/2,
                      enemy.r[1]+hbx/2,enemy.r[2]-hby/2,
                      enemy.r[1],enemy.r[2]-hby/2 )
    love.graphics.setLineWidth(lw)
    local charge_string = string.format("%.2f", enemy.charge)
    love.graphics.printf(enemy.name..":"..charge_string,
                         enemy.r[1]-hbx/2,enemy.r[2]-hby/2,hbx-4, "center")
end
    

function draw_bullet( bullet )
    if bullet.active then
        love.graphics.setColor( charge_to_color( bullet.charge ) )
        love.graphics.circle("fill",bullet.r[1],bullet.r[2], 2)
    end
end


function activate_bullet( bullet, xx, vv, charge )
    bullet.r = {xx[1],xx[2]}
    bullet.v = vv
    bullet.charge = charge
    bullet.age = 0.0
    bullet.active = true
    bullet.draw   = draw_bullet
end

function deactivate_bullet( bullet )
    bullet.r = {0,0}
    bullet.v = {0,0}
    bullet.charge = 0
    bullet.age = 0.0
    bullet.active = false
    bullet.draw = nothing
end

function deactivate_enemy( enemy )
    enemy.active    = false
    enemy.charge    = 0
    enemy.draw      = nothing
    enemy.update    = nothing
end    

function half_shield_hit( enemy, bullet )
    if bullet.v[1] < 0 then
        deactivate_enemy( enemy )
    end
end

function create_player( xx )
    local player    = {}
    player.name     = "player"
    player.r        = xx
    player.v        = {0.0,0.0}
    player.theta    = 0 --degrees from horizontal (currently just charge beam angle)
    player.omega    = 0 --rotational velocity (currently of charge beam)
    player.draw     = draw_player
    player.update   = update_player
    player.charge   = 0
    player.cannon_timer = 0.0
    player.cannon_reload = 1.0
    player.loaded_bullet_index = 1
    player.loaded_bullet_charge = 0
    player.firing_cannon  = false
    player.is_cooled_down = true
    player.beam_state = 0 --0 off. 1 for on (may add faster rates later)
    player.beam_dx = 1.0 --beam drawing unit vector
    player.beam_dy = 0.0 
    player.length  = 16
    --velocity of loaded bullet as it leaves muzzle
    player.loaded_bullet_velocity = 10.0
    player.net_charge = 0
    return player
end

function draw_player( player )
    local pl = player.length
    local pw = 4
    love.graphics.setColor( charge_to_color( player.loaded_bullet_charge ) )
    love.graphics.polygon( "fill", player.r[1]+2*pl, player.r[2],
                                    player.r[1],    player.r[2]+pw,
                                    player.r[1],    player.r[2]-pw )
end

function cycle_charge(current_charge)
    if current_charge == 1 then
        return -1, {0,0,255}
    end
    if current_charge == -1 then
        return 0, {255,255,255}
    end
    if current_charge == 0 then
        return 1, {255, 0, 0}
    end
end

function love.keyreleased(key)
    if key == "f" then
        go.player.firing = true
    end
    if key == "a" then
        go.player.loaded_bullet_charge = cycle_charge(go.player.loaded_bullet_charge)
    end
    if key == "s" then
        go.player.loaded_bullet_charge = cycle_charge(
                                         cycle_charge(go.player.loaded_bullet_charge) )
    end
    if key == "escape" then
        love.event.quit( 0 )
    end
end
    

function update_player(player, dt, bullet_array)
    player.v[2] = 0
    player.omega = 0
    player.beam_state = 0
    local player_v = 100
    local beam_rotation_rate = math.pi/8.0;
    if love.keyboard.isDown("up") then
        player.v[2] = -player_v
    end
    if love.keyboard.isDown("down") then
        player.v[2] = player_v
    end
    if love.keyboard.isDown("right") then
        player.omega = beam_rotation_rate
    end
    if love.keyboard.isDown("left") then
        player.omega = -beam_rotation_rate
    end
    if love.keyboard.isDown("d") then
        player.beam_state = 1.0
    end
    if love.keyboard.isDown("f") then
        player.loaded_bullet_velocity = 
            math.min( player.loaded_bullet_velocity + dt*cc.bullet_charge_rate, 
                 cc.max_bullet_velocity )
    end
    if player.firing and player.is_cooled_down then
        activate_bullet( bullet_array[player.loaded_bullet_index],
                            player.r,{player.loaded_bullet_velocity,0.0},
                            player.loaded_bullet_charge )
        player.loaded_bullet_velocity = cc.min_bullet_velocity
        if player.loaded_bullet_index == #bullet_array then
            player.loaded_bullet_index = 1
        else
            player.loaded_bullet_index = player.loaded_bullet_index + 1
        end
        player.firing = false
        player.is_cooled_down = false
    end
    if player.is_cooled_down == false then
        player.cannon_timer = player.cannon_timer+dt
        if player.cannon_timer > player.cannon_reload then
            player.is_cooled_down = true
            player.cannon_timer = 0.0
        end
    end

    player.r[2] = math.max( 
        0,math.min(
            player.r[2]+player.v[2] * dt, love.graphics.getHeight()))
    
    player.theta = player.theta+player.omega * dt
    if player.theta < -math.pi/2.0 then
        player.theta = -math.pi/2.0
    end
    if player.theta > math.pi/2.0 then
        player.theta = math.pi/2.0
    end
end

function update_bullet( bullet, dt )
    
    local ff = electrostatic_force_on_bullet( bullet, go.enemies )
    local aa = {}
    aa[1] = ff[1]/bullet.mass
    aa[2] = ff[2]/bullet.mass
    bullet.r[1] = bullet.r[1]+bullet.v[1]*dt
    bullet.r[2] = bullet.r[2]+bullet.v[2]*dt
    bullet.v[1] = bullet.v[1]+aa[1]*dt
    bullet.v[2] = bullet.v[2]+aa[2]*dt

    bullet.age = bullet.age+dt
    if( bullet.age > bullet.lifetime ) then
        deactivate_bullet( bullet )
    end
end

--Discrete charge potential at point due to object
function potential_from_object( object, point )
    local dd = distance(object.r,point)
    return cc.ke*object.charge/distance(object.r,point)
end

--Discrete charge vector field at point due to object
function evector_from_object( object, point )
    local rr = {point[1]-object.r[1], point[2]-object.r[2]}
    local dd = distance(object.r,point)
    local runit = {rr[1]/dd, rr[2]/dd}

    local efield = cc.ke*object.charge/(dd^2)
    return {runit[1]*efield,runit[2]*efield}
end

--electrical force on bullet
function electrostatic_force_on_bullet( bullet, enemy_array )
    local sum = {0.0,0.0}
    local test_obj = bullet
    for index, object in ipairs(enemy_array) do
        if object.active then
            local efield = evector_from_object( object, test_obj.r )
            sum[1] = sum[1]+efield[1]*test_obj.charge
            sum[2] = sum[2]+efield[2]*test_obj.charge
        end
    end
    return sum
end

function love.keypressed(key, u)
   --Debug
   if key == "rctrl" then --set to whatever key you want to use
      debug.debug()
   end
end


--check for bullet collisions
function check_for_hit_and_resolve( bullet_array, enemy_array )
    for _, bullet in ipairs(bullet_array) do
        for _, enemy in ipairs(enemy_array ) do 
            if enemy.active and bullet.active then
                 --upper left corner of enemy
                 local ulc = {enemy.r[1]-enemy.hitbox[1]/2,
                              enemy.r[2]-enemy.hitbox[2]/2 }
                 local abs_hitbox = {{ulc[1],ulc[1]+enemy.hitbox[1]},
                                     {ulc[2],ulc[2]+enemy.hitbox[2]}}
                 local bx = bullet.r

                 if( bx[1] > abs_hitbox[1][1] and bx[1] < abs_hitbox[1][2] and
                     bx[2] > abs_hitbox[2][1] and bx[2] < abs_hitbox[2][2] ) then
                    enemy:on_hit( bullet )
                    deactivate_bullet( bullet )
                 end
            end
        end
    end
end

function distance( pointa, pointb )
    local xx = pointb[1] - pointa[1]
    local yy = pointb[2] - pointa[2]
    return math.sqrt( xx^2 + yy^2 )
end

function draw_field( field )

    local height = love.graphics.getHeight( )
    local width = love.graphics.getWidth( )
    local red = 0
    local blue = 0
    for hloc = 1,height,10 do
        for wloc = 1, width,10 do
            field_strength = field( {wloc, hloc} )
            
            if(field_strength < 0 ) then
                blue = -field_strength
            else
                red = field_strength
            end
            love.graphics.setColor( normalize_color({ math.min(red,240), 0, math.min(blue,240)}) )
            --love.graphics.circle( "fill",wloc,hloc, 5 )
            love.graphics.rectangle("fill",wloc-5,hloc-5,10,10)
        end
    end
end

function draw_charge_beam( player )
    local beam_color = normalize_color({0,255,0})
    if( player.beam_state ~= 0 ) then
        beam_color = charge_to_color(player.loaded_bullet_charge)
    end

    local x0 = player.r[1]+player.length
    local y0 = player.r[2]

    love.graphics.setColor( beam_color )
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth( lw+player.beam_state*2 )
    love.graphics.line( x0, y0, x0+1000.0*player.beam_dx, 
                                y0+1000.0*player.beam_dy )
    love.graphics.setLineWidth(lw)
end

function beam_y_at_x( player, x )
    return player.beam_dy/player.beam_dx*(x-player.length)+player.r[2]
end

function update_charge_beam_effects( player, dt, enemy_array )
    player.beam_dx = math.cos((player.theta))
    player.beam_dy = math.sin((player.theta))

    --if player.beam_state > 0 and player.loaded_bullet_charge ~= 0 then
        for _, enemy in ipairs( enemy_array ) do
            local frontx    = enemy.r[1]-enemy.hitbox[1]/2
            local backx     = enemy.r[1]+enemy.hitbox[1]/2
            local topy      = enemy.r[2]+enemy.hitbox[2]/2
            local bottomy   = enemy.r[2]-enemy.hitbox[2]/2
            
            local ybeam_front = beam_y_at_x(player,frontx)
            local ybeam_back  = beam_y_at_x(player,backx)
            if (( ybeam_front < topy and ybeam_front > bottomy ) or
                ( ybeam_back  < topy and ybeam_back  > bottomy ) ) then
                enemy.charge = enemy.charge+
                        player.beam_state*player.loaded_bullet_charge*dt
                if enemy.charge > cc.max_charge then
                    enemy.charge = cc.max_charge
                end
                if enemy.charge < -cc.max_charge then
                    enemy.charge = -cc.max_charge
                end
                enemy.linewidth=2
            else
                enemy.linewidth=1
            end
        end
    --end
end

function potential_field_update( objects )
    function potential_field( point )
        local sum = 0.0
        for _, object in ipairs(objects) do
            if object.active then
                sum = sum + potential_from_object(object, point )
            end
        end 
        return sum
    end
    return potential_field
end

function love.mousepressed(x, y, button, istouch)
    if button == cc.left_mouse_button then
        field_text_location[1] = x
        field_text_location[2] = y
    end
    if button == cc.right_mouse_button and go.player.is_cooled_down then
        activate_bullet( go.bullets[go.player.loaded_bullet_index],
                            {x,y},{0,0.0},
                            go.player.loaded_bullet_charge )
        if go.player.loaded_bullet_index == #go.bullets then
            go.player.loaded_bullet_index = 1
        else
            go.player.loaded_bullet_index = go.player.loaded_bullet_index + 1
        end
    end
        
end

function add_object( obj_array, object )
    obj_array[#obj_array+1]=object
end

function level1( )

    add_object(go.enemies, create_regular_enemy( "E0", {100,300}, 0 ) )

    add_object(go.enemies, create_regular_enemy( "E01", {300,100}, 0 ) )
    add_object(go.enemies, create_regular_enemy( "E02", {300,200}, 0 ) )
    add_object(go.enemies, create_regular_enemy( "E03", {300,300}, 0 ) )
    add_object(go.enemies, create_regular_enemy( "E04", {300,400}, 0 ) )
    add_object(go.enemies, create_regular_enemy( "E05", {300,500}, 0 ) )

    add_object(go.enemies, create_regular_enemy( "E11", {500,100}, 0 ) )
    add_object(go.enemies, create_regular_enemy( "E12", {500,200}, 0 ) )
    add_object(go.enemies, create_regular_enemy( "E13", {500,300}, 0 ) )
    add_object(go.enemies, create_regular_enemy( "E14", {500,400}, 0 ) )
    add_object(go.enemies, create_regular_enemy( "E15", {500,500}, 0 ) )

    add_object(go.enemies, create_shield_enemy( "S11", {400,100}, 0 ) )
    add_object(go.enemies, create_shield_enemy( "S12", {400,200}, 0 ) )
    add_object(go.enemies, create_shield_enemy( "S13", {400,300}, 0 ) )
    add_object(go.enemies, create_shield_enemy( "S14", {400,400}, 0 ) )
    add_object(go.enemies, create_shield_enemy( "S15", {400,500}, 0 ) )

    add_object(go.enemies, create_half_shield_enemy( "H1", {200,100}) )
    add_object(go.enemies, create_half_shield_enemy( "H2", {200,200}) )
    add_object(go.enemies, create_half_shield_enemy( "H3", {200,300}) )
    add_object(go.enemies, create_half_shield_enemy( "H4", {200,400}) )
    add_object(go.enemies, create_half_shield_enemy( "H5", {200,500}) )
end

function love.load()
    field_text_location = {0,0}

    level1()

    for index = 1, 20 do
        add_object(go.bullets,
            create_bullet( "B"..index, {0.0,0.0}, {0.0,0.0}, 0.001, 0) )
    end

    go.player  = create_player({0,300})

    love.mouse.setVisible(true)
end

function love.update(dt)
    --Calculate potential field
    go.field = potential_field_update( go.enemies )

    --Update player
    go.player:update(dt, go.bullets)
    --update beam
    update_charge_beam_effects(go.player, dt, go.enemies)
    --Updates bullets before enemies so that collisions are resolved
    --in other words, enemies don't move so only bullet motion needs to be
    --accounted for
    for index, bullet in ipairs(go.bullets) do
        bullet:update(dt)
    end

    for index, enemy in ipairs(go.enemies) do
        enemy:update(dt) --[[ currently does nothing since enemies don't move
                              and destuction is resolved after dynamics are updated--]]
    end
    check_for_hit_and_resolve(go.bullets, go.enemies)
end

function love.draw()
    --draw field strengh
    draw_field( go.field )

    love.graphics.setColor( 240, 240, 240 )    
    love.graphics.print( field_text_location[1]..","..field_text_location[2]..
                         ": "..go.field( field_text_location ),
                                                         field_text_location[1],
                                                         field_text_location[2] )

    go.player:draw()
    draw_charge_beam(go.player)

    for _,object in ipairs(go.enemies) do
        object:draw()
    end

    for _, object in ipairs(go.bullets) do
        object:draw()
    end 
end
