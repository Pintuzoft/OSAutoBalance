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
    EmulateMatchStart ( );
    HookEvent ( "round_start", Event_RoundStart );
    HookEvent ( "round_end", Event_RoundEnd );
    HookEvent ( "player_connect", Event_PlayerConnect );
    HookEvent ( "player_disconnect", Event_PlayerDisconnect );
}


public void OnPluginEnd ( ) {
    databaseDisconnect();
}

public void EmulateMatchStart ( ) {
    setTeamWeight ( );
    resetAllData();
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
    char name[32];
    int t_count = 0;
    float terrorists = 0.0;
    int ct_count = 0;
    float counterterrorists = 0.0;

    PrintToChatAll("[OSAutoBalance]: handleRoundEnd");

//    checkConnection();

    /* print all gathered player information */
    for ( int i=1; i < MAXPLAYERS; i++ ) {
        if ( IsClientConnected ( i ) && ! IsClientSourceTV ( i ) ) {
            /* get player name */
            GetClientName ( i, name, sizeof(name) );
            PrintToConsoleAll("[OSAutoBalance]: %s:%s:%f:%i", name, shortIds[i], databaseKD[i], typeKD[i]);
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

    for ( int i = 1; i <= MAXPLAYERS; i++ ) {
        if ( typeKD[i] == 0 ) {
            GetClientAuthId(i, AuthId_Engine, steamid, sizeof(steamid));
            PrintToConsoleAll("[OSAutoBalance]: 0:%s",steamid);

            if ( playerIsReal ( i ) ) {
                PrintToConsoleAll("[OSAutoBalance]: 1:playerIsReal");
                
                if ( isValidSteamID ( steamid ) ) {
                    PrintToConsoleAll("[OSAutoBalance]: 2:isValidSteamID");
                    strcopy(shortSteamId, sizeof(shortSteamId), steamid[8]);
                    strcopy(steamIds[i], 32, steamid);
                    strcopy(shortIds[i], 32, shortSteamId);
                    PrintToConsoleAll("[OSAutoBalance]: Get KD for player %s", shortIds[i]);
                    databaseGetKD ( i );
                    typeKD[i] = 1;
                } else {
                    
                    PrintToConsoleAll("[OSAutoBalance]: 3:isNotValidSteamID");

                    typeKD[i] = 0;
                    steamIds[i] = "";
                    shortIds[i] = "";
                    PrintToConsoleAll("[OSAutoBalance]: Random KD for player %s", steamid);
                    /* random KD from database */
                    databaseKD[i] = 0.4 + ( GetRandomFloat ( 0.0, 0.6 ) );
                }
                PrintToConsoleAll("[OSAutoBalance]: 4:");
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
            } else {
                PrintToConsoleAll("[OSAutoBalance]: 5:playerIsNotReal");
                typeKD[i] = 2;
                steamIds[i] = "";
                shortIds[i] = "";
                /* random KD from database */
                databaseKD[i] = 0.4 + ( GetRandomFloat ( 0.0, 0.6 ) );
            }
            PrintToConsoleAll("[OSAutoBalance]: 6:done");
        }
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