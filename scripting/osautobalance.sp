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

/* Name */
char nameKD[MAXPLAYERS+1][64];

/* KD from database */
float databaseKD[MAXPLAYERS+1];

/* KD from game */
float gameKD[MAXPLAYERS+1];

/* Player steamids */
char steamIds[MAXPLAYERS+1][32];

/* Player short steamids */
char shortIds[MAXPLAYERS+1][32];

/* KD type 1=db, 2=autogen */
int typeKD[MAXPLAYERS+1];


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
    CreateTimer ( 5.5, handleRoundEnd, winTeam );
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
    return Plugin_Continue;
}

public Action handleRoundEnd ( Handle timer, int winTeam ) {
    char nameStr[64];
    int t_count = 0;
    float terrorists = 0.0;
    int ct_count = 0;
    float counterterrorists = 0.0;

    PrintToChatAll("[OSAutoBalance]: handleRoundEnd");

//    checkConnection();

    /* print all gathered player information */
    for ( int i=1; i <= MAXPLAYERS; i++ ) {
        if ( IsClientConnected ( i ) && ! IsClientSourceTV ( i ) ) {
            /* get player name */
            GetClientName ( i, nameStr, 64 );
            strcopy(nameKD[i], 64, nameStr);
            PrintToConsoleAll("[OSAutoBalance]: %s:%s:%f:%i", nameKD[i], shortIds[i], databaseKD[i], typeKD[i]);
            if ( GetClientTeam(i) == CS_TEAM_CT ) {
                ct_count++;
                counterterrorists = counterterrorists + ((databaseKD[i]+gameKD[i])/2);
                PrintToChatAll ( " - CT-value: %0.2f", counterterrorists);
            } else if ( GetClientTeam(i) == CS_TEAM_T ) {
                t_count++;
                terrorists = terrorists + ((databaseKD[i]+gameKD[i])/2);
                PrintToChatAll ( " - T-value: %0.2f", terrorists);
            }
        }
    }


    return Plugin_Continue;

}




public void resetAllData ( ) {
    for ( int i = 1; i <= MAXPLAYERS; i++ ) {
        resetPlayerData ( i );
    }
}


public void resetPlayerData ( int client ) {
    nameKD[client] = "";
    steamIds[client] = "";
    shortIds[client] = "";
    databaseKD[client] = 0.0;
    gameKD[client] = 0.0;
    typeKD[client] = 0;
}

/* fetch player data */
public void fetchPlayerData ( ) {
    char steamid[32];
    char shortSteamId[32];
    PrintToConsoleAll("[OSAutoBalance]: 0:" );

    for ( int player = 1; player <= MAXPLAYERS; player++ ) {
        PrintToConsoleAll("[OSAutoBalance]: 1:%i:", player );
        if (!IsClientConnected(player)) {
            continue;  // Skip to the next player if the current one isn't connected
        }
        if ( IsFakeClient ( player ) ) {
    PrintToConsoleAll("[OSAutoBalance]: 2:" );
            /* BOT */
            if ( gameKD[player] == 0.0 ) {
    PrintToConsoleAll("[OSAutoBalance]: 3:" );
                gameKD[player] = 0.4 + ( GetRandomFloat ( 0.0, 0.6 ) );
            }
    PrintToConsoleAll("[OSAutoBalance]: 4:" );
        } else {
    PrintToConsoleAll("[OSAutoBalance]: 5:" );
            /* HUMAN */
            if ( typeKD[player] == 0 ) {
    PrintToConsoleAll("[OSAutoBalance]: 6:" );
                GetClientAuthId(player, AuthId_Steam2, steamid, sizeof(steamid));
    PrintToConsoleAll("[OSAutoBalance]: 7:" );
                if ( isValidSteamID ( steamid ) ) {
    PrintToConsoleAll("[OSAutoBalance]: 8:" );
                    strcopy(shortSteamId, sizeof(shortSteamId), steamid[8]);
    PrintToConsoleAll("[OSAutoBalance]: 9:" );
                    strcopy(steamIds[player], 32, steamid);
    PrintToConsoleAll("[OSAutoBalance]: 10:" );
                    strcopy(shortIds[player], 32, shortSteamId);
    PrintToConsoleAll("[OSAutoBalance]: 11:" );
                    databaseGetKD ( player );
    PrintToConsoleAll("[OSAutoBalance]: 12:" );
                    typeKD[player] = 1;
    PrintToConsoleAll("[OSAutoBalance]: 13:" );
                } else {
    PrintToConsoleAll("[OSAutoBalance]: 14:" );
                    gameKD[player] = 0.6;
    PrintToConsoleAll("[OSAutoBalance]: 15:" );
                }
    PrintToConsoleAll("[OSAutoBalance]: 16:" );
            }
    PrintToConsoleAll("[OSAutoBalance]: 17:" );

        }

    PrintToConsoleAll("[OSAutoBalance]: 18:" );
        int frags = GetClientFrags ( player );
    PrintToConsoleAll("[OSAutoBalance]: 19:" );
        int deaths = GetClientDeaths ( player );
    PrintToConsoleAll("[OSAutoBalance]: 20:" );
        if ( deaths == 0 ) {
    PrintToConsoleAll("[OSAutoBalance]: 21:" );
            gameKD[player] = 0.0 + frags;
        } else {
    PrintToConsoleAll("[OSAutoBalance]: 22:" );
            gameKD[player] = 0.0 + ( frags / deaths );
        }
    PrintToConsoleAll("[OSAutoBalance]: 23:" );

        PrintToConsoleAll("[OSAutoBalance]: 24:%i:done:%s", player, nameKD[player]);
        PrintToConsoleAll("[OSAutoBalance]:   - databaseKD: %0.2f", databaseKD[player]);
        PrintToConsoleAll("[OSAutoBalance]:   - gameKD: %0.2f", gameKD[player]);
        PrintToConsoleAll("[OSAutoBalance]:   - typeKD: %i", typeKD[player]);
    }

}

public void databaseGetKD ( int player ) {
    PrintToConsoleAll("[databaseGetKD]: 0");

    checkConnection();
    PrintToConsoleAll("[databaseGetKD]: 1");
    DBStatement stmt;
    PrintToConsoleAll("[databaseGetKD]: 2");

    PrintToConsoleAll("[databaseGetKD]: 3:Fetching KD for player %s", shortIds[player]);

    PrintToConsoleAll("[databaseGetKD]: 4");

    if ( ( stmt = SQL_PrepareQuery ( mysql, "SELECT kd FROM player WHERE steamid = ?", error, sizeof(error) ) ) == null ) {
        PrintToConsoleAll("[databaseGetKD]: 5");
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToConsoleAll("[databaseGetKD]: 6:Failed to prepare query[0x01] (error: %s)", error);
        databaseKD[player] = 0.4;
        return;
    }

    SQL_BindParamString ( stmt, 0, shortIds[player], false );
    if ( ! SQL_Execute ( stmt ) ) {

        PrintToConsoleAll("[databaseGetKD]: 7");
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToConsoleAll("[databaseGetKD]: 8:Failed to query[0x02] (error: %s)", error);
        databaseKD[player] = 0.4;
        return;
    }

    if ( SQL_FetchRow ( stmt ) ) {
        PrintToConsoleAll("[databaseGetKD]: 9");
        databaseKD[player] = SQL_FetchFloat ( stmt, 0 );
    } else {
        PrintToConsoleAll("[databaseGetKD]: 10");
        databaseKD[player] = 0.4;

    }
    PrintToConsoleAll("[databaseGetKD]: 11");

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