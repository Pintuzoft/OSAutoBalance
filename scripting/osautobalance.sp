#include <sourcemod>
#include <sdktools>
#include <cstrike>

static const int WINNER = 0;
static const int WINS = 1;
static const int STREAK = 2;
static const int KILLS = 3;
static const int SIZE = 4;
static const int BEST = 5;
static const int SECOND = 6;
static const int WORST = 7;

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
    RegConsoleCmd ( "sm_printinfo", Command_PrintInfo, "Print known information"  );
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
    if ( IsWarmupActive ( ) ) {
        zerofy ( );
        return;
    }
    int winTeam = GetEventInt(event, "winner");
    int loserTeam = getOtherTeam ( winTeam );

    /* GATHER DATA */
    gatherTeamsData ( winTeam, loserTeam );
    
    /* BALANCE */
    if ( shouldBalance ( winTeam, loserTeam ) ) {
        swapPlayersOnStreak ( winTeam, loserTeam );
        
    } else if ( moreTerrorists ( ) ) {
        swapPlayer ( team[CS_TEAM_T][WORST] );
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

/*** COMMANDS ***/
public Action Command_PrintInfo ( int client, int args ) {
    char name[64];
    PrintToChat ( client, "*** Counter-Terrorists ***" );
    PrintToChat ( client, "  Winner: %d", team[CS_TEAM_CT][WINNER] );
    PrintToChat ( client, "    Wins: %d", team[CS_TEAM_CT][WINS] );
    PrintToChat ( client, "  Streak: %d", team[CS_TEAM_CT][STREAK] );
    PrintToChat ( client, "   Kills: %d", team[CS_TEAM_CT][KILLS] );
    PrintToChat ( client, "    Size: %d", team[CS_TEAM_CT][SIZE] );
    if ( team[CS_TEAM_CT][BEST] > 0 ) {
        GetClientName ( team[CS_TEAM_CT][BEST], name, 64 );
        PrintToChat ( client, "    Best: %s", name );
    }
    if ( team[CS_TEAM_T][SECOND] > 0 ) {
        GetClientName ( team[CS_TEAM_CT][SECOND], name, 64 );
        PrintToChat ( client, "  Second: %s", name );
    }
    if ( team[CS_TEAM_T][WORST] > 0 ) {
        GetClientName ( team[CS_TEAM_CT][WORST], name, 64 );
        PrintToChat ( client, "   Worst: %s", name );
    }
    PrintToChat ( client, "*** Terrorists ***" );
    PrintToChat ( client, "  Winner: %d", team[CS_TEAM_T][WINNER] );
    PrintToChat ( client, "    Wins: %d", team[CS_TEAM_T][WINS] );
    PrintToChat ( client, "  Streak: %d", team[CS_TEAM_T][STREAK] );
    PrintToChat ( client, "   Kills: %d", team[CS_TEAM_T][KILLS] );
    PrintToChat ( client, "    Size: %d", team[CS_TEAM_T][SIZE] );
    if ( team[CS_TEAM_T][BEST] > 0 ) {
        GetClientName ( team[CS_TEAM_T][BEST], name, 64 );
        PrintToChat ( client, "    Best: %s", name );
    }
    if ( team[CS_TEAM_T][SECOND] > 0 ) {
        GetClientName ( team[CS_TEAM_T][SECOND], name, 64 );
        PrintToChat ( client, "  Second: %s", name );
    }
    if ( team[CS_TEAM_T][WORST] > 0 ) {
        GetClientName ( team[CS_TEAM_T][WORST], name, 64 );
        PrintToChat ( client, "   Worst: %s", name );
    }
    PrintToChat ( client, "*** End of PrintInfo ***");
    return Plugin_Handled;
}

/*** METHODS ***/

public void swapPlayer ( int player ) {
    char name[65];
    int otherTeam;

    GetClientName ( player, name, 64 );
    otherTeam = getOtherTeam ( GetClientTeam(player) );

    shieldPlayer ( player );
    if ( ! IsPlayerAlive ( player ) ) {
        ChangeClientTeam ( player, otherTeam );
    } else {
        CS_SwitchTeam ( player, otherTeam );
        CS_UpdateClientModel ( player );
    }
    PrintToChatAll ( "\x03[OSAutoBalance]: %s swapped to %s!", name, otherTeam );
}
/* unshield all players */
public void unShieldAllPlayers ( ) {
    for ( int player = 1; player <= MaxClients; player++ ) {
        if ( IsClientInGame ( player ) && IsPlayerAlive ( player ) && ! IsClientSourceTV ( player ) ) {
            unShieldPlayer ( player );
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
    return ( team[winTeam][STREAK] >= cvar_BalanceAfterStreak.IntValue && 
             GetClientCount(true) >= 6 );
}

/* swap players when we hit a streak */
public void swapPlayersOnStreak ( int winTeam, int loserTeam ) {
    if ( moreTerrorists ( ) ) {
        if ( terroristsWon ( ) ) {
            swapPlayer ( team[CS_TEAM_T][WORST] );
        } else {
            swapPlayer ( team[CS_TEAM_CT][BEST] );
            swapPlayer ( team[CS_TEAM_T][SECOND] );
            swapPlayer ( team[CS_TEAM_T][WORST] );
        }
       
    } else {
        swapPlayer ( team[winTeam][SECOND] );
        swapPlayer ( team[loserTeam][WORST] );
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
    int playerTeam;
    resetTeams ( );
    setWinsAndStreak ( winTeam );
    char name[64];
      
    team[playerTeam][SIZE] = GetTeamClientCount ( playerTeam );
    team[playerTeam][KILLS] = GetTeamScore ( playerTeam );

    /* loop players to set positions */
    for ( int player = 1; player <= MaxClients; player++ ) {
        if ( playerIsReal ( player ) ) {
            playerTeam = GetClientTeam(player);
            GetClientName ( player, name, 64 );
            PrintToConsoleAll ( "*** Checking: %s", name );
            int position = getScoreBoardPosition ( player );
            if ( position == 1 ) {
                team[playerTeam][BEST] = player;
                PrintToConsoleAll ( "added %s as BEST in %d", name, playerTeam );
            } else if ( position == 2 ) {
                team[playerTeam][SECOND] = player;
                PrintToConsoleAll ( "added %s as SECOND in %d", name, playerTeam );
            } else if ( position == team[playerTeam][SIZE] ) {
                team[playerTeam][WORST] = player;
                PrintToConsoleAll ( "added %s as WORST in %d", name, playerTeam );
            }
        }
    }
}

public int getScoreBoardPosition ( int player ) {
    int score = CS_GetClientContributionScore ( player );
    int position = 1;
    for ( int other = 1; other <= MaxClients; other++ ) {
        if ( playerIsReal ( other ) && CS_GetClientContributionScore ( other ) > score ) {
                ++position;
        }
    }
    return position;
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
    team[CS_TEAM_T][BEST] = -1;
    team[CS_TEAM_T][SECOND] = -1;
    team[CS_TEAM_T][WORST] = -1;
    team[CS_TEAM_CT][WINNER] = 0;
    team[CS_TEAM_CT][KILLS] = 0;
    team[CS_TEAM_CT][SIZE] = 0;
    team[CS_TEAM_CT][BEST] = -1;
    team[CS_TEAM_CT][SECOND] = -1;
    team[CS_TEAM_CT][WORST] = -1;
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
 
/* determine if its a warmup round */
bool IsWarmupActive ( ) {
	return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}



