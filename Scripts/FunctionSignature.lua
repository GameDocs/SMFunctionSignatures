FunctionSignature = class( nil )
FunctionSignature.MAX_PARAMS = 12

function FunctionSignature.new( func, name, types, environment )
    local object = FunctionSignature()

    object.func = func
    object.name = name
    object.types = types
    object.environment = environment

    object.signature = {
        paramsMin = nil,
        paramsMax = nil
    }

    return object
end

function FunctionSignature:getTypeInstanceByName( name )
    return self.types[name]
end

function FunctionSignature:getTypeName( variable )
    local typename = type(variable)
    local classname = "<" .. typename .. ">"

    if self.types[classname] then
        return classname
    end

    if typename == "table" then
        local tabletypes = "table {"

        for k, v in ipairs(variable) do
            tabletypes = tabletypes .. self:getTypeName(v)

            -- Add separator
            if k ~= #variable then
                tabletypes = tabletypes .. ", "
            end
        end

        tabletypes = tabletypes .. "}"

        return tabletypes
    end

    if self.types[typename] then
        return typename
    end

    return "unknown: " .. typename
end

function FunctionSignature:debug( ... )
    if debug then
        local file, line = debug.traceback():match("^.-\n.-\n.-\t%[string \"(.-)\"%]:(%d+):")
        print("\x1B[37m[" .. file .. ":" .. line .. "] " .. self.name .. ":\x1B[92m", ...)
    else
        print(self.name .. ":", ...)
    end
end

function FunctionSignature:error( ... )
    self:debug("\x1B[91mERROR:", ...)
end



function FunctionSignature:generate()
    if self:hasEnvironmentErrors() then
        return self.signature
    end

    self:findParamsMin()
    self:debug("paramsMin =", self.signature.paramsMin)

    self:findParamsMax()
    self:debug("paramsMax =", self.signature.paramsMax)

    local workingParams = {}

    -- Fill it with values we know (most likely) won't work
    for i = 1, self.signature.paramsMax do
        workingParams[i] = true
    end

    for i = 1, self.signature.paramsMax do
        local complete, argument, instance = self:findWorkingParams(workingParams)

        if complete == -1 then
            -- An error occured that can't be fixed by using different parameters
            return self.signature
        elseif complete then
            break
        else
            workingParams[argument] = instance
        end
    end

    self:debug("Working parameters:", workingParams)

    self:getReturnTypes(unpack(workingParams))

    return self.signature
end

function FunctionSignature:hasEnvironmentErrors()
    local success, err = pcall(self.func)
    self:debug(success, err)

    if success then
        -- No errors
        return false
    end

    if err == "Sandbox violation: calling client function from server callback." then
        self.signature.sandbox = "client"
    elseif err == "Sandbox violation: calling server function from client callback." then
        self.signature.sandbox = "server"
    elseif err == "Sandbox violation: mismatching scriptTypeID." then
        self.signature.scriptType = self.signature.scriptType or {}
        self.signature.scriptType[self.environment.type] = false
    elseif err == "Not available in this game mode" or err == "Not available this game mode" then
        self.signature.gamemode = self.signature.gamemode or {}
        self.signature.gamemode[self.environment.gamemode] = false
    else
        -- No environment errors
        return false
    end

    -- An error occured
    return true
end

function FunctionSignature:findParamsMin()
    local success, err = pcall(self.func)
    self:debug(success, err)

    if success then
        self.signature.paramsMin = 0
        return 0
    end

    local expected, got = string.match(err, "Expected (%d+) arguments %(got (%d+)%)")
    if expected then
        self.signature.paramsMin = tonumber(expected)
        return expected
    end

    local expected, got = string.match(err, "Expected at least (%d+) arguments %(got (%d+)%)")
    if expected then
        self.signature.paramsMin = tonumber(expected)
        return expected
    end

    error("Failed to get minimum amount of parameters: " .. "expected=" .. expected .. ", got=" .. got .. ", full=" .. tostring(err))
end

function FunctionSignature:findParamsMax()
    local values = {}
    for i = 1, self.MAX_PARAMS do
        values[i] = true
    end

    local success, err = pcall(self.func, unpack(values))
    self:debug(success, err)
    
    if success then
        self.signature.paramsMax = self.MAX_PARAMS
        return self.MAX_PARAMS
    end

    local expected, got = string.match(err, "Expected (%d+) arguments %(got (%d+)%)")
    if expected then
        self.signature.paramsMax = tonumber(expected)
        return expected
    end

    local expected, got = string.match(err, "Expected at most (%d+) arguments %(got (%d+)%)")
    if expected then
        self.signature.paramsMax = tonumber(expected)
        return expected
    end

    error("Failed to get maximum amount of parameters: " .. "expected=" .. expected .. ", got=" .. got .. ", full=" .. tostring(err))
end

function FunctionSignature:findWorkingParams( workingParams )
    -- Make a copy of the parameters that work
    local params = {}
    for k, v in ipairs(workingParams) do
        params[k] = v
    end


    self:debug("Running with", params)
    
    -- The function might return multiple parameters
    local result = { pcall(self.func, unpack(params)) }
    self:debug(result)

    if result[1] then
        self:debug("Success", result[2])
        return true
    else
        local err = result[2]

        if not self:shouldIgnoreRuntimeError(err) then
            local argument, expected, got = string.match(err, "bad argument #(%d+) to '.-' %((%w+) expected, got (%w+)%)")
            
            if expected == nil or got == nil then
                self:error("Failed trying amount of parameters of " .. tostring(i) .. ": " .. "expected=" .. tostring(expected) .. ", got=" .. tostring(got) .. ", full=" .. tostring(err))
                return -1
            end
            
            self:debug("Trying to find instance of type", expected)
            local instance = self:getTypeInstanceByName(expected) or self:getTypeInstanceByName("<" .. expected .. ">") or expected
            self:debug("Found", instance)

            return false, tonumber(argument), instance
        end

        return -1
    end
end

function FunctionSignature:shouldIgnoreRuntimeError( err )
    if err == "Unknown userdata received" then
        return true
    elseif err == "Expected userdata, got boolean" then
        return true
    elseif err == "Created shape expected the uuid of a block, received: {" .. tostring(self:getTypeInstanceByName("<Uuid>")) .. "}" then
        return true
    elseif err == "Uuid {" .. tostring(self:getTypeInstanceByName("<Uuid>")) .. "} is not of block type" then
        return true
    elseif err == "Effect not found: '" .. tostring(self:getTypeInstanceByName("string")) .. "'" then
        return true
    elseif err == tostring(self:getTypeInstanceByName("string")) .. " is not located in a valid directory" then
        return true
    elseif err == "Only uuids of block type can be validated" then
        return true
    end
    
    return false
end

function FunctionSignature:getReturnTypes( ... )
    self:debug("Getting return type with parameters", ...)

    local result = { pcall(self.func, ...) }
    self:debug(result)

    if not result[1] then
        self:error("Execution failed: " .. result[2])
        return
    end

    self.signature.returns = {}
    for i = 2, #result do
        table.insert(self.signature.returns, {
            type = self:getTypeName(result[i])
        })
    end

    return self.signature.returns
end
