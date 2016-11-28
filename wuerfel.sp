#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <cstrike>
#include <sdkhooks>
#include <emitsoundany>

#pragma newdecls required

#define TAG_COLOR "{darkred}"
#define HIGH_COLOR "{orchid}"
#define TEXT_COLOR "{green}"
#define DICE_SOUND     "ngx/dice/dice.mp3"
#define NEGATIVE_SOUND "ngx/dice/negative.mp3"
#define POSITIVE_SOUND "ngx/dice/positive.mp3"
#define TITLE    "Dice"

enum FX
{
	FxNone = 0,
	FxPulseFast,
	FxPulseSlowWide,
	FxPulseFastWide,
	FxFadeSlow,
	FxFadeFast,
	FxSolidSlow,
	FxSolidFast,
	FxStrobeSlow,
	FxStrobeFast,
	FxStrobeFaster,
	FxFlickerSlow,
	FxFlickerFast,
	FxNoDissipation,
	FxDistort,					// Distort/scale/translate flicker
	FxHologram,					// kRenderFxDistort + distance fade
	FxExplode,					// Scale up really big!
	FxGlowShell,				// Glowing Shell
	FxClampMinScale,		// Keep this sprite from getting very small (SPRITES only!)
	FxEnvRain,					// for environmental rendermode, make rain
	FxEnvSnow,					// for environmental rendermode, make snow
	FxSpotlight,
	FxRagdoll,
	FxPulseFastWider,
};

enum Render
{
	Normal = 0, 				// src
	TransColor, 				// c*a+dest*(1-a)
	TransTexture,				// src*a+dest*(1-a)
	Glow,								// src*a+dest -- No Z buffer checks -- Fixed size in screen space
	TransAlpha,					// src*srca+dest*(1-srca)
	TransAdd,						// src*a+dest
	Environmental,			// not drawn, used for environmental effects
	TransAddFrameBlend,	// use a fractional frame value to blend between animation frames
	TransAlphaAdd,			// src + dest*(1-a)
	WorldGlow,					// Same as kRenderGlow but not fixed size in screen space
	None,								// Don't render.
};

bool g_bDice[MAXPLAYERS+1] = {false, ...};
bool LastT[MAXPLAYERS+1] = {false, ...};
bool HE[MAXPLAYERS+1] = {false, ...};
bool DoubleDamage[MAXPLAYERS+1] = {false, ...};
bool DoubleDamageE[MAXPLAYERS+1] = {false, ...};
bool NoHSDMG[MAXPLAYERS+1] = {false, ...};
bool NoDamage[MAXPLAYERS+1] = {false, ...};
bool NoSelfHS[MAXPLAYERS+1] = {false, ...};
bool HalfSelfDMG[MAXPLAYERS+1] = {false, ...};
bool HalfDMG[MAXPLAYERS+1] = {false, ...};
bool NoWeaponUse[MAXPLAYERS+1] = {false, ...};
bool bZombie[MAXPLAYERS+1] = {false, ...};
bool Respawn[MAXPLAYERS+1] = {false, ...};
bool Nightvision[MAXPLAYERS+1] = {false, ...};
bool Godmode[MAXPLAYERS+1] = {false, ...};
bool AmmoInfi[MAXPLAYERS+1] = {false, ...};
bool Busy[MAXPLAYERS+1] = {false, ...};
Handle AmmoTimer;
int NoclipCounter[MAXPLAYERS+1];
Handle g_phTimerClientBeacons[MAXPLAYERS+1] = {null, ...};
Handle DiscoColor[MAXPLAYERS+1] = {null, ...};
Handle RespawnTimer[MAXPLAYERS+1] = {null, ...};
Handle SlapTimer[MAXPLAYERS+1] = {null, ...};
Handle DrugTimer[MAXPLAYERS+1] = {null, ...};
Handle BitchSlap[MAXPLAYERS+1] = {null, ...};
Handle SlapDMG[MAXPLAYERS+1] = {null, ...};
Handle DiceTimer[MAXPLAYERS + 1] =  { null, ... };
bool g_bCustomModel[MAXPLAYERS + 1] =  { false, ... };
int BeamSprite;
int HaloSprite;
int activeOffset = -1;
int clip1Offset = -1;
int clip2Offset = -1;
int secAmmoTypeOffset = -1;
int priAmmoTypeOffset = -1;
bool auto[MAXPLAYERS+1] = {false, ...};
bool bDebug = false;

int g_iCustomOption[MAXPLAYERS + 1] = -1;

public Plugin myinfo =
{
	name = "Dice",
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Wuerfel_ClientReset", Native_ClientReset);
	
	RegPluginLibrary("wuerfel");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_rtd", Command_Dice);
	RegConsoleCmd("sm_w", Command_Dice);
	RegConsoleCmd("sm_dice", Command_Dice);
	
	RegConsoleCmd("sm_wdebug", Command_Debug);
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("round_end", RoundEnd); // bad idea
	HookEvent("player_death", PlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", PlayerDeath);
	HookEvent("player_disconnect", PlayerDisconnect);
	HookEvent("hegrenade_detonate", HEGrenade, EventHookMode_Pre);
	activeOffset = FindSendPropInfo("CAI_BaseNPC", "m_hActiveWeapon");
	clip1Offset = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	clip2Offset = FindSendPropInfo("CBaseCombatWeapon", "m_iClip2");
	priAmmoTypeOffset = FindSendPropInfo("CBaseCombatWeapon", "m_iPrimaryAmmoCount");
	secAmmoTypeOffset = FindSendPropInfo("CBaseCombatWeapon", "m_iSecondaryAmmoCount");
}

public void OnMapStart()
{
	BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	HaloSprite = PrecacheModel("materials/sprites/halo.vmt");

	PrecacheModel("models/props/de_train/barrel.mdl");
	PrecacheModel("models/chicken/chicken_zombie.mdl");
	PrecacheModel("models/props/cs_office/vending_machine.mdl");
	PrecacheModel("models/props/cs_office/sofa.mdl");
	PrecacheModel("models/props/cs_office/bookshelf1.mdl");
	PrecacheModel("models/props/cs_office/chair_office.mdl");
	PrecacheModel("models/props/cs_office/computer_monitor.mdl");
	PrecacheModel("models/props/cs_office/computer_caseb.mdl");
	PrecacheModel("models/props/cs_office/ladder1.mdl");
	PrecacheModel("models/props/de_dust/dust_rusty_barrel.mdl");
	PrecacheModel("models/props/cs_office/tv_plasma.mdl");
	
	/* PrecacheModel("models/player/custom_player/legacy/security/security.mdl");
	AddFileToDownloadsTable("models/player/custom_player/legacy/security/security.mdl");
	AddFileToDownloadsTable("models/player/custom_player/legacy/security/security.dx90.vtx");
	AddFileToDownloadsTable("models/player/custom_player/legacy/security/security.phy");
	AddFileToDownloadsTable("models/player/custom_player/legacy/security/security.vvd");
	AddFileToDownloadsTable("materials/models/player/custom/security/Diff00_2.vmt");
	AddFileToDownloadsTable("materials/models/player/custom/security/Diff00_2.vtf");
	AddFileToDownloadsTable("materials/models/player/custom/security/Norm00_2.vtf"); */
    
	PrecacheSoundAny("weapons/rpg/rocketfire1.wav");
	PrecacheSoundAny("weapons/rpg/rocket1.wav");
	PrecacheSoundAny("weapons/hegrenade/explode3.wav");
	
	PrecacheSoundAny("ambient/tones/floor1.wav");
	PrecacheSoundAny(DICE_SOUND);
	PrecacheSoundAny(POSITIVE_SOUND);
	PrecacheSoundAny(NEGATIVE_SOUND);
	PrecacheSoundAny("sound/weapons/rpg/rocketfire1.wav");
	PrecacheSoundAny("sound/weapons/rpg/rocket1.wav");
	PrecacheSoundAny("sound/weapons/hegrenade/explode3.wav");
	PrecacheSoundAny("sound/ambient/tones/floor1.wav");
	AddFileToDownloadsTable("sound/" ... NEGATIVE_SOUND);
	AddFileToDownloadsTable("sound/" ... POSITIVE_SOUND);
	AddFileToDownloadsTable("sound/" ... DICE_SOUND);

	if (AmmoTimer)
	{
		KillTimer(AmmoTimer, false);
	}
	
	AmmoTimer = CreateTimer(1.0, ResetAmmo, _, TIMER_REPEAT);
}

public void OnClientDisconnect(int client)
{
	Dice_Reset(client);
}

void fReset(int client)
{
	if (!IsClientInGame(client)) 
		return;
	
	float pos[3];
	float angs[3];
	
	freeze(client, false, 0.0);
	godmode(client, false);

	ExtinguishEntity(client);
	ClientCommand(client, "r_screenoverlay 0");
	
	GetClientAbsOrigin(client, pos);
	GetClientEyeAngles(client, angs);

	SetEntProp(client, Prop_Send, "m_iDefaultFOV", 90);
	
	angs[2] = 0.0;
	
	TeleportEntity(client, pos, angs, NULL_VECTOR);	
	
	Handle message = StartMessageOne("Fade", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
			
	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
	{
		PbSetInt(message, "duration", 1536);
		PbSetInt(message, "hold_time", 1536);
		PbSetInt(message, "flags", (0x0001 | 0x0010));
		PbSetColor(message, "clr", {0, 0, 0, 0});
	}
	else
	{
		BfWriteShort(message, 1536);
		BfWriteShort(message, 1536);
		BfWriteShort(message, (0x0001 | 0x0010));
		BfWriteByte(message, 0);
		BfWriteByte(message, 0);
		BfWriteByte(message, 0);
		BfWriteByte(message, 0);
	}

	EndMessage();
	
	message = StartMessageOne("Shake", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
	{
		PbSetInt(message, "command", 1);
		PbSetFloat(message, "local_amplitude", 0.0);
		PbSetFloat(message, "frequency", 0.0);
		PbSetFloat(message, "duration", 1.0);
	}
	else
	{
		BfWriteByte(message, 1);
		BfWriteFloat(message, 0.0);
		BfWriteFloat(message, 0.0);
		BfWriteFloat(message, 1.0);
	}
	
	EndMessage();
	g_iCustomOption[client] = -1;
}

void freeze(int client, bool turnOn, float time)
{	
	if (IsClientInGame(client))
	{
		if (turnOn)
		{
			SetEntityMoveType(client, MOVETYPE_NONE);
			
			if (time > 0) 
				CreateTimer(time, freezeOff, client);
		}
		else
			SetEntityMoveType(client, MOVETYPE_WALK);
	}
}

public Action freezeOff(Handle timer, any client)
{
	freeze(client, false, 0.0);
	
	return Plugin_Handled;
}

void burn(int client, int health)
{
	float time = float(health) / 5.0;
	
	if (health < 100) 
		IgniteEntity(client, time);
	else 
		IgniteEntity(client, 100.0);
}

void rocket(int client)
{
	float Origin[3];
	
	GetClientAbsOrigin(client, Origin);
	
	Origin[2] = Origin[2] + 20;
	
	godmode(client, true);
	shake(client, 10, 40, 25);
	
	EmitSoundToAll("weapons/rpg/rocketfire1.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	
	CreateTimer(1.0, PlayRocketSound, client);
	CreateTimer(3.1, EndRocket, client);
}

void godmode(int client, bool turnOn)
{
	if (turnOn) 
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	else
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
}

void shake(int client, int time, int distance, int value)
{
	Handle message = StartMessageOne("Shake", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
	{
		PbSetInt(message, "command", 0);
		PbSetFloat(message, "local_amplitude", float(value));
		PbSetFloat(message, "frequency", float(distance));
		PbSetFloat(message, "duration", float(time));
	}
	else
	{
		BfWriteByte(message, 0);
		BfWriteFloat(message, float(value));
		BfWriteFloat(message, float(distance));
		BfWriteFloat(message, float(time));
	}
	
	EndMessage();	
}

public Action PlayRocketSound(Handle timer, int client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) 
		return;
	
	float Origin[3];
	
	GetClientAbsOrigin(client, Origin);
	
	Origin[2] = Origin[2] + 50;
	
	EmitSoundToAll("weapons/rpg/rocket1.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	
	for (int x=1; x <= 15; x++) 
		CreateTimer(0.2*x, rocket_loop, client);
	
	TeleportEntity(client, Origin, NULL_VECTOR, NULL_VECTOR);
}

public Action EndRocket(Handle timer, int client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;
	
	float Origin[3];
	
	GetClientAbsOrigin(client, Origin);
	
	Origin[2] = Origin[2] + 50;
	
	for (int x=1; x <= MaxClients; x++)
	{
		if (IsClientConnected(x)) 
			StopSound(x, SNDCHAN_AUTO, "weapons/rpg/rocket1.wav");
	}
	
	EmitSoundToAll("weapons/hegrenade/explode3.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
	
	int expl = CreateEntityByName("env_explosion");
	
	TeleportEntity(expl, Origin, NULL_VECTOR, NULL_VECTOR);
	
	DispatchKeyValue(expl, "fireballsprite", "sprites/zerogxplode.spr");
	DispatchKeyValue(expl, "spawnflags", "0");
	DispatchKeyValue(expl, "iMagnitude", "1000");
	DispatchKeyValue(expl, "iRadiusOverride", "100");
	DispatchKeyValue(expl, "rendermode", "0");
	
	DispatchSpawn(expl);
	ActivateEntity(expl);
	
	AcceptEntityInput(expl, "Explode");
	AcceptEntityInput(expl, "Kill");
	
	godmode(client, false);
	ForcePlayerSuicide(client);

	return Plugin_Handled;
}

public Action rocket_loop(Handle timer, int client)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;
		
	float velocity[3];
	
	velocity[2] = 300.0;
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
	
	return Plugin_Handled;
}

bool IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients)
		if (IsClientInGame(client))
			return true;
	return false;
}

bool IsClientValidAlive(int client)
{
	if (IsClientValid(client))
		if (IsPlayerAlive(client))
			return true;
	return false;
}

public Action Command_Debug(int client, int args)
{
	if(bDebug && !CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT, true))
		return Plugin_Handled;
	
	PrintToChat(client, "You suck hard!");
	char option[12];
	GetCmdArg(1, option, sizeof(option));
	g_iCustomOption[client] = StringToInt(option);
	Busy[client] = true;
	DiceTimer[client] = CreateTimer(1.0, tWuerfel, client);
	
	return Plugin_Continue;
}

public Action Command_Dice(int client, int args)
{
	if (IsClientValid(client))
	{
		if (GetClientTeam(client) == CS_TEAM_T)
		{
			if (!g_bDice[client])
			{
				if(!Busy[client] || DiceTimer[client] != null)
				{
					if (IsPlayerAlive(client))
					{
						EmitSoundToClientAny(client, DICE_SOUND);
						Handle hPanel = CreatePanel();
						SetPanelTitle(hPanel, "Bitte warten...");
						DrawPanelText(hPanel, "(Glücksspiel kann süchtig machen)");
						SendPanelToClient(hPanel, client, PanelHandler, 10);
						CloseHandle(hPanel);
						Busy[client] = true;
						DiceTimer[client] = CreateTimer(2.0, tWuerfel, client);
					}
					else
						CPrintToChat(client, "%s[%s] %sSie sind nicht am leben!", TAG_COLOR, TITLE, TEXT_COLOR);
				}
				else
					CPrintToChat(client, "%s[%s] %sDer Würfel rollt gerade...", TAG_COLOR, TITLE, TEXT_COLOR);
			}
			else
				CPrintToChat(client, "%s[%s] %sSie haben bereits gewürfelt!", TAG_COLOR, TITLE, TEXT_COLOR);
		}
		else
			CPrintToChat(client, "%s[%s] %sSie müssen ein T sein um zu würfeln!!", TAG_COLOR, TITLE, TEXT_COLOR);
	}
	return Plugin_Continue;
}

public Action HEGrenade(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (HE[client])
	{
		GivePlayerItem(client, "weapon_hegrenade");
	}
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(bDebug)
		for (int count = 0; count <= 10; count++)
			PrintToChatAll("Dice Debug enabled!");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientValid(client))
		{
			Dice_Reset(client);
		}
	}
}

public Action PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(IsClientValid(client))
	{
		Dice_Reset(client);
	}
	
	CreateTimer(1.0, Timer_CheckKnife, GetClientUserId(client));
}

public Action Timer_CheckKnife(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(IsClientValid(client))
	{
		if(GetClientTeam(client) == CS_TEAM_T && !NoWeaponUse[client])
		{
			int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
			if (iWeapon == INVALID_ENT_REFERENCE)
			{
				int weapon = GivePlayerItem(client, "weapon_knife");
				EquipPlayerWeapon(client, weapon);
			}
		}
	}
}

public Action PlayerDeathPre(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(IsClientValid(client))
	{
		if(!g_bCustomModel[client])
			return Plugin_Continue;
		
		int iEntity = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
		
		if(iEntity > 0 && IsValidEdict(iEntity))
			AcceptEntityInput(iEntity, "Kill");
	}
	return Plugin_Continue;
}

public Action PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0);
	if (Respawn[client])
	{
		RespawnTimer[client] = CreateTimer(0.3, RespawnPlayer, client);
	}
	if (GetTeamClientCount(2) == 1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientValidAlive(i))
			{
				if (LastT[i])
				{
					ForcePlayerSuicide(i);
				}
			}
		}
	}
	
	if (IsClientValid(client))
	{
		Dice_Reset(client);
	}
	
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (ragdoll<0)
		return Plugin_Continue;
	RemoveEdict(ragdoll);
	
	return Plugin_Continue;
}

public Action PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientValid(client))
	{
		Dice_Reset(client);
	}
}

void drug(int client)
{
	DrugTimer[client] = CreateTimer(1.0, drug_loop, client, TIMER_REPEAT);	
}

public Action drug_loop(Handle timer, any client)
{
	if (!IsClientInGame(client)) 
		return Plugin_Stop;
	
	float DrugAngles[20] = {0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 20.0, 15.0, 10.0, 5.0, 0.0, -5.0, -10.0, -15.0, -20.0, -25.0, -20.0, -15.0, -10.0, -5.0};

	if (!IsPlayerAlive(client))
	{
		float pos[3];
		float angs[3];
		
		GetClientAbsOrigin(client, pos);
		GetClientEyeAngles(client, angs);
		
		angs[2] = 0.0;
		
		TeleportEntity(client, pos, angs, NULL_VECTOR);	
		
		Handle message = StartMessageOne("Fade", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
		
		if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
		{
			PbSetInt(message, "duration", 1536);
			PbSetInt(message, "hold_time", 1536);
			PbSetInt(message, "flags", (0x0001 | 0x0010));
			PbSetColor(message, "clr", {0, 0, 0, 255});
		}
		else
		{
			BfWriteShort(message, 1536);
			BfWriteShort(message, 1536);
			BfWriteShort(message, (0x0001 | 0x0010));
			BfWriteByte(message, 0);
			BfWriteByte(message, 0);
			BfWriteByte(message, 0);
			BfWriteByte(message, 0);
		}
		
		EndMessage();	
		
		return Plugin_Stop;
	}
	
	float pos[3];
	float angs[3];
	int coloring[4];

	coloring[0] = GetRandomInt(0,255);
	coloring[1] = GetRandomInt(0,255);
	coloring[2] = GetRandomInt(0,255);
	coloring[3] = 128;
	
	GetClientAbsOrigin(client, pos);
	GetClientEyeAngles(client, angs);
	
	angs[2] = DrugAngles[GetRandomInt(0,100) % 20];
	
	TeleportEntity(client, pos, angs, NULL_VECTOR);

	Handle message = StartMessageOne("Fade", client);

	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
	{
		PbSetInt(message, "duration", 255);
		PbSetInt(message, "hold_time", 255);
		PbSetInt(message, "flags", (0x0002));
		PbSetColor(message, "clr", coloring);
	}
	else
	{
		BfWriteShort(message, 255);
		BfWriteShort(message, 255);
		BfWriteShort(message, (0x0002));
		BfWriteByte(message, GetRandomInt(0,255));
		BfWriteByte(message, GetRandomInt(0,255));
		BfWriteByte(message, GetRandomInt(0,255));
		BfWriteByte(message, 128);
	}
	
	EndMessage();	
		
	return Plugin_Handled;
}

void SetGlow(int client, FX fx = FxNone, int r = 255, int g = 255, int b = 255, Render render = Normal, int nAmount = 255)
{
	SetEntProp(client, Prop_Send, "m_nRenderFX", fx, 1);
	SetEntProp(client, Prop_Send, "m_nRenderMode", render, 1);

	int nOffsetClrRender = GetEntSendPropOffs(client, "m_clrRender");
	SetEntData(client, nOffsetClrRender, r, 1, true);
	SetEntData(client, nOffsetClrRender + 1, g, 1, true);
	SetEntData(client, nOffsetClrRender + 2, b, 1, true);
	SetEntData(client, nOffsetClrRender + 3, nAmount, 1, true);
}

public Action TimerBeacon(Handle timer, any nClient)
{
	if(IsClientConnected(nClient) && IsClientInGame(nClient) && IsPlayerAlive(nClient))
	{
		// beacon effect...
		float pfEyePosition[3];
		GetClientEyePosition(nClient, pfEyePosition);

#if defined(SOUND_BEACON)
		EmitAmbientSound(SOUND_BEACON, pfEyePosition, SOUND_FROM_WORLD, SNDLEVEL_ROCKET);
#endif

		float pfAbsOrigin[3];
		GetClientAbsOrigin(nClient, pfAbsOrigin);
		pfAbsOrigin[2] += 5.0;

		TE_Start("BeamRingPoint");
		TE_WriteVector("m_vecCenter", pfAbsOrigin);
		TE_WriteFloat("m_flStartRadius", 20.0);
		TE_WriteFloat("m_flEndRadius", 400.0);
		TE_WriteNum("m_nModelIndex", BeamSprite);
		TE_WriteNum("m_nHaloIndex", HaloSprite);
		TE_WriteNum("m_nStartFrame", 0);
		TE_WriteNum("m_nFrameRate", 0);
		TE_WriteFloat("m_fLife", 1.0);
		TE_WriteFloat("m_fWidth", 3.0);
		TE_WriteFloat("m_fEndWidth", 3.0);
		TE_WriteFloat("m_fAmplitude", 0.0);
		TE_WriteNum("r", 128);
		TE_WriteNum("g", 255);
		TE_WriteNum("b", 128);
		TE_WriteNum("a", 192);
		TE_WriteNum("m_nSpeed", 100);
		TE_WriteNum("m_nFlags", 0);
		TE_WriteNum("m_nFadeLength", 0);
		TE_SendToAll();
	}
	else
	{
		KillTimer(timer);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public int PanelHandlerSpawn(Menu hPanel, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 1)
		{
			ClientCommand(param1, "say /w");
		}
		if (param2 == 2)
		{
			CloseHandle(hPanel);
		}
	}
	if (action == MenuAction_Cancel)
	{
		CloseHandle(hPanel);
	}
	return 0;
}

public int PanelHandler(Menu hPanel, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Cancel)
	{
		CloseHandle(hPanel);
	}
	return 0;
}

public Action SlapTimerPlayer(Handle timer, int client)
{
	if (IsClientValid(client))
	{
		if (SlapTimer[client] != null)
		{
			if(IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_T)
			{
				SlapPlayer(client, 0, true);
				return Plugin_Continue;
			}
		}
	}
	SlapTimer[client] = null;
	return Plugin_Stop;
}

public Action TimerBitchSlap(Handle timer, int client)
{
	if (IsClientValid(client))
	{
		if (BitchSlap[client] != null)
		{
			if(IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_T)
			{
				SlapPlayer(client, 0, true);
				return Plugin_Continue;
			}
		}
	}
	BitchSlap[client] = null;
	return Plugin_Stop;
}

public Action DMGSlapTimerPlayer(Handle timer, int client)
{
	if (IsClientValid(client))
	{
		if (SlapDMG[client] != null)
		{
			if(IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_T)
			{
				SlapPlayer(client, 5, true);
				return Plugin_Continue;
			}
		}
	}
	SlapDMG[client] = null;
	return Plugin_Stop;
}

public Action tWuerfel(Handle timer, int client)
{
	if (IsClientValid(client) && DiceTimer[client] != null)
	{
		SetRandomSeed(GetTime());
		int rand = 1;
		rand = GetRandomInt(1, 89);
		rand = GetRandomInt(1, 89);
		Busy[client] = false;
		
		if(bDebug)
			PrintToChat(client, "Rand: %d - Custom: %d", rand, g_iCustomOption[client]);
			
		if(g_iCustomOption[client] >= 0)
			rand = g_iCustomOption[client];
		
		if(bDebug)
			PrintToChat(client, "Rand: %d - Custom: %d", rand, g_iCustomOption[client]);
		
		if(bDebug)
			PrintToChat(client, "Würfel Option: %d", rand);
		
		LogMessage("[Dice] Player: \"%L\" Option: %d 1/2", client, rand);
		
		if (rand == 1)
		{
			g_bDice[client] = true;
			EmitSoundToClientAny(client, NEGATIVE_SOUND);

			SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
		}
		else
		{
			if (rand == 2)
			{
				int rHP = GetRandomInt(1, 50);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie haben %d HP bekommen!", rHP);
				g_bDice[client] = true;
				SetEntityHealth(client, GetClientHealth(client) + rHP);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 3)
			{
				int rHP = GetRandomInt(1, 50);
				float rSpeed = GetRandomFloat(0.01, 0.2);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie bekommen %d HP und sind %.0f Prozent schneller!", rHP, rSpeed * 100);
				g_bDice[client] = true;
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", rSpeed + 1, 0);
				SetEntityHealth(client, GetClientHealth(client) + rHP);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 4)
			{
				float rSpeed = GetRandomFloat(0.01, 0.2);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %.0f Prozent schneller!", rSpeed * 100);
				g_bDice[client] = true;
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", rSpeed + 1, 0);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 5)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
			}
			if (rand == 6)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, POSITIVE_SOUND);

				SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
			}
			if (rand == 7)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
			}
			if (rand == 8)
			{
				float rSpeed = GetRandomFloat(0.1, 0.3);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %.0f Prozent langsamer!", rSpeed * 100);
				g_bDice[client] = true;
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1 - rSpeed, 0);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 9)
			{
				int rHP = GetRandomInt(1, 50);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie bekommen %d HP!", rHP);
				g_bDice[client] = true;
				SetEntityHealth(client, GetClientHealth(client) + rHP);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 10)
			{
				int rHP = GetRandomInt(1, 50);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie haben nun %d HP!", rHP);
				g_bDice[client] = true;
				SetEntityHealth(client, rHP);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 11)
			{
				float rSpeed = GetRandomFloat(0.1, 0.3);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %.0f Prozent langsamer!", rSpeed * 100);
				g_bDice[client] = true;
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1 - rSpeed, 0);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 12)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
			}
			if (rand == 13)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
			}
			if (rand == 14)
			{
				g_bDice[client] = true;
				
				int ent = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);

				if (ent == -1)
					ent = client;
				
				TE_SetupBeamFollow(ent, BeamSprite, HaloSprite, 10.0, 4.0, 4.0, 3, {0, 255, 0, 255});
				TE_SendToAll();
				EmitSoundToClientAny(client, NEGATIVE_SOUND);

				SendDicePanel(rand, client, TITLE, "Ein grüner Laser verfolgt Sie nun!");
			}
			if (rand == 15)
			{
				g_bDice[client] = true;
				
				int ent = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);

				if (ent == -1)
					ent = client;
				
				TE_SetupBeamFollow(ent, BeamSprite, HaloSprite, 10.0, 4.0, 4.0, 3, {255, 0, 0, 255});
				TE_SendToAll();
				EmitSoundToClientAny(client, NEGATIVE_SOUND);

				SendDicePanel(rand, client, TITLE, "Ein roter Laser verfolgt Sie nun!");
			}
			if (rand == 16)
			{
				g_bDice[client] = true;
				
				int ent = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);

				if (ent == -1)
					ent = client;
				
				TE_SetupBeamFollow(ent, BeamSprite, HaloSprite, 10.0, 4.0, 4.0, 3, {0, 0, 255, 255});
				TE_SendToAll();
				EmitSoundToClientAny(client, NEGATIVE_SOUND);

				SendDicePanel(rand, client, TITLE, "Ein blauer Laser verfolgt Sie nun!");
			}
			if (rand == 17)
			{
				int rHP = GetRandomInt(30, 70);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie haben %d HP verloren!", rHP);
				g_bDice[client] = true;
				if((GetClientHealth(client) - rHP) > 0)
					SetEntityHealth(client, GetClientHealth(client) - rHP);
				else
					ForcePlayerSuicide(client);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 18)
			{
				int rHP = GetRandomInt(30, 70);
				float rSpeed = GetRandomFloat(0.1, 0.3);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie haben %d HP verloren und sind %.0f Prozent langsamer!", rHP, rSpeed * 100);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				g_bDice[client] = true;
				if((GetClientHealth(client) - rHP) > 0)
					SetEntityHealth(client, GetClientHealth(client) - rHP);
				else
					ForcePlayerSuicide(client);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1 - rSpeed, 0);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 19)
			{
				int rHP = GetRandomInt(10, 50);
				float rSpeed = GetRandomFloat(0.1, 0.2);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie haben %d HP bekommen und sind %.0f Prozent schneller!", rHP, rSpeed * 100);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				g_bDice[client] = true;
				SetEntityHealth(client, GetClientHealth(client) + rHP);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", rSpeed + 1, 0);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 20)
			{
				float rSpeed = GetRandomFloat(0.1, 0.2);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %.0f Prozent schneller und werden von ein grünen Laser verfolgt!", rSpeed * 100);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				g_bDice[client] = true;
				
				int ent = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);

				if (ent == -1)
					ent = client;
				
				TE_SetupBeamFollow(ent, BeamSprite, HaloSprite, 10.0, 4.0, 4.0, 3, {0, 255, 0, 255});
				TE_SendToAll();
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", rSpeed + 1, 0);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 21)
			{
				float rGrav = GetRandomFloat(0.05, 0.2);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %.0f Prozent leichter!", rGrav * 100);
				g_bDice[client] = true;
				SetEntityGravity(client, 1 - rGrav);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 22)
			{
				float rGrav = GetRandomFloat(0.1, 0.5);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %.0f Prozent schwerer!", rGrav * 100);
				g_bDice[client] = true;
				SetEntityGravity(client, rGrav + 1);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 23)
			{
				g_bDice[client] = true;
				ClientCommand(client, "r_screenoverlay effects/redflare.vmt");
				EmitSoundToClientAny(client, NEGATIVE_SOUND);

				SendDicePanel(rand, client, TITLE, "Sie haben ein rot/grünen Punkt vor Augen!?");
			}
			if (rand == 24)
			{
				g_bDice[client] = true;
				ForcePlayerSuicide(client);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);

				SendDicePanel(rand, client, TITLE, "Da sind Sie vor Schreck umgefallen!");
			}
			if (rand == 25)
			{
				g_bDice[client] = true;
				
				int iItem = GivePlayerItem(client, "weapon_deagle");
				EquipPlayerWeapon(client, iItem);
				
				Weapon_SetAmmo(iItem, 0);
				Weapon_SetReserveAmmo(iItem, 0);
				
				EmitSoundToClientAny(client, NEGATIVE_SOUND);

				SendDicePanel(rand, client, TITLE, "Sie haben eine Deagle bekommen! Viel Glück ;)");
			}
			if (rand == 26)
			{
				g_bDice[client] = true;
				
				if(GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != INVALID_ENT_REFERENCE)
				{
					EmitSoundToClientAny(client, NEGATIVE_SOUND);
					SendDicePanel(rand, client, TITLE, "Sie haben eine Niete gezogen!");
				}
				else
				{
					int iItem = GivePlayerItem(client, "weapon_deagle");
					EquipPlayerWeapon(client, iItem);
					EmitSoundToClientAny(client, POSITIVE_SOUND);
					SendDicePanel(rand, client, TITLE, "Sie haben eine Deagle bekommen!");
				}
			}
			if (rand == 27)
			{
				int rTime = GetRandomInt(20, 60);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie werden %d Sekunden geschüttelt!", rTime);
				g_bDice[client] = true;
				shake(client, rTime, 20, 160);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 28)
			{
				float rTime = GetRandomFloat(10.0, 60.0);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %0.f Sekunden eingefroren!", rTime);
				g_bDice[client] = true;
				freeze(client, true, rTime);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 29)
			{
				g_bDice[client] = true;
				rocket(client);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Viel Spass im Weltall!");
			}
			if (rand == 30)
			{
				g_bDice[client] = true;
				burn(client, 70);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie stehen unter Feuer!");
			}
			if (rand == 31)
			{
				g_bDice[client] = true;
				drug(client);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie stehen unter Drogen!");
			}
			if (rand == 32)
			{
				g_bDice[client] = true;
				SetGlow(client, FxNone, 0, 255, 0, Glow, 255);
				SetEntityRenderFx(client, RENDERFX_GLOWSHELL);
				SetEntityRenderMode(client, RENDER_GLOW);
				g_phTimerClientBeacons[client] = CreateTimer(2.0, TimerBeacon, client, TIMER_REPEAT);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie blinken!");
			}
			if (rand == 33)
			{
				g_bDice[client] = true;
				SetEntityModel(client, "models/props/de_train/barrel.mdl");
				g_bCustomModel[client] = true;
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind ein Fass!");
			}
			if (rand == 34)
			{
				g_bDice[client] = true;
				SetEntityHealth(client, 1);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben 1HP!");
			}
			if (rand == 35)
			{
				g_bDice[client] = true;
				SetEntityModel(client, "models/props/cs_office/vending_machine.mdl");
				g_bCustomModel[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind ein Automat!");
			}
			if (rand == 36)
			{
				g_bDice[client] = true;
				SetEntityModel(client, "models/props/cs_office/sofa.mdl");
				g_bCustomModel[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind ein Sofa!");
			}
			if (rand == 37)
			{
				g_bDice[client] = true;
				SetEntityModel(client, "models/props/cs_office/bookshelf1.mdl");
				g_bCustomModel[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind ein Bücherregal!");
			}
			if (rand == 38)
			{
				g_bDice[client] = true;
				SetEntityModel(client, "models/props/cs_office/vending_machine.mdl");
				g_bCustomModel[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind ein Getränkeautomat!");
			}
			if (rand == 39)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				SendDicePanel(rand, client, TITLE, "Sie haben eine Niete gewürfelt... :-(");
				
				// SetEntityModel(client, "models/player/custom_player/legacy/security/security.mdl");
				// EmitSoundToClientAny(client, POSITIVE_SOUND);
				// SendDicePanel(rand, client, TITLE, "Sie haben nun ein CT-Skin!");
			}
			if (rand == 40)
			{
				g_bDice[client] = true;
				DiscoColor[client] = CreateTimer(0.1, Timer_ChangePlayerColor, client, TIMER_REPEAT);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Ihr Körper ändert dauerthaft ihre Farbe!");
			}
			if (rand == 41)
			{
				g_bDice[client] = true;
				Respawn[client] = true;
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Wiedergeburt!");
			}
			if (rand == 42)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Niete...!");
			}
			if (rand == 43)
			{
				g_bDice[client] = true;
				Nightvision[client] = true;
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben ein Nachtsichtgerät!");
			}
			if (rand == 44)
			{
				g_bDice[client] = true;
				SetEntProp(client, Prop_Send, "m_iDefaultFOV", 35, 4, 0);
				SetEntProp(client, Prop_Send, "m_iFOV", 35, 4, 0);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben Zoom Sicht!");
			}
			if (rand == 45)
			{
				g_bDice[client] = true;
				SetEntProp(client, Prop_Send, "m_iDefaultFOV", 200, 4, 0);
				SetEntProp(client, Prop_Send, "m_iFOV", 200, 4, 0);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben eine andere Sicht!");
			}
			if (rand == 46)
			{
				int rHP = GetRandomInt(110, 150);
				float rSpeed = GetRandomFloat(0.1, 0.2);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie haben %d HP, sind %.0f Prozent schneller aber Sie brennen!", rHP, rSpeed * 100);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				g_bDice[client] = true;
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", rSpeed + 1, 0);
				SetEntityHealth(client, rHP);
				burn(client, rHP + -1);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 47)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
			}
			if (rand == 48)
			{
				float rTime = GetRandomFloat(5.0, 10.0);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind für %0.f Sekunden unsterblich!", rTime);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				g_bDice[client] = true;
				Godmode[client] = true;
				SetEntityRenderColor(client, 0, 255, 255, 255);
				CreateTimer(rTime, OpcionNumero16c, client);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 49)
			{
				g_bDice[client] = true;
				AmmoInfi[client] = true;
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben unendlich Munition!");
			}
			if (rand == 50)
			{
				int rHP = GetRandomInt(110, 150);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie haben nun %d HP!", rHP);
				g_bDice[client] = true;
				SetEntityHealth(client, rHP);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 51)
			{
				g_bDice[client] = true;
				GivePlayerItem(client, "weapon_flashbang");
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben nun eine Blendgranate!");
			}
			if (rand == 52)
			{
				g_bDice[client] = true;
				GivePlayerItem(client, "weapon_flashbang");
				GivePlayerItem(client, "weapon_flashbang");
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben nun zwei Blendgranate!");
			}
			if (rand == 53)
			{
				g_bDice[client] = true;
				GivePlayerItem(client, "weapon_smokegrenade");
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben nun eine Rauchgranate!");
			}
			if (rand == 54)
			{
				g_bDice[client] = true;
				GivePlayerItem(client, "weapon_hegrenade");
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben nun eine HE!");
			}
			if (rand == 55)
			{
				g_bDice[client] = true;
				GivePlayerItem(client, "weapon_flashbang");
				GivePlayerItem(client, "weapon_flashbang");
				GivePlayerItem(client, "weapon_smokegrenade");
				GivePlayerItem(client, "weapon_hegrenade");
				EmitSoundToClientAny(client, POSITIVE_SOUND);

				SendDicePanel(rand, client, TITLE, "Sie haben nun:\n+ 2 Blendgranaten\n+ 1 Rauchgranaten\n+ 1 HE");
			}
			if (rand == 56)
			{
				g_bDice[client] = true;
				if(GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != INVALID_ENT_REFERENCE)
				{
					EmitSoundToClientAny(client, NEGATIVE_SOUND);
					SendDicePanel(rand, client, TITLE, "... Niete ...");
				}
				else
				{
					int iItem = GivePlayerItem(client, "weapon_deagle");
					EquipPlayerWeapon(client, iItem);
					EmitSoundToClientAny(client, POSITIVE_SOUND);
					SendDicePanel(rand, client, TITLE, "Sie haben eine Deagle bekommen!");
				}
			}
			if (rand == 57)
			{
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie dürfen noch einmal würfeln!");
			}
			if (rand == 58)
			{
				g_bDice[client] = true;
				auto[client] = true;
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie können nun die 'jump'-Taste gedrückt halten!");
			}
			if (rand == 59)
			{
				float rSpeed = GetRandomFloat(1.0, 5.0);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie werden nun alle %0.f Sekunden geohrfeigt!", rSpeed);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				g_bDice[client] = true;
				SlapTimer[client] = CreateTimer(rSpeed, SlapTimerPlayer, client, TIMER_REPEAT);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 60)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
			}
			if (rand == 61)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
			}
			if (rand == 62)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
			}
			if (rand == 63)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				int ts = 0;
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if(IsClientValid(i) && GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
					{
						ts++;
					}
				}
				
				if(ts > 1)
				{
					LastT[client] = true;
					SendDicePanel(rand, client, TITLE, "Sie sterben, wenn Sie letzter T sind!");
				}
				else
				{
					ForcePlayerSuicide(client);
					SendDicePanel(rand, client, TITLE, "Sie sterben, weil Sie letzter T waren!");
				}
					
			}
			if (rand == 64)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Mirror Slay... aber es wurde nur eine Niete. :)");
			}
			if (rand == 65)
			{
				g_bDice[client] = true;
				DoubleDamage[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie bekommen doppelten Schaden!");
			}
			if (rand == 66)
			{
				g_bDice[client] = true;
				NoHSDMG[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie machen kein Headshot Schaden mehr!");
			}
			if (rand == 67)
			{
				g_bDice[client] = true;
				DoubleDamageE[client] = true;
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie machen doppelten Schaden!");
			}
			if (rand == 68)
			{
				g_bDice[client] = true;
				NoDamage[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie machen kein Schaden mehr!");
			}
			if (rand == 69)
			{
				g_bDice[client] = true;
				NoSelfHS[client] = true;
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie bekommen kein Headshot Schaden mehr!");
			}
			if (rand == 70)
			{
				int rHP = GetRandomInt(10, 70);
				float rSpeed = GetRandomFloat(0.1, 0.2);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie verlieren %d HP aber Sie sind %.0f Prozent schneller!", rHP, rSpeed * 100);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				g_bDice[client] = true;
				if((GetClientHealth(client) - rHP) > 0)
					SetEntityHealth(client, GetClientHealth(client) - rHP);
				else
					ForcePlayerSuicide(client);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", rSpeed + 1, 0);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 71)
			{
				g_bDice[client] = true;
				HE[client] = true;
				GivePlayerItem(client, "weapon_hegrenade");
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben unendlich HEs!");
			}
			if (rand == 72)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Niete - Versuchen Sie es später noch einmal!");
			}
			if (rand == 73)
			{
				float rSpeed = GetRandomFloat(0.1, 0.3);
				float rGrav = GetRandomFloat(0.1, 0.3);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %.0f Prozent langsamer und %.0f Prozent schwerer!", rSpeed * 100, rGrav * 100);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				g_bDice[client] = true;
				SetEntityGravity(client, rGrav + 1);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1 - rSpeed, 0);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 74)
			{
				float rSpeed = GetRandomFloat(0.1, 0.2);
				float rGrav = GetRandomFloat(0.1, 0.2);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %.0f Prozent schneller und %.0f Prozent leichter!", rSpeed * 100, rGrav * 100);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				g_bDice[client] = true;
				SetEntityGravity(client, 1 - rGrav);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", rSpeed + 1, 0);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 75)
			{
				float rSpeed = GetRandomFloat(0.1, 0.2);
				float rGrav = GetRandomFloat(0.1, 0.3);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %.0f Prozent schneller und %.0f Prozent schwerer!", rSpeed * 100, rGrav * 100);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				g_bDice[client] = true;
				SetEntityGravity(client, rGrav + 1);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", rSpeed + 1, 0);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 76)
			{
				float rSpeed = GetRandomFloat(0.1, 0.3);
				float rGrav = GetRandomFloat(0.1, 0.2);
				char buffer[64];
				Format(buffer, sizeof(buffer), "Sie sind %.0f Prozent langsamer und %.0f Prozent leichter!", rSpeed * 100, rGrav * 100);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				g_bDice[client] = true;
				SetEntityGravity(client, 1 - rSpeed);
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1 - rGrav, 0);
				
				SendDicePanel(rand, client, TITLE, buffer);
			}
			if (rand == 77)
			{
				g_bDice[client] = true;
				HalfDMG[client] = true;
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie bekommen halben Schaden!");
			}
			if (rand == 78)
			{
				g_bDice[client] = true;
				HalfSelfDMG[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie machen nur noch halben Schaden!");
			}
			if (rand == 79)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben eine Niete gewürfelt!");
			}
			if (rand == 80)
			{
				g_bDice[client] = true;
				NoWeaponUse[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie können keine Waffen mehr aufheben!");
			}
			if (rand == 81)
			{
				g_bDice[client] = true;
				HalfSelfDMG[client] = true;
				
				if(GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != INVALID_ENT_REFERENCE)
				{
					EmitSoundToClientAny(client, NEGATIVE_SOUND);
					SendDicePanel(rand, client, TITLE, "Sie haben eine Niete gezogen!");
				}
				else
				{
					int iItem = GivePlayerItem(client, "weapon_deagle");
					EquipPlayerWeapon(client, iItem);
					EmitSoundToClientAny(client, POSITIVE_SOUND);
					SendDicePanel(rand, client, TITLE, "Sie haben eine Deagle bekommen!");
				}
			}
			if (rand == 82)
			{
				g_bDice[client] = true;
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				int iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE);
				if(iWeapon != INVALID_ENT_REFERENCE)
				{
					RemovePlayerItem(client, iWeapon); 
					AcceptEntityInput(iWeapon, "Kill");
				}
				
				SendDicePanel(rand, client, TITLE, "Sie verlieren ihr Messer");
			}
			if (rand == 83)
			{
				g_bDice[client] = true;
				SetEntityGravity(client, 1600.0);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sollten weniger essen...");
			}
			if (rand == 84)
			{
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie können noch einmal Wuerfeln!");
			}
			if (rand == 85)
			{
				g_bDice[client] = true;
				NoWeaponUse[client] = true;
				bZombie[client] = true;
				SetEntityHealth(client, 500);
				SetEntityModel(client, "models/chicken/chicken_zombie.mdl");
				g_bCustomModel[client] = true;
				SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.6, 0);
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind ein Zombie Huhn,\n Sie können keine Waffen aufheben,\n Sie machen kein Waffen/Granat Schaden,\n aber Sie bekommen 500HP,\n aber Sie 40% langsamer.");
			}
			if (rand == 86)
			{
				g_bDice[client] = true;
				int iItem = GivePlayerItem(client, "weapon_deagle");
				EquipPlayerWeapon(client, iItem);
				Weapon_SetAmmo(iItem, 0);
				Weapon_SetReserveAmmo(iItem, 0);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie haben eine Deagle bekommen! Viel Glück");
			}
			if (rand == 87)
			{
				g_bDice[client] = true;
				BitchSlap[client] = CreateTimer(0.5, TimerBitchSlap, client, TIMER_REPEAT);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie leiden unter Bitchslap!");
			}
			if (rand == 88)
			{
				g_bDice[client] = true;
				SlapDMG[client] = CreateTimer(2.0, DMGSlapTimerPlayer, client, TIMER_REPEAT);
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie leiden unter Slap!");
			}
			if (rand == 89)
			{
				g_bDice[client] = true;
				SetEntityModel(client, "models/props/cs_office/chair_office.mdl");
				g_bCustomModel[client] = true;

				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind ein Chef-Sessel!");
			}
			if (rand == 90)
			{
				g_bDice[client] = true;
				SetEntityModel(client, "models/props/cs_office/computer_monitor.mdl");
				g_bCustomModel[client] = true;

				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind ein Monitor!");
			}
			if (rand == 91)
			{
				g_bDice[client] = true;
				SetEntityModel(client, "models/props/cs_office/computer_caseb.mdl");
				g_bCustomModel[client] = true;

				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind ein Computer!");
			}
			if (rand == 92)
			{
				g_bDice[client] = true;
				SetEntityModel(client, "models/props/cs_office/ladder1.mdl");
				g_bCustomModel[client] = true;

				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind eine Leiter!");
			}
			if (rand == 93)
			{
				g_bDice[client] = true;
				SetEntityModel(client, "models/props/cs_office/tv_plasma.mdl");
				g_bCustomModel[client] = true;

				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind ein Fernseher!");
			}
			if (rand == 94)
			{
				g_bDice[client] = true;
				NoDamage[client] = true;
				SetEntityModel(client, "models/props/de_dust/dust_rusty_barrel.mdl");
				g_bCustomModel[client] = true;
				
				EmitSoundToClientAny(client, POSITIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie sind eine rostige Tonne,\n und Sie machen kein Schaden.");
			}
			if (rand == 95)
			{
				g_bDice[client] = true;
				NoDamage[client] = true;
				
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie machen kein Schaden mehr!");
			}
			if (rand == 96)
			{
				g_bDice[client] = true;
				NoDamage[client] = true;
				
				EmitSoundToClientAny(client, NEGATIVE_SOUND);
				
				SendDicePanel(rand, client, TITLE, "Sie machen kein Schaden mehr!");
			}
		}
		
		LogMessage("[Dice] Player: \"%L\" Option: %d 2/2", client, rand);
	}
	DiceTimer[client] = null;
	return Plugin_Stop;
}

public Action Timer_ChangePlayerColor(Handle timer, int client)
{
	if (IsClientValid(client))
	{
		if (DiscoColor[client] != null)
		{
			int Red = GetRandomInt(0, 255);
			int Green = GetRandomInt(0, 255);
			int Blue = GetRandomInt(0, 255);
			SetEntityRenderMode(client, RENDER_NORMAL);
			SetEntityRenderColor(client, Red, Green, Blue, 255);
			
			return Plugin_Continue;
		}
	}
	
	return Plugin_Stop;
}

public Action RespawnPlayer(Handle timer, int client)
{
	CS_RespawnPlayer(client);
}

void ClearTimer(Handle & rHandle, bool bKill)
{
	if(rHandle != null)
	{
		if(!bKill)
			CloseHandle(rHandle);
		else
			KillTimer(rHandle);
		rHandle = null;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsClientValid(client))
	{
		if(IsPlayerAlive(client))
			if (auto[client])
				if (!(GetEntityFlags(client) & FL_ONGROUND))
					if (!(GetEntityMoveType(client) & MOVETYPE_LADDER))
					{
						int iType = GetEntProp(client, Prop_Data, "m_nWaterLevel");
						if (iType <= 1)
							buttons &= ~IN_JUMP;
					}
	}
	return Plugin_Continue;
}

public void OnGameFrame()
{
	for (int i = 1; i < MaxClients + 1; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && Nightvision[i])
			SetEntProp(i, Prop_Send, "m_bNightVisionOn", 1);
	}
}

public Action TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (victim> 0 && attacker > 0 && IsClientValid(victim) && IsClientValid(attacker))
	{
		char sWeapon[64];
		GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
		
		if(bZombie[attacker] && !StrEqual(sWeapon, "weapon_knife", false))
			return Plugin_Handled;
		if (NoDamage[attacker])
			return Plugin_Handled;
		if (Godmode[victim])
			return Plugin_Handled;
		if (GetClientTeam(attacker) == CS_TEAM_T)
		{
			if (DoubleDamageE[attacker])
			{
				damage = damage * 2.0;
				return Plugin_Changed;
			}
			if (HalfSelfDMG[attacker])
			{
				damage = damage * 0.5;
				return Plugin_Changed;
			}
			if(damagetype & CS_DMG_HEADSHOT)
			{
				if (NoHSDMG[attacker])
					return Plugin_Handled;
			}
		}
		if (GetClientTeam(victim) == CS_TEAM_T)
		{
			if (DoubleDamage[victim])
			{
				damage = damage * 2.0;
				return Plugin_Changed;
			}
			if (HalfDMG[victim])
			{
				damage = damage * 0.5;
				return Plugin_Changed;
			}
			if(damagetype & CS_DMG_HEADSHOT)
			{
				if (NoSelfHS[victim])
					return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public Action WeaponCanUse(int client, int weapon)
{
	if (IsClientValid(client) && NoWeaponUse[client])
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlive, TraceAttack);
	SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUse);
}

public void OnClientPostAdminCheck(int client)
{
	Godmode[client] = false;
	auto[client] = false;
}

public Action OpcionNumero16c(Handle timer, int client)
{
	if (IsClientInGame(client))
	{
		Godmode[client] = false;
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}

public Action ResetAmmo(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValidAlive(i) && AmmoInfi[i])
		{
			Client_ResetAmmo(i);
		}
	}
}

void Client_ResetAmmo(int client)
{
	if(IsClientValid(client))
	{
		int zomg = GetEntDataEnt2(client, activeOffset);
		if (clip1Offset != -1)
			SetEntData(zomg, clip1Offset, 200, 4, true);
		if (clip2Offset != -1)
			SetEntData(zomg, clip2Offset, 200, 4, true);
		if (priAmmoTypeOffset != -1)
			SetEntData(zomg, priAmmoTypeOffset, 200, 4, true);
		if (secAmmoTypeOffset != -1)
			SetEntData(zomg, secAmmoTypeOffset, 200, 4, true);
	}
}

void Dice_Reset(int client)
{
	g_bDice[client] = false;
	LastT[client] = false;
	HE[client] = false;
	DoubleDamage[client] = false;
	DoubleDamageE[client] = false;
	NoHSDMG[client] = false;
	HalfDMG[client] = false;
	HalfSelfDMG[client] = false;
	NoWeaponUse[client] = false;
	bZombie[client] = false;
	NoDamage[client] = false;
	NoSelfHS[client] = false;
	g_iCustomOption[client] = -1;
	g_bCustomModel[client] = false;
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		SetEntityGravity(client, 1.0);
		SetGlow(client, FxNone, 255, 255, 255, Normal, 255);
		SetEntProp(client, Prop_Send, "m_iDefaultFOV", 90);
	}
	NoclipCounter[client] = 5;
	Respawn[client] = false;
	Busy[client] = false;
	fReset(client);
	Nightvision[client] = false;
	Godmode[client] = false;
	AmmoInfi[client] = false;
	auto[client] = false;
	
	if (DrugTimer[client] != null)
		ClearTimer(DrugTimer[client], true);
	
	if (g_phTimerClientBeacons[client] != null)
		ClearTimer(g_phTimerClientBeacons[client], true);
	
	if (DiscoColor[client] != null)
		ClearTimer(DiscoColor[client], true);
	
	if (BitchSlap[client] != null)
		ClearTimer(BitchSlap[client], true);

	DiceTimer[client] = null;

	if (SlapDMG[client] != null)
		ClearTimer(SlapDMG[client], true);
	
	if (SlapTimer[client] != null)
		ClearTimer(SlapTimer[client], true);
}

stock void SendDicePanel(int number, int client, const char[] title, const char[] text)
{
	char sTitle[64];
	Format(sTitle, sizeof(sTitle), "%s - Option: %d", TITLE, number);
	Panel panel = new Panel();
	panel.SetTitle(sTitle);
	panel.DrawText(text);
	panel.Send(client, PanelHandler, 10);
	panel.Close();
}

public int Native_ClientReset(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(IsClientValid(client))
		Dice_Reset(client);
}

public void OnStartLR(int PrisonerIndex, int GuardIndex, int LR_Type)
{
	Dice_Reset(PrisonerIndex);
}

stock void Weapon_SetAmmo(int iWeapon, int iAmmo)
{
	SetEntProp(iWeapon, Prop_Data, "m_iClip1", iAmmo);
}

stock void Weapon_SetReserveAmmo(int iWeapon, int iReserveAmmo)
{
	SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", iReserveAmmo);
}
