#include <sourcemod>
#include <sdktools>
#include <cstrike>

/*
Plugin to connect to hlstatsx and get the player kd ratio and use it to balance the teams
plugin will also make sure that the teams are balanced both in number of players and in skill level / kd ratio 
if odd number of players the plugin will check how many bomb sites the map has and if it has 2 bomb sites it will make sure that CT has 1 more player than T
if the map has only 1 bomb site it will make sure that T has 1 more player than CT

*/

int team[4][8];
int teamWeight = CS_TEAM_CT;

public Plugin myinfo = {
	name = "OSAutoBalance",
	author = "Pintuz",
	description = "OldSwedes Auto-Balance plugin",
	version = "0.02",
	url = "https://github.com/Pintuzoft/OSAutoBalance"
}
 
public OnPluginStart ( ) {
    HookEvent ( "round_start", Event_RoundStart );
    HookEvent ( "round_end", Event_RoundEnd );
    //HookEvent ( "announce_phase_end", Event_HalfTime );
}

public OnMapStart ( ) {
    setTeamWeight ( );
}

/* 
On round end check team sizes and make sure 
1 bomb site = T has 1 more player than CT
2 bomb sites = CT has 1 more player than T
3 bomb sites = CT has 1 more player than T
 */    

public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
    //unShieldAllPlayers ( );
}

public void Event_RoundEnd ( Event event, const char[] name, bool dontBroadcast ) {
    int winTeam = GetEventInt(event, "winner");
    //CreateTimer ( 5.5, handleRoundEnd, winTeam );
}

 
public void setTeamWeight ( ) {
    int bombSites = 0;
    int entity = 0;
    while ( ( entity = FindEntityByClassname ( entity, "func_bomb_target" ) ) != INVALID_ENT_REFERENCE ) {
        bombSites++;
    }
    /* IsHostageMap */
    if ( bombSites == 0 ) {
        teamWeight = CS_TEAM_CT;

    /* hasOneBombSite */
    } else if ( bombSites == 1 ) {
        teamWeight = CS_TEAM_T;

    /* hasTwoBombSites */
    } else if ( bombSites == 2 ) {
        teamWeight = CS_TEAM_CT;

    /* hasThreeBombSites+ */
    } else {
        teamWeight = CS_TEAM_CT;
    }
    // log to console
    PrintToConsoleAll ( "OSAutoBalance: Map has %d bomb sites. Map weight: %d", bombSites, teamWeight );


}


