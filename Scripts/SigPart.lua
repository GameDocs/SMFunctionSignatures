dofile("$CONTENT_7712f974-cb87-4d9e-8f9c-7e81a9829a13/Scripts/FunctionSignature.lua")

SigPart = class( nil )
SigPart.maxChildCount = 0
SigPart.maxParentCount = 1
SigPart.connectionInput = sm.interactable.connectionType.logic
SigPart.connectionOutput = sm.interactable.connectionType.none
SigPart.colorNormal = sm.color.new( 0x404040ff )
SigPart.colorHighlight = sm.color.new( 0x606060ff )

function SigPart:client_onInteract( character, state )
    if not state then return end

    self.network:sendToServer("sv_onInteract")
end

function SigPart:sv_onInteract()
    self:sv_generateSignatures()
end





function SigPart:sv_generateSignatures()
    local types = { -- TODO
        ["boolean"] = true,          
        ["number"] = 13.37,
        ["integer"] = 8,
        ["string"] = "sample text",
        ["table"] = {foo = "bar"},
        ["userdata"] = self.shape,
        ["function"] = function() end,
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
        ["piston"] = self.shape:createJoint(sm.uuid.new("260b4597-f1ac-409c-8e6b-90c998c5fe94"), self.shape.localPosition + sm.vec3.new(0, 1, 1), sm.vec3.new(0, 0, 1)),
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

    local environment = {
        type = "part",
        gamemode = "creative"
    }

    local function traverse(tbl, prefix)
        local signatures = {}

        for k, v in pairs(tbl) do
            local childNodePrefix = tostring(prefix) .. "." .. k
            
            if type(v) == "table" then
                signatures[k] = traverse(v, childNodePrefix)
            elseif type(v) == "function" then
                print("\n\nBruteforcing signatures of " .. childNodePrefix)

                local funcSig = FunctionSignature.new(v, childNodePrefix, types, environment)
                signatures[k] = funcSig:generate()

                -- local success, returned = pcall(bruteforceSignature, v, scriptDetails)
                
                -- if success then
                --     signatures[k] = returned
                -- else
                --     errorsFound[CURRENT_NAME] = returned
                -- end
            else
                signatures[k] = v
            end
        end

        return signatures
    end

    local smCopy = {}
    for k, v in pairs(sm) do
        smCopy[k] =v
    end

    smCopy.terrainData = nil
    smCopy.body = nil

    local signatures = traverse(smCopy, "sm")
    print(signatures)
    sm.json.save(signatures, "$CONTENT_7712f974-cb87-4d9e-8f9c-7e81a9829a13/out/signatures2.json")

end
