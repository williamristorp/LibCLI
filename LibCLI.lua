local _, addon = ...
addon = addon or {}

local libcli = addon.libcli or {}
addon.libcli = libcli

if LibStub then
    local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibCLI-1.0", 0
    local lib = LibStub:NewLibrary(LIBSTUB_MAJOR, LIBSTUB_MINOR)
    if not lib then
        return
    end

    for _, key in ipairs(libcli) do
        if key ~= "internal" then
            lib[key] = libcli[key]
        end
    end
end
