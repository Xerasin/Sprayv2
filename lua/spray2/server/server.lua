local spray2 = _G.spray2
local _, _, _, NET = spray2.URLS, spray2.STATUS, spray2.STATUS_NAME, spray2.NET

util.AddNetworkString("Sprayv2")
net.Receive("Sprayv2", function(len, ply)
    local networkID = net.ReadInt(8)
    if networkID == NET.Spray then
        ply:PostSpray(net.ReadTable())
    elseif networkID == NET.Token then
        spray2.OnReceiveTokenRequest(ply)
    end
end)

hook.Add("PlayerSpray", "Sprayv2", function(ply)
    if ply:PostSpray() then return true end
end)

hook.Add("NetData", "sprayv2", function(pl, key, value)
    if key == "sprayv2" then
        return not value or (type(value) == "table" and value.url and value.url ~= "")
    end
end)

local function addcmd()
    aowl.AddCommand({"spraymenu", "sprays", "spray", "sprayv2"}, function(ply, line)
        ply:ConCommand("sprayv2_openfavorites")
    end)

    aowl.AddCommand("clearspray2", function(ply, line, target)
        if target and ply:IsSuperAdmin() then
            local targetPly = easylua.FindEntity(target)
            if IsValid(targetPly) and targetPly:IsPlayer() then
                targetPly:StripSpray2()
            end
        else
            ply:StripSpray2()
        end
    end)
end

if aowl then
    addcmd()
else
    hook.Add("AowlInitialized", "sprayv2_addCommands", function()
        addcmd()
        hook.Remove("AowlInitialized", "sprayv2_addCommands")
    end)
end

local pmeta = FindMetaTable("Player")
function pmeta:StripSpray2()
    net.Start("Sprayv2")
        net.WriteInt(NET.ClearSpray, 8)
        net.WriteEntity(self)
    net.Broadcast()
end
local whitelist = {
    ["prop_physics"] = true,
    ["prop_ragdoll"] = true,
    ["prop_vehicle_airboat"] = true,
    ["prop_vehicle_jeep"] = true,
    ["prop_vehicle_prisoner_pod"] = true,
    ["gmod_sent_vehicle_fphysics_base"] = true,
    ["mediaplayer_tv"] = true,
    ["mediaplayer_projector"] = true,
    ["mediaplayer_repeater"] = true,
    ["prop_dynamic"] = true,
    ["prop_static"] = true
}
local function IsValidSprayTrace(trace)
    if trace.HitPos:Distance(trace.StartPos) > 200 then return false end
    if trace.HitWorld then return true end
    if trace.Hit and IsValid(trace.Entity) and whitelist[trace.Entity:GetClass()] then return true end
    return false
end

function pmeta:PostSpray(sprayData)
    if not IsValid(self) then return end
    local spray = sprayData or (self.GetNetData and self:GetNetData("sprayv2"))
    if not spray or not spray.url or spray.url == "" then return end

    if (not self.LastSpray or (CurTime() - self.LastSpray) > 2.5) then
        local trace = self:GetEyeTrace()
        if IsValidSprayTrace(trace) then
            self.LastSpray = CurTime()
            net.Start("Sprayv2")
                net.WriteInt(NET.Spray, 8)
                net.WriteEntity(self)
                net.WriteString(spray.url)
                net.WriteVector(trace.HitPos)
                net.WriteVector(trace.HitNormal)
                net.WriteInt(trace.Entity:EntIndex(), 32)
                net.WriteBool(trace.HitWorld)
                net.WriteTable({nsfw = spray.nsfw})
            net.Broadcast()
        end
    end
    return true
end