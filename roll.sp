#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <multicolors>

#define MAX_INT 2147483647

int g_iInterval = 5;
int g_iDice[MAXPLAYERS + 1] =  { 0, ... };

public Plugin myinfo = 
{
	name = "Simple Roll",
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_roll", Command_Roll);
}

public Action Command_Roll(int client, int args)
{
	if(GetClientTeam(client) != CS_TEAM_CT && !CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
	{
		ReplyToCommand(client, "Nur CT und Admins können dies benutzen!");
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "Du musst dafür leben!");
		return Plugin_Handled;
	}
	
	if (args != 2)
	{
		ReplyToCommand(client, "Usage: sm_roll <minimum> <maximum>");
		return Plugin_Handled;
	}
	
	char sRoll1[12], sRoll2[12];
	GetCmdArg(1, sRoll1, sizeof(sRoll1));
	GetCmdArg(2, sRoll2, sizeof(sRoll2));
	
	if(!IsNumeric(sRoll1) || !IsNumeric(sRoll2))
	{
		ReplyToCommand(client, "Es müssen Zahlen sein!");
		return Plugin_Handled;
	}
	
	int iRoll1 = StringToInt(sRoll1);
	int iRoll2 = StringToInt(sRoll2);
	
	if(iRoll1 > MAX_INT || iRoll2 > MAX_INT)
	{
		ReplyToCommand(client, "Der maximal Wer ist %d!", MAX_INT);
		return Plugin_Handled;
	}
	
	int iLeft = g_iInterval - (GetTime() - g_iDice[client]);
	
	if(iLeft > 0)
	{
		ReplyToCommand(client, "Du kannst erst wieder in %d Sekunden würfeln!", iLeft);
		return Plugin_Handled;
	}
	
	if(iRoll1 > iRoll2)
	{
		ReplyToCommand(client, "Der erste Werte muss kleiner als der zweite Wert sein!");
		return Plugin_Handled;
	}

	if(iRoll1 < 0 || iRoll2 < 0)
	{
		ReplyToCommand(client, "Die Werte dürfen nicht unter 0 sein!");
		return Plugin_Handled;
	}
	
	if(iRoll1 == iRoll2)
	{
		ReplyToCommand(client, "Die Zahlen müssen sich unterscheiden!");
		return Plugin_Handled;
	}
	
	SetRandomSeed(GetTime());
	int iRandom = GetRandomInt(iRoll1, iRoll2);
	CPrintToChatAll("{darkred}%N {green}hat einen Würfel von {purple}%d {green}bis {purple}%d {green}benutzt und eine {purple}%d {green}gewürfelt!", client, iRoll1, iRoll2, iRandom);
	
	g_iDice[client] = GetTime();
	
	return Plugin_Continue;
}

bool IsNumeric(const char[] str)
{	
	int x = 0;
	int dotsFound = 0;
	int numbersFound = 0;

	if (str[x] == '+' || str[x] == '-') {
		x++;
	}

	while (str[x] != '\0') {

		if (IsCharNumeric(str[x])) {
			numbersFound++;
		}
		else if (str[x] == '.') {
			dotsFound++;
			
			if (dotsFound > 1) {
				return false;
			}
		}
		else {
			return false;
		}
		
		x++;
	}
	
	if (!numbersFound) {
		return false;
	}
	
	return true;
}
