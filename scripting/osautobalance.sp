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
    calculateAverageKD ( );
    compareTeams ( );
    evenTeams ( );
    return Plugin_Continue;
}

public void evenTeams ( ) {
    float ct_kd_sum = 0.0;
    float t_kd_sum = 0.0;
    int worstPlayer = -1;
    float worstKD = 9999999.0; // Some large value for initial comparison
PrintToConsoleAll("[OSAutoBalance]: 0:");
    // 1. Calculate the total KD for each team & identify the worst player
    for (int i = 1; i < MAXPLAYERS; i++) {
PrintToConsoleAll("[OSAutoBalance]: 1:");
        if ( ! IsClientConnected ( i ) || IsClientSourceTV ( i )) continue;
        
PrintToConsoleAll("[OSAutoBalance]: 2:");
        if (team[i] == CS_TEAM_CT) {
PrintToConsoleAll("[OSAutoBalance]: 3:");
            ct_kd_sum += avgKD[i];
            if (avgKD[i] < worstKD) {
PrintToConsoleAll("[OSAutoBalance]: 4:");
                worstKD = avgKD[i];
                worstPlayer = i;
            }
PrintToConsoleAll("[OSAutoBalance]: 5:");
        } else if (team[i] == CS_TEAM_T) {
PrintToConsoleAll("[OSAutoBalance]: 6:");
            t_kd_sum += avgKD[i];
            if (avgKD[i] < worstKD) {
PrintToConsoleAll("[OSAutoBalance]: 7:");
                worstKD = avgKD[i];
                worstPlayer = i;
            }
PrintToConsoleAll("[OSAutoBalance]: 8:");
        }
PrintToConsoleAll("[OSAutoBalance]: 9:");
    }

    int teamSizeDifference = absoluteValue(ct_count - t_count);
    if (teamSizeDifference <= 1) return;

    int playersToMove = teamSizeDifference / 2;
    float kdDifference = ct_kd_sum/ct_count - t_kd_sum/t_count;
    int largerTeam = (ct_count > t_count) ? CS_TEAM_CT : CS_TEAM_T;
PrintToConsoleAll("[OSAutoBalance]: 10:%.2f:%.2f:%i", ct_kd_sum, t_kd_sum, teamSizeDifference);

    int foundPlayers = 0;
    for (int i = 1; i < MAXPLAYERS && foundPlayers <= playersToMove; i++) {
PrintToConsoleAll("[OSAutoBalance]: 11:%i", playersToMove);
        if ( ! IsClientConnected ( i ) || IsClientSourceTV ( i )) continue;
PrintToConsoleAll("[OSAutoBalance]: 12:");
        if (team[i] != largerTeam) continue;
PrintToConsoleAll("[OSAutoBalance]: 13:");

        if (absoluteValueFloat(kdDifference - avgKD[i]) <= kdDifference/playersToMove) {
PrintToConsoleAll("[OSAutoBalance]: 14:");
            PrintToConsoleAll("Suggest moving (diff) [%i]player %d to balance teams. Team KD Gap: %.2f, Player KD: %.2f", team[i], i, kdDifference, avgKD[i]);
            kdDifference -= avgKD[i];
            foundPlayers++;
PrintToConsoleAll("[OSAutoBalance]: 15:");
        }
PrintToConsoleAll("[OSAutoBalance]: 16:");
    }
PrintToConsoleAll("[OSAutoBalance]: 17:");

    // Fallback: If we didn't find enough players, suggest the worst player
    if (foundPlayers < playersToMove && worstPlayer != -1) {
PrintToConsoleAll("[OSAutoBalance]: 18:");
        PrintToConsoleAll("Fallback: Suggest moving (worst) player %d with KD %.2f to balance teams.", worstPlayer, worstKD);
PrintToConsoleAll("[OSAutoBalance]: 19:");
    }
PrintToConsoleAll("[OSAutoBalance]: 20:");
}
public void calculateAverageKD ( ) {
    t_count = 0;
    ct_count = 0;

    for ( int player = 1; player < MAXPLAYERS; player++ ) {
        if ( IsClientConnected ( player ) && ! IsClientSourceTV ( player ) ) {
            PrintToConsoleAll("Player %s | Initial KDs -> Database: %f, Game: %f", nameKD[player], dbKD[player], gameKD[player]);

            if ( dbKD[player] == -1.0 ) {
                avgKD[player] = (defaultNewKD + gameKD[player]) / 2.0;
                PrintToConsoleAll(" - Average KD (New/Bot): %f", avgKD[player]);

            } else {
                float lowerBound = dbKD[player] - expectedPerformanceRange;
                float upperBound = dbKD[player] + expectedPerformanceRange;
                float histWeight;

                if ( gameKD[player] > upperBound ) {
                    histWeight = strongHistWeight;
                    PrintToConsoleAll(" - Status: Over-Performing");

                } else if ( gameKD[player] < lowerBound ) {
                    histWeight = weakHistWeight;
                    PrintToConsoleAll(" - Status: Under-Performing");
                
                } else {
                    histWeight = normalHistWeight;
                    PrintToConsoleAll(" - Status: Performing as Expected");
                }

                float currWeight = 1.0 - histWeight;
                avgKD[player] = (histWeight * dbKD[player]) + (currWeight * gameKD[player]);

                PrintToConsoleAll(" - Weights -> Historical: %f, Game: %f", histWeight, currWeight);
                PrintToConsoleAll(" - Average KD: %f", avgKD[player]);
            }

            if ( GetClientTeam(player) == CS_TEAM_CT ) {
                ct_count++;
                team[player] = CS_TEAM_CT;
            } else if ( GetClientTeam(player) == CS_TEAM_T ) {
                t_count++;
                team[player] = CS_TEAM_T;
            }
            PrintToConsoleAll("-----------------------------");
        }
    }
}

public void compareTeams ( ) {
    float team1TotalKD = 0.0;
    float team2TotalKD = 0.0;

    int team1Players = 0;
    int team2Players = 0;

    for (int player = 1; player < MAXPLAYERS; player++) {
        if ( ! IsClientConnected(player) ) {
            continue;
        }

        if ( team[player] == CS_TEAM_T ) {
            team1TotalKD += avgKD[player];
            team1Players++;

        } else if ( team[player] == CS_TEAM_CT ) {
            team2TotalKD += avgKD[player];
            team2Players++;
        }
    }

    // Without considering player weight
    float team1AvgWithoutWeight = team1Players ? team1TotalKD / team1Players : 0.0;
    float team2AvgWithoutWeight = team2Players ? team2TotalKD / team2Players : 0.0;

    PrintToConsoleAll("Without Player Weight:");
    PrintToConsoleAll(" - Team 1 Avg KD: %f", team1AvgWithoutWeight);
    PrintToConsoleAll(" - Team 2 Avg KD: %f", team2AvgWithoutWeight);
    PrintToConsoleAll("-----------------------------");

    // With considering player weight
    int totalPlayers = team1Players + team2Players;

    float playerWeightForTeam1 = 1.0 * totalPlayers / (team1Players ? team1Players : 1);
    float playerWeightForTeam2 = 1.0 * totalPlayers / (team2Players ? team2Players : 1);

    float team1AvgWithWeight = team1TotalKD * playerWeightForTeam1 / team1Players;
    float team2AvgWithWeight = team2TotalKD * playerWeightForTeam2 / team2Players;

    PrintToConsoleAll("With Player Weight:");
    PrintToConsoleAll(" - Team 1 Avg KD: %f", team1AvgWithWeight);
    PrintToConsoleAll(" - Team 2 Avg KD: %f", team2AvgWithWeight);
    PrintToConsoleAll("-----------------------------");
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

    for ( int player = 1; player < MAXPLAYERS; player++ ) {
        if (!IsClientConnected(player)) {
            continue;  // Skip to the next player if the current one isn't connected
        }
      
        GetClientName ( player, nameStr, 64 );
        strcopy(nameKD[player], 64, nameStr);

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