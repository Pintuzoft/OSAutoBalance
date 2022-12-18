#include <sourcemod>
#include <sdktools>
#include <cstrike>

static const int WINNER = 0;
static const int WINS = 1;
static const int STREAK = 2;
static const int KILLS = 3;
static const int SIZE = 4;
static const int FIRST = 5;
static const int SECOND = 6;
static const int LAST = 7;

static const int NUMTEAMVALUES = 8;
int team[4][8];

ConVar cvar_BalanceAfterStreak;

public Plugin myinfo = {
	name = "OSAutoBalance",
	author = "Pintuz",
	description = "OldSwedes Auto-Balance plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSAutoBalance"
}
 
public void OnPluginStart ( ) {
    cvar_BalanceAfterStreak = CreateConVar ( "os_balanceafterstreak", "3", "Balance teams after X streak", _, true, 1.0 );
    HookEvent ( "round_start", Event_RoundStart );
    HookEvent ( "round_end", Event_RoundEnd );
    HookEvent ( "announce_phase_end", Event_HalfTime );
    AutoExecConfig ( true, "osautobalance" );
}
 

/*** EVENTS ***/
public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
    unShieldAllPlayers ( );
}
public void Event_RoundEnd ( Event event, const char[] name, bool dontBroadcast ) {
    int winTeam = GetEventInt(event, "winner");
    int loserTeam = getOtherTeam ( winTeam );

    /* GATHER DATA */
    gatherTeamsData ( winTeam, loserTeam );
    
    /* BALANCE */
    if ( shouldBalance ( winTeam, loserTeam ) ) {
        shieldAllPlayers ( );
        swapPlayersOnStreak ( );
        team[winTeam][STREAK] = 0;
        
    } else if ( moreTerrorists ( ) ) {
        shieldAllPlayers ( );
        if ( team[CS_TEAM_T][LAST] > 0 ) {
            swapPlayer ( team[CS_TEAM_T][LAST] );
        } else {
            moveRandomTerrorist (  );
        }
    }
}
public void Event_HalfTime ( Event event, const char[] name, bool dontBroadcast ) {
    int buf;
    for ( int val = 0; val < NUMTEAMVALUES; val++ ) {
        buf = team[CS_TEAM_T][val];
        team[CS_TEAM_T][val] = team[CS_TEAM_CT][val];
        team[CS_TEAM_CT][val] = buf;
    }
}

/*** METHODS ***/

public void moveRandomTerrorist ( ) {
    int random = GetRandomInt ( 0, team[CS_TEAM_T][SIZE] );
    for ( int player = 1; player <= MaxClients; player++ ) {
        if ( playerIsReal ( player ) && GetClientTeam(player) == CS_TEAM_T ) {
            --random;
            if ( random < 1 ) {
                swapPlayer ( player );
                return;
            }
        }
    }
}

public void swapPlayer ( int player ) {
    char name[65];
    char teamName[24];
    int otherTeam;
    GetClientName ( player, name, 64 );
    otherTeam = getOtherTeam ( GetClientTeam(player) );
    teamName = (otherTeam == 2 ? "Terrorists" : "Counter-Terrorists");

    shieldPlayer ( player );
    if ( ! IsPlayerAlive ( player ) ) {
        ChangeClientTeam ( player, otherTeam );
    } else {
        CS_SwitchTeam ( player, otherTeam );
        CS_UpdateClientModel ( player );
    }

    PrintToChatAll ( " \x02[OSAutoBalance]: \x07%s swapped to %s!", name, teamName );
}

/* unshield all players */
public void unShieldAllPlayers ( ) {
    for ( int player = 1; player <= MaxClients; player++ ) {
        if ( IsClientInGame ( player ) && IsPlayerAlive ( player ) && ! IsClientSourceTV ( player ) ) {
            unShieldPlayer ( player );
        }
    }
}
 /* unshield all players */
public void shieldAllPlayers ( ) {
    for ( int player = 1; player <= MaxClients; player++ ) {
        if ( IsClientInGame ( player ) && IsPlayerAlive ( player ) && ! IsClientSourceTV ( player ) ) {
            shieldPlayer ( player );
        }
    }
}
 
/* shield off */
public void shieldPlayer ( int player ) {
    if ( IsClientInGame ( player ) && ! IsClientSourceTV ( player ) ) {
        /* Shield here */ 
        SetEntityRenderColor(player, 0, 0, 255, 100);
        SetEntProp(player, Prop_Data, "m_takedamage", 0, 1);
    }
}

/* shield off */
public void unShieldPlayer ( int player ) {
    if ( IsClientInGame ( player ) && ! IsClientSourceTV ( player ) ) {
        /* unshield here */
        SetEntProp(player, Prop_Data, "m_takedamage", 2, 1);
        SetEntityRenderColor(player, 255, 255, 255, 255);
    }
}

/* return true if we should balance the teams */
public bool shouldBalance ( winTeam, loserTeam ) {
    PrintToConsoleAll ( "=============================" );
    PrintToConsoleAll ( "0:" );

    if ( GetClientCount(true) >= 6 ) {
    PrintToConsoleAll ( "1:" );
        if ( team[winTeam][STREAK] >= cvar_BalanceAfterStreak.IntValue ) {
    PrintToConsoleAll ( "2:" );
            /* we hit a streak */
            if ( (team[loserTeam][KILLS] * 2) < team[winTeam][KILLS] ) {
    PrintToConsoleAll ( "3:" );
                PrintToConsoleAll ( "shouldBalance:true -> %d / %d >= 2", team[winTeam][KILLS], team[loserTeam][KILLS] );
                return true;
            } else {
    PrintToConsoleAll ( "4:" );
                PrintToConsoleAll ( "shouldBalance:false -> %d / %d < 2", team[winTeam][KILLS], team[loserTeam][KILLS] );
            }
    PrintToConsoleAll ( "5:" );
            
        }  
    PrintToConsoleAll ( "6:" );
    }
    PrintToConsoleAll ( "7:" );
    return false;
}

/* swap players when we hit a streak */
public void swapPlayersOnStreak ( ) {
    /* TERRORISTS IS MORE */
    if ( moreTerrorists ( ) ) {
        swapPlayer ( team[CS_TEAM_T][LAST] );
        
    /* COUNTER-TERRORISTS IS SAME OR MORE */
    } else {
        if ( terroristsWon ( ) ) {
            swapPlayer ( team[CS_TEAM_T][SECOND] );
            swapPlayer ( team[CS_TEAM_CT][LAST] );
        } else {
            swapPlayer ( team[CS_TEAM_CT][SECOND] );
            swapPlayer ( team[CS_TEAM_T][LAST] );
        }
    }
}

/* return true if terrorists won the round */
public bool terroristsWon ( ) {
    return ( team[CS_TEAM_T][WINNER] == 1 );
}

/* return true if there is more terrorists than counter-terrorists*/
public bool moreTerrorists ( ) {
    return ( team[CS_TEAM_T][SIZE] > team[CS_TEAM_CT][SIZE] );
}

/* returns the id of the other team */
public int getOtherTeam ( int winTeam ) {
    return ( winTeam == 2 ? 3 : 2 );
}
public void gatherTeamsData ( int winTeam, loserTeam ) {
    resetTeams ( );
    setWinsAndStreak ( winTeam );
      
    team[CS_TEAM_T][SIZE] = GetTeamClientCount ( CS_TEAM_T );
    team[CS_TEAM_CT][SIZE] = GetTeamClientCount ( CS_TEAM_CT );

    getTeamPlayerStats ( );

    team[CS_TEAM_T][FIRST] = getBestPlayerInTeam ( CS_TEAM_T, 0 );
    team[CS_TEAM_CT][FIRST] = getBestPlayerInTeam ( CS_TEAM_CT, 0 );
    team[CS_TEAM_T][SECOND] = getBestPlayerInTeam ( CS_TEAM_T, team[CS_TEAM_T][FIRST] );
    team[CS_TEAM_CT][SECOND] = getBestPlayerInTeam ( CS_TEAM_CT, team[CS_TEAM_CT][FIRST] );
    team[CS_TEAM_T][LAST] = getWorstPlayerInTeam ( CS_TEAM_T, 0 );
    team[CS_TEAM_CT][LAST] = getWorstPlayerInTeam ( CS_TEAM_CT, 0 );
}

/* get player stats */
public void getTeamPlayerStats ( ) {
    int pTeam;
    for ( int player = 1; player <= MaxClients; player++ ) {
        if ( playerIsReal ( player ) ) {
            pTeam = GetClientTeam ( player );
            team[pTeam][KILLS] += GetClientFrags ( player );
        }
    }
}

/* get best player */
public int getBestPlayerInTeam ( int inTeam, int exclude ) {
    int found = -1;
    for ( int player = 1; player <= MaxClients; player++ ) {
        if ( playerIsReal ( player ) && 
             player != exclude && 
             GetClientTeam ( player ) == inTeam ) {
            if ( found < 0 ) {
                /* we found the best one so far */
                found = player;
            } else if ( playerIsBetter ( found, player ) ) {
                /* we found one better */
                found = player;
            }
        }
    }
    return found;
}

/* get worst player */
public int getWorstPlayerInTeam ( int inTeam, int exclude ) {
    int found = -1;
    for ( int player = 1; player <= MaxClients; player++ ) {
        if ( playerIsReal ( player ) && 
             player != exclude && 
             GetClientTeam ( player ) == inTeam ) {
            if ( found < 0 ) {
                /* we found the worst one so far */
                found = player;
            } else if ( ! playerIsBetter ( found, player ) ) {
                /* we found one better */
                found = player;
            }
        }
    }
    return found;
}

public bool playerIsBetter ( int p1, int p2 ) {
    int score1 = CS_GetClientContributionScore ( p1 );
    int score2 = CS_GetClientContributionScore ( p2 );
    int frags1 = GetClientFrags ( p1 );
    int frags2 = GetClientFrags ( p2 );
    int assists1 = CS_GetClientAssists ( p1 );
    int assists2 = CS_GetClientAssists ( p2 );
    int deaths1 = GetClientDeaths ( p1 );
    int deaths2 = GetClientDeaths ( p2 );
    
    /* CHEAK SCORE */
    if ( score2 > score1 ) {
        return true;
    } else if ( score1 > score2 ) {
        return false;
    } 
    
    /* CHECK FRAGS */
    if ( frags2 > frags1 ) {
        return true;
    } else if ( frags1 > frags2 ) {
        return false;
    } 
    
    /* CHECK DEATHS */
    if ( deaths2 < deaths1 ) {
        return true;
    } else if ( deaths1 < deaths2 ) {
        return false;
    } 
    
    /* CHECK ASSISTS */
    if ( assists2 > assists1 ) {
        return true;
    } else if ( assists1 > assists2 ) {
        return false;
    } 
    
    /* everything is the same so we return false */
    return false;
}
 
/* return true if players team won the round */
public bool playerWon ( int player ) {
    return (team[GetClientTeam(player)][WINNER] == 1);
}

/* make sure wins and streak count is correct */
public void setWinsAndStreak ( int winTeam ) {
    int loserTeam = getOtherTeam ( winTeam );
    team[winTeam][WINS]++;
    team[winTeam][WINNER] = 1;
    team[winTeam][STREAK]++;
    team[loserTeam][STREAK] = 0;
}

/* reset the round team data */
public void resetTeams ( ) {
    team[CS_TEAM_T][WINNER] = 0;
    team[CS_TEAM_T][KILLS] = 0;
    team[CS_TEAM_T][SIZE] = 0;
    team[CS_TEAM_T][FIRST] = -1;
    team[CS_TEAM_T][SECOND] = -1;
    team[CS_TEAM_T][LAST] = -1;
    team[CS_TEAM_CT][WINNER] = 0;
    team[CS_TEAM_CT][KILLS] = 0;
    team[CS_TEAM_CT][SIZE] = 0;
    team[CS_TEAM_CT][FIRST] = -1;
    team[CS_TEAM_CT][SECOND] = -1;
    team[CS_TEAM_CT][LAST] = -1;
}


/* return true if player is real */
public bool playerIsReal ( int player ) {
    return ( IsClientInGame ( player ) &&
             !IsClientSourceTV ( player ) );
}

/* reset all we know about the teams */
public void zerofy ( ) {
    team[CS_TEAM_T][WINNER] = 0;
    team[CS_TEAM_T][WINS] = 0;
    team[CS_TEAM_T][STREAK] = 0;
    team[CS_TEAM_T][KILLS] = 0;
    team[CS_TEAM_T][SIZE] = 0;
    team[CS_TEAM_CT][WINNER] = 0;
    team[CS_TEAM_CT][WINS] = 0;
    team[CS_TEAM_CT][STREAK] = 0;
    team[CS_TEAM_CT][KILLS] = 0;
    team[CS_TEAM_CT][SIZE] = 0;
}
  