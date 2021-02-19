#include <sourcemod>
#include <multicolors>

#define PLUGIN_AUTHOR "OverWolf (Ravid)"
#define PLUGIN_VERSION "1.0"
#define PREFIX " \x04[Advertisement]\x01"
#define PREFIX_MENU "[Advertisement]"

#define MAX_ADS 25
#define CONFIG_PATH "addons/sourcemod/configs/Ads.cfg"

enum AdParamType
{
	Type_Message = 0, 
	Type_Time
}

enum PropMode
{
	None_Mode = 0, 
	Add_Mode, 
	Edit_Mode
}

enum
{
	Message_Text = 0, 
	Message_Hint, 
	Message_Hud
}

enum struct AdProp
{
	char szAd[256];
	int iTime;
	bool bForAdmins;
	int iType;
}

enum struct EditProp
{
	PropMode iEditMode;
	AdParamType iEditType;
	bool bEditForAdmins;
	int iAdIndex;
	char szAd[256];
	char szTime[32];
	int iType;
}

AdProp g_esAd[MAX_ADS];
EditProp g_esEditProp[MAXPLAYERS + 1];

Handle g_hAdTimer[MAX_ADS];

char g_szMessageTypes[3][32] =  { "Chat", "Hint", "Hud" };

char g_szColorTag[][] =  { "{d}", "{dr}", "{g}", "{lg}", "{r}", "{b}", "{o}", "{l}", "{lr}", "{p}", "{gr}", "{y}", "{or}", "{bg}", "{lb}", "{db}", "{gr2}", "{m}", "{lr2}" };
char g_szColorHint[][] =  { "<font color='#FFFFFF'>", "<font color='#FF0000'>", "<font color='#008000'>", "<font color='#00FF00'>", "<font color='#DF1010'>", "<font color='#00008b'>", "<font color='#808000'>", "<font color='#bfff00'>", "<font color='#ec5454'>", "<font color='#800080'>", "<font color='#808080'>", "<font color='#ffff00'>", "<font color='#FFA500'>", "<font color='#6699cc'>", "<font color='#0000ff'>", "<font color='#0000ff'>", "<font color='#a9a9a9'>", "<font color='#ff00ff'>", "<font color='ffcccb'>" };

int g_iNumOfAds;

public Plugin myinfo = 
{
	name = "[CS:GO] Advertisement System", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = "https://steamcommunity.com/id/Over_Wolf", 
};

public void OnPluginStart()
{
	RegAdminCmd("sm_ads", Command_Ads, ADMFLAG_ROOT);
	
	char sDirPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sDirPath, PLATFORM_MAX_PATH, "configs/Ads.cfg");
	File hFile = OpenFile(sDirPath, "a+");
	LoadAds();
	delete hFile;
}

/* Events */

public void OnMapEnd()
{
	char sDirPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sDirPath, PLATFORM_MAX_PATH, "configs/Ads.cfg");
	File hFile = OpenFile(sDirPath, "w+");
	UpdateAds();
	delete hFile;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] szArgs)
{
	if (g_esEditProp[client].iEditMode != None_Mode)
	{
		if (StrEqual(szArgs, "-1"))
		{
			PrintToChat(client, "%s Operation aborted.", PREFIX);
			
			if (g_esEditProp[client].iEditMode == Add_Mode)
				showAddAdMenu(client, g_esEditProp[client].szAd, g_esEditProp[client].szTime);
			else
				showManageAdMenu(client, g_esEditProp[client].iAdIndex);
			
			g_esEditProp[client].iAdIndex = -1;
			g_esEditProp[client].iEditMode = None_Mode;
			return Plugin_Handled;
		}
		if (g_esEditProp[client].iEditMode == Add_Mode)
		{
			if (g_esEditProp[client].iEditType == Type_Message)
				strcopy(g_esEditProp[client].szAd, sizeof(g_esEditProp[].szAd), szArgs);
			else
				strcopy(g_esEditProp[client].szTime, sizeof(g_esEditProp[].szTime), szArgs);
			
			g_esEditProp[client].iEditMode = None_Mode;
			showAddAdMenu(client, g_esEditProp[client].szAd, g_esEditProp[client].szTime);
			return Plugin_Handled;
		} else {
			
			char szKey[16];
			
			Format(szKey, sizeof(szKey), "%s", g_esEditProp[client].iEditType == Type_Message ? "Message" : "Time");
			
			editAd(g_esEditProp[client].iAdIndex, szKey, szArgs);
			PrintToChat(client, "%s You set the \x02%s\x01 of the ad to \x04\"%s\"\x01.", PREFIX, szKey, szArgs);
			showManageAdMenu(client, g_esEditProp[client].iAdIndex);
			g_esEditProp[client].iAdIndex = -1;
			g_esEditProp[client].iEditMode = None_Mode;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

/* */

/* Commands */

public Action Command_Ads(int client, int args)
{
	showAdsMenu(client);
	return Plugin_Handled;
}

/* */

/* Menus */

void showAdsMenu(int client)
{
	Menu menu = new Menu(Handler_Ads);
	menu.SetTitle("%s Advertisement Menu - Main Menu (%d %s)\n ", PREFIX_MENU, g_iNumOfAds, g_iNumOfAds == 1 ? "Ad":"Ads");
	menu.AddItem("", "Add Advertisement\n ", g_iNumOfAds == MAX_ADS ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	if (g_iNumOfAds == 0)
		menu.AddItem("", "There Are No Ads", ITEMDRAW_DISABLED);
	else
	{
		menu.AddItem("", "Ads For Admins Only", getNumOfAds(true) > 0 ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
		menu.AddItem("", "Ads For Everyone", getNumOfAds(false) > 0 ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_Ads(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch (itemNum)
		{
			case 0:showAddAdMenu(client, g_esEditProp[client].szAd, g_esEditProp[client].szTime);
			case 1:showListOfAds(client, true);
			case 2:showListOfAds(client, false);
		}
	}
}

void showListOfAds(int client, bool forAdmins)
{
	char szItem[236], szAdId[32];
	
	Menu menu = new Menu(Handler_ListOfAds);
	menu.SetTitle("%s Advertisement Menu - Ads For %s\n ", PREFIX_MENU, forAdmins ? "Admins Only":"Everyone");
	
	for (int i = 0; i < g_iNumOfAds; i++)
	{
		IntToString(i, szAdId, sizeof(szAdId));
		Format(szItem, sizeof(szItem), "%s (Every %d Minutes) [Type: %s Message]", g_esAd[i].szAd, g_esAd[i].iTime, g_szMessageTypes[g_esAd[i].iType]);
		if (g_esAd[i].bForAdmins && forAdmins)
		{
			menu.AddItem(szAdId, szItem);
		}
		if (!g_esAd[i].bForAdmins && !forAdmins)
		{
			menu.AddItem(szAdId, szItem);
		}
	}
	if (getNumOfAds(forAdmins) == 0)
		menu.AddItem("", "There Are No Ads In This List", ITEMDRAW_DISABLED);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_ListOfAds(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char szItem[32];
		menu.GetItem(itemNum, szItem, sizeof(szItem));
		int adId = StringToInt(szItem);
		showManageAdMenu(client, adId);
	}
	else if (action == MenuAction_Cancel && itemNum == MenuCancel_ExitBack)
	{
		showAdsMenu(client);
	}
}

void showAddAdMenu(int client, char[] message, char[] time)
{
	char szItem[236];
	
	Menu menu = new Menu(Handler_AddAd);
	menu.SetTitle("%s Advertisement Menu - Adding an Advertisement\n \n• Colors: {g} => green, {p} => purple, {b} => blue, {m} => magenta, {l} => lime...\n• Default = {d}\n• Note: colors have no use in hud message\n ", PREFIX_MENU);
	
	Format(szItem, sizeof(szItem), "Ad Message: %s", message[0] == 0 ? "None" : message);
	menu.AddItem("", szItem);
	
	Format(szItem, sizeof(szItem), "%s minutes", time);
	Format(szItem, sizeof(szItem), "Ad Time: %s", time[0] == 0 ? "None" : szItem);
	menu.AddItem("", szItem);
	
	Format(szItem, sizeof(szItem), "Ad For Admins: %s", g_esEditProp[client].bEditForAdmins ? "Yes" : "No");
	menu.AddItem("", szItem);
	
	Format(szItem, sizeof(szItem), "Ad Message Type: %s\n ", g_szMessageTypes[g_esEditProp[client].iType]);
	menu.AddItem("", szItem);
	
	menu.AddItem("", "Preview Ad\n ");
	menu.AddItem("", "Finish");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_AddAd(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch (itemNum)
		{
			case 2:
			{
				g_esEditProp[client].bEditForAdmins = !g_esEditProp[client].bEditForAdmins;
				showAddAdMenu(client, g_esEditProp[client].szAd, g_esEditProp[client].szTime);
			}
			case 3:
			{
				g_esEditProp[client].iType++;
				g_esEditProp[client].iType = g_esEditProp[client].iType % sizeof(g_szMessageTypes);
				showAddAdMenu(client, g_esEditProp[client].szAd, g_esEditProp[client].szTime);
			}
			case 4:
			{
				if (g_esEditProp[client].iType == Message_Text)
				{
					CPrintToChat(client, "%s The Ad: \"%s\"", PREFIX, g_esEditProp[client].szAd);
				} else {
					char szAd[256];
					strcopy(szAd, sizeof(szAd), g_esEditProp[client].szAd)
					if (g_esEditProp[client].iType == Message_Hint) {
						for (int iColorHint = 0; iColorHint < sizeof(g_szColorTag); iColorHint++)
						{
							ReplaceString(szAd, sizeof(szAd), g_szColorTag[iColorHint], g_szColorHint[iColorHint]);
						}
						Format(szAd, sizeof(szAd), "<font color='008000'>Advertisement</font> The Ad:\n%s", szAd);
						PrintHintText(client, szAd);
					} else {
						SetHudTextParams(-1.0, 0.1, 5.0, 0, 255, 0, 0, 1, 0.1, 0.1, 0.1);
						for (int iColorHud = 0; iColorHud < sizeof(g_szColorTag); iColorHud++)
						{
							ReplaceString(szAd, sizeof(szAd), g_szColorTag[iColorHud], "");
						}
						Format(szAd, sizeof(szAd), "[Advertisement] The Ad:\n%s", szAd);
						ShowHudText(client, 10, szAd);
					}
				}
				showAddAdMenu(client, g_esEditProp[client].szAd, g_esEditProp[client].szTime);
			}
			case 5:
			{
				if (g_esEditProp[client].szAd[0] != 0 && g_esEditProp[client].szTime[0] != 0)
				{
					AddAd(client, g_esEditProp[client].szAd, g_esEditProp[client].szTime);
					PrintToChat(client, "%s You add the ad \x04\"%s\"\x01 and set the time to \x02%s minutes\x01%s, Printed in \x04%s Message\x01.", PREFIX, g_esEditProp[client].szAd, g_esEditProp[client].szTime, g_esEditProp[client].bEditForAdmins ? ", \x04Only for Admins":"", g_szMessageTypes[g_esEditProp[client].iType]);
					Format(g_esEditProp[client].szAd, sizeof(g_esEditProp[].szAd), "");
					Format(g_esEditProp[client].szTime, sizeof(g_esEditProp[].szTime), "");
					g_esEditProp[client].bEditForAdmins = false;
					showAdsMenu(client);
				}
				else
					PrintToChat(client, "%s \x02Invalid advertisement parametars\x01", PREFIX);
			}
			default:
			{
				g_esEditProp[client].iEditMode = Add_Mode;
				g_esEditProp[client].iEditType = view_as<AdParamType>(itemNum);
				PrintToChat(client, "%s Type the \x04%s\x01 you want to add in the chat or type \x02-1 \x01to abort.", PREFIX, view_as<AdParamType>(itemNum) == Type_Message ? "Advertisement" : "Time");
			}
		}
	}
	else if (action == MenuAction_Cancel && itemNum == MenuCancel_ExitBack)
	{
		Format(g_esEditProp[client].szAd, sizeof(g_esEditProp[].szAd), "");
		Format(g_esEditProp[client].szTime, sizeof(g_esEditProp[].szTime), "");
		g_esEditProp[client].bEditForAdmins = false;
		showAdsMenu(client);
	}
}

void showManageAdMenu(int client, int adId)
{
	char szItem[32], szItemInfo[8];
	IntToString(adId, szItemInfo, sizeof(szItemInfo));
	
	Menu menu = new Menu(Handler_ManageAd);
	menu.SetTitle("%s Advertisement Menu - Manage an Advertisement\n• Message: %s\n• Time: %d Minutes\n \n• Colors: {g} => green, {p} => purple, {b} => blue, {m} => magenta, {l} => lime...\n• Default = {d}\n• Note: colors have no use in hud message\n ", PREFIX_MENU, g_esAd[adId].szAd, g_esAd[adId].iTime);
	
	menu.AddItem(szItemInfo, "Edit Ad Message");
	menu.AddItem(szItemInfo, "Edit Ad Time");
	
	Format(szItem, sizeof(szItem), "Ad For Admins: %s", g_esAd[adId].bForAdmins ? "Yes" : "No");
	menu.AddItem(szItemInfo, szItem);
	
	Format(szItem, sizeof(szItem), "Ad Message Type: %s\n ", g_szMessageTypes[g_esAd[adId].iType]);
	menu.AddItem(szItemInfo, szItem);
	
	menu.AddItem(szItemInfo, "Preview Ad\n ");
	
	menu.AddItem(szItemInfo, "Delete Ad");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_ManageAd(Menu menu, MenuAction action, int client, int itemNum)
{
	char szItem[32];
	menu.GetItem(0, szItem, sizeof(szItem));
	int adId = StringToInt(szItem);
	
	if (action == MenuAction_Select)
	{
		switch (itemNum)
		{
			case 2:
			{
				g_esAd[adId].bForAdmins = !g_esAd[adId].bForAdmins;
				PrintToChat(client, "%s You setted the ad %s\x01 for admins.", PREFIX, g_esAd[adId].bForAdmins ? "\x04Only" : "\x02Not");
				showManageAdMenu(client, adId);
				
			}
			case 3:
			{
				g_esAd[adId].iType++;
				g_esAd[adId].iType = g_esAd[adId].iType % sizeof(g_szMessageTypes);
				PrintToChat(client, "%s You setted the ad to be printed in \x04%s Message\x01.", PREFIX, g_szMessageTypes[g_esAd[adId].iType]);
				showManageAdMenu(client, adId);
			}
			case 4:
			{
				if (g_esAd[adId].iType == Message_Text)
				{
					CPrintToChat(client, "%s The Ad: \"%s\"", PREFIX, g_esAd[adId].szAd);
				} else {
					char szAd[256];
					strcopy(szAd, sizeof(szAd), g_esAd[adId].szAd)
					if (g_esAd[adId].iType == Message_Hint) {
						for (int iColorHint = 0; iColorHint < sizeof(g_szColorTag); iColorHint++)
						{
							ReplaceString(szAd, sizeof(szAd), g_szColorTag[iColorHint], g_szColorHint[iColorHint]);
						}
						Format(szAd, sizeof(szAd), "<font color='#008000'>Advertisement</font> The Ad:\n%s", szAd);
						PrintHintText(client, szAd);
					} else {
						SetHudTextParams(-1.0, 0.1, 5.0, 0, 255, 0, 0, 1, 0.1, 0.1, 0.1);
						for (int iColorHud = 0; iColorHud < sizeof(g_szColorTag); iColorHud++)
						{
							ReplaceString(szAd, sizeof(szAd), g_szColorTag[iColorHud], "");
						}
						Format(szAd, sizeof(szAd), "[Advertisement] The Ad:\n%s", szAd);
						ShowHudText(client, 10, szAd);
					}
				}
				showManageAdMenu(client, adId);
			}
			case 5:
			{
				DeleteAd(client, adId);
				showAdsMenu(client)
			}
			default:
			{
				g_esEditProp[client].iEditMode = Edit_Mode;
				g_esEditProp[client].iEditType = view_as<AdParamType>(itemNum);
				g_esEditProp[client].iAdIndex = adId;
				PrintToChat(client, "%s Type the \x04%s\x01 you want to set instead, in the chat or type \x02-1 \x01to abort.", PREFIX, view_as<AdParamType>(itemNum) == Type_Message ? "Advertisement" : "Time");
			}
		}
	}
	else if (action == MenuAction_Cancel && itemNum == MenuCancel_ExitBack)
		showListOfAds(client, g_esAd[adId].bForAdmins);
}

/* */

/* Timers */

public Action Timer_RepeatAd(Handle timer, int iAdId)
{
	char szAd[256];
	if (g_esAd[iAdId].bForAdmins)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetUserAdmin(i) != INVALID_ADMIN_ID)
			{
				if (g_esAd[iAdId].iType == Message_Text)
				{
					CPrintToChat(i, g_esAd[iAdId].szAd);
				} else {
					strcopy(szAd, sizeof(szAd), g_esAd[iAdId].szAd)
					if (g_esAd[iAdId].iType == Message_Hint) {
						for (int iColorHint = 0; iColorHint < sizeof(g_szColorTag); iColorHint++)
						{
							ReplaceString(szAd, sizeof(szAd), g_szColorTag[iColorHint], g_szColorHint[iColorHint]);
						}
						PrintHintText(i, szAd);
					} else {
						for (int iColorHud = 0; iColorHud < sizeof(g_szColorTag); iColorHud++)
						{
							ReplaceString(szAd, sizeof(szAd), g_szColorTag[iColorHud], "");
						}
						SetHudTextParams(-1.0, 0.1, 5.0, 0, 255, 0, 0, 1, 0.1, 0.1, 0.1);
						ShowHudText(i, 10, szAd);
					}
				}
			}
		}
	} else {
		if (g_esAd[iAdId].iType == Message_Text)
		{
			CPrintToChatAll(g_esAd[iAdId].szAd);
		} else {
			strcopy(szAd, sizeof(szAd), g_esAd[iAdId].szAd)
			if (g_esAd[iAdId].iType == Message_Hint) {
				for (int iColorHint = 0; iColorHint < sizeof(g_szColorTag); iColorHint++)
				{
					ReplaceString(szAd, sizeof(szAd), g_szColorTag[iColorHint], g_szColorHint[iColorHint]);
				}
				PrintHintTextToAll(szAd);
			} else {
				SetHudTextParams(-1.0, 0.1, 5.0, 0, 255, 0, 0, 1, 0.1, 0.1, 0.1);
				for (int iColorHud = 0; iColorHud < sizeof(g_szColorTag); iColorHud++)
				{
					ReplaceString(szAd, sizeof(szAd), g_szColorTag[iColorHud], "");
				}
				for (int iCurrentClient = 1; iCurrentClient <= MaxClients; iCurrentClient++)
				{
					if (IsClientInGame(iCurrentClient))
					{
						ShowHudText(iCurrentClient, 10, szAd);
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

/* */

/* Functions */

void AddAd(int client, char[] message, char[] time)
{
	strcopy(g_esAd[g_iNumOfAds].szAd, sizeof(g_esAd[].szAd), message);
	
	g_esAd[g_iNumOfAds].bForAdmins = g_esEditProp[client].bEditForAdmins;
	g_esAd[g_iNumOfAds].iType = g_esEditProp[client].iType;
	
	g_esAd[g_iNumOfAds].iTime = StringToInt(time);
	float fAdTimer = float(g_esAd[g_iNumOfAds].iTime) * 60;
	g_hAdTimer[g_iNumOfAds] = CreateTimer(fAdTimer, Timer_RepeatAd, g_iNumOfAds, TIMER_REPEAT);
	
	g_iNumOfAds++;
}

void editAd(int adId, char[] key, const char[] value)
{
	if (StrEqual(key, "Message"))
		strcopy(g_esAd[adId].szAd, sizeof(g_esAd[].szAd), value);
	else if (StrEqual(key, "Time"))
	{
		g_esAd[adId].iTime = StringToInt(value);
		if (g_hAdTimer[adId] != INVALID_HANDLE)
			KillTimer(g_hAdTimer[adId]);
		
		float fAdTimer = float(g_esAd[adId].iTime) * 60;
		g_hAdTimer[adId] = CreateTimer(fAdTimer, Timer_RepeatAd, adId, TIMER_REPEAT);
	}
}

void DeleteAd(int client, int adId)
{
	if (g_hAdTimer[adId] != INVALID_HANDLE)
		KillTimer(g_hAdTimer[adId])
	g_hAdTimer[adId] = INVALID_HANDLE
	
	PrintToChat(client, "%s You have deleted the ad \x04\"%s\"\x01.", PREFIX, g_esAd[adId].szAd);
	for (int i = adId; i < g_iNumOfAds - 1; i++)
	{
		strcopy(g_esAd[i].szAd, sizeof(g_esAd[].szAd), g_esAd[i + 1].szAd);
		g_esAd[i].bForAdmins = g_esAd[i + 1].bForAdmins;
		g_esAd[i].iTime = g_esAd[i + 1].iTime;
		if (g_hAdTimer[i] != INVALID_HANDLE)
			KillTimer(g_hAdTimer[i]);
		g_hAdTimer[i] = CreateTimer(float(g_esAd[i + 1].iTime) * 60, Timer_RepeatAd, i, TIMER_REPEAT);
	}
	
	if (g_hAdTimer[g_iNumOfAds] != INVALID_HANDLE)
		KillTimer(g_hAdTimer[g_iNumOfAds]);
	
	g_hAdTimer[g_iNumOfAds] = INVALID_HANDLE
	Format(g_esAd[g_iNumOfAds].szAd, sizeof(g_esAd[].szAd), "");
	g_esAd[g_iNumOfAds].bForAdmins = false;
	g_esAd[g_iNumOfAds].iTime = 0;
	g_iNumOfAds--;
}

int getNumOfAds(bool forAdmins)
{
	int iCount = 0;
	for (int i = 0; i < g_iNumOfAds; i++)
	{
		if (forAdmins && g_esAd[i].bForAdmins)
			iCount++;
		if (!forAdmins && !g_esAd[i].bForAdmins)
			iCount++;
	}
	return iCount;
}


/* */

/* Keyvalues */

void LoadAds()
{
	if (!FileExists(CONFIG_PATH))
		SetFailState("Cannot find file %s", CONFIG_PATH);
	
	KeyValues kConfig = new KeyValues("Ads");
	kConfig.ImportFromFile(CONFIG_PATH);
	kConfig.GotoFirstSubKey();
	int iAdsCounter = 0;
	float fAdTimer;
	char szTime[8], szAdmin[16], szType[16];
	
	do {
		kConfig.GetString("Message", g_esAd[iAdsCounter].szAd, sizeof(g_esAd[].szAd));
		kConfig.GetString("Time", szTime, sizeof(szTime));
		kConfig.GetString("Admin", szAdmin, sizeof(szAdmin));
		kConfig.GetString("Type", szType, sizeof(szType));
		
		g_esAd[iAdsCounter].bForAdmins = StrEqual(szAdmin, "Yes");
		g_esAd[iAdsCounter].iType = StrEqual(szType, "Chat") ? Message_Text : StrEqual(szType, "Hint") ? Message_Hint : Message_Hud;
		
		g_esAd[iAdsCounter].iTime = StringToInt(szTime);
		if (g_esAd[iAdsCounter].szAd[0] != 0 && g_esAd[iAdsCounter].iTime > 0)
		{
			fAdTimer = float(g_esAd[iAdsCounter].iTime) * 60;
			
			if (g_hAdTimer[iAdsCounter] != INVALID_HANDLE)
				KillTimer(g_hAdTimer[iAdsCounter]);
			
			g_hAdTimer[iAdsCounter] = CreateTimer(fAdTimer, Timer_RepeatAd, iAdsCounter, TIMER_REPEAT);
			iAdsCounter++;
		}
	}
	while (kConfig.GotoNextKey())
		
	g_iNumOfAds = iAdsCounter;
	
	kConfig.Rewind();
	kConfig.ExportToFile(CONFIG_PATH);
	delete kConfig;
}

void UpdateAds()
{
	if (!FileExists(CONFIG_PATH))
		SetFailState("Cannot find file %s", CONFIG_PATH);
	
	KeyValues kConfig = new KeyValues("Ads");
	kConfig.ImportFromFile(CONFIG_PATH);
	
	char szKey[8], szTime[8];
	for (int iCurrentAd = 0; iCurrentAd < g_iNumOfAds; iCurrentAd++)
	{
		IntToString(iCurrentAd, szKey, sizeof(szKey));
		kConfig.JumpToKey(szKey, true);
		kConfig.GotoFirstSubKey();
		kConfig.SetString("Message", g_esAd[iCurrentAd].szAd);
		IntToString(g_esAd[iCurrentAd].iTime, szTime, sizeof(szTime));
		kConfig.SetString("Time", szTime);
		kConfig.SetString("Admin", g_esAd[iCurrentAd].bForAdmins ? "Yes" : "No");
		kConfig.SetString("Type", g_szMessageTypes[g_esAd[iCurrentAd].iType]);
		kConfig.GoBack();
		KillTimer(g_hAdTimer[iCurrentAd]);
	}
	
	kConfig.Rewind();
	kConfig.ExportToFile(CONFIG_PATH);
	delete kConfig;
}

/* */