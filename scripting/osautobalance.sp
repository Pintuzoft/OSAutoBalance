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

int weight = CS_TEAM_CT;
int ctSize = 0;
int tSize = 0;
float ctKD = 0.0;
float tKD = 0.0;

/* KD from database */
float databaseKD[MAXPLAYERS+1];

/* KD from game */
float gameKD[MAXPLAYERS+1];

/* Player steamids */
char steamIds[MAXPLAYERS+1][32];

/* Player short steamids */
char shortIds[MAXPLAYERS+1][32];





public Plugin myinfo = {
	name = "OSAutoBalance",
	author = "Pintuz",
	description = "OldSwedes Auto-Balance plugin",
	version = "0.02",
	url = "https://github.com/Pintuzoft/OSAutoBalance"
}
 
public void OnPluginStart ( ) {
    databaseConnect();
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

    /* Gather player data */
    fetchPlayerData ( );



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

public void resetData ( ) {
    for ( int i = 0; i < MAXPLAYERS; i++ ) {
        steamIds[i] = "";
        shortIds[i] = "";
        databaseKD[i] = 0.0;
        gameKD[i] = 0.0;
    }
}

/* fetch player data */
public void fetchPlayerData ( ) {
    char steamid[32];
    char shortSteamId[32];

    resetData ( );

    for ( int i = 0; i < MAXPLAYERS; i++ ) {
     //   if ( IsValidPlayer(i) ) {
            GetClientAuthId(i, AuthId_Engine, steamid, sizeof(steamid));
            strcopy(shortSteamId, sizeof(shortSteamId), steamid[8]);
            strcopy(steamIds[i], 32, steamid);
            strcopy(shortIds[i], 32, shortSteamId);
            databaseGetKD ( i );
            PrintToChatAll ( "OSAutoBalance: Steamid: %s", shortIds[i] );
            PrintToChatAll ( "OSAutoBalance: databaseKD: %f", databaseKD[i] );

            /* get player kills */
            int frags = GetClientFrags ( i );

            /* get player deaths */
            int deaths = GetClientDeaths ( i );

            /* calculate kd */
            if ( deaths == 0 ) {
                gameKD[i] = 0.0 + frags;
            } else {
                gameKD[i] = 0.0 + ( frags / deaths );
            }
            PrintToChatAll ( "OSAutoBalance: gameKD: %f", gameKD[i] );
    //    } else {
    //        steamIds[i] = "";
    //        shortIds[i] = "";
    //    }
    }
}

public void databaseGetKD ( int player ) {
    checkConnection();
    DBStatement stmt;
    PrintToConsoleAll("[OSAutoBalance]: 0");

    PrintToChatAll("[OSAutoBalance]: Fetching KD for player %s", shortIds[player]);

    PrintToConsoleAll("[OSAutoBalance]: 1");

    if ( ( stmt = SQL_PrepareQuery ( mysql, "SELECT kd FROM player WHERE steamid = ?", error, sizeof(error) ) ) == null ) {

        PrintToConsoleAll("[OSAutoBalance]: 2");
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToServer("[OSAutoBalance]: Failed to prepare query[0x01] (error: %s)", error);
        databaseKD[player] = 0.4;
        return;
    }

    SQL_BindParamString ( stmt, 0, shortIds[player], false );
    if ( ! SQL_Execute ( stmt ) ) {

        PrintToConsoleAll("[OSAutoBalance]: 3");
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToServer("[OSAutoBalance]: Failed to query[0x02] (error: %s)", error);
        databaseKD[player] = 0.4;
        return;
    }

    if ( SQL_FetchRow ( stmt ) ) {
        PrintToConsoleAll("[OSAutoBalance]: 4");
        databaseKD[player] = SQL_FetchFloat ( stmt, 0 );
    } else {
        PrintToConsoleAll("[OSAutoBalance]: 5");
        databaseKD[player] = 0.4;

    }


    if ( stmt != null ) {
        delete stmt;
    }
}



 


public void setTeamWeight ( ) {
    int bombSites = 0;
    int entity = 0;
    while ( ( entity = FindEntityByClassname ( entity, "func_bomb_target" ) ) != INVALID_ENT_REFERENCE ) {
        bombSites++;
    }
    /* IsHostageMap */
    if ( bombSites == 0 ) {
        weight = CS_TEAM_CT;

    /* hasOneBombSite */
    } else if ( bombSites == 1 ) {
        weight = CS_TEAM_T;

    /* hasTwoBombSites */
    } else if ( bombSites == 2 ) {
        weight = CS_TEAM_CT;

    /* hasThreeBombSites+ */
    } else {
        weight = CS_TEAM_CT;
    }
    // log to console
    PrintToConsoleAll ( "OSAutoBalance: Map has %d bomb sites. Map weight: %d", bombSites, weight );


}

public void databaseConnect() {
    if ((mysql = SQL_Connect("osautobalance", true, error, sizeof(error))) != null) {
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

