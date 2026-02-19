local _, addon = ...
addon = addon or {}

local libcli = addon.libcli or {}
addon.libcli = libcli

local Option = libcli.Option
local IsValidCommandName = libcli.IsValidCommandName

--- @class ParsedOptions
--- @field _options table<string, any> A table mapping option names to their parsed values.
local ParsedOptions = {}
ParsedOptions.__index = ParsedOptions

--- @param options table<string, any>? [Default: `{}`] Initial options to include in the `ParsedOptions` object.
--- @return ParsedOptions
--- Creates a `ParsedOptions` with optional initial options.
function ParsedOptions.New(options)
    if options == nil then
        options = {}
    end

    local obj = setmetatable({}, ParsedOptions)
    obj._options = options
    return obj
end

function ParsedOptions:Get(name)
    return self._options[name]
end

function ParsedOptions:GetAll(name)
    local value = self._options[name]
    if type(value) == "table" then
        return value
    elseif value ~= nil then
        return { value }
    else
        return nil
    end
end

function ParsedOptions:GetLast(name)
    local value = self._options[name]
    if type(value) == "table" then
        return value[#value]
    else
        return value
    end
end

function ParsedOptions:GetFlattened(name)
    local value = self._options[name]
    if type(value) == "table" then
        local flattened = {}
        local function flatten(tbl)
            for _, v in ipairs(tbl) do
                if type(v) == "table" then
                    flatten(v)
                else
                    table.insert(flattened, v)
                end
            end
        end
        flatten(value)
        return flattened
    elseif value ~= nil then
        return { value }
    else
        return nil
    end
end

--- @param name string
--- @return boolean # `true` if an option with the given name exists, otherwise `false`.
--- Checks if an option with the given name exists in the parsed options.
function ParsedOptions:Has(name)
    return self._options[name] ~= nil
end

--- @param name string
--- @param value any
--- Sets the value of the option with the given name.
---
--- If the option already has a value, it will be overwritten.
function ParsedOptions:Set(name, value)
    self._options[name] = value
end

--- @param name string
--- @param value any
--- Inserts a value for the option with the given name.
---
--- If the option does not already exist, a new array will be created and the value will be inserted into it.
--- If the option already exists and is an array, the value will be appended to the existing array.
--- If the option already exists and is not an array, this will overwrite the existing value with a new array containing both the existing value and the new value.
function ParsedOptions:Insert(name, value)
    if self._options[name] == nil then
        self._options[name] = { value }
    else
        if type(self._options[name]) == "table" then
            table.insert(self._options[name], value)
        else
            self._options[name] = { self._options[name], value }
        end
    end
end

--- @return fun(): (string?, any?)
--- Returns an iterator function that iterates over the parsed options, returning each option name and its corresponding value as a pair.
---
--- ## Examples
---
--- ```lua
--- local parsedOptions = ParsedOptions.New({
---     foo = "bar",
---     id = { 123, 456 },
--- })
---
--- for name, value in parsedOptions:Pairs() do
---     -- Runs two iterations:
---     -- 1. With name "foo" and value "bar"
---     -- 2. With name "id" and value {123, 456}
--- end
--- ```
---
--- ```lua
--- local myCommand = Command:New("mycmd")
---     :InsertOption(Option.NewNumber("id"):SetMultiple("append"):SetDelimiter(","))
---
--- local input = "/mycmd --id=123,456 --id=789"
---
--- local tokens = Tokens.New(input)
--- local err, options = myCommand:ParseOptions(tokens)
---
--- for name, value in options:Pairs() do
---     -- Runs two iterations:
---     -- 1. With name "foo" and value "bar"
---     -- 2. With name "id" and value {123, 456}
--- end
--- ```
function ParsedOptions:Pairs()
    local keys = {}
    for key, _ in pairs(self._options) do
        table.insert(keys, key)
    end

    local index = 0
    return function()
        index = index + 1
        if index <= #keys then
            local key = keys[index]
            return key, self._options[key]
        else
            return nil, nil
        end
    end
end

--- @class Command
--- @field name string
--- @field description string
--- @field aliases string[]
--- @field options Option[]
--- @field subcommands Command[]
--- @field handler fun(self: Command, cli: CLI, tokens: Tokens, options: ParsedOptions)?
--- An executable command that can be registered as a slash command or as a subcommand of another command.
---
--- ## Command Execution
---
--- Command execution follows these steps:
---
--- * Commands will first parse options from the following tokens until they encounter a non-option token.
--- * If there are no more tokens after parsing options and a handler function is defined, the handler will be called with the parsed options.
--- * If the next token matches a subcommand, it will delegate to that subcommand instead, passing the remaining tokens to it.
--- * If a handler function is defined, it will be called with the remaining tokens and parsed options.
--- * If no handler is defined but additional tokens are present, it will return an error indicating that the subcommand is unknown.
--- * If no handler is defined and no additional arguments are provided, the command will print its help message.
---
--- ## Errors
---
--- * If any required options are missing.
--- * If an unknown option is present (i.e. a token that starts with `--` but does not match any defined option).
--- * If an option that does not allow multiple occurrences is provided multiple times.
--- * If additional tokens are present but no handler is defined and no matching subcommand is found.
--- * If an error occurs while parsing an option value and the option's `failure` strategy is `"error"`.
---
--- ## Examples
---
--- ### Creating a command with options and a subcommand using the builder pattern:
---
--- ```lua
--- local myCommand = Command:New("mycmd")
---     :SetDescription("This is my command")
---     :AddAlias("alias1")
---     :AddAlias("alias2")
---     :AddOption {
---         name = "opt1",
---         kind = "string",
---         description = "First option",
---         required = true,
---     }
---     :AddOption {
---         name = "opt2",
---         kind = "number",
---         description = "Second option",
---         defaultValue = "42",
---     }
---     :AddSubcommand(Subcommand:New("subcmd")
---         :SetDescription("This is a subcommand")
---         :SetHandler(function(self, cli, tokens, options)
---             print("Handler called for subcommand '" .. self.name .. "' with options:")
---             for name, value in options:Pairs() do
---                 print("  " .. name .. ": " .. tostring(value))
---             end
---         end)
---     )
---     :SetHandler(function(self, cli, tokens, options)
---         print("Handler called for command '" .. self.name .. "' with options:")
---         for name, value in options:Pairs() do
---             print("  " .. name .. ": " .. tostring(value))
---         end
---     end)
--- ```
---
--- ### Creating a command with options using the `NewWith` method:
---
--- See [`Command.NewWith`](lua://Command.NewWith) for an example of creating a command with options using the `NewWith` method.
local Command = {}
Command.__index = Command

--- @param name string
--- @param description string?
--- @param handler fun(self: Command, cli: CLI, tokens: Tokens, options: ParsedOptions)?
--- @return Command
function Command.New(name, description, handler)
    local obj = setmetatable({}, Command)
    obj.name = name
    obj.description = description
    obj.aliases = {}
    obj.options = {}
    obj.subcommands = {}
    obj.handler = handler
    return obj
end

--- @class CommandArgs
--- @field name string
--- @field description string?
--- @field aliases string[]?
--- @field options OptionArgs[]?
--- @field subcommands Command[]?
--- @field handler fun(self: Command, cli: CLI, tokens: Tokens, options: ParsedOptions)?
local CommandArgs = {}
CommandArgs.__index = CommandArgs

--- @param args CommandArgs A table of arguments for creating the command.
--- @return Command command
--- Creates a `Command` from the given arguments.
---
--- `args` may include the following properties:
--- * `name`: The name of the command, which must be a non-empty string starting with an alphanumeric character.
--- * `description`: A brief description of the command used for help messages. Defaults to `nil`.
--- * `aliases`: An array of strings representing alternative names for the command. Defaults to `{}`.
--- * `options`: An array of `OptionArgs` tables representing the options for the command. Defaults to `{}`.
--- * `subcommands`: An array of `Command` objects representing the subcommands of this command. Defaults to `{}`.
--- * `handler`: A function that will be called when the command is executed, with the parsed options passed as an argument. Defaults to `nil`.
---
--- See [`CommandArgs`](lua://CommandArgs) for a full type definition of `args`.<br>
--- See [`OptionArgs`](lua://OptionArgs) for details on the expected format of the `options` property.
---
--- ## Safety
---
--- This function does not perform any validation on the provided arguments, so it is possible to create an invalid `Command` using this function.
--- If you want to ensure the command is valid, you should call [`Validate()`](lua://Command.Validate) on the returned object and check for errors.
---
--- ## Examples
---
--- ```lua
--- local myCommand = Command.NewWith {
---     name = "mycmd",
---     description = "This is my command",
---     aliases = { "alias1", "alias2" },
---     options = { {
---             name = "opt1",
---             kind = "string",
---             description = "First option",
---             required = true,
---         }, {
---             name = "opt2",
---             kind = "number",
---             description = "Second option",
---             defaultValue = "42",
---         }
---     },
---     subcommands = { Subcommand.NewWith {
---         name = "subcmd",
---         description = "This is a subcommand",
---         handler = function(self, cli, tokens, options)
---             print("Handler called for subcommand '" .. self.name)
---         end,
---     } },
---     handler = function(self, cli, tokens, options)
---         print("Handler called for command '" .. self.name)
---     end,
--- }
--- ```
function Command.NewWith(args)
    local obj = setmetatable({}, Command)
    obj.aliases = args.aliases or {}
    obj.description = args.description
    obj.name = args.name
    obj.options = args.options or {}
    obj.subcommands = args.subcommands or {}
    obj.handler = args.handler
    return obj
end

function Command:Validate()
    local err = IsValidCommandName(self.name)
    if err then
        return ("Invalid command name '%s': %s"):format(self.name, err)
    end

    if self.aliases ~= nil then
        for _, alias in ipairs(self.aliases) do
            local err = IsValidCommandName(alias)
            if err then
                return ("Invalid alias '%s' in command '%s': %s"):format(alias, self.name, err)
            end
        end
    end

    if self.description ~= nil and type(self.description) ~= "string" then
        return ("Invalid description for command '%s': description must be a string"):format(self.name)
    end

    if self.handler ~= nil and type(self.handler) ~= "function" then
        return ("Invalid handler for command '%s': handler must be a function"):format(self.name)
    end

    for _, option in ipairs(self.options) do
        local err = option:Validate()
        if err then
            return ("Invalid option '%s' in command '%s': %s"):format(option.name, self.name, err)
        end
    end

    for _, subcommand in ipairs(self.subcommands) do
        local err = subcommand:Validate()
        if err then
            return ("Invalid subcommand '%s' in command '%s': %s"):format(subcommand.name, self.name, err)
        end
    end

    return nil, self
end

--- @param description string
--- @return Command self
function Command:SetDescription(description)
    self.description = description
    return self
end

--- @param handler fun(self: Command, cli: CLI, tokens: Tokens, options: Option[])
--- @return Command self
function Command:SetHandler(handler)
    self.handler = handler
    return self
end

--- @param alias string
--- @return Command self
--- Adds an alias for this command.
---
--- # Example
---
--- ```lua
--- local myCommand = Command:New("mycmd")
---     :AddAlias("alias1")
---     :AddAlias("alias2")
---     :AddAlias("alias3")
--- ```
function Command:AddAlias(alias)
    table.insert(self.aliases, alias)
    return self
end

--- @param aliases string[]
--- @return Command self
--- Adds multiple aliases for this command.
---
--- # Example
---
--- ```lua
--- local myCommand = Command:New("mycmd")
---     :AddAliases({"alias1", "alias2", "alias3"})
--- ```
function Command:AddAliases(aliases)
    for _, alias in ipairs(aliases) do
        self:AddAlias(alias)
    end
    return self
end

--- @param option Option
--- @return Command self
--- @see Command.AddOption
--- Adds an option to this command.
---
--- # Example
---
--- ```lua
--- local myOption = Option.With {
---     name = "opt1",
---     kind = "string",
---     description = "First option",
---     required = true,
--- }
---
--- local myCommand = Command:New("mycmd")
---     :InsertOption(myOption)
--- ```
function Command:InsertOption(option)
    table.insert(self.options, option)
    return self
end

--- @param options Option[]
--- @return Command self
function Command:InsertOptions(options)
    for _, option in ipairs(options) do
        self:InsertOption(option)
    end
    return self
end

--- @param args table
--- @return Command self
--- Shorthand for creating and adding a string option to this command in one step.
---
--- See [Option.NewWith](lua://Option.NewWith) for details on the expected format of `args`.
function Command:AddStringOption(args)
    local option = Option.StringWith(args)
    self:InsertOption(option)
    return self
end

--- @param args table
--- @return Command self
--- Shorthand for creating and adding a number option to this command in one step.
---
--- See [Option.NewWith](lua://Option.NewWith) for details on the expected format of `args`.
function Command:AddNumberOption(args)
    local option = Option.NumberWith(args)
    self:InsertOption(option)
    return self
end

--- @param args table
--- @return Command self
--- Shorthand for creating and adding a boolean option to this command in one step.
---
--- See [Option.NewWith](lua://Option.NewWith) for details on the expected format of `args`.
function Command:AddBooleanOption(args)
    local option = Option.BooleanWith(args)
    self:InsertOption(option)
    return self
end

--- @param subcommand Command
--- @return Command self
function Command:AddSubcommand(subcommand)
    table.insert(self.subcommands, subcommand)
    return self
end

--- Prints a help message for this command, including its description, options, and subcommands.
function Command:PrintHelp()
    print(self.name .. " - " .. self.description)
    print("  Options:")
    for _, option in ipairs(self.options) do
        print("    --" .. option.name .. " - " .. option.description)
    end
    print("  Subcommands:")
    for _, subcommand in ipairs(self.subcommands) do
        print("    " .. subcommand.name .. " - " .. subcommand.description)
    end
end

--- @param name string
--- @return boolean matches `true` if the given name matches this command's name or any of its aliases, otherwise `false`.
function Command:Matches(name)
    if name == self.name then
        return true
    end

    for _, alias in ipairs(self.aliases) do
        if name == alias then
            return true
        end
    end

    return false
end

--- @param name string
--- @return Command? subcommand The subcommand with the given name or alias, or `nil` if no such subcommand exists.
function Command:FindSubcommand(name)
    for _, subcommand in ipairs(self.subcommands) do
        if subcommand:Matches(name) then
            return subcommand
        end
    end
    return nil
end

--- @param tokens Tokens
--- @return string? error An error message if parsing failed, otherwise `nil`.
--- @return ParsedOptions options A `ParsedOptions` object containing the parsed options.
--- Parses the given tokens as options for this command, returning a `ParsedOptions` object.
---
--- * Options with a default value that are not present will be set to their default value in the output table.
--- * Options without a default value that are not present will be set to `nil` in the output table.
---
--- ## Errors
---
--- * If any option's value fails to parse.
--- * If an option is required but not present.
--- * If an unknown option is present (i.e. a token that starts with `--` but does not match any defined option).
function Command:ParseOptions(tokens)
    local parsedOptions = ParsedOptions.New()

    local err, optionTokens = tokens:NextOptionTokens()
    if err then
        return "Failed to get option tokens: " .. err, parsedOptions
    end

    -- Loop through each option from the input, find the corresponding option definition, and parse the value according to the option's kind and properties.
    for _, option in ipairs(optionTokens) do
        local optionName = option.name
        local optionValue = option.value

        local foundOption = nil
        for _, cmdOption in ipairs(self.options) do
            if cmdOption:Matches(optionName) then
                foundOption = cmdOption
                break
            end
        end

        if foundOption == nil then
            return ("Unknown option '--%s'"):format(optionName), parsedOptions
        end

        local err, parsedValue = foundOption:ParseValue(optionValue)
        if err then
            return ("Failed to parse value for option '--%s': %s"):format(optionName, err), parsedOptions
        end

        if foundOption.failure == "ignore" and parsedValue == nil then
            -- If the failure strategy is "ignore" and the parsed value is nil, we skip setting this option.
        elseif foundOption.multiple == "fail" then
            if parsedOptions:Has(foundOption.name) then
                return ("Duplicate option '--%s'"):format(optionName), parsedOptions
            end
            parsedOptions:Set(foundOption.name, parsedValue)
        elseif foundOption.multiple == "set" then
            parsedOptions:Set(foundOption.name, parsedValue)
        elseif foundOption.multiple == "append" then
            parsedOptions:Insert(foundOption.name, parsedValue)
        end
    end

    -- Loop through all options defined for this command, setting any missing options to their default value and checking for required options that are missing.
    for _, option in ipairs(self.options) do
        if not parsedOptions:Has(option.name) then
            if option._defaultValueParsed ~= nil then
                parsedOptions:Set(option.name, option._defaultValueParsed)
            elseif option.defaultValue ~= nil then
                local err, parsedValue = option:ParseValue(option.defaultValue)
                if err then
                    return ("Failed to parse default value for option '--%s': %s"):format(option.name, err), parsedOptions
                end
                parsedOptions:Set(option.name, parsedValue)
            elseif option.required then
                return ("Missing required option '--%s'"):format(option.name), parsedOptions
            end
        end
    end

    return nil, parsedOptions
end

--- @param cli CLI
--- @param tokens Tokens
--- @return string? error An error message if execution failed, otherwise `nil`.
function Command:RunWithTokens(cli, tokens)
    local err, options = self:ParseOptions(tokens)
    if err then
        return ("Failed to parse options for command '%s': %s"):format(self.name, err)
    end
end

--- @param cli CLI
--- @param tokens Tokens
--- @return string? error An error message if execution failed, otherwise `nil`.
--- Runs this command with the given tokens.
---
--- This will parse options first until it encounters a non-option token.
--- If any required options are missing or if any options fail to parse, the command will not run.
---
--- If the next non-option token matches a subcommand, it will delegate to that subcommand instead, passing the remaining tokens to it.
---
--- ## Errors
---
--- * See [`Command:ParseOptions`](lua://Command.ParseOptions) for errors related to option parsing.
--- * If no handler is defined for this command and the next token does not match any subcommand.
---   * If there are no more tokens, it will print the help message for this command.
function Command:Run(cli, tokens)
    local err, options = self:ParseOptions(tokens)
    if err then
        return ("Failed to parse options for command '%s': %s"):format(self.name, err)
    end

    -- If there are subcommands, we try to find a matching subcommand and delegate to it if found.
    local nextToken = tokens:Peek()
    if nextToken ~= nil then
        local subcommand = self:FindSubcommand(nextToken)
        if subcommand then
            tokens:Next()

            local err = subcommand:Run(cli, tokens)
            if err then
                return err
            end

            return nil
        end

        if self.handler == nil then
            return ("Unknown subcommand '%s' for command '%s'"):format(nextToken, self.name)
        end
    end

    if self.handler ~= nil then
        self.handler(self, cli, tokens, options)
        return nil
    end

    self:PrintHelp()
    return nil
end

libcli.Command = Command
