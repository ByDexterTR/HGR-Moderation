#include <sourcemod>
#include <hgr>
#include <multicolors>
#include <clientprefs>
#undef REQUIRE_PLUGIN
#include <store>
#include <warden>

#pragma semicolon 1
#pragma newdecls required

Handle g_HookaccessC = null, g_GrabaccessC = null, g_RopeaccessC = null;

bool Block = false, Ip[65] = { false, ... };

ConVar g_Announce = null, g_AnnounceStyle = null, 
g_BlockT = null, g_BlockCT = null, 
g_Roundend = null, 
g_StoreBuy = null, g_HookPrice = null, g_GrabPrice = null, g_RopePrice = null, 
g_WardenHook = null, g_WardenGrab = null, g_WardenRope = null, 
g_Serveriprequirement = null, g_Serverip = null;

bool bStore = false, bWarden = false;

public Plugin myinfo = 
{
	name = "HookGrabRope Moderation", 
	author = "ByDexter", 
	description = "Features for Hook Grab Rope", 
	version = "1.1", 
	url = "https://steamcommunity.com/id/ByDexterTR - ByDexter#5494"
};

public void OnPluginStart()
{
	LoadTranslations("hgr-moderation.phrases.txt");
	
	g_Announce = CreateConVar("sm_hgr_use_annouce", "1", "Report users of Hook Grab Rope", 0, true, 0.0, true, 1.0);
	g_AnnounceStyle = CreateConVar("sm_hgr_style_announce", "1", "0 = Chat | 1 = Console | 2 = Chat + Console", 0, true, 0.0, true, 2.0);
	
	g_BlockT = CreateConVar("sm_hgr_block_t", "0", "0 = No | 1 = Block T Hgr", 0, true, 0.0, true, 1.0);
	g_BlockCT = CreateConVar("sm_hgr_block_ct", "0", "0 = No | 1 = Block CT Hgr", 0, true, 0.0, true, 1.0);
	g_Roundend = CreateConVar("sm_hgr_round_end", "0", "HGR use end of tour only", 0, true, 0.0, true, 1.0);
	g_Serveriprequirement = CreateConVar("sm_hgr_serverip_requirement", "0", "Do users of Hook Grab Rope have to take the server address on their name?", 0, true, 0.0, true, 1.0);
	g_Serverip = CreateConVar("sm_hgr_serverip", "github.com/ByDexterTR", "Server Ip");
	
	g_StoreBuy = CreateConVar("sm_hgr_store", "1", "Buying HookGrabRope", 0, true, 0.0, true, 1.0);
	g_HookPrice = CreateConVar("sm_hgr_hook_price", "500", "Price Hook", 0, true, 0.0);
	g_GrabPrice = CreateConVar("sm_hgr_grab_price", "500", "Price Grab", 0, true, 0.0);
	g_RopePrice = CreateConVar("sm_hgr_rope_price", "500", "Price Rope", 0, true, 0.0);
	
	AddCommandListener(Control_ExitWarden, "sm_uw");
	AddCommandListener(Control_ExitWarden, "sm_unwarden");
	AddCommandListener(Control_ExitWarden, "sm_uc");
	AddCommandListener(Control_ExitWarden, "sm_uncommander");
	
	g_WardenHook = CreateConVar("sm_hgr_warden_hook", "1", "Warden hook access", 0, true, 0.0, true, 1.0);
	g_WardenGrab = CreateConVar("sm_hgr_warden_grab", "1", "Warden grab access", 0, true, 0.0, true, 1.0);
	g_WardenRope = CreateConVar("sm_hgr_warden_rope", "1", "Warden rope access", 0, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_hgrbuy", BuyHGR);
	RegConsoleCmd("sm_hgrstatus", StatusHGR);
	
	g_HookaccessC = RegClientCookie("Moderation-HookAccess-Cookie", "Store buy hook", CookieAccess_Private);
	g_GrabaccessC = RegClientCookie("Moderation-GrabAccess-Cookie", "Store buy grab", CookieAccess_Private);
	g_RopeaccessC = RegClientCookie("Moderation-RopeAccess-Cookie", "Store buy rope", CookieAccess_Private);
	
	HookEvent("round_start", RoundStart);
	HookEvent("round_end", RoundEnd);
	
	AutoExecConfig(true, "HGR-Moderation", "ByDexter");
}

public void OnMapStart()
{
	bStore = LibraryExists("store") || LibraryExists("store_zephyrus");
	bWarden = LibraryExists("warden");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "warden"))
		bWarden = false;
	else if (StrEqual(name, "store") || StrEqual(name, "store_zephyrus"))
		bStore = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "warden"))
		bWarden = true;
	else if (StrEqual(name, "store") || StrEqual(name, "store_zephyrus"))
		bStore = false;
}

public Action notify(Handle timer, int client)
{
	if (IsValidClient(client))
	{
		CPrintToChat(client, "%t", "notifymsg");
	}
	return Plugin_Stop;
}

public Action BuyHGR(int client, int args)
{
	if (!bStore && !g_StoreBuy.BoolValue)
	{
		CPrintToChat(client, "%t", "HGR-store-disabled");
		return Plugin_Handled;
	}
	char secenek[128];
	Menu menu = new Menu(Menu_Callback);
	menu.SetTitle("[Moderation] HookGrabRope - Store");
	if (Store_GetClientCredits(client) < g_HookPrice.IntValue || GetIntCookie(client, g_HookaccessC) == 1)
	{
		Format(secenek, sizeof(secenek), "Hook Buy - %d Credit", g_HookPrice.IntValue);
		menu.AddItem("0", secenek, ITEMDRAW_DISABLED);
	}
	else if (Store_GetClientCredits(client) >= g_HookPrice.IntValue || GetIntCookie(client, g_HookaccessC) != 1)
	{
		Format(secenek, sizeof(secenek), "Hook Buy - %d Credit", g_HookPrice.IntValue);
		menu.AddItem("0", secenek, ITEMDRAW_DEFAULT);
	}
	if (Store_GetClientCredits(client) < g_GrabPrice.IntValue || GetIntCookie(client, g_GrabaccessC) == 1)
	{
		Format(secenek, sizeof(secenek), "Grab Buy - %d Credit", g_GrabPrice.IntValue);
		menu.AddItem("1", secenek, ITEMDRAW_DISABLED);
	}
	else if (Store_GetClientCredits(client) >= g_GrabPrice.IntValue || GetIntCookie(client, g_GrabaccessC) != 1)
	{
		Format(secenek, sizeof(secenek), "Grab Buy - %d Credit", g_GrabPrice.IntValue);
		menu.AddItem("1", secenek, ITEMDRAW_DEFAULT);
	}
	if (Store_GetClientCredits(client) < g_RopePrice.IntValue || GetIntCookie(client, g_RopeaccessC) == 1)
	{
		Format(secenek, sizeof(secenek), "Rope Buy - %d Credit", g_RopePrice.IntValue);
		menu.AddItem("2", secenek, ITEMDRAW_DISABLED);
	}
	else if (Store_GetClientCredits(client) >= g_RopePrice.IntValue || GetIntCookie(client, g_RopeaccessC) != 1)
	{
		Format(secenek, sizeof(secenek), "Rope Buy - %d Credit", g_RopePrice.IntValue);
		menu.AddItem("2", secenek, ITEMDRAW_DEFAULT);
	}
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int Menu_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (bStore && g_StoreBuy.BoolValue)
			{
				char Item[4];
				menu.GetItem(param2, Item, sizeof(Item));
				int item = StringToInt(Item);
				switch (item)
				{
					case 0:
					{
						CPrintToChat(param1, "%t", "Hook-buy");
						Store_SetClientCredits(param1, Store_GetClientCredits(param1) - g_HookPrice.IntValue);
						HGR_ClientAccess(param1, 0, 0);
						SetClientCookie(param1, g_HookaccessC, "1");
					}
					case 1:
					{
						CPrintToChat(param1, "%t", "Grab-buy");
						Store_SetClientCredits(param1, Store_GetClientCredits(param1) - g_GrabPrice.IntValue);
						HGR_ClientAccess(param1, 0, 1);
						SetClientCookie(param1, g_GrabaccessC, "1");
					}
					case 2:
					{
						CPrintToChat(param1, "%t", "Rope-buy");
						Store_SetClientCredits(param1, Store_GetClientCredits(param1) - g_RopePrice.IntValue);
						HGR_ClientAccess(param1, 0, 2);
						SetClientCookie(param1, g_RopeaccessC, "1");
					}
				}
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

public Action StatusHGR(int client, int args)
{
	Menu menustat = new Menu(MenuStat_Callback);
	menustat.SetTitle("[Moderation] HookGrabRope - Status");
	if (g_Announce.BoolValue)
	{
		if (g_AnnounceStyle.IntValue == 0)
			menustat.AddItem("0", "Announce : Chat", ITEMDRAW_DISABLED);
		else if (g_AnnounceStyle.IntValue == 1)
			menustat.AddItem("1", "Announce : Console", ITEMDRAW_DISABLED);
		else if (g_AnnounceStyle.IntValue == 2)
			menustat.AddItem("2", "Announce : Chat + Console", ITEMDRAW_DISABLED);
	}
	else
	{
		menustat.AddItem("X", "Announce : Disabled", ITEMDRAW_DISABLED);
	}
	
	if (g_BlockT.BoolValue && !g_BlockCT.BoolValue)
	{
		menustat.AddItem("1", "Block Team: T", ITEMDRAW_DISABLED);
	}
	else if (!g_BlockT.BoolValue && g_BlockCT.BoolValue)
	{
		menustat.AddItem("1", "Block Team: CT", ITEMDRAW_DISABLED);
	}
	else if (g_BlockT.BoolValue && g_BlockCT.BoolValue)
	{
		menustat.AddItem("2", "Block Team: T + CT", ITEMDRAW_DISABLED);
	}
	else
	{
		menustat.AddItem("2", "Block Team: None", ITEMDRAW_DISABLED);
	}
	
	if (g_Roundend.BoolValue)
	{
		menustat.AddItem("1", "HGR Round End: Enable", ITEMDRAW_DISABLED);
	}
	else
	{
		menustat.AddItem("2", "HGR Round End: Disable", ITEMDRAW_DISABLED);
	}
	
	if (g_Serveriprequirement.BoolValue)
	{
		char Serverip[32];
		g_Serverip.GetString(Serverip, sizeof(Serverip));
		char secenek[256];
		Format(secenek, sizeof(secenek), "Server ip REQ: %s", Serverip);
		menustat.AddItem("1", secenek, ITEMDRAW_DISABLED);
	}
	else
	{
		menustat.AddItem("2", "Server ip REQ: Disable", ITEMDRAW_DISABLED);
	}
	
	if (bStore && g_StoreBuy.BoolValue)
	{
		menustat.AddItem("store", "HGR Store: Enable", ITEMDRAW_DEFAULT);
	}
	else
	{
		menustat.AddItem("1", "HGR Store: Disable", ITEMDRAW_DISABLED);
	}
	
	menustat.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuStat_Callback(Menu menustat, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menustat;
		}
		case MenuAction_Select:
		{
			FakeClientCommand(param1, "sm_hgrbuy");
		}
	}
	return 0;
}

public void OnClientPostAdminCheck(int client)
{
	if (GetIntCookie(client, g_HookaccessC) == 1)
		HGR_ClientAccess(client, 0, 0);
	if (GetIntCookie(client, g_GrabaccessC) == 1)
		HGR_ClientAccess(client, 0, 1);
	if (GetIntCookie(client, g_RopeaccessC) == 1)
		HGR_ClientAccess(client, 0, 2);
	
	CreateTimer(8.0, notify, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Roundend.BoolValue)
	{
		if (!Block)
			Block = true;
	}
	else
	{
		if (Block)
			Block = false;
	}
	return Plugin_Continue;
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Roundend.BoolValue)
	{
		if (Block)
			Block = false;
	}
	else
	{
		if (Block)
			Block = false;
	}
	return Plugin_Continue;
}

public Action HGR_OnClientHook(int client)
{
	if (g_Serveriprequirement.BoolValue)
	{
		if (!Ip[client])
		{
			char playerName[32];
			char Serverip[32];
			g_Serverip.GetString(Serverip, sizeof(Serverip));
			GetClientName(client, playerName, 32);
			if (StrContains(playerName, Serverip, false) != -1)
			{
				Ip[client] = true;
			}
			else
			{
				Ip[client] = false;
				CPrintToChat(client, "%t", "IpReq", Serverip);
				return Plugin_Handled;
			}
		}
	}
	if (Block)
	{
		CPrintToChat(client, "%t", "Hook-disable");
		return Plugin_Handled;
	}
	int team = GetClientTeam(client);
	if ((team == 2 && g_BlockT.BoolValue) || (team == 3 && g_BlockCT.BoolValue))
	{
		CPrintToChat(client, "%t", "Hook-disable");
		return Plugin_Handled;
	}
	if (g_Announce.BoolValue)
	{
		if ((team == 2 && !g_BlockT.BoolValue) || (team == 3 && !g_BlockCT.BoolValue))
		{
			if (g_AnnounceStyle.IntValue == 0)
			{
				CPrintToChatAll("%t", "Hook-announce-chat", client);
			}
			else if (g_AnnounceStyle.IntValue == 1)
			{
				PrintToConsoleAll("------------------------------------------");
				PrintToConsoleAll("%t", "Hook-announce-console", client);
				PrintToConsoleAll("------------------------------------------");
			}
			else if (g_AnnounceStyle.IntValue == 2)
			{
				CPrintToChatAll("%t", "Hook-announce-chat", client);
				PrintToConsoleAll("------------------------------------------");
				PrintToConsoleAll("%t", "Hook-announce-console", client);
				PrintToConsoleAll("------------------------------------------");
			}
		}
	}
	return Plugin_Continue;
}

public Action HGR_OnClientGrab(int client)
{
	if (g_Serveriprequirement.BoolValue)
	{
		if (!Ip[client])
		{
			char playerName[32];
			char Serverip[32];
			g_Serverip.GetString(Serverip, sizeof(Serverip));
			GetClientName(client, playerName, 32);
			if (StrContains(playerName, Serverip, false) != -1)
			{
				Ip[client] = true;
			}
			else
			{
				Ip[client] = false;
				CPrintToChat(client, "%t", "IpReq", Serverip);
				return Plugin_Handled;
			}
		}
	}
	if (Block)
	{
		CPrintToChat(client, "%t", "Grab-disable");
		return Plugin_Handled;
	}
	int team = GetClientTeam(client);
	if ((team == 2 && g_BlockT.BoolValue) || (team == 3 && g_BlockCT.BoolValue))
	{
		CPrintToChat(client, "%t", "Grab-disable");
		return Plugin_Handled;
	}
	if (g_Announce.BoolValue)
	{
		if ((team == 2 && !g_BlockT.BoolValue) || (team == 3 && !g_BlockCT.BoolValue))
		{
			if (g_AnnounceStyle.IntValue == 0)
			{
				CPrintToChatAll("%t", "Grab-announce-chat", client);
			}
			else if (g_AnnounceStyle.IntValue == 1)
			{
				PrintToConsoleAll("------------------------------------------");
				PrintToConsoleAll("%t", "Grab-announce-console", client);
				PrintToConsoleAll("------------------------------------------");
			}
			else if (g_AnnounceStyle.IntValue == 2)
			{
				CPrintToChatAll("%t", "Grab-announce-chat", client);
				PrintToConsoleAll("------------------------------------------");
				PrintToConsoleAll("%t", "Grab-announce-console", client);
				PrintToConsoleAll("------------------------------------------");
			}
		}
	}
	return Plugin_Continue;
}

public Action HGR_OnClientRope(int client)
{
	if (g_Serveriprequirement.BoolValue)
	{
		if (!Ip[client])
		{
			char playerName[32];
			char Serverip[32];
			g_Serverip.GetString(Serverip, sizeof(Serverip));
			GetClientName(client, playerName, 32);
			if (StrContains(playerName, Serverip, false) != -1)
			{
				Ip[client] = true;
			}
			else
			{
				Ip[client] = false;
				CPrintToChat(client, "%t", "IpReq", Serverip);
				return Plugin_Handled;
			}
		}
	}
	if (Block)
	{
		CPrintToChat(client, "%t", "Rope-disable");
		return Plugin_Handled;
	}
	int team = GetClientTeam(client);
	if ((team == 2 && g_BlockT.BoolValue) || (team == 3 && g_BlockCT.BoolValue))
	{
		CPrintToChat(client, "%t", "Rope-disable");
		return Plugin_Handled;
	}
	if (g_Announce.BoolValue)
	{
		if ((team == 2 && !g_BlockT.BoolValue) || (team == 3 && !g_BlockCT.BoolValue))
		{
			if (g_AnnounceStyle.IntValue == 0)
			{
				CPrintToChatAll("%t", "Rope-announce-chat", client);
			}
			else if (g_AnnounceStyle.IntValue == 1)
			{
				PrintToConsoleAll("------------------------------------------");
				PrintToConsoleAll("%t", "Rope-announce-console", client);
				PrintToConsoleAll("------------------------------------------");
			}
			else if (g_AnnounceStyle.IntValue == 2)
			{
				CPrintToChatAll("%t", "Rope-announce-chat", client);
				PrintToConsoleAll("------------------------------------------");
				PrintToConsoleAll("%t", "Rope-announce-console", client);
				PrintToConsoleAll("------------------------------------------");
			}
		}
	}
	return Plugin_Continue;
}

public void warden_OnWardenCreated(int client)
{
	if (bWarden)
	{
		if (g_WardenHook.BoolValue && GetIntCookie(client, g_HookaccessC) != 1)
		{
			HGR_ClientAccess(client, 0, 0);
		}
		if (g_WardenGrab.BoolValue && GetIntCookie(client, g_GrabaccessC) != 1)
		{
			HGR_ClientAccess(client, 0, 1);
		}
		if (g_WardenRope.BoolValue && GetIntCookie(client, g_RopeaccessC) != 1)
		{
			HGR_ClientAccess(client, 0, 2);
		}
	}
}

public void warden_OnWardenRemoved(int client)
{
	if (bWarden)
	{
		if (g_WardenHook.BoolValue && GetIntCookie(client, g_HookaccessC) != 1)
		{
			HGR_ClientAccess(client, 1, 0);
		}
		if (g_WardenGrab.BoolValue && GetIntCookie(client, g_GrabaccessC) != 1)
		{
			HGR_ClientAccess(client, 1, 1);
		}
		if (g_WardenRope.BoolValue && GetIntCookie(client, g_RopeaccessC) != 1)
		{
			HGR_ClientAccess(client, 1, 2);
		}
	}
}

public Action Control_ExitWarden(int client, const char[] command, int argc)
{
	if (bWarden && IsValidClient(client) && warden_iswarden(client))
	{
		if (g_WardenHook.BoolValue && GetIntCookie(client, g_HookaccessC) != 1)
		{
			HGR_ClientAccess(client, 1, 0);
		}
		if (g_WardenGrab.BoolValue && GetIntCookie(client, g_GrabaccessC) != 1)
		{
			HGR_ClientAccess(client, 1, 1);
		}
		if (g_WardenRope.BoolValue && GetIntCookie(client, g_RopeaccessC) != 1)
		{
			HGR_ClientAccess(client, 1, 2);
		}
	}
	return Plugin_Continue;
}

int GetIntCookie(int client, Handle handle)
{
	char sCookieValue[32];
	GetClientCookie(client, handle, sCookieValue, sizeof(sCookieValue));
	return StringToInt(sCookieValue);
}

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
} 