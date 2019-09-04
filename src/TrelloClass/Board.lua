--[[
    Name: Board.lua
    From roblox-trello v2

    Description: Constructor for Trello Boards.
    This script is in public domain.
--]]

local HTTP = require(script.Parent.Parent.TrelloHttp)

-- TrelloBoard Metatable
local META_TrelloBoard = {
    __tostring = "TrelloBoard",

    __metatable = "TrelloBoard",

    -- Hopefully this will not throw false positives. Functions that will eventually work with this should be aware.
    __index = function(_, index)
        error("[TrelloBoard]: Attempted to index non-existant property "..tostring(index)..".", 0)
    end,

    -- This can be bypassed using rawset, but at that point it's not on us
    __newindex = function(_, index, _)
        error("[TrelloBoard]: Attempted to set non-existant property "..tostring(index)..".", 0)
    end
}

-- Local function prototype to make a board based on a body dump
local makeBoard

local TrelloBoard = {}

--[[**
    Creates a new TrelloBoard, that represents a Trello board, that is then also created on Trello.

    @param [t:TrelloEntity] entity The entity the board will be assigned to.
    @param [t:String] name The Board's name. Must to be a non-empty string with a maximum of 16384 characters.
    @param [t:Boolean] public Whether the board is public or not. If this field is not provided, the board will be private.

    @returns [t:TrelloBoard] A new TrelloBoard that was freshly created.
**--]]
function TrelloBoard.new(entity, name, public)
    if not entity or getmetatable(entity) ~= "TrelloEntity" then
        error("[TrelloBoard.new]: Invalid entity!", 0)
    elseif not name or name == "" or name:len() > 16384 then
        error("[TrelloBoard.new]: Invalid name! Make sure that the name is a non-empty string with less than 16384 characters.", 0)
    end

    local commitURL = entity:MakeURL("/boards", {
        name = name,
        defaultLabels = false,
        defaultLists = false,
        prefs_selfJoin = false,
        prefs_cardCovers = false,
        prefs_permissionLevel = public and "public" or "private"
    })

    local result = HTTP.RequestInsist(commitURL, HTTP.HttpMethod.POST, "{}", true)

    return makeBoard(entity, result.Body)
end

--[[**
    Fetches a TrelloBoard from Trello.

    @param [t:TrelloEntity] entity The entity the board will be assigned to.
    @param [t:String] name The Board's ID.

    @returns [t:Variant<TrelloBoard,nil>] The Trello Board fetched. Returns nil if the board doesn't exist.
**--]]
function TrelloBoard.fromRemote(entity, remoteId)
    if not entity or getmetatable(entity) ~= "TrelloEntity" then
        error("[TrelloBoard.fromRemote]: Invalid entity!", 0)
    elseif not remoteId or remoteId == "" then
        error("[TrelloBoard.fromRemote]: Invalid board id!", 0)
    end

    local commitURL = entity:MakeURL("/boards/" .. remoteId, {
        customFields = false,
        card_pluginData = false,
        fields = {"name","desc","descData","closed","prefs"},
    })

    local result = HTTP.RequestInsist(commitURL, HTTP.HttpMethod.GET, nil, true)

    return makeBoard(entity, result.Body)
end

-- Prototype implementation
makeBoard = function(entity, data)
    if not data then
        return nil
    end

    local TrelloBoard = {
        RemoteId = data.id,
        Name = data.name,
        Description = data.desc,
        Public = data.prefs.permissionLevel == "public",
        Closed = data.closed,
        _Remote = {
            Name = data.name,
            Description = data.desc,
            Public = data.prefs.permissionLevel == "public",
            Closed = data.closed
        }
    }

    --[[**
        Pushes all metadata changes to Trello. (Doesn't apply to lists, cards, etc.)

        @param [t:Boolean] force Whether to push all changes to the board even though nothing has been changed.

        @returns [t:Void]
    **--]]
    function TrelloBoard:Commit(force)
        local count = 0
        local commit = {}

        for i, v in pairs (TrelloBoard._Remote) do
            if (v ~= TrelloBoard[i]) or force then
                commit[i] = TrelloBoard[i]
                count = count + 1
            end
        end

        if count == 0 then
            warn("[Trello/Board.Commit]: Nothing to change. Skipping")
        end

        local commitURL = entity:MakeURL("/boards/"..TrelloBoard.RemoteId, {
            name = commit.Name,
            desc = commit.Description,
            closed = commit.Closed,
            prefs = (commit.Public ~= nil) and {
                permissionLevel = commit.Public and "public" or "private"
            } or nil
        })

        HTTP.RequestInsist(commitURL, HTTP.HttpMethod.PUT, "{}", true)

        for i, v in pairs(commit) do
            TrelloBoard._Remote[i] = v
        end
    end

    --[[**
        Deletes this board from Trello. All garbage collection is up to the developer to perform.

        @returns [t:Void]
    **--]]
    function TrelloBoard:Delete()
        local commitURL = entity:MakeURL("/boards/" .. TrelloBoard.RemoteId)

        HTTP.RequestInsist(commitURL, HTTP.HttpMethod.DELETE, nil, true)

        TrelloBoard = nil
    end

    return setmetatable(TrelloBoard, META_TrelloBoard)
end

return TrelloBoard
