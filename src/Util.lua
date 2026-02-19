local _, addon = ...
addon = addon or {}

local libcli = addon.libcli or {}
addon.libcli = libcli

--- @param name string
--- @return string? # An error message if the option name is invalid, otherwise `nil`.
--- Checks if a given string is a valid option name.
---
--- ## Errors
---
--- * If `name` is `nil` or an empty string.
--- * If `name` contains characters other than ASCII letters, numbers, hyphens, and underscores.
--- * If `name` does not start and end with an alphanumeric character.
local function IsValidOptionName(name)
    if name == nil or name == "" then
        return "Option name must contain at least one character"
    end

    if name:match("[^%w%-_]") then
        return "Option name must only contain ASCII letters, numbers, hyphens, and underscores"
    end

    if not name:match("^%w.*%w$") then
        return "Option name must start and end with an alphanumeric character"
    end

    return nil
end

--- @param name string
--- @return string? # An error message if the command name is invalid, otherwise `nil`.
--- Checks if a given string is a valid command name.
---
--- Uses the same validation rules as option names, so command names must also be valid option names.
--- See [`IsValidOptionName`](lua://IsValidOptionName) for details on the validation rules for option names.
local function IsValidCommandName(name)
    return IsValidOptionName(name)
end

libcli.IsValidOptionName = IsValidOptionName
libcli.IsValidCommandName = IsValidCommandName
