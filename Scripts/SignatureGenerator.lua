dofile("$CONTENT_7712f974-cb87-4d9e-8f9c-7e81a9829a13/Scripts/FunctionSignature.lua")

SignatureGenerator = class( nil )

function SignatureGenerator:getUnsidedTypes()
    local types = {}

    types["boolean"] = true
    types["number"] = 13.37
    types["integer"] = 8
    types["string"] = "sample text"
    types["table"] = {foo = "bar"}
    types["userdata"] = self.shape
    types["function"] = function() end
    types["<Uuid>"] = sm.uuid.new("b4ae94a6-d11c-4503-9b87-1c008ab8d2df")
    types["<Vec3>"] = sm.vec3.new(1, 1, 1)
    types["<Quat>"] = sm.quat.identity()
    types["<Color>"] = sm.color.new(0xff0000ff)
    types["<RaycastResult>"] = select(2, sm.physics.raycast(sm.vec3.new(0, 0, -1), sm.vec3.new(0, 0, 1)))
    types["<Shape>"] = self.shape
    types["<Body>"] = self.shape.body
    types["<Interactable>"] = self.interactable
    -- types["<Container>"] = self.interactable:getContainer(0) or self.interactable:addContainer(3, 4, 5)
    -- types["<Harvestable>"] = sm.harvestable.create(sm.uuid.new("6757b211-f50c-42c5-bd7c-648dcbe3ed52"), sm.vec3.new(0, 0, 1), sm.quat.identity(), sm.vec3.new(0, 0, 1))
    types["<Network>"] = self.network
    types["<World>"] = self.shape.body:getWorld()
    -- types["<Unit>"] = sm.unit.getAllUnits()[1] or sm.unit.createUnit( sm.uuid.new( "00000000-0000-0000-0000-000000000000" ), sm.vec3.new(0, 0, 1), 0, { tetherPoint = sm.vec3.new(0, 0, 1), deathTick = sm.game.getCurrentTick() + 400 } )
    types["<Storage>"] = self.storage
    types["<Player>"] = sm.player.getAllPlayers()[1]
    types["<Character>"] = sm.player.getAllPlayers()[1].character
    -- types["<Joint>"] = self.shape:createJoint(sm.uuid.new("4a1b886b-913e-4aad-b5b6-6e41b0db23a6"), self.shape.localPosition + sm.vec3.new(0, 0, 1), sm.vec3.new(0, 0, 1))
    -- types["piston"] = self.shape:createJoint(sm.uuid.new("260b4597-f1ac-409c-8e6b-90c998c5fe94"), self.shape.localPosition + sm.vec3.new(0, 1, 1), sm.vec3.new(0, 0, 1))
    types["<Quest>"] = nil -- sm.quest.addQuest(sm.uuid.new("4f5c93bb-632b-4036-9dde-10ff1f40bd1c"))
    types["<AreaTrigger>"] = sm.areaTrigger.createAttachedBox(self.interactable, sm.vec3.new(1, 1, 1), sm.vec3.new(0, 0, 1), sm.quat.identity())
    -- types["<Portal>"] = sm.portal.createPortal(sm.vec3.new(1, 1, 1))
    types["<PathNode>"] = sm.pathNode.createPathNode(sm.vec3.new(0, 0, 1), 1)
    types["<Lift>"] = nil
    types["<Widget>"] = nil -- Removed
    types["<Tool>"] = nil
    -- types["<Effect>"] = sm.effect.createEffect( "MountedPotatoRifle - Shoot", self.interactable )
    -- types["<GuiInterface>"] = nil sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout" )

    return types
end

function SignatureGenerator:getServerTypes( types )
    types = types or self:getUnsidedTypes()

    types["<Container>"] = self.interactable:getContainer(0) or self.interactable:addContainer(3, 4, 5)
    types["<Harvestable>"] = sm.harvestable.create(sm.uuid.new("6757b211-f50c-42c5-bd7c-648dcbe3ed52"), sm.vec3.new(0, 0, 1), sm.quat.identity(), sm.vec3.new(0, 0, 1))
    types["<Unit>"] = sm.unit.getAllUnits()[1] or sm.unit.createUnit( sm.uuid.new( "00000000-0000-0000-0000-000000000000" ), sm.vec3.new(0, 0, 1), 0, { tetherPoint = sm.vec3.new(0, 0, 1), deathTick = sm.game.getCurrentTick() + 400 } )
    types["<Joint>"] = self.shape:createJoint(sm.uuid.new("4a1b886b-913e-4aad-b5b6-6e41b0db23a6"), self.shape.localPosition + sm.vec3.new(0, 0, 1), sm.vec3.new(0, 0, 1))
    types["piston"] = self.shape:createJoint(sm.uuid.new("260b4597-f1ac-409c-8e6b-90c998c5fe94"), self.shape.localPosition + sm.vec3.new(0, 1, 1), sm.vec3.new(0, 0, 1))
    types["<Portal>"] = sm.portal.createPortal(sm.vec3.new(1, 1, 1))

    return types
end

function SignatureGenerator:getClientTypes( types )
    types = types or self:getUnsidedTypes()

    types["<Effect>"] = sm.effect.createEffect( "MountedPotatoRifle - Shoot", self.interactable )
    types["<GuiInterface>"] = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout" )

    return types
end

function SignatureGenerator:getGamemode()
    if sm.event.sendToGame("cl_onClearConfirmButtonClick", {}) then
        return "creative"
    elseif sm.event.sendToGame("sv_e_setWarehouseRestrictions", {}) then
        return "survival"
    elseif sm.event.sendToGame("server_getLevelUuid", {}) then
        return "challenge"
    end

    return "unknown_gamemode"
end

function SignatureGenerator:getSide()
    return sm.isServerMode() and "server" or "client"
end

function SignatureGenerator:generateSignatures( types, environment )

    environment = environment or {}
    environment.type = environment.type or "unknown_type"
    environment.gamemode = environment.gamemode or self:getGamemode()
    environment.side = environment.side or self:getSide()

    local failed = {}

    local function traverse(tbl, prefix)
        local signatures = {}

        for k, v in pairs(tbl) do
            local childNodePrefix = tostring(prefix) .. "." .. k
            
            if type(v) == "table" then
                signatures[k] = traverse(v, childNodePrefix)
            elseif type(v) == "function" then
                print("\n\nBruteforcing signatures of " .. childNodePrefix)

                local funcSig = FunctionSignature.new(v, childNodePrefix, types, environment)
                local success = false
                success, signatures[k] = funcSig:generate()

                if not success then
                    table.insert(failed, childNodePrefix)
                end
            end
        end

        return signatures
    end

    local smCopy = {}
    for k, v in pairs(sm) do
        smCopy[k] =v
    end

    smCopy.terrainData = nil

    local main_signatures = traverse(smCopy, "sm")

    local userdata_signatures = nil
    if getmetatable then
        userdata_signatures = {}

        for typeName, typeInstance in pairs(types) do
            local mt = getmetatable(typeInstance)

            if mt and mt.__typeid then
                userdata_signatures[typeName] = traverse(mt, typeName)
            end
        end
    end

    local signatures = {
        failed = failed,
        main_signatures = main_signatures,
        userdata_signatures = userdata_signatures
    }

    print(signatures)

    sm.json.save(signatures, ("$CONTENT_7712f974-cb87-4d9e-8f9c-7e81a9829a13/out/signatures.%s.%s.%s.json"):format(environment.type, environment.gamemode, environment.side))

end

function SignatureGenerator:resetAccidentalChanges()
    sm.player.getAllPlayers()[1].character:setLockingInteractable(nil)
    sm.gui.hideGui( false )
    sm.camera.setCameraState( sm.camera.state.default )
    sm.localPlayer.setLockedControls( false )
    sm.gui.endFadeToBlack(1)
end
