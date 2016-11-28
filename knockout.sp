#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <smlib>

public Plugin myinfo =
{
	name = "Knockout",
	author = "Zipcore & Bara",
	description = "",
	version = "1.0.0",
	url = ""
}

int g_CollisionGroup;
int g_Freeze;

bool g_bKnockout[MAXPLAYERS+1] = {false, ...};
int g_iRagdoll[MAXPLAYERS+1] = {-1, ...};

UserMsg g_FadeUserMsgId;
int ClientCamera[MAXPLAYERS+1];
char Attachment[]= "forward";

public void OnPluginStart()
{
	g_CollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	if (g_CollisionGroup == -1)
		SetFailState("CBaseEntity:m_CollisionGroup not found");

	g_Freeze = FindSendPropInfo("CBasePlayer", "m_fFlags");
	if(g_Freeze == -1)
		SetFailState("CBasePlayer:m_fFlags not found");

	g_FadeUserMsgId = GetUserMessageId("Fade");

	RegConsoleCmd("sm_ragdoll", Command_Ragdoll);

	for(new i=1;i<=MaxClients;i++)
	{
		if(IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action Command_Ragdoll(int client, int args)
{
	KnockoutPlayer(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	int iInitialButtons = buttons;

	char sWeapon[64];
	Client_GetActiveWeaponName(client, sWeapon, sizeof(sWeapon));

	if(GetClientTeam(client) == CS_TEAM_CT && buttons & IN_ATTACK && StrEqual(sWeapon, "taser", true))
	{
		int target = GetClientAimTarget(client);

		if(target != -1 && !g_bKnockout[target] && GetClientTeam(target) == CS_TEAM_T)
		{
			if(Entity_InRange(client, target, 64.0))
			{
				buttons &= ~IN_ATTACK;
				KnockoutPlayer(target);
			}
		}
	}

	if(iInitialButtons != buttons)
		return Plugin_Changed;
	else
		return Plugin_Continue;
}

void KnockoutPlayer(int client)
{
	g_bKnockout[client] = true;

	char sModel[256];
	GetClientModel(client, sModel, sizeof(sModel));

	float pos[3];
	GetClientEyePosition(client, pos);

	int iEntity = CreateEntityByName("prop_ragdoll");
	DispatchKeyValue(iEntity, "model", sModel);
	DispatchKeyValue(iEntity, "targetname", "fake_body");
	SetEntProp(iEntity, Prop_Data, "m_nSolidType", 6);
	SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 5);
	DispatchSpawn(iEntity);

	pos[2] -= 16.0;
	TeleportEntity(iEntity, pos, NULL_VECTOR, NULL_VECTOR);
	Entity_SetNoblockable(iEntity);

	g_iRagdoll[client] = iEntity;
	Entity_SetNoblockable(client);
	SetEntityRenderMode(client, RENDER_NONE);
	StripPlayerWeapons(client);
	Entity_SetNonMoveable(client);

	CreateTimer(5.0, Timer_Delete, client, TIMER_FLAG_NO_MAPCHANGE);

	SpawnCamAndAttach(client, iEntity);

	PerformBlind(client, 255);
}

public Action OnWeaponCanUse(int client, int weapon)
{
	if(!IsClientInGame(client))
		return Plugin_Continue;

	int team = GetClientTeam(client);

	if(team <= CS_TEAM_SPECTATOR)
		return Plugin_Continue;

	if(g_bKnockout[client])
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(g_bKnockout[victim])
		return Plugin_Handled;

	return Plugin_Continue;
}

public Action Timer_Delete(Handle timer, any client)
{
	int entity = g_iRagdoll[client];

	if (entity != -1 && IsValidEntity(entity))
		AcceptEntityInput(entity, "kill");

	g_iRagdoll[client] = -1;
	g_bKnockout[client] = false;

	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		Entity_SetBlockable(client);
		Entity_SetMoveable(client);
		SetClientViewEntity(client, client);
		ClientCamera[client] = false;
		PerformBlind(client, 0);
	}
}

stock void Entity_SetNonMoveable(int entity)
{
	SetEntData(entity, g_Freeze, FL_CLIENT|FL_ATCONTROLS, 4, true);
}

stock void Entity_SetMoveable(int entity)
{
	SetEntData(entity, g_Freeze, FL_FAKECLIENT|FL_ONGROUND|FL_PARTIALGROUND, 4, true);
}

stock void Entity_SetNoblockable(int entity)
{
	SetEntData(entity, g_CollisionGroup, 2, 4, true);
}

stock void Entity_SetBlockable(int entity)
{
	SetEntData(entity, g_CollisionGroup, 5, 4, true);
}

stock void StripPlayerWeapons(int client)
{
	int iWeapon = -1;
	for(new i=CS_SLOT_PRIMARY;i<=CS_SLOT_C4;i++)
	{
		while((iWeapon = GetPlayerWeaponSlot(client, i)) != -1)
		{
			CS_DropWeapon(client, iWeapon, true, true);
		}
	}
}

stock bool SpawnCamAndAttach(int Client, int Ragdoll)
{
	char StrModel[64];
	Format(StrModel, sizeof(StrModel), "models/blackout.mdl");
	PrecacheModel(StrModel, true);

	char StrName[64]; Format(StrName, sizeof(StrName), "fpd_Ragdoll%d", Client);
	DispatchKeyValue(Ragdoll, "targetname", StrName);

	int Entity = CreateEntityByName("prop_dynamic");
	if (Entity == -1)
		return false;

	char StrEntityName[64]; Format(StrEntityName, sizeof(StrEntityName), "fpd_RagdollCam%d", Entity);

	DispatchKeyValue(Entity, "targetname", StrEntityName);
	DispatchKeyValue(Entity, "parentname", StrName);
	DispatchKeyValue(Entity, "model",	  StrModel);
	DispatchKeyValue(Entity, "solid",	  "0");
	DispatchKeyValue(Entity, "rendermode", "10"); // dont render
	DispatchKeyValue(Entity, "disableshadows", "1"); // no shadows

	float angles[3]; GetClientEyeAngles(Client, angles);
	char CamTargetAngles[64];
	Format(CamTargetAngles, 64, "%f %f %f", angles[0], angles[1], angles[2]);
	DispatchKeyValue(Entity, "angles", CamTargetAngles);

	SetEntityModel(Entity, StrModel);
	DispatchSpawn(Entity);

	SetVariantString(StrName);
	AcceptEntityInput(Entity, "SetParent", Entity, Entity, 0);

	SetVariantString(Attachment);
	AcceptEntityInput(Entity, "SetParentAttachment", Entity, Entity, 0);

	AcceptEntityInput(Entity, "TurnOn");

	SetClientViewEntity(Client, Entity);
	ClientCamera[Client] = Entity;

	return true;
}

void PerformBlind(int client, int amount)
{
	int targets[2];
	targets[0] = client;

	int duration = 1536;
	int holdtime = 1536;
	int flags;
	if (amount == 0)
		flags = (0x0001 | 0x0010);
	else flags = (0x0002 | 0x0008);

	int color[4] = { 0, 0, 0, 0 };
	color[3] = amount;

	Handle message = StartMessageEx(g_FadeUserMsgId, targets, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", duration);
		PbSetInt(message, "hold_time", holdtime);
		PbSetInt(message, "flags", flags);
		PbSetColor(message, "clr", color);
	}
	else
	{
		BfWriteShort(message, duration);
		BfWriteShort(message, holdtime);
		BfWriteShort(message, flags);
		BfWriteByte(message, color[0]);
		BfWriteByte(message, color[1]);
		BfWriteByte(message, color[2]);
		BfWriteByte(message, color[3]);
	}

	EndMessage();
}
