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

enum struct GameInfo {
   int scoreT;
   int scoreCT;
   int playersT;
   int playersCT;
   int streakT;
   int streakCT; 
   int bestPlayer;
   int worstPlayer;
}
GameInfo gameInfo;

public void OnPluginStart() {
	cvar_OSTeamBalance = FindConVar("mp_autoteambalance");
	cvar_MinPlayers = CreateConVar("os_minplayers", "3", "Minimum amount of players needed to try rebalance teams", _, true, 3.0);
	cvar_BalanceAfterStreak = CreateConVar("os_balanceafterstreak", "3", "Balance teams after X streak", _, true, 3.0);
	HookEvent("game_start", Event_GameStart);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("announce_phase_end", Event_HalfTime);
}

public void Event_GameStart ( Event event, const char[] name, bool dontBroadcast ) {
    gameInfo.scoreT = 0;
    gameInfo.scoreCT = 0;
    gameInfo.streakT = 0;
    gameInfo.streakCT = 0;
    gameInfo.bestPlayer = 0;
    gameInfo.worstPlayer = 0;
}

public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
    if ( gameInfo.bestPlayer != -1 ) {
        unShieldPlayer ( gameInfo.bestPlayer );
        gameInfo.bestPlayer = -1;
    }
    if ( gameInfo.worstPlayer != -1 ) {
        unShieldPlayer ( gameInfo.worstPlayer );
        gameInfo.worstPlayer = -1;
    }
}
public void Event_RoundEnd ( Event event, const char[] name, bool dontBroadcast ) {
    int winTeam = GetEventInt ( event, "winner" );
    if ( winTeam == CS_TEAM_T ) {
        gameInfo.scoreT++;
        gameInfo.streakT++;
        if ( gameInfo.streakCT > 0 ) {
            gameInfo.streakCT--;
        }
    } else {
        gameInfo.scoreCT++;
        gameInfo.streakCT++;
        if ( gameInfo.streakT > 0 ) {
            gameInfo.streakT--;
        }
    }
    balanceTeams ( winTeam );
}
public void Event_HalfTime ( Event event, const char[] name, bool dontBroadcast ) {
    /* Swap score */
    int buf = gameInfo.scoreT;
    gameInfo.scoreCT = gameInfo.scoreT;
    gameInfo.scoreT = buf;

    /* Swap streak */
    buf = gameInfo.streakT;
    gameInfo.streakCT = gameInfo.streakT;
    gameInfo.streakT = buf;
}

public void balanceTeams ( int winTeam ) {
    /* check if we should balance players */
    if ( shouldBalance ( winTeam ) ) {
        /* Pick out best and worst players */ 
        for ( int i = 1; i <= MaxClients; i++ ) {
            if ( winTeam == GetClientTeam ( i ) ) {
                if ( gameInfo.bestPlayer < 0 || GetClientFrags(i) > GetClientFrags(gameInfo.bestPlayer) ) {
                    gameInfo.bestPlayer = i;
                }
            } else if ( GetClientTeam(i) >= 2 ) {
                if ( gameInfo.worstPlayer < 0 || GetClientFrags(i) < GetClientFrags(gameInfo.worstPlayer) ) {
                    gameInfo.worstPlayer = i;
                }
            }
        }
        /* swap best with worst */
        if ( gameInfo.bestPlayer > 0 && gameInfo.worstPlayer > 0 ) {
            shieldPlayer ( gameInfo.bestPlayer );
            shieldPlayer ( gameInfo.worstPlayer );
            movePlayerToOtherTeam ( gameInfo.bestPlayer );
            movePlayerToOtherTeam ( gameInfo.worstPlayer );
        }
    }
} 

public bool shouldBalance ( int winTeam ) {
    return ( cvar_OSTeamBalance.BoolValue ) && ( GetClientCount(true) >= cvar_MinPlayers.IntValue ) &&
           ( ( winTeam == CS_TEAM_T && gameInfo.streakT >= cvar_BalanceAfterStreak.IntValue ) ||
           ( winTeam == CS_TEAM_CT && gameInfo.streakCT >= cvar_BalanceAfterStreak.IntValue ) );
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
