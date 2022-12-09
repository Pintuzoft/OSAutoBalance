#include <sourcemod>
#include <sdktools>
#include <cstrike>

ConVar cvar_OSTeamBalance;
ConVar cvar_MinPlayers;
ConVar cvar_BalanceAfterStreak;

public Plugin myinfo = {
	name = "OSAutoBalance",
	author = "Pintuz",
	description = "OldSwedes Auto-Balance plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSAutoBalance"
}

int scoreT;
int scoreCT;
int playersT;
int playersCT;
int streakT;
int streakCT; 
int bestPlayer;
int secondPlayer;
int worstPlayer;
int immuneBest;
int immuneWorst;
char best[64];
char second[64];
char worst[64];
bool swapFirst;

public void OnPluginStart ( ) {
    cvar_OSTeamBalance = CreateConVar ( "os_autobalance", "1", "Enable autobalance", _, true, 1.0 );
    cvar_MinPlayers = CreateConVar ( "os_minplayers", "6", "Minimum amount of players needed to try rebalance teams", _, true, 6.0 );
    cvar_BalanceAfterStreak = CreateConVar ( "os_balanceafterstreak", "3", "Balance teams after X streak", _, true, 1.0 );
    HookEvent ( "round_start", Event_RoundStart );
    HookEvent ( "round_end", Event_RoundEnd );
    HookEvent ( "announce_phase_end", Event_HalfTime );
    AutoExecConfig ( true, "osautobalance" );
}

public void zerofy ( ) {
    scoreT = 0;
    scoreCT = 0;
    streakT = 0;
    streakCT = 0;

}
public void zerofyPlayers ( ) {
    bestPlayer = -1;
    secondPlayer = -1;
    worstPlayer = -1;
    best = "-";
    second = "-";
    worst = "-";
}
public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
    fixPlayerNames ( );
    printDebug ( );
    unShieldPlayers ( );
}
public void Event_RoundEnd ( Event event, const char[] name, bool dontBroadcast ) {
    if (IsWarmupActive()) {
        zerofy();
        return;
    }
    fixPlayerNames ( );
    printDebug ( );
    int winTeam = GetEventInt ( event, "winner" );
    if ( winTeam == CS_TEAM_T ) {
        scoreT++;
        streakT++;
        if ( streakCT > 0 ) {
            streakCT--;
        }
    } else {
        scoreCT++;
        streakCT++;
        if ( streakT > 0 ) {
            streakT--;
        }
    }
    balanceTeams ( winTeam );
}
/* Halftime, lets swap score & streak */
public void Event_HalfTime ( Event event, const char[] name, bool dontBroadcast ) {
    int buf = scoreCT;
    scoreCT = scoreT;
    scoreT = buf;
    buf = streakCT;
    streakCT = streakT;
    streakT = buf;
}

public void balanceTeams ( int winTeam ) {
    /* check if we should balance players */
    if ( shouldBalance ( winTeam ) ) {
        
        /* loop all users to find target players */
        findTargetPlayers ( winTeam );
        
        /* swap the target players if we found them */
        if ( bestPlayer > 0 && secondPlayer > 0 && worstPlayer > 0 ) {
            swapTargetPlayers ( );
        }
    }
} 

public findTargetPlayers ( int winTeam ) {
    zerofyPlayers ( );
    /* Pick out best and worst players */ 
    for ( int i = 1; i <= MaxClients; i++ ) {
       
        if ( i == immuneBest || i == immuneWorst ) {
        /* skip a user that was recently swapped */
        } else if ( IsClientInGame ( i ) ) {
            char name[64];
            GetClientName (i, name, 64);
    PrintToConsoleAll ( "---[%s]-----------", name );
            if ( winTeam == GetClientTeam ( i ) ) {
                if ( bestPlayer < 0 ) {
    PrintToConsoleAll ( " - set best player" );
                    bestPlayer = i;
                } else if ( GetClientFrags(i) > GetClientFrags(bestPlayer) ) {
    PrintToConsoleAll ( " - set best player[0]" );
                    secondPlayer = bestPlayer;
                    bestPlayer = i;
                } else if ( GetClientFrags(i) > GetClientFrags(secondPlayer) ) {
    PrintToConsoleAll ( " - set second player[1]" );
                    secondPlayer = i;
                }
    PrintToConsoleAll ( " - end best" );

            } else if ( GetClientTeam(i) >= 2 ) {
                if ( worstPlayer < 0 ) {
    PrintToConsoleAll ( " - set worst player" );
                    worstPlayer = i;
                } else if ( GetClientFrags(i) < GetClientFrags(worstPlayer) ) {
    PrintToConsoleAll ( " - set worst player" );
                    worstPlayer = i;
                }
    PrintToConsoleAll ( " - end worst" );

            }
        }
    }
}

public swapTargetPlayers ( ) {
    /* swap best or second with worst */
    swapFirst = GetRandomInt(0,1) == 1 ? true : false;
    if ( swapFirst ) {
        shieldPlayer ( bestPlayer );
        PrintToChatAll ( "\x07[OSAutoBalance]: %s swapped!", best );
        movePlayerToOtherTeam ( bestPlayer );
    } else {
        shieldPlayer ( secondPlayer );
        PrintToChatAll ( "\x07[OSAutoBalance]: %s swapped!", second );
        movePlayerToOtherTeam ( secondPlayer );
    }
    shieldPlayer ( worstPlayer );
    PrintToChatAll ( "\x07[OSAutoBalance]: %s swapped!", worst );
    movePlayerToOtherTeam ( worstPlayer );
}

public bool shouldBalance ( int winTeam ) {
    return ( cvar_OSTeamBalance.IntValue == 1 ) && ( GetClientCount(true) >= cvar_MinPlayers.IntValue ) &&
           ( ( winTeam == CS_TEAM_T && streakT >= cvar_BalanceAfterStreak.IntValue ) ||
           ( winTeam == CS_TEAM_CT && streakCT >= cvar_BalanceAfterStreak.IntValue ) );
}

/* shield on */
public void shieldPlayer ( int player ) {
    if ( IsPlayerAlive ( player ) && ! IsClientSourceTV ( player ) ) {
        /* Shield here */ 
        SetEntityRenderColor(player, 0, 100, 100, 255);
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
public void movePlayerToOtherTeam ( int player ) {
    if ( GetClientTeam ( player ) > 1 ) {
        if ( ! IsPlayerAlive ( player ) ) {
            ChangeClientTeam ( player, getOtherTeamID ( player ) );
        } else {
            CS_SwitchTeam ( player, getOtherTeamID ( player ) );
            CS_UpdateClientModel ( player );
        }
    }
}


/* Random methods */

/* return players enemy team */ 
public int getOtherTeamID ( int player ) {
    return ( GetClientTeam(player) == 2 ? 3 : 2 );
}

/* store player names */
public void fixPlayerNames ( ) {
    if ( bestPlayer > 0 ) {
        GetClientName (bestPlayer, best, 64);
    }
    if ( secondPlayer > 0 ) {
        GetClientName (secondPlayer, second, 64);
    }
    if ( worstPlayer > 0 ) {
        GetClientName (worstPlayer, worst, 64);
    }
}

/* unshielding all players */
public void unShieldPlayers ( ) {
    if ( bestPlayer != -1 ) {
        unShieldPlayer ( bestPlayer );
        bestPlayer = -1;
    }
    
    if ( secondPlayer != -1 ) {
        unShieldPlayer ( secondPlayer );
        secondPlayer = -1;
    }
    
    if ( worstPlayer != -1 ) {
        unShieldPlayer ( worstPlayer );
        worstPlayer = -1;
    }
}

/* print debug information */
public void printDebug ( ) {
    PrintToChatAll ( "scoreT: %d", scoreT );
    PrintToChatAll ( "scoreCT: %d", scoreCT );
    PrintToChatAll ( "streakT: %d", streakT );
    PrintToChatAll ( "streakCT: %d", streakCT );
    PrintToChatAll ( "best: %s", best );
    PrintToChatAll ( "second: %s", second );
    PrintToChatAll ( "worst: %s",  worst );
}

/* determine if its a warmup round */
bool IsWarmupActive() {
	return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}