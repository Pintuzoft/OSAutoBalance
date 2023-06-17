#include <sourcemod>
#include <sdktools>
#include <cstrike>

/*
Plugin to connect to hlstatsx and get the player kd ratio and use it to balance the teams
plugin will also make sure that the teams are balanced both in number of players and in skill level / kd ratio 
if odd number of players the plugin will check how many bomb sites the map has and if it has 2 bomb sites it will make sure that CT has 1 more player than T
if the map has only 1 bomb site it will make sure that T has 1 more player than CT

*/

char error[255];
Handle mysql = null;

int teamWeight = CS_TEAM_CT;
int ctSize = 0;
int tSize = 0;
float ctKD = 0.0;
float tKD = 0.0;
int players[MAXPLAYERS+1];
char ctSteamids[512];
char tSteamids[512];

float teamCT_kd = 0.0;
float teamT_kd = 0.0;



public Plugin myinfo = {
	name = "OSAutoBalance",
	author = "Pintuz",
	description = "OldSwedes Auto-Balance plugin",
	version = "0.02",
	url = "https://github.com/Pintuzoft/OSAutoBalance"
}
 
public void OnPluginStart ( ) {
    HookEvent ( "round_start", Event_RoundStart );
    HookEvent ( "round_end", Event_RoundEnd );
    //HookEvent ( "announce_phase_end", Event_HalfTime );
}

/* 
On round end check team sizes and make sure 
1 bomb site = T has 1 more player than CT
2 bomb sites = CT has 1 more player than T
3 bomb sites = CT has 1 more player than T
 */    

public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
//    setTeamWeight ( );
    //unShieldAllPlayers ( );
}

public void Event_RoundEnd ( Event event, const char[] name, bool dontBroadcast ) {
    setTeamWeight ( );
    int winTeam = GetEventInt(event, "winner");
    CreateTimer ( 5.5, handleRoundEnd, winTeam );
}

public Action handleRoundEnd ( Handle timer, int winTeam ) {

    checkConnection();

    /* Gather team data */
    fetchTeamData ( );

    /* Gather team kd from database */
    int teamCT_kd_db = 0;
    int teamT_kd_db = 0;


    PrintToConsoleAll ( "OSAutoBalance: Team CT size: %d, Team T size: %d", ctSize, tSize );
    PrintToConsoleAll ( "OSAutoBalance: Team CT kd: %d, Team T kd: %d", teamCT_kd, teamT_kd );

    PrintToConsoleAll ( "OSAutoBalance: CT Steamids: ", ctSteamids );
    PrintToConsoleAll ( "OSAutoBalance: T Steamids: ", tSteamids );

    return Plugin_Continue;

}

public bool IsValidPlayer ( int client ) {
    if ( client < 1 || client > MAXPLAYERS ) {
        return false;
    }
    if ( !IsClientInGame ( client ) ) {
        return false;
    }
    if ( !IsClientConnected ( client ) ) {
        return false;
    }
    if ( IsFakeClient ( client ) ) {
        return false;
    }
    return true;
}

public void fetchTeamData ( ) {
    ctSize = 0;
    ctKD = 0.0;
    tSize = 0;
    tKD = 0.0;
    ctSteamids[0] = '\0';
    char tmpSteamid[32];
    for ( int i = 0; i < MAXPLAYERS; i++ ) {
        if ( IsValidPlayer(i) ) {
            int team = GetClientTeam ( i );
            GetClientAuthId(i, AuthId_Steam2, tmpSteamid, sizeof(tmpSteamid));
            PrintToConsoleAll ( "OSAutoBalance: Steamid: %s", tmpSteamid );
            if ( team == CS_TEAM_CT ) {
                ctSize++;
                ctKD += GetClientKDRatio ( i );
                if (ctSteamids[0] != '\0') {
                    StrCat(ctSteamids, sizeof(ctSteamids), ",");
                }
                StrCat(ctSteamids, sizeof(ctSteamids), tmpSteamid);
            } else if ( team == CS_TEAM_T ) {
                tSize++;
                tKD += GetClientKDRatio ( i );
                if (tSteamids[0] != '\0') {
                    StrCat(tSteamids, sizeof(tSteamids), ",");
                }
                StrCat(tSteamids, sizeof(tSteamids), tmpSteamid);
            }
        } else {
            players[i] = 0;
        }
    }
}

public float GetClientKDRatio ( int client ) {
    int kills = GetClientFrags ( client );
    int deaths = GetClientDeaths ( client );
    if ( deaths == 0 ) {
        return kills;
    }
    return kills / deaths;
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

public void databaseConnect() {
    if ((mysql = SQL_Connect("hlxce", true, error, sizeof(error))) != null) {
        PrintToServer("[OSAutoBalance]: Connected to mysql database!");
    } else {
        PrintToServer("[OSAutoBalance]: Failed to connect to mysql database! (error: %s)", error);
    }
}

public void checkConnection() {
    if (mysql == null || mysql == INVALID_HANDLE) {
        databaseConnect();
    }
}

