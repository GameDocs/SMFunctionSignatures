FunctionSignature = class( nil )
FunctionSignature.MAX_PARAMS = 12

function FunctionSignature.new( func, name, types, environment )
    local object = FunctionSignature()

    object.func = func
    object.name = name
    object.types = types
    object.environment = environment

    object.typesCount = 0
    for k, v in pairs(types) do
        object.typesCount = object.typesCount + 1
    end

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
        if not variable[1] then
            return typename
        end

        local tabletypes = "table {" .. self:getTypeName(variable[1]) .. "}"

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
    if debug then
        local file, line = debug.traceback():match("^.-\n.-\n.-\t%[string \"(.-)\"%]:(%d+):")
        print("\x1B[37m[" .. file .. ":" .. line .. "] " .. self.name .. ": \x1B[91mERROR:", ...)
    else
        print(self.name .. ": ERROR:", ...)
    end
end



function FunctionSignature:generate()
    if self:hasEnvironmentErrors() then
        return false, self.signature
    end

    self:findParamsMin()
    self:debug("paramsMin =", self.signature.paramsMin)

    self:findParamsMax()
    self:debug("paramsMax =", self.signature.paramsMax)

    local initialParams = self:findInitialParams()
    self:debug("Initial parameters =", initialParams)
    if not initialParams then
        return false, self.signature
    end

    self:getReturnTypes(unpack(initialParams))

    self.signature.params = self:findAllParams(initialParams)
    self:debug("All parameters found =", self.signature.params)

    return true, self.signature
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

function FunctionSignature:findInitialParams()

    local function try( initialParams )
        -- Make a copy of the parameters that work
        local params = {}
        for k, v in ipairs(initialParams) do
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
                
                if argument == nil or expected == nil or got == nil then
                    self:error("Failed trying amount of parameters of " .. tostring(i) .. ": " .. "expected=" .. tostring(expected) .. ", got=" .. tostring(got) .. ", full=" .. tostring(err))
                    return -1
                end

                self:debug(tonumber(argument), self.signature.paramsMax)
                if tonumber(argument) > self.signature.paramsMax then
                    -- I think this has something to do with how Lua works with the stack
                    self:error("Parameter of type table has invalid content! " .. err)
                    return -1
                end
                
                self:debug("Trying to find instance of type", expected)
                local instance = self:getTypeInstanceByName(expected) or self:getTypeInstanceByName("<" .. expected .. ">")

                if not instance then
                    self:error("Unable to find instance of type " .. expected)
                    return -1
                end

                self:debug("Found", instance)

                return false, tonumber(argument), instance
            end

            return -1
        end
    end

    local initialParams = {}

    -- Fill it with values we know (most likely) won't work
    for i = 1, self.signature.paramsMax do
        initialParams[i] = true
    end

    -- Repeatedly try calling the function, changing the parameter when the error tells us to
    -- Once for each parameter, +1 to check if parameters of type table throw errors
    for i = 1, self.signature.paramsMax + 1 do
        local complete, argument, instance = try(initialParams)

        if complete == -1 then
            -- An error occured that can't be fixed by using different parameters
            return nil
        elseif complete then
            break
        else
            initialParams[argument] = instance
        end
    end

    return initialParams
end

function FunctionSignature:shouldIgnoreRuntimeError( err )
    if err == "Unknown userdata received"
        or err == "Expected userdata, got boolean"
        or err == "Created shape expected the uuid of a block, received: {" .. tostring(self:getTypeInstanceByName("<Uuid>")) .. "}"
        or err == "Uuid {" .. tostring(self:getTypeInstanceByName("<Uuid>")) .. "} is not of block type"
        or err == "Effect not found: '" .. tostring(self:getTypeInstanceByName("string")) .. "'"
        or err == tostring(self:getTypeInstanceByName("string")) .. " is not located in a valid directory"
        or err == "Only uuids of block type can be validated"
        or err == "Failed to create joint"
        or err:sub(1, 28) == "Failed to parse json string:"
        or err == "invalid uuid '" .. tostring(self:getTypeInstanceByName("string")) .. "'!"
        or err == "Portal hook '" .. tostring(self:getTypeInstanceByName("string")) .. "' already exists for world " .. tostring(self:getTypeInstanceByName("<World>").id)
        or tonumber(select(1, string.match(err, "bad argument #(%d+) to '.-' %((%w+) expected, got (%w+)%)")) or 0) > self.signature.paramsMax
        or err == "Failed to create shape, parent joint is already in use."
        or err == "AreaTrigger does not exist"
    then
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

function FunctionSignature:findAllParams( initialParams )

    if not self:doParamsWork(initialParams) then
        self:error("Initial parameters do not work!", initialParams)
        self:error("Signature:", self.signature)
        error("Initial parameters do not work!")
    end

    -- Keep track of all parameters that we know work
    local allParams = {}
    for i, initialParam in ipairs(initialParams) do
        allParams[i] = {
            types = {}
        }
    end

    for i = 1, #initialParams do
        -- Copy the initial parameters
        local currentParams = {}
        for i, initialParam in ipairs(initialParams) do
            -- self:debug(i, initialParam)
            currentParams[i] = initialParam
        end

        for paramType, paramInstance in pairs(self.types) do
            currentParams[i] = paramInstance

            if self:doParamsWork(currentParams) then
                table.insert(allParams[i].types, paramType)
            end
        end

        self:debug("abcdef", #allParams[i].types, self.typesCount)
        if #allParams[i].types == self.typesCount then
            allParams[i].anyType = true
        end

        if i > self.signature.paramsMin then
            allParams[i].optional = true
        end
    end

    return allParams

end

function FunctionSignature:doParamsWork( params )

    self:debug("Testing if these parameters work:", params)
    local success, err = pcall(self.func, unpack(params))
    self:debug(success, err)

    if success then
        return true
    end

    if self:shouldIgnoreRuntimeError(err) then
        return true
    end

    if string.match(err, "Expected (%d+) arguments %(got (%d+)%)")
        or string.match(err, "Expected at least (%d+) arguments %(got (%d+)%)")
        or string.match(err, "Expected at most (%d+) arguments %(got (%d+)%)")
        or string.match(err, "bad argument #(%d+) to '.-' %((%w+) expected, got (%w+)%)")
        or err:sub(1, 21) == "Unsupported userdata:"
        or string.match(err, "cannot apply impulse on '.-'")
    then
        return false
    end

    error("Unknown error: " .. err)
    return true
end
