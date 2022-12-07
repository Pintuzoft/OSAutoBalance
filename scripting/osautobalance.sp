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
int worstPlayer;
char best[64];
char worst[64];
    

public void OnPluginStart() {
	cvar_OSTeamBalance = CreateConVar("os_autobalance", "1", "Enable autobalance", _, true, 1.0);
	cvar_MinPlayers = CreateConVar("os_minplayers", "3", "Minimum amount of players needed to try rebalance teams", _, true, 10.0);
	cvar_BalanceAfterStreak = CreateConVar("os_balanceafterstreak", "3", "Balance teams after X streak", _, true, 3.0);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("announce_phase_end", Event_HalfTime);
    scoreT = 0;
    scoreCT = 0;
    streakT = 0;
    streakCT = 0;
    bestPlayer = -1;
    worstPlayer = -1;
}
  
public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
    if ( bestPlayer > 0 ) {
        GetClientName (bestPlayer, best, 64);
    }
    if ( worstPlayer > 0 ) {
        GetClientName (worstPlayer, worst, 64);
    }
    PrintToChatAll ( "scoreT: %d", scoreT );
    PrintToChatAll ( "scoreCT: %d", scoreCT );
    PrintToChatAll ( "streakT: %d", streakT );
    PrintToChatAll ( "streakCT: %d", streakCT );
    PrintToChatAll ( "BestPlayer: %s", best );
    PrintToChatAll ( "WorstPlayer: %s",  worst );
    if ( bestPlayer != -1 ) {
        unShieldPlayer ( bestPlayer );
        bestPlayer = -1;
    }
    
    if ( worstPlayer != -1 ) {
        unShieldPlayer ( worstPlayer );
        worstPlayer = -1;
    }
}
public void Event_RoundEnd ( Event event, const char[] name, bool dontBroadcast ) {
    if ( bestPlayer > 0 ) {
        GetClientName (bestPlayer, best, 64);
    }
    if ( worstPlayer > 0 ) {
        GetClientName (worstPlayer, worst, 64);
    }
    PrintToChatAll ( "scoreT: %d", scoreT );
    PrintToChatAll ( "scoreCT: %d", scoreCT );
    PrintToChatAll ( "streakT: %d", streakT );
    PrintToChatAll ( "streakCT: %d", streakCT );
    PrintToChatAll ( "BestPlayer: %s", best );
    PrintToChatAll ( "WorstPlayer: %s",  worst );

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
public void Event_HalfTime ( Event event, const char[] name, bool dontBroadcast ) {
    PrintToChatAll("!!HALFTIME!!");

    /* Swap score */
    int buf = scoreT;
    scoreCT = scoreT;
    scoreT = buf;

    /* Swap streak */
    buf = streakT;
    streakCT = streakT;
    streakT = buf;
}

public void balanceTeams ( int winTeam ) {
    /* check if we should balance players */
    if ( shouldBalance ( winTeam ) ) {
        /* Pick out best and worst players */ 
        for ( int i = 1; i <= MaxClients; i++ ) {
            if ( winTeam == GetClientTeam ( i ) ) {
                if ( bestPlayer < 0 || GetClientFrags(i) > GetClientFrags(bestPlayer) ) {
                    bestPlayer = i;
                }
            } else if ( GetClientTeam(i) >= 2 ) {
                if ( worstPlayer < 0 || GetClientFrags(i) < GetClientFrags(worstPlayer) ) {
                    worstPlayer = i;
                }
            }
        }
        /* swap best with worst */
        if ( bestPlayer > 0 && worstPlayer > 0 ) {
            shieldPlayer ( bestPlayer );
            shieldPlayer ( worstPlayer );
            movePlayerToOtherTeam ( bestPlayer );
            movePlayerToOtherTeam ( worstPlayer );
        }
    }
} 

public bool shouldBalance ( int winTeam ) {
    return ( cvar_OSTeamBalance.IntValue == 1 ) && ( GetClientCount(true) >= cvar_MinPlayers.IntValue ) &&
           ( ( winTeam == CS_TEAM_T && streakT >= cvar_BalanceAfterStreak.IntValue ) ||
           ( winTeam == CS_TEAM_CT && streakCT >= cvar_BalanceAfterStreak.IntValue ) );
}

public void shieldPlayer ( int player ) {
    if ( IsPlayerAlive ( player ) && ! IsClientSourceTV ( player ) ) {
        /* Shield here */ 
        SetEntityRenderColor(player, 0, 100, 100, 255);
        SetEntProp(player, Prop_Data, "m_takedamage", 0, 1);
    }
}
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

public int getOtherTeamID ( int player ) {
    return ( GetClientTeam(player) == 2 ? 3 : 2 );
}
