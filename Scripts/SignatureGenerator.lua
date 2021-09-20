types = types or {}

SignatureGenerator = class( nil )
SignatureGenerator.maxChildCount = 0
SignatureGenerator.maxParentCount = 1
SignatureGenerator.connectionInput = sm.interactable.connectionType.logic
SignatureGenerator.connectionOutput = sm.interactable.connectionType.none
SignatureGenerator.colorNormal = sm.color.new( 0x404040ff )
SignatureGenerator.colorHighlight = sm.color.new( 0x606060ff )

function SignatureGenerator.server_onRefresh( self )
    self:server_init()
end

function SignatureGenerator.server_onCreate( self )
    types = { -- TODO
        ["boolean"] = true,          
        ["number"] = 13.37,
        ["string"] = "sample text",
        ["table"] = {foo = "bar"},
        ["<Uuid>"] = sm.uuid.new("b4ae94a6-d11c-4503-9b87-1c008ab8d2df"),
        ["<Vec3>"] = sm.vec3.new(1, 1, 1),
        ["<Quat>"] = sm.quat.identity(),
        ["<Color>"] = sm.color.new(0xff0000ff),
        ["<RaycastResult>"] = select(2, sm.physics.raycast(sm.vec3.new(0, 0, -1), sm.vec3.new(0, 0, 1))),
        ["<Shape>"] = self.shape,
        ["<Body>"] = self.shape.body,
        ["<Interactable>"] = self.interactable,
        ["<Container>"] = self.interactable:getContainer(0) or self.interactable:addContainer(3, 4, 5),
        ["<Harvestable>"] = sm.harvestable.create(sm.uuid.new("6757b211-f50c-42c5-bd7c-648dcbe3ed52"), sm.vec3.new(0, 0, 1), sm.quat.identity(), sm.vec3.new(0, 0, 1)),
        ["<Network>"] = self.network,
        ["<World>"] = self.shape.body:getWorld(),
        ["<Unit>"] = sm.unit.getAllUnits()[1] or sm.unit.createUnit( sm.uuid.new( "00000000-0000-0000-0000-000000000000" ), sm.vec3.new(0, 0, 1), 0, { tetherPoint = sm.vec3.new(0, 0, 1), deathTick = sm.game.getCurrentTick() + 400 } ),
        ["<Storage>"] = self.storage,
        ["<Player>"] = sm.player.getAllPlayers()[1],
        ["<Character>"] = sm.player.getAllPlayers()[1].character,
        ["<Joint>"] = self.shape:createJoint(sm.uuid.new("4a1b886b-913e-4aad-b5b6-6e41b0db23a6"), self.shape.localPosition + sm.vec3.new(0, 0, 1), sm.vec3.new(0, 0, 1)),
        ["<Quest>"] = nil, -- sm.quest.addQuest(sm.uuid.new("4f5c93bb-632b-4036-9dde-10ff1f40bd1c"))
        ["<AreaTrigger>"] = sm.areaTrigger.createAttachedBox(self.interactable, sm.vec3.new(1, 1, 1), sm.vec3.new(0, 0, 1), sm.quat.identity()),
        ["<Portal>"] = sm.portal.createPortal(sm.vec3.new(1, 1, 1)),
        ["<PathNode>"] = sm.pathNode.createPathNode(sm.vec3.new(0, 0, 1), 1),
        ["<Lift>"] = nil,
        ["<Widget>"] = nil, -- Removed
        ["<Tool>"] = nil,
        ["<Effect>"] = nil, -- sm.effect.createEffect( "MountedPotatoRifle - Shoot", self.interactable ),
        ["<GuiInterface>"] = nil -- sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/PopUp/PopUp_YN.layout" )
    }

    errorsFound = {}

    print(types["<PathNode>"])

    self:server_init()
end

function SignatureGenerator.server_init( self )
    sm.terrainData = nil

    print("==================")

    local signatures = getSignaturesOfTable(sm.vec3, {
        type = "part",
        gamemode = "creative"
    }, "sm.vec3")
    print(signatures)
    for k, v in pairs(errorsFound) do
        print(k, v)
    end
    sm.json.save(signatures, "$CONTENT_7712f974-cb87-4d9e-8f9c-7e81a9829a13/out/signatures.json")
end

function getSignaturesOfTable(t, scriptDetails, prefix)
    local sigs = {}

    for k, v in pairs(t) do
        CURRENT_NAME = tostring(prefix) .. "." .. k
        
        if type(v) == "table" then
            sigs[k] = getSignaturesOfTable(v, scriptDetails, CURRENT_NAME)
        elseif type(v) == "function" then
            print("\n\nBruteforcing signatures of " .. CURRENT_NAME)

            -- sigs[k] = bruteforceSignature(v, scriptDetails)

            local success, returned = pcall(bruteforceSignature, v, scriptDetails)
            
            if success then
                sigs[k] = returned
            else
                errorsFound[CURRENT_NAME] = returned
            end
        end
    end

    return sigs
end

function bruteforceSignature(func, scriptDetails, sig, known)
    local signature = sig or {
        params = {},
        returns = {}
    }
    local knownInfo = known or {}

    function getTypeName(variable)
        local typename = type(variable)
        local classname = "<" .. typename .. ">"

        if types[classname] then
            return classname
        end

        if typename == "table" then
            local tabletypes = "table {"

            for k, v in ipairs(variable) do
                tabletypes = tabletypes .. getTypeName(v)

                -- Add separator
                if k ~= #variable then
                    tabletypes = tabletypes .. ", "
                end
            end

            tabletypes = tabletypes .. "}"

            return tabletypes
        end

        if types[typename] then
            return typename
        end

        return "unknown: " .. typename
    end

    
    if not knownInfo.paramsMin then
        print("Doesn't know paramsMin yet")
        local success, err = pcall(func)
        print(success, err)

        if success then
            -- The function successfully ran without any parameters
            signature.paramsMin = 0 -- We now know the minimum amount is 0
            knownInfo.paramsMin = true
        else
            -- This is the first time an error might get thrown. Sandbox violations are always throw
            -- before any parameter checking is done.
            if err == "Sandbox violation: calling client function from server callback." then
                signature.sandbox = "client"
                return signature
            elseif err == "Sandbox violation: calling server function from client callback." then
                signature.sandbox = "server"
                return signature
            elseif err == "Sandbox violation: mismatching scriptTypeID." then
                signature.scriptType = signature.scriptType or {}
                signature.scriptType[scriptDetails.type] = false
                return signature
            elseif err == "Not available this game mode" then
                signature.gamemode = signature.gamemode or {}
                signature.gamemode[scriptDetails.gamemode] = false
                return signature
            end

            local expected, got = string.match(err, "Expected (%d+) arguments %(got (%d+)%)")
            if expected ~= nil then
                -- The function failed but told us the *exact* amount we need
                signature.paramsMin = tonumber(expected)
                signature.paramsMax = tonumber(expected)
                signature.paramsExact = tonumber(expected)

                knownInfo.paramsMin = true
                knownInfo.paramsMax = true
            end

            if expected == nil or got == nil then
                print("Failed to get minimum amount of parameters: " .. "expected=" .. tostring(expected) .. ", got=" .. tostring(got) .. ", full=" .. tostring(err))
            end
        end
    end



    if not knownInfo.paramsMax then
        print("Doesn't know paramsMax yet")

        local MAX_PARAMS = 12

        local values = {}
        for i = 1, MAX_PARAMS do
            values[i] = true
        end

        local success, err = pcall(func, unpack(values))
        print(success, err)

        if success then
            signature.paramsMax = MAX_PARAMS
            knownInfo.paramsMax = true
        else
            -- Functions with 0 parameters throw this error
            local expected, got = string.match(err, "Expected (%d+) arguments %(got (%d+)%)")
            
            -- Not all functions throw the error above, so we check for this one too
            if expected == nil or got == nil then
                expected, got = string.match(err, "Expected at most (%d+) arguments %(got (%d+)%)")
            end

            if expected ~= nil then
                signature.paramsMin = tonumber(expected)
                signature.paramsMax = tonumber(expected)
                signature.paramsExact = tonumber(expected)

                knownInfo.paramsMin = true
                knownInfo.paramsMax = true
            end

            if expected == nil or got == nil then
                error("Failed to get maximum amount of parameters: " .. "expected=" .. tostring(expected) .. ", got=" .. tostring(got) .. ", full=" .. err)
            end
        end
    end

    for i = signature.paramsMin, signature.paramsMax do
        print("Trying parameter count of " .. i)

        local currentTypes = {}
        for j = 1, i do
            print(j, signature.params)
            if signature.params[j] then
                currentTypes[j] = types[signature.params[j].type[1]]
            else
                currentTypes[j] = types["number"]
            end
        end

        local expectedName = ""

        for typeName, typeExample in pairs(types) do
            currentTypes[i] = typeExample

            -- The function might return multiple parameters
            local result = {pcall(func, unpack(currentTypes))}

            print(typeName, result)

            if result[1] then
                signature.params[i] = signature.params[i] or {}
                signature.params[i].type = signature.params[i].type or {}
                table.insert(signature.params[i].type, typeName)

                table.remove(result, 1)

                signature.returns = {}
                for _, v in ipairs(result) do
                    table.insert(signature.returns, {type = getTypeName(v)})
                end
            else
                local expected, got = string.match(result[2], "%((%w+) expected, got (%w+)%)")
                expectedName = types[expected] or types["<" .. expected .. ">"] or expectedName

                if expected == nil or got == nil then
                    error("Failed trying amount of parameters of " .. tostring(i) .. ": " .. "expected=" .. tostring(expected) .. ", got=" .. tostring(got) .. ", full=" .. tostring(result[2]))
                end
            end
        end

        if not signature.params[i] then
            signature.params[i] = {type = {"unknown: " .. expectedName}}
        end
    end

    print("Done!", signature, knownInfo)
    return signature
end