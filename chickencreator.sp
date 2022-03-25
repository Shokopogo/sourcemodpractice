#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BlueberryCream"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <sdkhooks>
#include <adt>
#include <adt_trie>


#pragma newdecls required

#define MODEL_CHICKEN "models/chicken/chicken.mdl"
#define MODEL_CHICKEN_ZOMBIE "models/chicken/chicken_zombie.mdl"

#define MAX_CHICKENS 64

public Plugin myinfo = 
{
	name = "Chicken Creator", 
	author = PLUGIN_AUTHOR, 
	description = "Opens up a menu for creating chickens.", 
	version = PLUGIN_VERSION, 
	url = "forums.alliedmods.net"
};

bool g_AnnounceChicken[MAXPLAYERS + 1];

Handle g_ChickenCookie;

ConVar g_GlowDefault;

bool g_GlowSetting;

int g_ChickenEntities[MAX_CHICKENS];

int g_ChickenHealth[MAX_CHICKENS];

int g_NumberOfChickens = 0;

StringMap g_ChickenValues;

enum struct ChickenSettings
{
	bool glow;
	char colour[16];
	float glowDistance;
	int glowStyle;
	float skin;
	char model[64];
	int health;
}

ChickenSettings g_newChickenSettings[MAXPLAYERS + 1];


public void OnPluginStart()
{	

	g_ChickenValues = new StringMap();
	
	
	g_GlowDefault = CreateConVar("glow_enabled_default", "0", "If 1 glow will be enabled by default for all new players.");
	g_GlowDefault.AddChangeHook(OnGlowDefaultChange);

	g_GlowSetting = GetConVarBool(g_GlowDefault);
	
	for (int i = 0; i <= MaxClients; i++)
	{
		SetupKeyArray(i);
	}
	
	RegAdminCmd("sm_chickencreator", Command_ChickenCreator, ADMFLAG_GENERIC, "Opens a menu to create a chicken at crosshair position.");
	RegAdminCmd("sm_chickencreate", Command_ChickenCreator, ADMFLAG_GENERIC, "Opens a menu to create a chicken at crosshair position.");
	RegAdminCmd("sm_cc", Command_ChickenCreator, ADMFLAG_GENERIC, "Opens a menu to create a chicken at crosshair position.");
	RegAdminCmd("sm_cca", Command_ChickenCreatorAnnounce, ADMFLAG_GENERIC, "Enables or Disables announcement of chicken values based on provided value.");
	g_ChickenCookie = RegClientCookie("announce_chicken", "Determines if we should announce in chat chicken settings", CookieAccess_Protected);
	SetupStringMap();
}

public void SetupStringMap()
{
	
	g_ChickenValues.SetValue("disable", false, true);
	g_ChickenValues.SetValue("enable", true, true);
	g_ChickenValues.SetString("red", "255 0 0", true);
	g_ChickenValues.SetString("blue", "0 0 255", true);
	g_ChickenValues.SetString("green", "0 255 0", true);
	g_ChickenValues.SetString("black", "128 0 50", true);
	g_ChickenValues.SetString("white", "255 255 255", true);
	g_ChickenValues.SetValue("small", 1000.0, true);
	g_ChickenValues.SetValue("medium", 2000.0, true);
	g_ChickenValues.SetValue("large", 10000.0, true);
	g_ChickenValues.SetValue("defaultstyle", 0, true);
	g_ChickenValues.SetValue("shimmer", 1, true);
	g_ChickenValues.SetValue("outline", 2, true);
	g_ChickenValues.SetValue("outlinepulse", 3, true);
	g_ChickenValues.SetValue("skin0", 0, true);
	g_ChickenValues.SetValue("skin1", 0.5, true);
	g_ChickenValues.SetValue("skin2", 1, true);
	g_ChickenValues.SetString("defaultmodel", MODEL_CHICKEN, true);
	g_ChickenValues.SetString("party", MODEL_CHICKEN, true);
	g_ChickenValues.SetString("ghost", MODEL_CHICKEN_ZOMBIE, true);
	g_ChickenValues.SetString("sweater", MODEL_CHICKEN, true);
	g_ChickenValues.SetString("bunny", MODEL_CHICKEN, true);
	g_ChickenValues.SetString("pumpkin", MODEL_CHICKEN, true);
	g_ChickenValues.SetValue("health1", 1, true);
	g_ChickenValues.SetValue("health10", 10, true);
	g_ChickenValues.SetValue("health100", 100, true);
	g_ChickenValues.SetValue("health1000", 1000, true);
	
	
}

public void OnGlowDefaultChange(ConVar con, char[] oldc, char[] newc)
{
	g_GlowSetting = GetConVarBool(g_GlowDefault);
}

public Action EntityDamagedEvent(int victim, int & attacker, int & inflictor, float & damage, int & damagetype)
{
	
	int chickenIndex = -1;
	
	for (int i = 0; i < MAX_CHICKENS; i++)
	{
		if (g_ChickenEntities[i] == victim)
		{
			chickenIndex = i;
			break;
		}
	}
	
	if (chickenIndex < 0)
	{
		//exit out and allow entity to be killed
		return Plugin_Continue;
	}
	
	g_ChickenHealth[chickenIndex] -= RoundFloat(damage);
	
	if (g_ChickenHealth[chickenIndex] <= 0)
	{
		// chicken ran out of health so kill it
		g_ChickenHealth[chickenIndex] = 0;
		g_ChickenEntities[chickenIndex] = -1;
		g_NumberOfChickens -= 1;
		return Plugin_Continue;
	}
	
	//else we just want to block the event, and display chickens remaining health
	PrintToChatAll("Remaining Chicken Health: %d", g_ChickenHealth[chickenIndex]);
	damage = 0.0;
	return Plugin_Changed;
}

public void OnMapStart()
{
	PrecacheModel(MODEL_CHICKEN, true);
	PrecacheModel(MODEL_CHICKEN_ZOMBIE, true);
}

public void SetupKeyArray(int client)
{
	// Chicken Glow is set to convar default
	g_newChickenSettings[client].glow = g_GlowSetting;

	// Chicken Glow Colour is set to red
	strcopy(g_newChickenSettings[client].colour, sizeof(g_newChickenSettings[].colour), "255 0 0");
	
	// Chicken Glow Distance is set to small
	g_newChickenSettings[client].glowDistance = 1000.0;
	
	// Chicken Glow Style is set to default
	g_newChickenSettings[client].glowStyle = 0;
	
	// Chicken Skin is set to 0
	g_newChickenSettings[client].skin = 0.0;
	
	// Chicken Model is set to default
	strcopy(g_newChickenSettings[client].model, sizeof(g_newChickenSettings[].model), MODEL_CHICKEN);
	
	// Chicken Health is set to 1
	g_newChickenSettings[client].health = 1;
}

public void OnClientCookiesCached(int client)
{
	char valBuffer[8];
	GetClientCookie(client, g_ChickenCookie, valBuffer, sizeof(valBuffer));
	
	if (StrEqual(valBuffer, NULL_STRING))
	{
		strcopy(valBuffer, sizeof(valBuffer), "1");
	}
	
	g_AnnounceChicken[client] = (StringToInt(valBuffer) == 0) ? false : true;
	
}

public void OnClientPutInServer(int client)
{
	SetupKeyArray(client);
}

public Action Command_ChickenCreator(int client, int args)
{
	if (args != 0)
	{
		ReplyToCommand(client, "[SM] usage: sm_chickencreator, sm_chickencreate, sm_cc");
		return Plugin_Handled;
	}
	
	Menu menu = SetupMenu(0, client);
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
	
}

public Action Command_ChickenCreatorAnnounce(int client, int args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "[SM] usage: sm_cca <1/0>");
		return Plugin_Handled;
	}
	
	char arg[8];
	GetCmdArg(args, arg, sizeof(arg));
	
	// if argument provided isn't a 1 or a 0 then error
	if (!(StrEqual(arg, "0") || StrEqual(arg, "1")))
	{
		ReplyToCommand(client, "[SM] usage: sm_cca <1/0>");
		return Plugin_Handled;
	}
	
	SetClientCookie(client, g_ChickenCookie, arg);
	
	return Plugin_Handled;
}

public Menu SetupMenu(int type, int client)
{
	// create the menu to be setup
	Menu menu = new Menu(Menu_Callback);
	
	switch (type)
	{
		// Main Menu
		case 0:
		{
			menu.SetTitle("Chicken Creator");
			menu.AddItem("glow", "Chicken Glow");
			menu.AddItem("glowcolour", "Chicken Glow Colour");
			menu.AddItem("glowdistance", "Chicken Glow Distance");
			menu.AddItem("glowstyle", "Chicken Glow Style");
			menu.AddItem("skin", "Chicken Skin");
			menu.AddItem("model", "Chicken Model");
			menu.AddItem("health", "Chicken Health");
			menu.AddItem("spawn", "Spawn Chicken");
		}
		// Enable Glow Menu
		case 1:
		{
			menu.SetTitle("Chicken Glow");
			menu.AddItem("disable", "Disable Glow");
			menu.AddItem("enable", "Enable Glow");
			menu.AddItem("back", "Back");
		}
		case 2:
		{
			menu.SetTitle("Chicken Glow Colour");
			menu.AddItem("red", "Red");
			menu.AddItem("blue", "Blue");
			menu.AddItem("green", "Green");
			menu.AddItem("black", "Black");
			menu.AddItem("white", "White");
			menu.AddItem("back", "Back");
		}
		// Glow Distance Menu
		case 3:
		{
			menu.SetTitle("Chicken Glow Distance");
			menu.AddItem("small", "Small (1000)");
			menu.AddItem("medium", "Medium (2000)");
			menu.AddItem("large", "Large (10000)");
			menu.AddItem("back", "Back");
		}
		// Glow Style Menu
		case 4:
		{
			menu.SetTitle("Chicken Glow Style");
			menu.AddItem("defaultstyle", "Default");
			menu.AddItem("shimmer", "Shimmer");
			menu.AddItem("outline", "Outline");
			menu.AddItem("outlinepulse", "Outline Pulse");
			menu.AddItem("back", "Back");
		}
		// Skin Menu
		case 5:
		{
			menu.SetTitle("Chicken Skin");
			menu.AddItem("skin0", "0");
			menu.AddItem("skin1", "1");
			menu.AddItem("skin2", "2");
			menu.AddItem("back", "Back");
		}
		// Model Menu
		case 6:
		{
			menu.SetTitle("Chicken Model");
			menu.AddItem("defaultmodel", "Default");
			menu.AddItem("party", "Birthday");
			menu.AddItem("ghost", "Halloween Ghost");
			menu.AddItem("sweater", "Christmas");
			menu.AddItem("bunny", "Easter");
			menu.AddItem("pumpkin", "Halloween Pumpkin");
			menu.AddItem("back", "Back");
		}
		// Health Menu
		case 7:
		{
			menu.SetTitle("Chicken Health");
			menu.AddItem("health1", "1");
			menu.AddItem("health10", "10");
			menu.AddItem("health100", "100");
			menu.AddItem("health1000", "1000");
			menu.AddItem("back", "Back");
		}
	}
	return menu;
}

public int Menu_Callback(Menu menu, MenuAction action, int client, int choice)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char item[32];
			char title[32];
			menu.GetItem(choice, item, sizeof(item));
			menu.GetTitle(title, sizeof(title));
			
			// Spawn a chicken
			if (StrEqual(item, "spawn"))
			{
				// If we have space for another chicken entity
				if (g_NumberOfChickens < MAX_CHICKENS)
				{
					// Spawn the chicken
					SpawnChicken(client);
				}
				else
				{
					// Not enough space to spawn another chicken entity
					ReplyToCommand(client, "Too many chicken entities spawned, please kill one and try again");
				}
			}
			// Main menu, so really only sends to other menus
			else if (StrEqual(title, "Chicken Creator"))
			{
				// Setup the new menu to display, and display it
				Menu nmenu = SetupMenu(choice + 1, client);
				nmenu.Display(client, MENU_TIME_FOREVER);
			}
			// Pressed the back button on a sub-menu go back to Main menu
			else if (StrEqual(item, "back"))
			{
				// Setup the main menu and display it
				Menu nmenu = SetupMenu(0, client);
				nmenu.Display(client, MENU_TIME_FOREVER);
			}
			// Option selected was one that changes chicken settings
			else
			{
				// Find the sub menu where the option was selected so we can change the value of the appropriate setting
				if (StrEqual(title, "Chicken Glow"))
				{
					g_ChickenValues.GetValue(item, g_newChickenSettings[client].glow);
				}
				else if (StrEqual(title, "Chicken Glow Colour"))
				{
					g_ChickenValues.GetString(item, g_newChickenSettings[client].colour, sizeof(g_newChickenSettings[].colour));
				}
				else if (StrEqual(title, "Chicken Glow Distance"))
				{
					g_ChickenValues.GetValue(item, g_newChickenSettings[client].glowDistance);
				}
				else if (StrEqual(title, "Chicken Glow Style"))
				{
					g_ChickenValues.GetValue(item, g_newChickenSettings[client].glowStyle);
				}
				else if (StrEqual(title, "Chicken Skin"))
				{
					g_ChickenValues.GetValue(item, g_newChickenSettings[client].skin);
				}
				else if (StrEqual(title, "Chicken Model"))
				{
					g_ChickenValues.GetString(item, g_newChickenSettings[client].model, sizeof(g_newChickenSettings[].model));
				}
				else if (StrEqual(title, "Chicken Health"))
				{
					g_ChickenValues.GetValue(item, g_newChickenSettings[client].health);
				}
				
			}
			
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public int SpawnChicken(int client)
{
	
	// Look into cookies more as this seems redundant
	
	char valBuffer[8];
	GetClientCookie(client, g_ChickenCookie, valBuffer, sizeof(valBuffer));
	
	if (StrEqual(valBuffer, NULL_STRING))
	{
		strcopy(valBuffer, sizeof(valBuffer), "1");
	}
	
	g_AnnounceChicken[client] = (StringToInt(valBuffer) == 0) ? false : true;
	
	
	//chicken spawning stuff
	float fPos[3], fBackwards[3];
	float fOrigin[3], fAngles[3];
	
	GetClientEyePosition(client, fOrigin);
	GetClientEyeAngles(client, fAngles);
	
	Handle trace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceRayTest, client);
	
	GetAngleVectors(fAngles, fBackwards, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(fBackwards, fBackwards);
	ScaleVector(fBackwards, 10.0);
	
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(fPos, trace);
	}
	
	delete trace;
	
	// Trying to create an entity
	int entity = CreateEntityByName("chicken");
	
	int chickenIndex = -1;
	
	for (int i = 0; i < MAX_CHICKENS; i++)
	{
		if (g_ChickenEntities[i] <= 0)
		{
			chickenIndex = i;
			break;
		}
	}
	
	if (chickenIndex < 0)
	{
		// error, couldn't find a place in the array
		ReplyToCommand(client, "Couldn't create a chicken, please kill some to make space.");
		return -1;
	}
	
	g_ChickenEntities[chickenIndex] = entity;
	
	
	if (!IsValidEntity(entity)) {
		ReplyToCommand(client, "Entity Error, Couldn't Create a chicken");
		return -1;
	}
	
	
	DispatchKeyValueFloat(entity, "glowstyle", g_newChickenSettings[client].glowStyle);
	DispatchKeyValueFloat(entity, "glowdist", g_newChickenSettings[client].glowDistance);
	DispatchKeyValue(entity, "glowcolor", g_newChickenSettings[client].colour);
	DispatchKeyValueFloat(entity, "glowenabled", (g_newChickenSettings[client].glow)?1.0:0.0);
	g_ChickenHealth[g_NumberOfChickens] = g_newChickenSettings[client].health;
	
	SDKHook(entity, SDKHook_OnTakeDamage, EntityDamagedEvent);
	
	g_NumberOfChickens += 1;
	DispatchSpawn(entity);
	SetEntityModel(entity, g_newChickenSettings[client].model);
	TeleportEntity(entity, fPos, NULL_VECTOR, NULL_VECTOR);
	
	
	if (g_AnnounceChicken[client])
	{
		PrintToChatAll("Chicken Spawned With Settings: %d - %s - %.2f - %d - %.2f - %s - %d", 
			g_newChickenSettings[client].glow, 
			g_newChickenSettings[client].colour,
			g_newChickenSettings[client].glowDistance, 
			g_newChickenSettings[client].glowStyle, 
			g_newChickenSettings[client].skin, 
			g_newChickenSettings[client].model, 
			g_newChickenSettings[client].health);
	}
	return entity;
}

public bool TraceRayTest(int entity, int mask, any data)
{
	if (0 < entity <= MaxClients)
	{
		return false;
	}
	return true;
} 