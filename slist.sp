#pragma semicolon 1

#include <sourcemod>
#include <multicolors>
#include <stamm>

public Plugin myinfo = 
{
	name = "Stamm Online List",
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_solist", Command_SoList);
}

public Action Command_SoList(int client, int args)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			int iPoints = STAMM_GetClientPoints(i);
			PrintToConsole(client, "[%d] %N", iPoints, i);
		}
	}
	ReplyToCommand(client, "List is in your console!");
}
