#include <sourcemod>
#include <sdktools>
#include <cstrike>

ConVar cvar_OSTeamBalance;
ConVar cvar_MinPlayers;
ConVar cvar_BalanceAfterStreak;

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
char movePlayer[64];
bool swapFirst;
int winTeam;

public Plugin myinfo = {
	name = "OSAutoBalance",
	author = "Pintuz",
	description = "OldSwedes Auto-Balance plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSAutoBalance"
}

public void OnPluginStart ( ) {
    cvar_OSTeamBalance = CreateConVar ( "os_autobalance", "1", "Enable autobalance", _, true, 1.0 );
    cvar_MinPlayers = CreateConVar ( "os_minplayers", "6", "Minimum amount of players needed to try rebalance teams", _, true, 6.0 );
    cvar_BalanceAfterStreak = CreateConVar ( "os_balanceafterstreak", "3", "Balance teams after X streak", _, true, 1.0 );
    HookEvent ( "round_start", Event_RoundStart );
    HookEvent ( "round_end", Event_RoundEnd );
    HookEvent ( "announce_phase_end", Event_HalfTime );
    AutoExecConfig ( true, "osautobalance" );
}

/*** EVENTS ***/
public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
    printDebug ( );
    unShieldAllPlayers ( );
}
public void Event_RoundEnd ( Event event, const char[] name, bool dontBroadcast ) {
    if (IsWarmupActive()) {
        zerofy();
        return;
    }
    winTeam = 0;
    winTeam = GetEventInt ( event, "winner" );
    printDebug ( );    
    CreateTimer ( 1.0, DelayBalanceTeams, TIMER_DATA_HNDL_CLOSE );
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
/*** END EVENTS ***/

public Action DelayBalanceTeams ( Handle timer ) {  
    analyzeStatistics ( );
    makeSureThereIsMoreCT ( );
    return ;
}
/* analyze statistical information */
public void analyzeStatistics ( ) {
    switch ( winTeam ) {
        case CS_TEAM_T: {
            ++scoreT;
            ++streakT;
            if ( streakCT > 0 ) {
                --streakCT;
            }
        }
        case CS_TEAM_CT: {
            ++scoreCT;
            ++streakCT;
            if ( streakT > 0 ) {
                --streakT;
            }
        }
    }
}

/* balance teams  */
public void balanceTeams ( ) {
    /* check if we should balance players */
    if ( shouldBalance ( ) ) {
        
        /* loop all users to find target players */
        findTargetPlayers ( );
        
        /* swap the target players if we found them */
        if ( bestPlayer > 0 && secondPlayer > 0 && worstPlayer > 0 ) {
            shieldAllPlayers ( );
            swapTargetPlayers ( );
        }
    }
} 

/* make sure CT is the bigger team if its not */
public void makeSureThereIsMoreCT ( ) {
    PrintToConsoleAll ( "0:" );
    int playerT = 999;
    for ( int i = 1; i <= MaxClients; i++ ) {
    PrintToConsoleAll ( "1:" );
        if ( IsClientInGame ( i ) && ! IsClientSourceTV ( i ) ) {
    PrintToConsoleAll ( "2:" )
            switch ( GetClientTeam(i) ) {
                case CS_TEAM_T: {
    PrintToConsoleAll ( "3:" );
                    ++playersT;
                    PrintToConsoleAll ( "i:%d", i );
                    PrintToConsoleAll ( "playerT:%d", playerT );
                    if ( playerT == 999 ) {
    PrintToConsoleAll ( "4:" );
                        playerT = i;
                    } else if ( GetClientFrags(i) < GetClientFrags(playerT) ) {
    PrintToConsoleAll ( "5:" );
                        playerT = i;
                    }
    PrintToConsoleAll ( "6:" );
                }
                case CS_TEAM_CT: {
    PrintToConsoleAll ( "7:" );
                    ++playersCT;
                }
            }
    PrintToConsoleAll ( "8:" );
        }
    PrintToConsoleAll ( "9:" );
    }
    printDebug
    if ( playersT > playersCT && playerT < 999 ) {
    PrintToConsoleAll ( "10:" );
        shieldAllPlayers ( );
        movePlayerToOtherTeam ( playerT );
    }
}

/* find the target users */
public findTargetPlayers ( ) {
    zerofyPlayers ( );
    /* Pick out best and worst players */ 
    for ( int i = 1; i <= MaxClients; i++ ) {
        if ( IsClientInGame ( i ) && ! IsClientSourceTV ( i ) ) {
            if ( i == immuneBest || i == immuneWorst ) {
            /* skip a user that was recently swapped */
            } else  {
                if ( winTeam == GetClientTeam ( i ) ) {
                    if ( bestPlayer < 0 ) {
                        bestPlayer = i;
                    } else if ( GetClientFrags(i) > GetClientFrags(bestPlayer) ) {
                        secondPlayer = bestPlayer;
                        bestPlayer = i;
                    } else if ( secondPlayer < 0 ) {
                        secondPlayer = i;
                    } else if ( GetClientFrags(i) > GetClientFrags(secondPlayer) ) {
                        secondPlayer = i;
                    }

                } else if ( GetClientTeam(i) >= 2 ) {
                    if ( worstPlayer < 0 ) {
                        worstPlayer = i;
                    } else if ( GetClientFrags(i) < GetClientFrags(worstPlayer) ) {
                        worstPlayer = i;
                    }
                }
            }
        }
    }
}

/* swap the players we found */
public swapTargetPlayers ( ) {
    fixPlayerNames ( );
    /* swap best or second with worst */
    swapFirst = GetRandomInt(0,1) == 1 ? true : false;
    if ( swapFirst ) {
        movePlayerToOtherTeam ( bestPlayer );
        immuneBest = bestPlayer;
    } else {
        movePlayerToOtherTeam ( secondPlayer );
        immuneBest = bestPlayer;
    }
    
    movePlayerToOtherTeam ( worstPlayer );
    immuneBest = worstPlayer;

    /* reset streak */
    streakT = 0;
    streakCT = 0;
}


/*** STATIC ***/

/* reset score and streak information */
public void zerofy ( ) {
    scoreT = 0;
    scoreCT = 0;
    streakT = 0;
    streakCT = 0;
}

/* reset player information */
public void zerofyPlayers ( ) {
    bestPlayer = -1;
    secondPlayer = -1;
    worstPlayer = -1;
    best = "-";
    second = "-";
    worst = "-";
    playersT = 0;
    playersCT = 0;
}

public bool shouldBalance (  ) {
    return ( cvar_OSTeamBalance.IntValue == 1 ) && ( GetClientCount(true) >= cvar_MinPlayers.IntValue ) &&
           ( ( winTeam == CS_TEAM_T && streakT >= cvar_BalanceAfterStreak.IntValue ) ||
           ( winTeam == CS_TEAM_CT && streakCT >= cvar_BalanceAfterStreak.IntValue ) );
}

/* shield all players */
public void shieldAllPlayers ( ) {
    for ( int i = 1; i <= MaxClients; i++ ) {
        if ( IsClientInGame ( i ) && IsPlayerAlive ( i ) && ! IsClientSourceTV ( i ) ) {
            shieldPlayer ( i );
        }
    }
}

/* unshield all players */
public void unShieldAllPlayers ( ) {
    for ( int i = 1; i <= MaxClients; i++ ) {
        if ( IsClientInGame ( i ) && IsPlayerAlive(i) && ! IsClientSourceTV ( i ) ) {
            unShieldPlayer ( i );
        }
    }
}

/* shield on */
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

/* move player to other team */
public void movePlayerToOtherTeam ( int player ) {
    if ( IsClientInGame ( player ) && GetClientTeam ( player ) > 1 ) {
        GetClientName (player, movePlayer, 64);
        char team[64] = getOtherTeamName ( player );
        PrintToChatAll ( "\x03[OSAutoBalance]: %s swapped to %s!", movePlayer, team );
        if ( ! IsPlayerAlive ( player ) ) {
            ChangeClientTeam ( player, getOtherTeamID ( player ) );
        } else {
            CS_SwitchTeam ( player, getOtherTeamID ( player ) );
            CS_UpdateClientModel ( player );
        }
    }
}

/* return players enemy team */ 
public int getOtherTeamID ( int player ) {
    return ( GetClientTeam(player) == 2 ? 3 : 2 );
}
/* return players enemy team name*/ 
public char getOtherTeamName ( int player ) {
    return ( GetClientTeam(player) == 2 ? "CT" : "T" );
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
    PrintToChatAll ( "playersT: %s", playersT );
    PrintToChatAll ( "playersCT: %s",  playersCT );
}

/* determine if its a warmup round */
bool IsWarmupActive() {
	return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}