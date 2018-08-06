METOO_MSG_ADDONNAME = "MeToo"
METOO_MSG_VERSION   = GetAddOnMetadata(METOO_MSG_ADDONNAME,"Version")
METOO_MSG_AUTHOR    = "opussf"

-- Colours
COLOR_RED = "|cffff0000";
COLOR_GREEN = "|cff00ff00";
COLOR_BLUE = "|cff0000ff";
COLOR_PURPLE = "|cff700090";
COLOR_YELLOW = "|cffffff00";
COLOR_ORANGE = "|cffff6d00";
COLOR_GREY = "|cff808080";
COLOR_GOLD = "|cffcfb52b";
COLOR_NEON_BLUE = "|cff4d4dff";
COLOR_END = "|r";

BINDING_HEADER_METOOBUTTONS = "MeToo Bindings"
BINDING_NAME_METOOBUTTON = "MeToo!"

MeToo = {}
MeToo.knownEmotes = {}

function MeToo.Print( msg, showName)
	-- print to the chat frame
	-- set showName to false to suppress the addon name printing
	if (showName == nil) or (showName) then
		msg = COLOR_PURPLE..METOO_MSG_ADDONNAME.."> "..COLOR_END..msg
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
function MeToo.ADDON_LOADED()
	MeToo_Frame:UnregisterEvent( "ADDON_LOADED" )
	MeToo.BuildEmoteList()

	MeToo.OptionsPanel_Reset()
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
		aName, _, aIcon, _, aType, _, _, _, _, aID = UnitAura( unit, an )
		if( aName and MeToo.mountSpells[aID] and MeToo.mountSpells[aID] == aName ) then
			--print( unit.." is on: "..aName )
			return aID, aName
		end
	end
end
function MeToo.PerformMatch()
	if( UnitIsBattlePetCompanion( "target" ) ) then  -- target is battle pet
		speciesID = UnitBattlePetSpeciesID( "target" )
		petType = UnitBattlePetType( "target" )

		isOwned = ( C_PetJournal.GetOwnedBattlePetString( speciesID ) and true or nil )
		-- returns a string of how many you have or nil if you have none.   Convert this to 1 - nil for

		if isOwned then
			petName = C_PetJournal.GetPetInfoBySpeciesID( speciesID )  -- get the petName
			_, petID = C_PetJournal.FindPetIDByName( petName )  -- == speciesID from the petName

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
					DoEmote( MeToo_options.companionSuccess_emote, "player" )
				end
			else
				--MeToo.Print( "Pets are the same" )
			end
		else
			if( MeToo_options.companionFailure_doEmote and strlen( MeToo_options.companionFailure_emote ) > 0 ) then
				DoEmote( MeToo_options.companionFailure_emote, "player" )
			end
		end
	elseif( UnitIsPlayer( "target" ) ) then
		_, unitSpeed = GetUnitSpeed( "target" )
		--print( "Target unitSpeed: "..unitSpeed )
		if( unitSpeed ~= 7 ) then  -- there is no IsMounted( unitID ), use the UnitSpeed to guess if they are mounted.
			myMountID = nil
			if( not MeToo.mountSpells ) then  -- build the mount spell list here
				MeToo.BuildMountSpells()
			end
			if( IsMounted() ) then  -- if you are mounted, scan and find your mount ID
				myMountID, myMountName = MeToo.GetMountID( "player" )
			end
			theirMountID, theirMountName = MeToo.GetMountID( "target" )   --

			if( theirMountID and theirMountID ~= myMountID ) then  -- not the same mount
				mountSpell = C_MountJournal.GetMountFromSpell( theirMountID )

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
				end
			end
		end
	else
		-- MeToo.Print( "Target is NOT a battle pet or player." )
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
		["func"] = function() InterfaceOptionsFrame_OpenToCategory( METOO_MSG_ADDONNAME ) end,
		["help"] = { "", "Open the options panel." }
	},
}
