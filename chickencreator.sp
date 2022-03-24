#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BlueberryCream"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <sdkhooks>

#pragma newdecls required

#define MODEL_CHICKEN "models/chicken/chicken.mdl"
#define MODEL_CHICKEN_ZOMBIE "models/chicken/chicken_zombie.mdl"

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

char g_ChickenSettings[MAXPLAYERS + 1][7][64];

char g_GlowSetting[8];

int g_ChickenEntities[64];

int g_ChickenHealth[64];

int g_NumberOfChickens = 0;

public void OnPluginStart()
{
	
	g_GlowDefault = CreateConVar("glow_enabled_default", "0", "If 1 glow will be enabled by default for all new players.");
	g_GlowDefault.AddChangeHook(OnGlowDefaultChange);
	
	GetConVarString(g_GlowDefault, g_GlowSetting, sizeof(g_GlowSetting));
	
	for (int i = 0; i <= MAXPLAYERS; i++)
	{	
		SetupKeyArray(i);
	}
	
	RegAdminCmd("sm_chickencreator", Command_ChickenCreator, ADMFLAG_GENERIC, "Opens a menu to create a chicken at crosshair position.");
	RegAdminCmd("sm_chickencreate", Command_ChickenCreator, ADMFLAG_GENERIC, "Opens a menu to create a chicken at crosshair position.");
	RegAdminCmd("sm_cc", Command_ChickenCreator, ADMFLAG_GENERIC, "Opens a menu to create a chicken at crosshair position.");
	RegAdminCmd("sm_cca", Command_ChickenCreatorAnnounce, ADMFLAG_GENERIC, "Enables or Disables announcement of chicken values based on provided value.");
	g_ChickenCookie = RegClientCookie("announce_chicken", "Determines if we should announce in chat chicken settings", CookieAccess_Protected);
}

public void OnGlowDefaultChange(ConVar con, char[] oldc, char[] newc)
{
	GetConVarString(g_GlowDefault, g_GlowSetting, sizeof(g_GlowSetting));
}

public Action EntityDamagedEvent(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	
	int chickenIndex = -1;
	
	for (int i = 0; i < sizeof(g_ChickenEntities); i++)
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
	strcopy(g_ChickenSettings[client][0], sizeof(g_ChickenSettings[][]), g_GlowSetting);
	
	// Chicken Glow Colour is set to red
	strcopy(g_ChickenSettings[client][1], sizeof(g_ChickenSettings[][]), "255 0 0");
	
	// Chicken Glow Distance is set to small
	strcopy(g_ChickenSettings[client][2], sizeof(g_ChickenSettings[][]), "1000");
	
	// Chicken Glow Style is set to default
	strcopy(g_ChickenSettings[client][3], sizeof(g_ChickenSettings[][]), "0");
	
	// Chicken Skin is set to 0
	strcopy(g_ChickenSettings[client][4], sizeof(g_ChickenSettings[][]), "0");
	
	// Chicken Model is set to default
	strcopy(g_ChickenSettings[client][5], sizeof(g_ChickenSettings[][]), MODEL_CHICKEN);
	
	// Chicken Health is set to 1
	strcopy(g_ChickenSettings[client][6], sizeof(g_ChickenSettings[][]), "1");
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
	if ( !(StrEqual(arg, "0") || StrEqual(arg, "1")) )
	{
		ReplyToCommand(client, "[SM] usage: sm_cca <1/0>");
		return Plugin_Handled;
	}
	
	SetClientCookie(client, g_ChickenCookie, arg);
	
	return Plugin_Handled;
}

public Menu SetupMenu(int type, int client)
{
	switch (type)
	{
		// Main Menu
		case 0:
		{
			Menu menu = new Menu(Menu_Callback);
			menu.SetTitle("Chicken Creator");
			menu.AddItem("glow", "Chicken Glow");
			menu.AddItem("glowcolour", "Chicken Glow Colour");
			menu.AddItem("glowdistance", "Chicken Glow Distance");
			menu.AddItem("glowstyle", "Chicken Glow Style");
			menu.AddItem("skin", "Chicken Skin");
			menu.AddItem("model", "Chicken Model");
			menu.AddItem("health", "Chicken Health");
			menu.AddItem("spawn", "Spawn Chicken");
			return menu;
		}
		// Enable Glow Menu
		case 1:
		{
			Menu menu = new Menu(Menu_Callback);
			menu.SetTitle("Chicken Glow");
			menu.AddItem("disable", "Disable Glow");
			menu.AddItem("enable", "Enable Glow");
			menu.AddItem("back", "Back");
			return menu;
		}
		// Glow Colour Menu
		case 2:
		{
			Menu menu = new Menu(Menu_Callback);
			menu.SetTitle("Chicken Glow Colour");
			menu.AddItem("red", "Red");
			menu.AddItem("blue", "Blue");
			menu.AddItem("green", "Green");
			menu.AddItem("black", "Black");
			menu.AddItem("white", "White");
			menu.AddItem("back", "Back");
			return menu;
		}
		// Glow Distance Menu
		case 3:
		{
			Menu menu = new Menu(Menu_Callback);
			menu.SetTitle("Chicken Glow Distance");
			menu.AddItem("small", "Small (1000)");
			menu.AddItem("medium", "Medium (2000)");
			menu.AddItem("large", "Large (10000)");
			menu.AddItem("back", "Back");
			return menu;
		}
		// Glow Style Menu
		case 4:
		{
			Menu menu = new Menu(Menu_Callback);
			menu.SetTitle("Chicken Glow Style");
			menu.AddItem("defaultstyle", "Default");
			menu.AddItem("shimmer", "Shimmer");
			menu.AddItem("outline", "Outline");
			menu.AddItem("outlinepulse", "Outline Pulse");
			menu.AddItem("back", "Back");
			return menu;
		}
		// Skin Menu
		case 5:
		{
			Menu menu = new Menu(Menu_Callback);
			menu.SetTitle("Chicken Skin");
			menu.AddItem("skin0", "0");
			menu.AddItem("skin1", "1");
			menu.AddItem("skin2", "2");
			menu.AddItem("back", "Back");
			return menu;
		}
		// Model Menu
		case 6:
		{
			Menu menu = new Menu(Menu_Callback);
			menu.SetTitle("Chicken Model");
			menu.AddItem("defaultmodel", "Default");
			menu.AddItem("party", "Birthday");
			menu.AddItem("ghost", "Halloween Ghost");
			menu.AddItem("sweater", "Christmas");
			menu.AddItem("bunny", "Easter");
			menu.AddItem("pumpkin", "Halloween Pumpkin");
			menu.AddItem("back", "Back");
			return menu;
		}
		// Health Menu
		case 7:
		{
			Menu menu = new Menu(Menu_Callback);
			menu.SetTitle("Chicken Health");
			menu.AddItem("health1", "1");
			menu.AddItem("health10", "10");
			menu.AddItem("health100", "100");
			menu.AddItem("health1000", "1000");
			menu.AddItem("back", "Back");
			return menu;
		}
	}
	Menu menu = new Menu(Menu_Callback);
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
			
			// go back to main menu (to remove redundancy is separate)
			if (StrEqual(item, "back"))
			{
				//delete menu;
				Menu nmenu = SetupMenu(0, client);
				nmenu.Display(client, MENU_TIME_FOREVER);
			}
			else if (StrEqual(title, "Chicken Creator"))
			{
				if (StrEqual(item, "glow"))
				{
					//delete menu;
					Menu nmenu = SetupMenu(1, client);
					nmenu.Display(client, MENU_TIME_FOREVER);
				}
				else if (StrEqual(item, "glowcolour"))
				{
					//delete menu;
					Menu nmenu = SetupMenu(2, client);
					nmenu.Display(client, MENU_TIME_FOREVER);
				}
				else if (StrEqual(item, "glowdistance"))
				{
					//delete menu;
					Menu nmenu = SetupMenu(3, client);
					nmenu.Display(client, MENU_TIME_FOREVER);
				}
				else if (StrEqual(item, "glowstyle"))
				{
					//delete menu;
					Menu nmenu = SetupMenu(4, client);
					nmenu.Display(client, MENU_TIME_FOREVER);
				}
				else if (StrEqual(item, "skin"))
				{
					//delete menu;
					Menu nmenu = SetupMenu(5, client);
					nmenu.Display(client, MENU_TIME_FOREVER);
				}
				else if (StrEqual(item, "model"))
				{
					//delete menu;
					Menu nmenu = SetupMenu(6, client);
					nmenu.Display(client, MENU_TIME_FOREVER);
				}
				else if (StrEqual(item, "health"))
				{
					//delete menu;
					Menu nmenu = SetupMenu(7, client);
					nmenu.Display(client, MENU_TIME_FOREVER);
				}
				else if (StrEqual(item, "spawn"))
				{
					if (g_NumberOfChickens < 64)
					{
						SpawnChicken(client);
					}
					else
					{
						ReplyToCommand(client, "Too many chicken entities spawned, please kill one and try again");
					}
				}
			}
			else if (StrEqual(title, "Chicken Glow"))
			{
				if (StrEqual(item, "disable"))
				{
					PrintToChatAll("Disable Glow");
					strcopy(g_ChickenSettings[client][0], sizeof(g_ChickenSettings[][]), "0");
				}
				else if (StrEqual(item, "enable"))
				{
					PrintToChatAll("Enable Glow");
					strcopy(g_ChickenSettings[client][0], sizeof(g_ChickenSettings[][]), "1");
				}
			}
			else if (StrEqual(title, "Chicken Glow Colour"))
			{
				if (StrEqual(item, "red"))
				{
					PrintToChatAll("Red");
					strcopy(g_ChickenSettings[client][1], sizeof(g_ChickenSettings[][]), "255 0 0");
				}
				else if (StrEqual(item, "blue"))
				{
					PrintToChatAll("Blue");
					strcopy(g_ChickenSettings[client][1], sizeof(g_ChickenSettings[][]), "0 0 255");
				}
				else if (StrEqual(item, "green"))
				{
					PrintToChatAll("Green");
					strcopy(g_ChickenSettings[client][1], sizeof(g_ChickenSettings[][]), "0 255 0");
				}
				else if (StrEqual(item, "black"))
				{
					PrintToChatAll("Black");
					strcopy(g_ChickenSettings[client][1], sizeof(g_ChickenSettings[][]), "128 0 50");
				}
				else if (StrEqual(item, "white"))
				{
					PrintToChatAll("White");
					strcopy(g_ChickenSettings[client][1], sizeof(g_ChickenSettings[][]), "255 255 255");
				}
			}
			else if (StrEqual(title, "Chicken Glow Distance"))
			{
				if (StrEqual(item, "small"))
				{
					PrintToChatAll("Small");
					strcopy(g_ChickenSettings[client][2], sizeof(g_ChickenSettings[][]), "1000");
				}
				else if (StrEqual(item, "medium"))
				{
					PrintToChatAll("Medium");
					strcopy(g_ChickenSettings[client][2], sizeof(g_ChickenSettings[][]), "2000");
				}
				else if (StrEqual(item, "large"))
				{
					PrintToChatAll("Large");
					strcopy(g_ChickenSettings[client][2], sizeof(g_ChickenSettings[][]), "10000");
				}
			}
			else if (StrEqual(title, "Chicken Glow Style"))
			{
				if (StrEqual(item, "defaultstyle"))
				{
					PrintToChatAll("Default");
					strcopy(g_ChickenSettings[client][3], sizeof(g_ChickenSettings[][]), "0");
				}
				else if (StrEqual(item, "shimmer"))
				{
					PrintToChatAll("Shimmer");
					strcopy(g_ChickenSettings[client][3], sizeof(g_ChickenSettings[][]), "1");
				}
				else if (StrEqual(item, "outline"))
				{
					PrintToChatAll("Outline");
					strcopy(g_ChickenSettings[client][3], sizeof(g_ChickenSettings[][]), "2");
				}
				else if (StrEqual(item, "outlinepulse"))
				{
					PrintToChatAll("Outline Pulse");
					strcopy(g_ChickenSettings[client][3], sizeof(g_ChickenSettings[][]), "3");
				}
			}
			else if (StrEqual(title, "Chicken Skin"))
			{
				if (StrEqual(item, "skin0"))
				{
					PrintToChatAll("0");
					strcopy(g_ChickenSettings[client][4], sizeof(g_ChickenSettings[][]), "0");
				}
				else if (StrEqual(item, "skin1"))
				{
					PrintToChatAll("1");
					strcopy(g_ChickenSettings[client][4], sizeof(g_ChickenSettings[][]), "1");
				}
				else if (StrEqual(item, "skin2"))
				{
					PrintToChatAll("2");
					strcopy(g_ChickenSettings[client][4], sizeof(g_ChickenSettings[][]), "2");
				}
			}
			else if (StrEqual(title, "Chicken Model"))
			{
				if (StrEqual(item, "defaultmodel"))
				{
					PrintToChatAll("Default");
					strcopy(g_ChickenSettings[client][5], sizeof(g_ChickenSettings[][]), MODEL_CHICKEN);
				}
				else if (StrEqual(item, "party"))
				{
					PrintToChatAll("Birthday");
					strcopy(g_ChickenSettings[client][5], sizeof(g_ChickenSettings[][]), MODEL_CHICKEN);
				}
				else if (StrEqual(item, "ghost"))
				{
					PrintToChatAll("Halloween Ghost");
					strcopy(g_ChickenSettings[client][5], sizeof(g_ChickenSettings[][]), MODEL_CHICKEN_ZOMBIE);
				}
				else if (StrEqual(item, "sweater"))
				{
					PrintToChatAll("Christmas");
					strcopy(g_ChickenSettings[client][5], sizeof(g_ChickenSettings[][]), MODEL_CHICKEN);
				}
				else if (StrEqual(item, "bunny"))
				{
					PrintToChatAll("Easter");
					strcopy(g_ChickenSettings[client][5], sizeof(g_ChickenSettings[][]), MODEL_CHICKEN);
				}
				else if (StrEqual(item, "pumpkin"))
				{
					PrintToChatAll("Halloween Pumpkin");
					strcopy(g_ChickenSettings[client][5], sizeof(g_ChickenSettings[][]), MODEL_CHICKEN);
				}
			}
			else if (StrEqual(title, "Chicken Health"))
			{
				if (StrEqual(item, "health1"))
				{
					PrintToChatAll("1");
					strcopy(g_ChickenSettings[client][6], sizeof(g_ChickenSettings[][]), "1");
				}
				else if (StrEqual(item, "health10"))
				{
					PrintToChatAll("10");
					strcopy(g_ChickenSettings[client][6], sizeof(g_ChickenSettings[][]), "10");
				}
				else if (StrEqual(item, "health100"))
				{
					PrintToChatAll("100");
					strcopy(g_ChickenSettings[client][6], sizeof(g_ChickenSettings[][]), "100");
				}
				else if (StrEqual(item, "health1000"))
				{
					PrintToChatAll("1000");
					strcopy(g_ChickenSettings[client][6], sizeof(g_ChickenSettings[][]), "1000");
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
	
	for (int i = 0; i < sizeof(g_ChickenEntities); i++)
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
	
	
	DispatchKeyValue(entity, "glowstyle", g_ChickenSettings[client][3]);
	DispatchKeyValue(entity, "glowdist", g_ChickenSettings[client][2]);
	DispatchKeyValue(entity, "glowcolor", g_ChickenSettings[client][1]);
	DispatchKeyValue(entity, "glowenabled", g_ChickenSettings[client][0]);
	
	g_ChickenHealth[g_NumberOfChickens] = StringToInt(g_ChickenSettings[client][6], 10);
	
	SDKHook(entity, SDKHook_OnTakeDamage, EntityDamagedEvent);
	
	g_NumberOfChickens += 1;
	DispatchSpawn(entity);
	SetEntityModel(entity, g_ChickenSettings[client][5]);
	TeleportEntity(entity, fPos, NULL_VECTOR, NULL_VECTOR);

	
	if (g_AnnounceChicken[client])
	{
		PrintToChatAll("Chicken Spawned With Settings: %s - %s - %s - %s - %s - %s - %s", 
			g_ChickenSettings[client][0], 
			g_ChickenSettings[client][1], 
			g_ChickenSettings[client][2], 
			g_ChickenSettings[client][3], 
			g_ChickenSettings[client][4], 
			g_ChickenSettings[client][5], 
			g_ChickenSettings[client][6]);
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