METOO_SLUG, MeToo   = ...
METOO_MSG_ADDONNAME = C_AddOns.GetAddOnMetadata( METOO_SLUG, "Title" )
METOO_MSG_VERSION   = C_AddOns.GetAddOnMetadata( METOO_SLUG, "Version" )
METOO_MSG_AUTHOR    = C_AddOns.GetAddOnMetadata( METOO_SLUG, "Author" )

-- Colours
COLOR_RED = "|cffff0000"
COLOR_GREEN = "|cff00ff00"
COLOR_BLUE = "|cff0000ff"
COLOR_PURPLE = "|cff700090"
COLOR_YELLOW = "|cffffff00"
COLOR_ORANGE = "|cffff6d00"
COLOR_GREY = "|cff808080"
COLOR_GOLD = "|cffcfb52b"
COLOR_NEON_BLUE = "|cff4d4dff"
COLOR_END = "|r"

BINDING_HEADER_METOOBUTTONS = "MeToo Bindings"
BINDING_NAME_METOOBUTTON = "MeToo!"

MeToo.knownEmotes = {}
MeToo_mountList = {}
MeToo_companionList = {}

function MeToo.Print( msg, showName)
	-- print to the chat frame
	-- set showName to false to suppress the addon name printing
	if (showName == nil) or (showName) then
		msg = COLOR_BLUE..METOO_MSG_ADDONNAME.."> "..COLOR_END..msg
	end
	DEFAULT_CHAT_FRAME:AddMessage( msg )
end
function MeToo.OnLoad()
	SLASH_METOO1 = "/M2"
	SLASH_METOO2 = "/METOO"
	SlashCmdList["METOO"] = function( msg ) MeToo.Command( msg ); end
	MeToo_Frame:RegisterEvent( "NEW_MOUNT_ADDED" )
	MeToo_Frame:RegisterEvent( "ADDON_LOADED" )
end
function MeToo.ADDON_LOADED( _, arg1 )
--	print( "ADDON_LOADED( "..(arg1 or "NIL").." )" )
--	print( arg1 .. " ?= "..METOO_SLUG .. (arg1 == METOO_SLUG and " YES!" or " no....") )

	if( arg1 == METOO_SLUG ) then
		MeToo_Frame:UnregisterEvent( "ADDON_LOADED" )
		MeToo.BuildEmoteList()

		MeToo.RemoveFromLists()
		MeToo.UpdateOptions()
		MeToo.OptionsPanel_Reset()
	end
end
function MeToo.NEW_MOUNT_ADDED()
	--print( "NEW_MOUNT_ADDED" )
	MeToo.BuildMountSpells()
end
------------
function MeToo.BuildEmoteList()
	for i = 1, 1000 do
		local token = _G["EMOTE"..i.."_TOKEN"]
		if token then
			table.insert( MeToo.knownEmotes, token )
		end
	end
	table.sort( MeToo.knownEmotes )
end
function MeToo.BuildMountSpells()
	-- Build a table of [spellID] = "mountName"
	-- This needs to be expired or rebuilt when a new mount is learned.
	MeToo.mountSpells = {}
	local mountIDs = C_MountJournal.GetMountIDs()
	for _, mID in pairs(mountIDs) do
		--print( mID )
		mName, mSpellID = C_MountJournal.GetMountInfoByID( mID )
		MeToo.mountSpells[ mSpellID ] = mName
	end
end
function MeToo.GetMountID( unit )
	-- return the current mount ID...
	-- match this against the mounts you know.
	for an=1,40 do  -- scan ALL of the auras...  :(
		auraData = C_UnitAuras.GetAuraDataByIndex( unit, an )
		if( auraData and MeToo.mountSpells[auraData.spellId] and MeToo.mountSpells[auraData.spellId] == auraData.name ) then
			--print( unit.." is on: "..auraData.name )
			return auraData.spellId, auraData.name
		end
	end
end
function MeToo.PerformMatch()
	if( UnitIsBattlePet( "target" ) ) then  -- target is battle pet
		speciesID = UnitBattlePetSpeciesID( "target" )
		petType = UnitBattlePetType( "target" )

		isOwned = ( C_PetJournal.GetOwnedBattlePetString( speciesID ) and true or nil )
		-- returns a string of how many you have or nil if you have none.   Convert this to 1 - nil for
		-- C_PetJournal.GetNumCollectedInfo(speciesId)  -- returns have/max

		petName = C_PetJournal.GetPetInfoBySpeciesID( speciesID )  -- get the petName
		-- MeToo_companionList[time()] = petName  -- because of the BattlePetGUID included in the link....
		-- the API will not provide a link from the speciesID...  Even though the main link is:
		-- |c........|Hbattlepet:<speciesID>:...junk...:petGUID\h[<petName>]|h|r
		-- "|cff0070dd|Hbattlepet:193:7:3:464:96:68:BattlePet-0-00000492C932|h[Giant Sewer Rat]|h|r"
		-- not sure what would happen if I crafted a 'fake' link....

		if isOwned then
			_, petID = C_PetJournal.FindPetIDByName( petName )  -- == petID (which is YOUR petID) from the petName
			currentPet = C_PetJournal.GetSummonedPetGUID()  -- get your current pet

			if( currentPet ) then -- you have one summoned
				currentSpeciesID = C_PetJournal.GetPetInfoByPetID( currentPet )  -- get the speciesID of your current pet
			end

			-- summon pet if
				-- no current pet ( currentPet == nil )
				-- or
					-- currentPet
					-- AND
					-- speciesID != currentSpeciesID
			if( (not currentPet) or
					( currentPet and speciesID ~= currentSpeciesID ) ) then
				-- no current pet
				-- or current pet, and species do not match
				C_PetJournal.SummonPetByGUID( petID )
				if( MeToo_options.companionSuccess_doEmote and strlen( MeToo_options.companionSuccess_emote ) > 0 ) then
					DoEmote( MeToo_options.companionSuccess_emote, (not MeToo_options.companionSuccess_useTarget) and "player" or nil )
				end
			else
				--MeToo.Print( "Pets are the same" )
			end
		else
			if( MeToo_options.companionFailure_doEmote and strlen( MeToo_options.companionFailure_emote ) > 0 ) then
				DoEmote( MeToo_options.companionFailure_emote, (not MeToo_options.companionFailure_useTarget) and "player" or nil )
			end
			MeToo.Print( "Pet name: "..petName )
			MeToo_companionList[time()] = petName
		end
	elseif( UnitIsPlayer( "target" ) ) then
		_, unitSpeed = GetUnitSpeed( "target" )
		--print( "Target unitSpeed: "..unitSpeed )
		if( unitSpeed ~= 7 ) then  -- there is no IsMounted( unitID ), use the UnitSpeed to guess if they are mounted.
			MeToo.MountUp()
		end
	else -- Target is NOT a battle pet or player.   Try to match NPC.
		MeToo.MountUp()
	end
end
function MeToo.MountUp()
	myMountID = nil
	if( not MeToo.mountSpells ) then  -- build the mount spell list here
		MeToo.BuildMountSpells()
	end
	if( IsMounted() ) then  -- if you are mounted, scan and find your mount ID
		myMountID, myMountName = MeToo.GetMountID( "player" )
	end
	theirMountID, theirMountName = MeToo.GetMountID( "target" )
	if( theirMountID and theirMountID ~= myMountID ) then
		mountSpell = C_MountJournal.GetMountFromSpell( theirMountID )
		mountLink = C_Spell.GetSpellLink( theirMountID )
		MeToo.Print( "Mount Link: "..mountLink )

		_, _, _, _, isUsable = C_MountJournal.GetMountInfoByID( mountSpell ) -- isUsable = can mount

		if( isUsable ) then
			if( MeToo_options.mountSuccess_doEmote and strlen( MeToo_options.mountSuccess_emote ) > 0 ) then
				DoEmote( MeToo_options.mountSuccess_emote, MeToo_options.mountSuccess_useTarget and "target" or "player" )
			end
			if( not IsFlying() ) then  -- only do this if you are NOT flying...
				C_MountJournal.SummonByID( mountSpell )
			else
				MeToo.Print( "You are flying. Not going to try to change mounts." )
			end
		else
			if( MeToo_options.mountFailure_doEmote and strlen( MeToo_options.mountFailure_emote ) > 0 ) then
				DoEmote( MeToo_options.mountFailure_emote, MeToo_options.mountFailure_useTarget and "target" or "player" )
			end
			MeToo_mountList[time()] = mountLink
		end
	end
end
function MeToo.ShowList( listTypeIn )
	-- type is "companion" or "mount"
	local listType = string.lower( listTypeIn )
	--print( "ShowList( "..listType.." )" )
	local workingList = ( listType == "companion" and MeToo_companionList or MeToo_mountList )
	local displayList = {}
	if( workingList ) then
		MeToo.Print( ("Saw it... Want it... (%s list)"):format( ( listType == "companion" and listType or "mount" ) ) )
		for ts, name in pairs( workingList ) do
			displayList[ name ] = displayList[ name ] and displayList[ name ] + 1 or 1
		end
		for name, count in pairs( displayList ) do
			MeToo.Print( ("%s seen %d time%s."):format( name, count, ( count > 1 and "s" or "" ) ), false )
		end
	end
	if( listTypeIn == "" ) then
		MeToo.ShowList( "companion" )
	end
end
function MeToo.ClearList( listTypeIn )
	local listType = string.lower( listTypeIn )
	--print( "ClearList( "..listType.." )" )
	local listType = ( listType == "companion" and "companion" or "mount" )
	if( listType == "mount" ) then
		MeToo_mountList = {}
		MeToo.Print( "Clearing mount list." )
	elseif( listType == "companion" ) then
		MeToo_companionList = {}
		MeToo.Print( "Clearing companion list." )
	end
	if( listTypeIn == "" ) then
		MeToo.ClearList( "companion" )
	end
end
function MeToo.RemoveFromLists( daysIn )
	local expireBefore = time() - ( (daysIn or ( MeToo_options.daysTrackWanted or MeToo.defaultOptions.daysTrackWanted ) ) * 86400 )
	for ts in pairs( MeToo_companionList ) do
		if( ts < expireBefore ) then
			MeToo_companionList[ts] = nil
		end
	end
	for ts in pairs( MeToo_mountList ) do
		if( ts < expireBefore ) then
			MeToo_mountList[ts] = nil
		end
	end
end
-----
function MeToo.ParseCmd( msg )
	if msg then
		msg = string.lower( msg )
		local a, b, c = strfind( msg, "(%S+)" )  -- contiguous string of non-space chars.  a = start, b=len, c=str
		if a then
			-- c is the matched string
			return c, strsub( msg, b+2 )
		else
			return ""
		end
	end
end
function MeToo.Command( msg )
	local cmd, param = MeToo.ParseCmd( msg )
	--MeToo.Print( "cl:"..cmd.." p:"..(param or "nil") )
	local cmdFunc = MeToo.commandList[cmd]
	if cmdFunc then
		cmdFunc.func( param )
	else
		MeToo.PerformMatch()
	end
end
function MeToo.PrintHelp()
	MeToo.Print( METOO_MSG_ADDONNAME.." ("..METOO_MSG_VERSION..") by "..METOO_MSG_AUTHOR )
	MeToo.Print( "Use: /METOO or /M2 targeting a player or companion pet." )
	for cmd, info in pairs( MeToo.commandList ) do
		MeToo.Print( string.format( "%s %s %s -> %s",
				SLASH_METOO1, cmd, info.help[1], info.help[2] ) )
	end
end
MeToo.commandList = {
	["help"] = {
		["func"] = MeToo.PrintHelp,
		["help"] = { "", "Print this help."}
	},
	["options"] = {
		["func"] = function() Settings.OpenToCategory( MeTooOptionsFrame.category:GetID() ) end,
		["help"] = { "", "Open the options panel." }
	},
	["list"] = {
		["func"] = MeToo.ShowList,
		["help"] = { "<mount | companion>", "Show a list of mounts or companions you were unable to match." },
	},
	["clear"] = {
		["func"] = MeToo.ClearList,
		["help"] = { "<mount | companion>", "Clear wanted mounts or companions list" },
	},
}
