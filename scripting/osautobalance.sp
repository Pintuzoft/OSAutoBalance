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
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("announce_phase_end", Event_HalfTime);
}

public void Event_GameStart ( Event event, const char[] name, bool dontBroadcast ) {
    gameInfo.scoreT = 0;
    gameInfo.scoreCT = 0;
    gameInfo.streakT = 0;
    gameInfo.streakCT = 0;
    gameInfo.bestWinner = 0;
    gameInfo.bestPlayer = 0;
    gameInfo.worstPlayer = 0;
}
public void Event_RoundEnd ( Event event, const char[] name, bool dontBroadcast ) {
    winner = event.GetEventInt ( "winner" );
    if ( winner == CS_TEAM_T ) {
        gameInfo.scoreT++;
        gameInfo.streakT++;
    } else {
        gameInfo.scoreCT++;
        gameInfo.streakCT = 0;
    }
    balanceTeams ( winner );
}
public void Event_HalfTime ( Event event, const char[] name, bool dontBroadcast ) {
    int buf = scoreT;
    scoreCT = scoreT;
    scoreT = buf;
}

public void balanceTeams ( int winner ) {
    /* check if we should balance players */
    bool shouldBalance = shouldBalance ( winner );
     
    if ( shouldBalance ) {
        for ( int i = 1; i <= MaxClients; i++ ) {
            if ( winner == GetClientTeam ( i ) ) {
                if ( gameInfo.bestPlayer < 0 || GetClientFrags(i) > GetClientFrags(gameInfo.bestPlayer) ) {
                    gameInfo.bestPlayer = i;
                }
            } else if ( GetClientTeam(i) >= 2 ) {
                if ( gameInfo.worstPlayer < 0 || GetClientFrags(i) < GetClientFrags(gameInfo.worstPlayer) ) {
                    gameInfo.worstPlayer = i;
                }
            }
        }
    }
    
    /* swap second best with last */
    if ( bestPlayer > 0 && worstPlayer > 0 ) {
        
    }


    /* swap second with last in winning team */
} 

public bool shouldBalance ( int winner ) {
    return ( winner == CS_TEAM_T && gameInfo.streakT >= cvar_BalanceAfterStreak ) ||
           ( winner == CS_TEAM_CT && gameInfo.streakCT >= cvar_BalanceAfterStreak );
}

public void balanceTeams ( int winner ) {

}

