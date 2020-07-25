#include <cstrike>
#include <sdktools>
#include <sourcemod>

#define PLUGIN_NAME "Instant Defuse"

int g_CurrentDefuserUserId = -1;
bool g_IsDefusingWithKit = false;
float g_PlantTime = 0.0;
int g_ActiveGrenadesCount = 0;
 
public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "ely",
	description = "Allows the CTs to defuse the bomb instantly if conditions are met.",
	version = "1.0",
	url = ""
};
 
public void OnPluginStart()
{
	PrintToServer("%s plugin started.", PLUGIN_NAME);
	HookEvent("bomb_planted", Event_BombPlanted);
	HookEvent("bomb_begindefuse", Event_BeginDefuse);
	HookEvent("bomb_abortdefuse", Event_AbortDefuse);
	HookEvent("grenade_thrown", Event_GrenadeThrown);
	HookEvent("hegrenade_detonate", Event_LowerActiveGrenades);
	HookEvent("molotov_detonate", Event_LowerActiveGrenades);		// molotov and incgrenade
	HookEvent("inferno_expire", Event_LowerActiveGrenades);			// molotov and incgrenade
	HookEvent("inferno_extinguish", Event_LowerActiveGrenades);		// molotov and incgrenade
	HookEvent("round_start", Event_RoundStart);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_CurrentDefuserUserId = -1;
	g_ActiveGrenadesCount = 0;
	g_PlantTime = 0.0;
}

void Event_BombPlanted(Event event, const char[] name, bool dontBroadcast)
{
	g_PlantTime = GetGameTime();
}

void Event_BeginDefuse(Event event, const char[] name, bool dontBroadcast)
{
	g_CurrentDefuserUserId = GetEventInt(event, "userid");
	g_IsDefusingWithKit = event.GetBool("haskit");
	AttemptInstantDefuse();
}

void Event_AbortDefuse(Event event, const char[] name, bool dontBroadcast)
{
	g_CurrentDefuserUserId = -1;
	g_IsDefusingWithKit = false;
}

void Event_GrenadeThrown(Event event, const char[] name, bool dontBroadcast)
{
	char weapon[64];
	event.GetString("weapon", weapon, sizeof(weapon));

	// We only care about damaging grenades here (not taking into account direct hit and omitting the potential decoy explosion damage).
	if (StrEqual(weapon, "hegrenade") || StrEqual(weapon, "incgrenade") || StrEqual(weapon, "molotov"))
	{
		++g_ActiveGrenadesCount;
	}
}

void Event_LowerActiveGrenades(Event event, const char[] name, bool dontBroadcast)
{
	if (--g_ActiveGrenadesCount < 0)
	{
		g_ActiveGrenadesCount = 0;
	}

	if (g_CurrentDefuserUserId != -1)
	{
		AttemptInstantDefuse();
	}
}

void AttemptInstantDefuse()
{
	// No active damaging grenades and no Ts alive.
	if (g_ActiveGrenadesCount == 0 && HasAlivePlayer(2) == false)
	{
		float remainingTime = GetConVarFloat(FindConVar("mp_c4timer")) - (GetGameTime() - g_PlantTime);

		// Checking if the remaining time is higher than what is required to defuse the bomb.
		if (remainingTime > 10.0 || remainingTime > 5.0 && g_IsDefusingWithKit)
		{
			// Apparently we need a timer to make SentEntPropXXX calls work...
			CreateTimer(0.0, InstantDefuse, g_CurrentDefuserUserId);
		}
	}
}

Action:InstantDefuse(Handle:timer, int userId)
{
	new client = GetClientOfUserId(userId);
	if (IsPlayerAlive(client))
	{
		new c4Entity = FindEntityByClassname(-1, "planted_c4");
		if (c4Entity != -1)
		{
			// Set both c4 and defuser entity properties to force the instant defuse.
			SetEntPropFloat(c4Entity, Prop_Send, "m_flDefuseCountDown", 0.0);
			SetEntPropFloat(c4Entity, Prop_Send, "m_flDefuseLength", 0.0);
			SetEntProp(client, Prop_Send, "m_iProgressBarDuration", 0.0);
		}
	}
}

bool HasAlivePlayer(int team)
{
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsValidClient(i, false) && IsPlayerAlive(i) && GetClientTeam(i) == team)
        {
            return true;
        }
    }
   
    return false;
}

bool IsValidClient(client, bool:noBots = true)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (noBots && IsFakeClient(client)))
    {
        return false; 
    }

    return IsClientInGame(client); 
}