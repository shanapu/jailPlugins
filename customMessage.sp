#pragma semicolon 1

#include <sourcemod>
#include <geoip>
#include <cstrike>
#include <multicolors>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Custom Message",
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = true;
	return Plugin_Changed;
}

public void OnClientPostAdminCheck(int client)
{
	char sID[24], sIP[32], sCountry[64], sMessage[256];
	
	GetClientAuthId(client, AuthId_Steam2, sID, sizeof(sID));
	GetClientIP(client, sIP, sizeof(sIP));
	
	if(!GeoipCountry(sIP, sCountry, sizeof(sCountry)))
		Format(sCountry, sizeof(sCountry), "Unknown");
	
	Format(sMessage, sizeof(sMessage), "{purple}[CONNECT] {green}%N {lightgreen}({green}%s{lightgreen}) has joined the server from {lightgreen}[{green}%s{lightgreen}]", client, sID, sCountry);
	CPrintToChatAll(sMessage);
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int team = event.GetInt("team");

	if(IsClientInGame(client))
	{
		if (team == CS_TEAM_SPECTATOR)
		{
			CPrintToChatAll("{purple}[TEAM] {green}%N {lightgreen}betritt den Zuschauern bei!", client);
			event.BroadcastDisabled = true;
			return Plugin_Changed;
		}
		if (team == CS_TEAM_T)
		{
			CPrintToChatAll("{purple}[TEAM] {green}%N {lightgreen}betritt das T-Team!", client);
			event.BroadcastDisabled = true;
			return Plugin_Changed;
		}
		if (team == CS_TEAM_CT)
		{
			CPrintToChatAll("{purple}[TEAM] {green}%N {lightgreen}betritt das CT-Team!", client);
			CPrintToChat(client, "{darkred}Durch das betreten des CT-Teams aktzeptieren Sie automatisch die Serverregeln!");
			event.BroadcastDisabled = true;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = true;
	return Plugin_Changed;
}
