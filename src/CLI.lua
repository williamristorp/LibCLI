local _, addon = ...
addon = addon or {}

local libcli = addon.libcli or {}
addon.libcli = libcli

local Tokens = libcli.Tokens

--- @class CLI
--- @field name string
--- @field slashCommands table<string, Command>
--- @see Command
--- Registers slash commands.
local CLI = {}
CLI.__index = CLI

--- @param name string The name of the CLI, used for error messages and help text.
--- @return CLI
function CLI.New(name)
    local obj = setmetatable({}, CLI)
    obj.name = name
    obj.slashCommands = {}
    return obj
end

--- Adds a slash command with the given name and handler function.
--- @param name string The name of the slash command, without the leading slash.
--- @param command Command The command object that defines the behavior of the slash command.
--- @param aliases string[]? Optional list of additional aliases for the command.
function CLI:AddSlashCommand(name, command, aliases)
    local names = aliases or {}
    table.insert(names, name)

    for _, cmdName in ipairs(names) do
        self.slashCommands[cmdName] = command
        _G["SLASH_" .. cmdName:upper() .. "1"] = "/" .. cmdName
        SlashCmdList[cmdName:upper()] = function(msg, editBox)
            local tokens = Tokens.New(msg)
            local err = command:Run(self, tokens)
            if err then
                print(err)
            end
        end
    end
end

--- @param name string The name of the slash command, without the leading slash.
--- @param msg string The message passed to the slash command handler, containing the command arguments.
--- @return string? An error message if an error occurred while executing the command, otherwise `nil`.
function CLI:ExecuteSlashCommand(name, msg)
    local command = self.slashCommands[name]
    if not command then
        return ("Unknown command '%s'. Type '/%s help' for a list of commands."):format(name, self.name)
    end

    local tokens = Tokens.New(msg)
    local err = command:Run(self, tokens)
    if err then
        return err
    end

    return nil
end

--- @param input string The full input string to parse and execute, including the command name and its arguments.
--- @return string? An error message if an error occurred while executing the command, otherwise `nil`.
function CLI:Run(input)
    local tokens = Tokens.New(input)
    local commandName = tokens:NextNonOption()
    if not commandName then
        return ("No command specified. Type '/%s help' for a list of commands."):format(self.name)
    end

    return self:ExecuteSlashCommand(commandName, tokens:Remaining())
end

libcli.CLI = CLI
