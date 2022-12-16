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
    if ( IsWarmupActive ( ) ) {
        zerofy ( );
        return;
    }
    int winTeam = GetEventInt(event, "winner");
    int loserTeam = getLoserTeam ( winTeam );

    /* GATHER DATA */
    gatherTeamsData ( winTeam, loserTeam );
    
    /* BALANCE */
    if ( shouldBalance ( ) ) {
        swapPlayersOnStreak ( winTeam, loserTeam );
        
    } else if ( moreTerrorists ( ) ) {
        swapPlayer ( team[CS_TEAM_T][WORST] );
    }
}



/*** METHODS ***/

public void swapPlayer ( int player ) {

}

public bool shouldBalance ( winTeam, loserTeam ) {
    return ( team[winTeam][STREAK] >= 3 && GetClientCount(true) >= 6 );
}

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

public bool terroristsWon ( ) {
    return ( team[CS_TEAM_T][WINNER] == 1 );
}
public bool moreTerrorists ( ) {
    return ( team[CS_TEAM_T][SIZE] > team[CS_TEAM_CT][SIZE] );
}
public int getLoserTeam ( int winTeam ) {
    return ( winTeam == 2 ? 3 : 2 );
}
public void gatherTeamsData ( int winTeam, loserTeam ) {
    int playerTeam;
    resetTeams ( );
    setWinsAndStreak ( winTeam );
    for ( int player = 1; player <= MaxClients; player++ ) {
        if ( playerIsReal ( player ) ) {
            playerTeam = GetClientTeam(player);
            team[playerTeam][SIZE]++;
            team[playerTeam][KILLS] += GetClientFrags ( player );
            if ( team[playerTeam][BEST] < 0 ) {
                team[playerTeam][BEST] = player;
            
            } else if ( GetClientFrags(player) > GetClientFrags(team[playerTeam][BEST]) ) {
                team[playerTeam][SECOND] = team[playerTeam][BEST];
                team[playerTeam][BEST] = player;
            
            } else if ( team[playerTeam][WORST] < 0 ) {
                team[playerTeam][WORST] = player;
            
            } else if ( GetClientFrags(player) < GetClientFrags(team[playerTeam][WORST] ) ) {
                team[playerTeam][WORST] = player;
            }
            
        }
    }
}

public bool playerWon ( int player ) {
    return (team[GetClientTeam(player)][WINNER] == 1);
}
public void setWinsAndStreak ( int winTeam ) {
    loserTeam = getLoserTeam ( winTeam );
    team[winTeam][WINS]++;
    team[winTeam][WINNER] = 1;
    team[winTeam][STREAK]++;
    team[loserTeam][STREAK] = 0;
}

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
public void playerIsReal ( int player ) {
    return ( IsClientInGame ( player ) &&
             !IsClientSourceTV ( player ) );
}
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
/* unshield all players */
public void unShieldAllPlayers ( ) {
    for ( int player = 1; player <= MaxClients; player++ ) {
        if ( IsClientInGame ( player ) && IsPlayerAlive ( player ) && ! IsClientSourceTV ( player ) ) {
            SetEntProp(player, Prop_Data, "m_takedamage", 2, 1);
            SetEntityRenderColor(player, 255, 255, 255, 255);
        }
    }
}
/* determine if its a warmup round */
bool IsWarmupActive ( ) {
	return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}



