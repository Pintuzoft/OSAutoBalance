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

int t_count = 0;
int ct_count = 0;
int bombSites = 0;

/* Name */
char nameKD[MAXPLAYERS+1][64];

/* Player teams */
int team[MAXPLAYERS+1];

/* Player steamids */
char steamIds[MAXPLAYERS+1][32];

/* Player short steamids */
char shortIds[MAXPLAYERS+1][32];

/* KD type 1=db, 0=check */
int typeKD[MAXPLAYERS+1];

float dbKD[MAXPLAYERS + 1];             // Database KD values.
float gameKD[MAXPLAYERS + 1];           // Current KD values from the game.
float avgKD[MAXPLAYERS + 1];            // Averaged KD values.

// Configuration variables
float strongHistWeight = 0.7;           // 70% weight for historical KD.
float weakHistWeight = 0.3;             // 30% weight for historical KD.
float normalHistWeight = 0.5;           // 50% weight for historical KD.
float expectedPerformanceRange = 0.2;   // 20% range around historical KD.
float defaultNewKD = 0.8;               // Default KD for new players.

public Plugin myinfo = {
	name = "OSAutoBalance",
	author = "Pintuz",
	description = "OldSwedes Auto-Balance plugin",
	version = "0.02",
	url = "https://github.com/Pintuzoft/OSAutoBalance"
}
 
public void OnPluginStart ( ) {
    databaseConnect();
    setTeamWeight ( );
    resetAllData();
    HookEvent ( "round_start", Event_RoundStart );
    HookEvent ( "round_end", Event_RoundEnd );
    HookEvent ( "player_connect", Event_PlayerConnect );
    HookEvent ( "player_disconnect", Event_PlayerDisconnect );
}


public void OnPluginEnd ( ) {
    databaseDisconnect();
}

public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
    //    setTeamWeight ( );
    //unShieldAllPlayers ( );

}

public void Event_RoundEnd ( Event event, const char[] name, bool dontBroadcast ) {
    setTeamWeight ( );
    int winTeam = GetEventInt(event, "winner");
    CreateTimer ( 3.0, handleRoundEndFetchData, winTeam );
  //  CreateTimer ( 5.5, handleRoundEnd, winTeam );
}

public void Event_PlayerConnect ( Event event, const char[] name, bool dontBroadcast ) {
    int client = GetEventInt(event, "userid");
    
    resetPlayerData ( client );
    
}

public void Event_PlayerDisconnect ( Event event, const char[] name, bool dontBroadcast ) {
    int client = GetEventInt(event, "userid");
    resetPlayerData ( client );
}

public Action handleRoundEndFetchData ( Handle timer, int winTeam ) {
    checkConnection();
    PrintToChatAll("[OSAutoBalance]: handleRoundEndFetchData");
    /* Gather player data */
    fetchPlayerData ( );

    balanceTeamsSeparated ( );
    return Plugin_Continue;
}



public void balanceTeamsSeparated ( ) {
    // Step 1: Equalize Team Size
    if (absoluteValue(ct_count - t_count) > 1) {
        adjustTeamSizesBasedOnBombsites ( );
        return; // Since team sizes were imbalanced by more than 1, we adjust and exit.
    }

    // Step 2: Balance Based on KD
    // (No need to process this in our current debugging scenario)
}

public void adjustTeamSizesBasedOnBombsites ( ) {
    int desiredCTCount = ct_count, desiredTCount = t_count;
    getDesiredTeamSizes( desiredCTCount, desiredTCount );

    int playersToMove = 0;
    if (ct_count - t_count > 1) {
        // CTs have more than 1 player advantage
        playersToMove = (ct_count - t_count) / 2;
        PrintToConsoleAll("Move %d CT players to T to equalize team size.", playersToMove);
    } else if (t_count - ct_count > 1) {
        // Ts have more than 1 player advantage
        playersToMove = (t_count - ct_count) / 2;
        PrintToConsoleAll("Move %d T players to CT to equalize team size.", playersToMove);
    }
}

public void getDesiredTeamSizes(int &desiredCTCount, int &desiredTCount) {
    int totalPlayers = desiredCTCount + desiredTCount;

    if (totalPlayers % 2 == 0) {  // Even number of players
        desiredCTCount = totalPlayers / 2;
        desiredTCount = totalPlayers / 2;

    } else {  // Odd number of players
        if (bombSites == 0) {  
            // Hostage map, so give CT the advantage
            desiredCTCount = (totalPlayers / 2) + 1;
            desiredTCount = totalPlayers / 2;

        } else if (bombSites == 1) {  
            // Only 1 bombsite, so give T the advantage
            desiredCTCount = totalPlayers / 2;
            desiredTCount = (totalPlayers / 2) + 1;

        } else if (bombSites == 2) {  
            // 2 bombsites, so give CT the advantage
            desiredCTCount = (totalPlayers / 2) + 1;
            desiredTCount = totalPlayers / 2;

        } else {  
            // For unforeseen cases, just balance them evenly
            desiredCTCount = totalPlayers / 2;
            desiredTCount = totalPlayers / 2;
        }
    }
}


public void resetAllData ( ) {
    for ( int i = 1; i < MAXPLAYERS; i++ ) {
        resetPlayerData ( i );
    }
}


public void resetPlayerData ( int client ) {
    nameKD[client] = "";
    team[client] = 0;
    steamIds[client] = "";
    shortIds[client] = "";
    dbKD[client] = 0.0;
    gameKD[client] = 0.0;
    typeKD[client] = 0;
}

/* fetch player data */
public void fetchPlayerData ( ) {
    char nameStr[64];
    char steamid[32];
    char shortSteamId[32];
    t_count = 0;
    ct_count = 0;
    for ( int player = 1; player < MAXPLAYERS; player++ ) {
        if (!IsClientConnected(player)) {
            continue;  // Skip to the next player if the current one isn't connected
        }
      
        GetClientName ( player, nameStr, 64 );
        strcopy(nameKD[player], 64, nameStr);
        int teamId = GetClientTeam ( player );
        team[player] = teamId;
        if ( teamId == 2 ) {
            t_count++;
        } else if ( teamId == 3 ) {
            ct_count++;
        }
        // Set DbKD
        if ( typeKD[player] == 0 ) {
            GetClientAuthId(player, AuthId_Steam2, steamid, sizeof(steamid));
            strcopy(shortSteamId, sizeof(shortSteamId), steamid[8]);
            strcopy(steamIds[player], 32, steamid);
            strcopy(shortIds[player], 32, shortSteamId);
            databaseGetKD ( player );
            if ( isValidSteamID ( steamid ) ) {
                typeKD[player] = 1;
            }
        }

        // Set GameKD
        int frags = GetClientFrags ( player );
        int deaths = GetClientDeaths ( player );
        if ( deaths == 0 ) {
            gameKD[player] = 1.0 * frags;
        } else {
            gameKD[player] = 1.0 * frags / deaths;
        }

        PrintToConsoleAll("[OSAutoBalance]: 24:%i:done:%s", player, nameKD[player]);
        PrintToConsoleAll("[OSAutoBalance]:   - dbKD: %0.2f", dbKD[player]);
        PrintToConsoleAll("[OSAutoBalance]:   - gameKD: %0.2f", gameKD[player]);
        PrintToConsoleAll("[OSAutoBalance]:   - typeKD: %i", typeKD[player]);
    }

}

public void databaseGetKD ( int player ) {
    checkConnection();
    DBStatement stmt;

    if ( ( stmt = SQL_PrepareQuery ( mysql, "SELECT kd FROM player WHERE steamid = ?", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToConsoleAll("[databaseGetKD]: Failed to prepare query[0x01] (error: %s)", error);
        dbKD[player] = -1.0;
        return;
    }

    SQL_BindParamString ( stmt, 0, shortIds[player], false );
    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToConsoleAll("[databaseGetKD]: Failed to query[0x02] (error: %s)", error);
        dbKD[player] = -1.0;
        return;
    }

    if ( SQL_FetchRow ( stmt ) ) {
        dbKD[player] = SQL_FetchFloat ( stmt, 0 );
    } else {
        dbKD[player] = -1.0;

    }

    if ( stmt != null ) {
        delete stmt;
    }
}


public void setTeamWeight ( ) {
    int entity = 0;
    bombSites = 0;
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
//    PrintToConsoleAll ( "OSAutoBalance: Map has %d bomb sites. Map weight: %d", bombSites, weight );


}

public void databaseConnect() {
    if ((mysql = SQL_Connect("osautobalance", true, error, sizeof(error))) != null) {
        PrintToServer("[OSAutoBalance]: Connected to mysql database!");
    } else {
        PrintToServer("[OSAutoBalance]: Failed to connect to mysql database! (error: %s)", error);
    }
}

public void databaseDisconnect() {
    if (mysql != null) {
        delete mysql;
        mysql = null;
    }
}

public void checkConnection() {
    if (mysql == null || mysql == INVALID_HANDLE) {
        databaseConnect();
    }
}

public bool playerIsReal ( int player ) {
    return ( player > 0 && 
             player < MAXPLAYERS &&
             IsClientInGame ( player ) &&
             ! IsFakeClient ( player ) &&
             ! IsClientSourceTV ( player ) );
}
public bool isValidSteamID ( char authid[32] ) {
    if ( stringContains ( authid, "STEAM_0" ) ) {
        return true;
    } else if ( stringContains ( authid, "STEAM_1" ) ) {
        return true;
    }
    return false;
}
public bool stringContains ( char string[32], char match[32] ) {
    return ( StrContains ( string, match, false ) != -1 );
}
int absoluteValue(int number) {
    if (number < 0) {
        return -number;
    }
    return number;
}
float absoluteValueFloat(float number) {
    if (number < 0) {
        return -number;
    }
    return number;
}