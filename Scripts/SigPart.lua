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

    self.network:sendToServer("sv_onInteract")
end

function SigPart:sv_onInteract()
    self:generateSignatures(self:getServerTypes(), {
        type = "part",
        gamemode = self:getGamemode(),
        side = "server"
    })
end
