local _, addon = ...
addon = addon or {}

local libcli = addon.libcli or {}
addon.libcli = libcli

local IsValidOptionName = libcli.IsValidOptionName

--- @generic T
--- @class OptionBase
local OptionBase = {}
OptionBase.__index = OptionBase

--- @generic T
--- @param input Token?
--- @return string? error An error message if parsing failed, otherwise `nil`.
--- @return T? value The parsed value, or `nil` if parsing failed.
--- Parses the option from an optional value.
function OptionBase:ParseValue(input)
    -- Must be implemented by subclasses.
    error("OptionBase:ParseValue() not implemented")
end

--- @class StringOption : OptionBase<string>
local StringOption = setmetatable({}, { __index = OptionBase })
StringOption.__index = StringOption

--- @return StringOption
function StringOption.New()
    local obj = setmetatable({}, StringOption)
    return obj
end

--- @param input Token?
--- @return string? error An error message if parsing failed, otherwise `nil`.
--- @return string? value The parsed string, or `nil` if no value was provided.
function StringOption:ParseValue(input)
    if input == nil then
        return "Missing value for string option", nil
    end

    return nil, input
end

--- @class NumberOption : OptionBase<number>
local NumberOption = setmetatable({}, { __index = OptionBase })
NumberOption.__index = NumberOption

--- @return NumberOption
function NumberOption.New()
    local obj = setmetatable({}, NumberOption)
    return obj
end

--- @param input Token?
--- @return string? error An error message if parsing failed, otherwise `nil`.
--- @return number? value The parsed number, or `nil` if no value was provided or parsing failed.
function NumberOption:ParseValue(input)
    if input == nil then
        return "Missing value for number option", nil
    end

    if input == "" then
        return "Empty value for number option", nil
    end

    local value = tonumber(input)
    if value == nil then
        return ("Invalid number '%s' for number option"):format(input), nil
    end

    return nil, value
end

--- @class BooleanOption : OptionBase<boolean>
--- Parses a boolean value from the input string.
---
--- This is always `true` if the option is present unless given an explicit value.
--- If given an explicit value, valid values are `true` or `false` (case-insensitive).
---
--- ## Errors
---
--- * If the value is invalid (valid values are `true` and `false`).
local BooleanOption = setmetatable({}, { __index = OptionBase })
BooleanOption.__index = BooleanOption

--- @return BooleanOption
function BooleanOption.New()
    local obj = setmetatable({}, BooleanOption)
    return obj
end

--- @param input Token?
--- @return string? error An error message if parsing failed, otherwise `nil`.
--- @return boolean? value The parsed boolean value, or `nil` if parsing failed.
function BooleanOption:ParseValue(input)
    if input == nil then
        return nil, true
    end

    local value = input:lower()
    if value == "true" then
        return nil, true
    elseif value == "false" then
        return nil, false
    else
        return ("Invalid boolean '%s' for boolean option"):format(input), nil
    end
end

--- @generic T
--- @class ArrayOption : OptionBase<T[]>
--- @field delimiter string Delimiter for splitting multiple values.
--- @field elementOption OptionBase<T> The option used to parse each element in the array.
--- @field failure "error" | "ignore" Determines how to handle parsing errors for this option (see section on parsing errors).
--- An array option that parses multiple values from a single option given a delimiter.
---
--- For example, with a comma delimiter, `/mycmd --id=1,2,3` would also result in the array `id = { 1, 2, 3 }`.
local ArrayOption = setmetatable({}, { __index = OptionBase })
ArrayOption.__index = ArrayOption

--- @generic T
--- @param elementOption OptionBase<T>
--- @param delimiter string Delimiter for splitting multiple values.
--- @return ArrayOption<T>
function ArrayOption.New(elementOption, delimiter, failure)
    local obj = setmetatable({}, ArrayOption)
    obj.elementOption = elementOption
    obj.delimiter = delimiter
    obj.failure = failure
    return obj
end

--- @generic T
--- @param input Token?
--- @return string? error An error message if parsing failed, otherwise `nil`.
--- @return T[]? value The parsed array, or `nil` if parsing failed.
--- Parses the array option from an optional value.
---
--- * If `input` is `nil` (i.e. `--option`), it returns an error.
--- * If `input` is an empty string (i.e. `--option=`), it returns an empty array.
--- * Otherwise, it splits the input string by the specified delimiter and parses each element using the `elementOption`.
---   * If any element fails to parse, the entire parsing fails and returns an error.
---   * If no delimiter is found, it returns an array with a single element.
---   * If the input string ends with a delimiter, it treats it as if there is an empty element at the end.<br>
---     For example, with a comma delimiter, `1,2,3,` would be parsed as `{1, 2, 3, ""}`.
---   * If the input string starts with a delimiter, it treats it as if there is an empty element at the beginning.<br>
---     For example, with a comma delimiter, `,1,2,3` would be parsed as `{"", 1, 2, 3}`.
---   * If there are consecutive delimiters, it treats them as if there are empty elements between them.<br>
---     For example, with a comma delimiter, `1,,,2` would be parsed as `{1, "", "", 2}`.
function ArrayOption:ParseValue(input)
    if input == nil then
        return "Missing value for array option", nil
    end

    if input == "" then
        return nil, {}
    end

    if self.delimiter == "" then
        local err, parsedElement = self.elementOption:ParseValue(input)
        if err then
            if self.failure == "error" then
                return ("Failed to parse element '%s' for array option: %s"):format(input, err), nil
            elseif self.failure == "ignore" then
                return nil, {}
            end
        end

        return nil, { parsedElement }
    end

    local values = {}

    local escapedDelimiter = self.delimiter:gsub("(%W)", "%%%1")
    local pattern = "(.-)" .. escapedDelimiter
    for element in (input .. self.delimiter):gmatch(pattern) do
        local err, parsedElement = self.elementOption:ParseValue(element)
        if err then
            if self.failure == "error" then
                return ("Failed to parse element '%s' for array option: %s"):format(element, err), nil
            elseif self.failure == "ignore" then
                -- Ignore error and continue parsing.
            end
        else
            table.insert(values, parsedElement)
        end
    end

    return nil, values
end

--- @generic T
--- @class Option
--- @field aliases string[] A list of alternative names for the option.
--- @field defaultValue string? The default value for the option if it is not provided.
--- @field delimiter string The delimiter to use for splitting the input string into array elements if the option is an array.
--- @field description string A brief description of the option used for documentation or help messages.
--- @field failure "error" | "ignore" Determines how to handle parsing errors for this option (see section on parsing errors).
--- @field multiple "set" | "append" | "fail" Determines how to handle multiple instances of this option (see section on multiple instances).
--- @field name string The name of the option, which must be a non-empty string starting with an alphanumeric.
--- @field required boolean If `true`, the command will not run if this option is not provided.
--- @field _defaultValueParsed T? The parsed default value (may be `nil` even if a default value is provided, as it is only parsed in `Option.With` or `Option:Validate`).
--- @field _inner OptionBase<T> The inner option that defines how to parse the value.
--- An option (i.e. an argument starting with `--`) for a command.
---
--- Options are command line arguments that start with `--` and are used to provide additional information or modify the behavior of a command.
--- All options must have a valid name (see [`IsValidOptionName`](lua://IsValidOptionName) for details) and may have a value provided using an `=` character (e.g. `--option=value`).
--- The option name is the part after the `--` and before the `=` (if present), and the option value is the part after the `=` (if present).
--- If no `=` is present, the value is considered to be `nil`, which may be valid for certain option types such as boolean options where the presence of the option implies a value of `true`.
--- If a `=` is present but no value is provided (e.g. `--option=`), the value is considered to be an empty string (`""`).
---
--- Depending on the option's `kind`, the value will be parsed into a specific type (e.g. string, number, boolean).
--- The parsed value will be available to the command's handler function when the command is executed.
---
--- If a delimiter is specified for an option, the value will be split by the delimiter and each element will be parsed individually according to the option's `kind`, resulting in an array of parsed values.
--- The option's kind is now an array of `kind`, and an empty value (e.g. `--option=`) will be parsed as an empty array, while a non-empty value will be split by the delimiter.
--- If the delimiter is an empty string (`""`), the entire input value will be treated as a single element array, unless the value is empty, in which case it will be parsed as an empty array.
--- Note that if the delimiter includes whitespace, the value must be quoted to be parsed correctly (e.g. with delimiter `" "`, `--option=value with spaces` becomes `{ "value" }` while `--option="value with spaces"` becomes `{ "value", "with", "spaces" }`).
---
--- ## Defining Options
---
--- There are two main ways to define an option.
--- You can either create an [`OptionArgs`](lua://OptionArgs) table and pass it to [`Option.NewWith`](lua://Option.NewWith), or you can use the builder pattern by calling methods on an `Option` instance.
--- Both approaches achieve the same result, so you can choose whichever one you prefer or find more convenient in a given situation.
---
--- ## Safety
---
--- To ensure that an `Option` is valid, you should call the `Validate()` method on the option instance after creating or modifying it.
--- Validation is not performed automatically when creating or modifying an `Option`, so it is possible to create an invalid option if you do not perform validation manually.
--- See [`Option:Validate`](lua://Option.Validate) for details on the validation rules and what makes an option valid or invalid.
--- If you are defining options manually, you may skip validation if you are certain that the properties you have set are valid according to the validation rules
--- It is always recommended to call `Validate()` to catch any potential errors or invalid configurations even if you are using hard-coded values.
---
--- ## Examples
---
--- See [`Command`](lua://Command) for examples of defining options for commands.
---
--- ```lua
--- local err, myOption = Option.NewString("name")
---     :SetDescription("Your name")
---     :SetDefaultValue("world")
---     :Validate()
---
--- if err then
---     print(err)
--- else
---     local command = Command.New("greet")
---         :InsertOption(myOption)
---         :SetHandler(function(args)
---             print("Hello, " .. args.name .. "!")
---         end)
---
---     command:Run() -- Prints "Hello, world!"
---     command:Run("--name=Alice") -- Prints "Hello, Alice!"
--- end
local Option = {}
Option.__index = Option

--- @generic T
--- @param name string
--- @return Option<T>
--- Creates a new `Option` with the given name and inner option.
---
--- ## Safety
---
--- This function does not perform any validation on the provided name, so it is possible to create an invalid `Option` using this function.
--- If you want to ensure the option is valid, you should call [`Validate()`](lua://Option.Validate) on the returned object and check for errors.
function Option.New(name, inner)
    local obj = setmetatable({}, Option)
    obj.name = name
    obj.aliases = {}
    obj.defaultValue = nil
    obj.delimiter = nil
    obj.description = nil
    obj.failure = "error"
    obj.multiple = "fail"
    obj.required = false
    obj._defaultValueParsed = nil
    obj._inner = inner
    return obj
end

--- @param name string
--- @return Option<string>
function Option.NewString(name)
    local obj = Option.New(name, StringOption.New())
    return obj
end

--- @param name string
--- @return Option<number>
function Option.NewNumber(name)
    local obj = Option.New(name, NumberOption.New())
    return obj
end

--- @param name string
--- @return Option<boolean>
function Option.NewBoolean(name)
    local obj = Option.New(name, BooleanOption.New())
    return obj
end

--- @class OptionArgs
--- @field aliases string[]?
--- @field defaultValue string?
--- @field delimiter string?
--- @field description string?
--- @field failure "error" | "ignore"?
--- @field multiple "set" | "append" | "fail"?
--- @field name string?
--- @field required boolean?
local OptionArgs = {}

--- @param args OptionArgs A table of arguments for creating the option.
--- @return Option option The created option if no error occurred, otherwise `nil`.
--- Creates an `Option` from the given arguments.
---
--- `args` may include the following optional properties:
--- * `aliases`: An array of strings representing alternative names for the option. Defaults to `{}`.
--- * `defaultValue`: The default value for the option if it is not provided. Defaults to `nil`.
--- * `delimiter`: The delimiter to use for splitting the input string into array elements if the option is an array. Defaults to `nil`.
---   * If this property is provided, the option will be parsed as an array of its given kind using the specified delimiter.
---   * If `delimiter` is an empty string, the option value will be treated as an array with a single element.
--- * `description`: The description of the option used for help messages. Defaults to `nil`.
--- * `failure`: Determines how to handle parsing errors for this option (`"error"`, `"ignore"`). Defaults to `"error"`.
---   * `"error"`: If a parsing error occurs for this option, parsing will fail and return an error.
---   * `"ignore"`: If a parsing error occurs for this option, the error will be ignored and the option will not be included in the parsed options passed to the command's handler.
---   * If `delimiter` is provided, the option will be parsed as an array of the specified kind.
--- * `multiple`: A strategy for how multiple occurrences of the option should be handled (`"set"`, `"append"`, `"fail"`). Defaults to `"fail"`.
---   * `"set"`: If the option is provided multiple times, only the last value will be used.
---   * `"append"`: If the option is provided multiple times, all occurrences will be parsed individually and each appear as a separate parsed option to the command.
---   * `"fail"`: If the option is provided multiple times, parsing will fail and return an error.
--- * `name`: The name of the option, which must be a non-empty string starting with an alphanumeric character.
--- * `required`: A boolean indicating whether the option is required and parsing should fail if not provided. Defaults to `false`.
---
--- See [`OptionArgs`](lua://OptionArgs) for a full type definition of `args`.
function Option.NewWith(inner, args)
    local obj = Option.New(args.name, inner)
    obj.aliases = args.aliases or {}
    obj.defaultValue = args.defaultValue
    obj.delimiter = args.delimiter
    obj.description = args.description
    obj.failure = args.failure
    obj.multiple = args.multiple
    obj.required = args.required or false
    return obj
end

--- @param args OptionArgs
--- @return Option
function Option.StringWith(args)
    local inner = StringOption.New()
    return Option.NewWith(inner, args)
end

function Option.NumberWith(args)
    local inner = NumberOption.New()
    return Option.NewWith(inner, args)
end

function Option.BooleanWith(args)
    local inner = BooleanOption.New()
    return Option.NewWith(inner, args)
end

--- @return string? error An error message if the option is invalid, otherwise `nil`.
--- @return Option? self The option itself if no error occurred, otherwise `nil`.
--- Validates the option's properties and returns an error message if any validation checks fail.
---
--- See [Option](lua://Option)'s Safety section for details on the validation rules.
function Option:Validate()
    local err = IsValidOptionName(self.name)
    if err then
        return ("Invalid `name`: '%s': %s"):format(self.name, err)
    end

    for _, alias in ipairs(self.aliases) do
        local err = IsValidOptionName(alias)
        if err then
            return ("Invalid alias '%s' in `aliases` for option '%s': %s"):format(alias, self.name, err)
        end
    end

    if self.defaultValue ~= nil then
        local err, value = self:ParseValue(self.defaultValue)
        if err then
            return ("Invalid `defaultValue`: '%s' (option '%s'): %s"):format(tostring(self.defaultValue), self.name, err)
        end

        self._defaultValueParsed = value
    end

    if self.delimiter ~= nil and type(self.delimiter) ~= "string" then
        return ("Invalid `delimiter`: '%s' (must be a string)"):format(tostring(self.delimiter))
    end

    if self.failure ~= "error" and self.failure ~= "ignore" then
        return ("Invalid `failure`: '%s' (valid values are 'error', 'ignore')"):format(tostring(self.failure))
    end

    if self.multiple ~= "set" and self.multiple ~= "append" and self.multiple ~= "fail" then
        return ("Invalid `multiple`: '%s' (valid values are 'set', 'append', 'fail')"):format(tostring(self.multiple))
    end

    if self.required and self.defaultValue ~= nil then
        return "Option cannot be required and have a default value at the same time"
    end

    if self._inner == nil then
        return "Option is missing an inner option for parsing values"
    end

    return nil, self
end

--- @param aliases string[]
--- @return Option self
function Option:SetAliases(aliases)
    self.aliases = aliases
    return self
end

--- @param defaultValue string
--- @return Option self
--- Sets the default value for this option if it is not provided.
---
--- Note that the default value is parsed using the same parsing logic as the option value, so it must be a string that can be parsed into the option's kind.
--- This allows the help message to show the default value in its original string form.
---
--- ## Safety
---
--- If `defaultValue` is not `nil` and this option is required, the option will be in an invalid state because it cannot be both required and have a default value at the same time.
--- You may call `Validate()` to check for this and other validation errors, or you must ensure that you do not provide a default value if `required` is `true`.
function Option:SetDefaultValue(defaultValue)
    self.defaultValue = defaultValue
    return self
end

--- @param delimiter string? [Default: `","`] Split the option value using this delimiter.
--- @return Option self
--- Sets the option to be an array option that parses multiple values from a single option given a delimiter.
---
--- If this method is called, the option will be parsed as an array of its given kind.
--- If `failure` is `ignore`, any parsing errors for individual elements will be ignored and the successfully parsed elements will still be included in the resulting array.
---
--- ## Examples
---
--- ```lua
--- local myOption = Option.NewString("id")
--- myOption:ParseValue("1") -- Returns the string "1"
--- myOption:ParseValue("1,2,3") -- Returns the string "1,2,3"
---
--- myOption:SetDelimiter(",") -- myOption is now an array option with a comma delimiter.
--- myOption:ParseValue("1") -- Returns the array { "1" }
--- myOption:ParseValue("1,2,3") -- Returns the array { "1", "2", "3" }
--- myOption:ParseValue("1;2;3") -- Returns the array { "1;2;3" }
---
--- myOption:SetDelimiter(";") -- myOption is still an array option but now with a semicolon delimiter instead.
--- myOption:ParseValue("1") -- Returns the array { "1" }
--- myOption:ParseValue("1;2;3") -- Returns the array { "1", "2", "3" }
---
--- myOption:SetDelimiter("") -- myOption is now an array option with an empty string delimiter, which means the entire input string is treated as a single element in the array.
--- myOption:ParseValue("1") -- Returns the array { "1" }
--- myOption:ParseValue("1,2,3") -- Returns the array { "1,2,3" }
--- ```
function Option:SetDelimiter(delimiter)
    if delimiter == nil then
        delimiter = ","
    end

    self.delimiter = delimiter
    return self
end

--- @param description string
--- @return Option self
function Option:SetDescription(description)
    self.description = description
    return self
end

--- @param failure "error" | "ignore"
--- @return Option self
function Option:SetFailure(failure)
    self.failure = failure
    return self
end

--- @param multiple "set" | "append" | "fail"
--- @return Option self
function Option:SetMultiple(multiple)
    self.multiple = multiple
    return self
end

--- @param required boolean
--- @return Option self
--- Sets whether this option is required.
---
--- ## Safety
---
--- If `required` is `true` and this option has a default value, the option will be in an invalid state because it cannot be both required and have a default value at the same time.
--- You may call `Validate()` to check for this and other validation errors, or you must ensure that you do not set `required` to `true` if a default value is provided.
function Option:SetRequired(required)
    self.required = required
    return self
end

--- @param alias string
--- @return Option self
--- Adds an alias for this option.
function Option:AddAlias(alias)
    table.insert(self.aliases, alias)
    return self
end

--- @param token Token
--- @return boolean # `true` if the token matches this option's name or any of its aliases, otherwise `false`.
--- Checks if the given token matches this option's name or any of its aliases.
function Option:Matches(token)
    if token == self.name then
        return true
    end

    for _, alias in ipairs(self.aliases) do
        if token == alias then
            return true
        end
    end

    return false
end

--- @generic T
--- @param input Token?
--- @return string? error An error message if parsing failed, otherwise `nil`.
--- @return T? value The parsed value if no error occurred, otherwise `nil`.
--- Parses the option value from the given input token to this option's kind.
function Option:ParseValue(input)
    if self.delimiter == nil then
        local err, value = self._inner:ParseValue(input)
        if err then
            if self.failure == "error" then
                return err
            elseif self.failure == "ignore" then
                return nil, nil
            end
        end
        return nil, value
    else
        -- If a delimiter is set, we treat this option as an array option regardless of its inner type, so we use the ArrayOption parsing logic.
        local arrayOption = ArrayOption.New(self._inner, self.delimiter, self.failure)
        local err, value = arrayOption:ParseValue(input)
        if err then
            return err
        end

        return nil, value
    end
end

libcli.OptionBase = OptionBase
libcli.StringOption = StringOption
libcli.NumberOption = NumberOption
libcli.BooleanOption = BooleanOption
libcli.ArrayOption = ArrayOption
libcli.Option = Option
