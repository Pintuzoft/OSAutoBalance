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


public void OnPluginStart() {
	cvar_OSTeamBalance = CreateConVar("os_autobalance", 1, "Enable autobalance", _, true, 1.0);
	cvar_MinPlayers = CreateConVar("os_minplayers", 3, "Minimum amount of players needed to try rebalance teams", _, true, 10.0);
	cvar_BalanceAfterStreak = CreateConVar("os_balanceafterstreak", 3, "Balance teams after X streak", _, true, 3.0);
	HookEvent("game_start", Event_GameStart);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("announce_phase_end", Event_HalfTime);
}

public void Event_GameStart ( Event event, const char[] name, bool dontBroadcast ) {
    scoreT = 0;
    scoreCT = 0;
    streakT = 0;
    streakCT = 0;
    bestPlayer = 0;
    worstPlayer = 0;
}

public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
    PrintToConsoleAll("OSTeamBalance-: %d", cvar_OSTeamBalance.IntValue );
    PrintToConsoleAll("MinPlayers: %d", cvar_MinPlayers.IntValue );
    PrintToConsoleAll("BalanceAfterStreak: %d", cvar_BalanceAfterStreak.IntValue );
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
    if (scoreT == null ) {
        scoreT = 0;
    }
    if (scoreCT == null ) {
        scoreCT = 0;
    }
    if (streakT == null ) {
        streakT = 0;
    }
    if (streakCT == null ) {
        streakCT = 0;
    }
     
    
    PrintToConsoleAll ( "scoreT: %d", scoreT );
    PrintToConsoleAll ( "scoreCT: %d", scoreCT );
    PrintToConsoleAll ( "streakT: %d", streakT );
    PrintToConsoleAll ( "streakCT: %d", streakCT );

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
    return ( cvar_OSTeamBalance.BoolValue ) && ( GetClientCount(true) >= cvar_MinPlayers.IntValue ) &&
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
