#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <shop>
#include <multicolors>

ConVar g_Cvar_Interval;
ConVar g_Cvar_CreditsPerTick;
Handle h_timer[MAXPLAYERS+1];

ConVar g_Cvar_CreditsForRoundWin;
ConVar g_Cvar_WinnersCredits;
ConVar g_Cvar_SoloWinnerCredits;
ConVar g_Cvar_KillCredits;
ConVar g_Cvar_DeathCredits;

public Plugin myinfo =
{
    name        = "[Shop] Credits Distributor",
    author      = "inGame",
    description = "Credits Distributor component",
    version     = "0.2",
    url         = "www.nide.gg"
};


public void OnPluginStart()
{
	g_Cvar_Interval = CreateConVar("sm_shop_creditsdistributor_interval", "180.0", "The interval of timer. Less than 1 to disable", 0, true, 0.0, false);
	g_Cvar_CreditsPerTick = CreateConVar("sm_shop_creditsdistributor_play_credits", "5", "Amount of credits all players get every (sm_shop_creditsdistributor_interval) time.", FCVAR_NONE);
	g_Cvar_CreditsForRoundWin = CreateConVar("sm_shop_creditsdistributor_round_win", "1", "Distribute credits for round win", 0, true, 0.0, true, 1.0);
	g_Cvar_WinnersCredits = CreateConVar("sm_shop_creditsdistributor_humans_credits", "10", "How many credits humans will earn for winning round", FCVAR_NONE);
	g_Cvar_SoloWinnerCredits = CreateConVar("sm_shop_creditsdistributor_solo_credits", "50", "How many credits solo winner will earn", FCVAR_NONE);
	g_Cvar_KillCredits = CreateConVar("sm_shop_creditsdistributor_kill_credits", "5", "How many credits player will earn for kill", 0, true, 0.0, false);
	g_Cvar_DeathCredits = CreateConVar("sm_shop_creditsdistributor_death_credits", "2", "How many credits player will lose for death", 0, true, 0.0, false);

	g_Cvar_Interval.AddChangeHook(OnIntervalChange);
	
	AutoExecConfig(true, "shop_creditsdistributor", "shop");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != CS_TEAM_T || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		OnClientDisconnect_Post(i);
		h_timer[i] = CreateTimer(60.0, GivePoints, i, TIMER_REPEAT);

		if(IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT || GetClientTeam(i) == CS_TEAM_T)
		{
			OnClientDisconnect_Post(i);
			h_timer[i] = CreateTimer(60.0, GivePoints, i, TIMER_REPEAT);
		}
	}
	
	HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Post);
	HookEvent("round_end", Event_OnRoundEnd, EventHookMode_Post);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Post);
	

	LoadTranslations("shop_creditsdistributor.phrases");
}

public void OnIntervalChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != CS_TEAM_T || GetClientTeam(i) != CS_TEAM_CT)
			continue;
		
		Create(i);
	}
}

public void OnClientDisconnect_Post(int client)
{
	if (h_timer[client] != null)
	{
		delete h_timer[client];
	}
}

public void Create(int client)
{
	OnClientDisconnect_Post(client);
	
	float interval = g_Cvar_Interval.FloatValue;
	if (interval < 1.0)
	{
		return;
	}
	
	h_timer[client] = CreateTimer(interval, GivePoints, client, TIMER_REPEAT);
}

public Action GivePoints(Handle timer, int client)
{
	int amount = g_Cvar_CreditsPerTick.IntValue;
	int gain = Shop_GiveClientCredits(client, amount, CREDITS_BY_NATIVE);
	if (gain != -1)
	{
		CPrintToChat(client, "%t", "Gain for play", gain);
	}
}

public void Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || IsFakeClient(client)) 
		return;
	
	switch (event.GetInt("team"))
	{
		case CS_TEAM_CT, CS_TEAM_T :
		{
			Create(client);
		}
		default :
		{
			OnClientDisconnect_Post(client);
		}
	}
}

public void Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	bool bCreditsForRoundWin = g_Cvar_CreditsForRoundWin.BoolValue;
	
	int iZombies = 0, iHumans = 0;
	int SoloWinner;

	if(!bCreditsForRoundWin)
		return;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(GetClientTeam(i) == CS_TEAM_T)
			{
				iZombies++;
			}
			else if(GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i))
			{
				iHumans++;
				SoloWinner = i;
			}
		}	
	}

	if(iZombies > 1)
	{
		if(iHumans == 1) // Solo winner
		{
			int iSoloWinnerCreditsAmount = g_Cvar_SoloWinnerCredits.IntValue;
			
			Shop_GiveClientCredits(SoloWinner, iSoloWinnerCreditsAmount, CREDITS_BY_NATIVE);

			char sName[256];
			GetClientName(SoloWinner, sName, sizeof(sName));
			CPrintToChatAll("%t", "Solo win", sName, iSoloWinnerCreditsAmount);
		}
		else if(iHumans > 1)
		{
			int iWinnersCreditsAmount = g_Cvar_WinnersCredits.IntValue;

			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsFakeClient(i))
				{
					if(GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i))
					{
						Shop_GiveClientCredits(i, iWinnersCreditsAmount, CREDITS_BY_NATIVE);
					}
				}	
			}

			CPrintToChatAll("%t", "Humans win", iWinnersCreditsAmount);
		}
	}
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client_died = GetClientOfUserId(event.GetInt("userid"));
	if(!client_died)
		return;

	int client_attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!client_attacker)
		return;

	if(client_died == client_attacker)
		return;
	
	int iKillCredits = g_Cvar_KillCredits.IntValue;
	int iDeathCredits = g_Cvar_DeathCredits.IntValue;

	if(IsClientInGame(client_attacker) && !IsFakeClient(client_attacker) && IsPlayerAlive(client_attacker) && IsClientInGame(client_died) && !IsFakeClient(client_died))
	{
		if(iKillCredits)
		{
			Shop_GiveClientCredits(client_attacker, iKillCredits, CREDITS_BY_NATIVE);
			CPrintToChat(client_attacker, "%t", "Kill", iKillCredits);
		}

		if(iDeathCredits)
		{
			Shop_TakeClientCredits(client_died, iDeathCredits, CREDITS_BY_NATIVE);
			CPrintToChat(client_died, "%t", "Death", iDeathCredits);
		}
	}
}