#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

ConVar g_cHealth = null;
ConVar g_cSpeed = null;

public Plugin myinfo = 
{
	name = "CT Boost",
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	g_cHealth = CreateConVar("ctboost_health", "9.1842", "Multiplikator Health (AnzahlT/AnzahlCT*Multiplator)");
	g_cSpeed = CreateConVar("ctboost_speed", "0.0242", "Multiplikator Speed (AnzahlT/AnzahlCT*Multiplator)");
	
	AutoExecConfig();
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public Action Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(IsClientValid(client))
	{
		CreateTimer(0.5, Timer_CTBoost, GetClientUserId(client));
	}
}

public Action Timer_CTBoost(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (IsClientValid(client))
	{
		if(GetClientTeam(client) != CS_TEAM_CT)
			return Plugin_Continue;
			
		int iT = 0;
		int iCT = 0;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientValid(i))
			{
				if(GetClientTeam(i) == CS_TEAM_CT)
					iCT++;
				else if(GetClientTeam(i) == CS_TEAM_T)
					iT++;
			}
		}
		
		// Health
		int iHP = RoundToCeil(iT / iCT * g_cHealth.FloatValue);
		SetEntityHealth(client, GetClientHealth(client) + iHP);
		
		// Armor
		SetEntProp(client, Prop_Send, "m_ArmorValue", GetEntProp(client, Prop_Send, "m_ArmorValue") + 110);
		SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
		
		// Speed
		float fSpeed = (iT / iCT * g_cSpeed.FloatValue + 1.0);
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", fSpeed);
	}
	return Plugin_Continue;
}

bool IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients)
		if (IsClientInGame(client))
			return true;
	return false;
}
