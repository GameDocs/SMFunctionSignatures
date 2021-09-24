dofile("$CONTENT_7712f974-cb87-4d9e-8f9c-7e81a9829a13/Scripts/SignatureGenerator.lua")

SigPart = class( SignatureGenerator )
SigPart.maxChildCount = 0
SigPart.maxParentCount = 1
SigPart.connectionInput = sm.interactable.connectionType.logic
SigPart.connectionOutput = sm.interactable.connectionType.none
SigPart.colorNormal = sm.color.new( 0x404040ff )
SigPart.colorHighlight = sm.color.new( 0x606060ff )

function SigPart:client_onInteract( character, state )
    if not state then return end

    self.allTypes = self:getClientTypes()

    self.network:sendToServer("sv_onInteract")
end

function SigPart:sv_onInteract()
    self.allTypes = self:getServerTypes(self.allTypes)

    self.gamemode = self:getGamemode()

    self:sv_generateSignatures()
    self.network:sendToClients("cl_generateSignatures")
end

function SigPart:sv_generateSignatures()
    self:generateSignatures(self.allTypes, {
        type = "part",
        gamemode = self.gamemode
    })
end

function SigPart:cl_generateSignatures()
    self:generateSignatures(self.allTypes, {
        type = "part",
        gamemode = self.gamemode
    })

    self:resetAccidentalChanges()
end

function SigPart:client_onRefresh()
    self:resetAccidentalChanges()
end
