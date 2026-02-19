local _, addon = ...
addon = addon or {}

local libcli = addon.libcli or {}
addon.libcli = libcli

local IsValidOptionName = libcli.IsValidOptionName

--- @alias Token string A token is a sequence of non-whitespace characters, or a quoted string that may contain whitespace.
--- @see Tokens

--- @class Tokens
--- @field input string
--- @field index number
--- @field parsedToken Token? The most recently parsed token, or `nil` if no token has been parsed yet.
--- @field endOfOptions boolean Indicates whether we have reached the end of options (i.e. encountered a `--` token).
--- Parses a string into a sequence of tokens.
---
--- Tokens are sequences of non-whitespace characters, separated by one or more whitespace characters.<br>
--- For example, the input string `foo bar baz` would be parsed into the tokens `foo`, `bar`, and `baz`.
---
--- If the token contains a quote character (`"` or `'`), it will include whitespace until the next matching quote character, excluding the quote characters themselves.<br>
--- For example, the input string `foo "bar baz"` would be parsed into the tokens `foo` and `bar baz`.
---
--- If the closing quote character is missing, the token will include all remaining characters.<br>
--- For example, `foo "bar baz` would be parsed into the tokens `foo` and `bar baz`.
---
--- If you want to escape a character, meaning it is treated literally even if it is a special character, precede it with a backslash (`\`).<br>
--- For example, the input string `foo \"bar \baz\"` would be parsed into the tokens `foo`, `"bar` and `baz"`.
---
--- If you want to include a literal backslash in a token, escape it with another backslash.<br>
--- For example, `foo bar\\baz` would be parsed into the tokens `foo` and `bar\baz`.
---
--- If inside quotes, you can also escape the quote character itself.<br>
--- For example, `foo "bar \"baz\" qux"` would be parsed into the tokens `foo` and `bar "baz" qux`.
---
--- If the token begins with `--`, it is considered an option token.<br>
--- For example, the input string `foo --bar=baz` would be parsed into the tokens `foo` and `--bar=baz`, where `--bar=baz` is an option token with name `bar` and value `baz`.
local Tokens = {}
Tokens.__index = Tokens

--- @param input string
--- @return Tokens
function Tokens.New(input)
    local obj = setmetatable({}, Tokens)
    obj.input = input
    obj.index = 1
    obj.parsedToken = nil
    obj.endOfOptions = false
    return obj
end

--- @private
--- @return Token? # The parsed token, or `nil` if there are no more tokens to parse.
--- Parse the next token from the input string.
---
--- Advances `self.index` to the position after the parsed token.
function Tokens:ParseNext()
    local inQuotes = false
    local quoteChar = nil
    local parts = {}

    local parsing = true
    while self.index <= #self.input and parsing do
        local char = self.input:sub(self.index, self.index)

        if char == "\\" then
            if self.index == #self.input then
                -- Backslash at end of input, treat it as a literal backslash.
                table.insert(parts, "\\")
                self.index = self.index + 1
                break
            end
            table.insert(parts, self.input:sub(self.index + 1, self.index + 1))
            self.index = self.index + 2
        elseif inQuotes then
            if char == quoteChar then
                inQuotes = false
                quoteChar = nil
                self.index = self.index + 1
            else
                table.insert(parts, char)
                self.index = self.index + 1
            end
        elseif char == "\"" or char == "'" then
            inQuotes = true
            quoteChar = char
            self.index = self.index + 1
        elseif string.match(char, "%s") then
            self.index = self.index + 1
            -- Whitespace at the start of a token is ignored.
            if #parts > 0 then
                -- We encountered non-quoted whitespace and our token is not empty, so we return it.
                parsing = false
            end
        else
            table.insert(parts, char)
            self.index = self.index + 1
        end
    end

    if #parts > 0 then
        local token = table.concat(parts)
        if token == "--" then
            self.endOfOptions = true
            return nil
        end
        return token
    else
        return nil
    end
end

--- @return Token? # Returns the next token, or `nil` if there are no more tokens to parse.
--- Get the next token.
function Tokens:Next()
    if self.parsedToken then
        local token = self.parsedToken
        self.parsedToken = nil
        return token
    end

    return self:ParseNext()
end

--- @return Token?
--- Peek at the next token without advancing the index.
--- Returns `nil` if there are no more tokens.
function Tokens:Peek()
    local token = self:Next()
    if token then
        self.parsedToken = token
    end
    return token
end

--- @return string? error An error message if an error occurred, otherwise `nil`.
--- @return Token? name If the next token is an option, returns the option name (without the `--` prefix) and its optional value, otherwise `nil`.
--- @return Token? value If the next token is an option with an `=` character, returns the value after the `=`, otherwise `nil`.
--- Get the next token if it is an option (i.e. starts with `--`).
---
--- Note: The return token will NOT include the `--` prefix.
---
--- ## Errors
---
--- * If the option name is invalid (see [`IsValidOptionName`](lua://IsValidOptionName)).
function Tokens:NextOptionToken()
    if self.endOfOptions then
        return nil, nil, nil
    end

    local token = self:Next()
    if token and token:sub(1, 2) == "--" then
        local eqIndex = token:find("=")
        local name, value = nil, nil
        if eqIndex then
            name = token:sub(3, eqIndex - 1)
            value = token:sub(eqIndex + 1)
        else
            name = token:sub(3)
        end

        local err = IsValidOptionName(name)
        if err then
            return ("Invalid option name '%s': %s"):format(name, err), nil, nil
        end

        return nil, name, value
    else
        self.parsedToken = token
        return nil, nil, nil
    end
end

--- @return string? error An error message if an error occurred, otherwise `nil`.
--- @return { name: Token, value: Token? }[] options A list of option tokens, where each token is a table containing the option name and its optional value.
--- Get all consecutive option tokens starting from the current index.
function Tokens:NextOptionTokens()
    local options = {}
    while true do
        local err, name, value = self:NextOptionToken()
        if err then
            return err, options
        end

        if name == nil then
            break
        end

        table.insert(options, { name = name, value = value })
    end
    return nil, options
end

--- @return Token? # The next non-option token, or `nil` if the next token is an option or if there are no more tokens.
function Tokens:NextNonOption()
    local token = self:Next()
    if token and token:sub(1, 2) ~= "--" or self.endOfOptions then
        return token
    else
        self.parsedToken = token
        return nil
    end
end

libcli.Tokens = Tokens
