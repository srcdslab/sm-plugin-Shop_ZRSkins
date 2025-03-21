// ==============================================================================================================================
// >>> GLOBAL INCLUDES
// ==============================================================================================================================
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <zombiereloaded>
#include <shop>
#include <multicolors>

// ==============================================================================================================================
// >>> PLUGIN INFORMATION
// ==============================================================================================================================
#define PLUGIN_VERSION "1.1.1"
public Plugin myinfo =
{
	name 			= "[Shop] ZR Skins",
	author 			= "AlexTheRegent",
	description 	= "Buy ZR skins in the shop",
	version 		= PLUGIN_VERSION,
	url 			= ""
}

// ==============================================================================================================================
// >>> DEFINES
// ==============================================================================================================================
#pragma newdecls required
#define MPS 		MAXPLAYERS+1
#define PMP 		PLATFORM_MAX_PATH
#define MTF 		MENU_TIME_FOREVER
#define CID(%0) 	GetClientOfUserId(%0)
#define UID(%0) 	GetClientUserId(%0)
#define SZF(%0) 	%0, sizeof(%0)
#define LC(%0) 		for (int %0 = 1; %0 <= MaxClients; ++%0) if ( IsClientInGame(%0) ) 

// ==============================================================================================================================
// >>> CONSOLE VARIABLES
// ==============================================================================================================================


// ==============================================================================================================================
// >>> GLOBAL VARIABLES
// ==============================================================================================================================
CategoryId	g_category_zombies;
CategoryId	g_category_humans;

ConVar 		g_shop_skins_zombie;
ConVar 		g_shop_skins_human;

// Menu 		g_team_menu;

char 		g_skin_zombie[MPS][PMP];
char 		g_skin_human[MPS][PMP];

bool 		g_in_preview[MPS];

// ==============================================================================================================================
// >>> LOCAL INCLUDES
// ==============================================================================================================================


// ==============================================================================================================================
// >>> FORWARDS
// ==============================================================================================================================
public void OnPluginStart() 
{
	if ( Shop_IsStarted() ) {
		Shop_Started();
	}
	
	// g_team_menu = new Menu(Handler_TeamMenu);
	// g_team_menu.SetTitle("Select team | Выберите команду:\n \n");
	// g_team_menu.AddItem("", "Humans | Люди");
	// g_team_menu.AddItem("", "Zombies | Зомби");
	
	HookEvent("player_spawn", Ev_PlayerSpawn);
	
	g_shop_skins_zombie = CreateConVar("zr_shop_skins_zombie", "1", "Enable (1) or Disable (0) zombies skins");
	g_shop_skins_human = CreateConVar("zr_shop_skins_human", "1", "Enable (1) or Disable (0) humans skins");
	AutoExecConfig(true, "zr_shop_skins", "shop");
}

public void OnPluginEnd() 
{
	Shop_UnregisterMe();
}

public void OnMapStart() 
{
	char path[PMP];
	BuildPath(Path_SM, SZF(path), "configs/shop/skins_dlist.txt");
	File_ReadDownloadList(path);
}

public void OnClientPutInServer(int client)
{
	g_skin_zombie[client][0] = 0;
	g_skin_human[client][0] = 0;
}

public void Shop_Started()
{
	// Shop_RegisterCategory("skins", "Скины", "всё для людей и зомби", INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION, OnCategorySelected);
	g_category_zombies = Shop_RegisterCategory("skins_zombies", "Zombies Skins", "Choose a zombie skin", INVALID_FUNCTION, INVALID_FUNCTION, OnShouldDisplayCategory);
	g_category_humans = Shop_RegisterCategory("skins_humans", "Humans Skins", "Choose a human skin", INVALID_FUNCTION, INVALID_FUNCTION, OnShouldDisplayCategory);
	
	PopulateCategory(g_category_zombies, "configs/shop/skins_zombies.txt");
	PopulateCategory(g_category_humans, "configs/shop/skins_humans.txt");
}

public bool OnShouldDisplayCategory(int client, CategoryId category_id, char[] category, ShopMenu menu)
{
	if ( g_shop_skins_zombie.BoolValue == false && category_id == g_category_zombies ) {
		return false;
	}
	else if ( g_shop_skins_human.BoolValue == false && category_id == g_category_humans ) {
		return false;
	}
	
	return true;
	// return false;
}

// public bool OnCategorySelected(int client, CategoryId category_id, char[] category, ShopMenu menu)
// {
	// g_team_menu.Display(client, MTF);
	// return false;
// }

// public int Handler_TeamMenu(Menu menu, MenuAction action, int client, int slot)
// {
	// if ( action == MenuAction_Select ) {
		// if ( slot == 0 ) {
			// Shop_ShowItemsOfCategory(client, g_category_humans);
		// }
		// else if ( slot == 1 ) {
			// Shop_ShowItemsOfCategory(client, g_category_zombies);
		// }
	// }
// }

// ==============================================================================================================================
// >>> 
// ==============================================================================================================================
void PopulateCategory(CategoryId category, const char[] source)
{
	char path[PMP];
	BuildPath(Path_SM, SZF(path), source);
	
	KeyValues kv = new KeyValues("Skins");
	if ( !kv.ImportFromFile(path) ) {
		LogError("File \"%s\" not found or broken", source);
		return;
	}
	
	if ( !kv.GotoFirstSubKey() ) {
		LogError("File \"%s\" is empty", source);
		return;
	}
	
	char name[128], anim[PMP];
	do {
		kv.GetSectionName(SZF(name));
		kv.GetString("skin", SZF(path));
		kv.GetString("anim", SZF(anim));
		if ( !IsModelPrecached(path) ) {
			PrecacheModel(path);
		}

		ItemId existingItemId = Shop_GetItemId(category, name);
		if (existingItemId != INVALID_ITEM && Shop_IsItemExists(existingItemId)) {
			Shop_UnregisterItem(existingItemId);
			LogMessage("Item %s already existed and was removed before re-adding", name);
		}
		
		Shop_StartItem(category, name);
		
		Shop_SetInfo(name, "", kv.GetNum("price", 99999999), kv.GetNum("sell_price", -1), Item_Togglable, kv.GetNum("duration", 86400));
		Shop_SetCallbacks(INVALID_FUNCTION, OnSkinSelected, INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION, OnPreviewSkin);
		Shop_SetCustomInfoString("skin", path);
		Shop_SetCustomInfoString("anim", anim);
		
		Shop_EndItem();
		
	} while ( kv.GotoNextKey() );
}

public ShopAction OnSkinSelected(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if ( !isOn && !elapsed ) {
		if ( category_id == g_category_zombies ) {
			Shop_GetItemCustomInfoString(item_id, "skin", g_skin_zombie[client], sizeof(g_skin_zombie[]), "");
			Shop_ToggleClientCategoryOff(client, category_id);
		}
		else {
			Shop_GetItemCustomInfoString(item_id, "skin", g_skin_human[client], sizeof(g_skin_human[]), "");
			Shop_ToggleClientCategoryOff(client, category_id);
		}
		
		CPrintToChat(client, "{green}[Shop] {default}Your skin will be changed in next round.");
		return Shop_UseOn;
	}

	return Shop_UseOff;
}

public void OnPreviewSkin(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item)
{
	char anim[PMP], skin[PMP];
	Shop_GetItemCustomInfoString(item_id, "anim", SZF(anim), "default");
	Shop_GetItemCustomInfoString(item_id, "skin", SZF(skin), "");

	if ( IsPlayerAlive(client) && !g_in_preview[client] && skin[0] ) {
		g_in_preview[client] = true;
		PreviewSkins(client, skin, anim);
		CreateTimer(5.0, AlreadyUsedBack, client);
	}
}

public Action AlreadyUsedBack(Handle timer, int client)
{
	g_in_preview[client] = false;
	return Plugin_Handled;
}

void PreviewSkins(int client, const char[] sModel="", const char[] animation = "")
{
	int entity = CreateEntityByName("prop_dynamic_override");
	
	float eye[3];
	GetPlayerEye(client, eye);
	DispatchKeyValue(entity, "model", sModel);
	DispatchKeyValue(entity, "DefaultAnim", animation[0] ? animation:"default");
	DispatchSpawn(entity);

	TeleportEntity(entity, eye, NULL_VECTOR, NULL_VECTOR);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	SetVariantString("OnUser1 !self:FadeAndKill::5.0:1");
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");

	SDKHook(entity, SDKHook_SetTransmit, SetTransmitSkin);
}

public Action SetTransmitSkin(int entity, int client)
{
	int owner;
	return ((owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity")) != -1 && (owner != client)) ? Plugin_Handled : Plugin_Continue;
}

// ==============================================================================================================================
// >>> 
// ==============================================================================================================================
public void Ev_PlayerSpawn(Event event, const char[] event_name, bool dont_broadcast)
{
	CreateTimer(0.5, Timer_ChangeSkin, event.GetInt("userid"));
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	CreateTimer(0.5, Timer_ChangeSkin, UID(client));
}

public Action Timer_ChangeSkin(Handle timer, any userid)
{
	int client = CID(userid);
	if ( client > 0 && IsClientInGame(client) && IsPlayerAlive(client) ) {
		if ( ZR_IsClientZombie(client) ) {
			if ( g_shop_skins_zombie.BoolValue ) {
				SetSkinSafe(client, g_skin_zombie[client]);
			}
		}
		else {
			if ( g_shop_skins_human.BoolValue ) {
				SetSkinSafe(client, g_skin_human[client]);
			}
		}
	}
	return Plugin_Continue;
}

void SetSkinSafe(int client, const char[] skin)
{
	if ( skin[0] != 0 ) {
		SetEntityModel(client, skin);
		//SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		//SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}

// ==============================================================================================================================
// >>> 
// ==============================================================================================================================
char _smlib_empty_twodimstring_array[][] = { { '\0' } };
stock void File_AddToDownloadsTable(char[] path, bool recursive = true, const char[][] ignoreExts = _smlib_empty_twodimstring_array, int size = 0)
{
	if (path[0] == '\0') return;
	
	int len = strlen(path)-1;
	
	if (path[len] == '\\' || path[len] == '/') path[len] = '\0';

	if (FileExists(path)) {
		
		char fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));
		
		if (StrEqual(fileExtension, "bz2", false) || StrEqual(fileExtension, "ztmp", false)) return;
		
		if (Array_FindString(ignoreExts, size, fileExtension) != -1) return;

		AddFileToDownloadsTable(path);
		
		if (StrEqual(fileExtension, "mdl", false)) PrecacheModel(path, true);
	}
	
	else if (recursive && DirExists(path)) {

		char dirEntry[PLATFORM_MAX_PATH];
		Handle __dir = OpenDirectory(path);

		while (ReadDirEntry(__dir, dirEntry, sizeof(dirEntry))) 
		{
			if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) continue;
			
			Format(dirEntry, sizeof(dirEntry), "%s/%s", path, dirEntry);
			File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
		}
		
		CloseHandle(__dir);
	}
	else if (FindCharInString(path, '*', true)) {
		
		char fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));

		if (StrEqual(fileExtension, "*")) {

			char
				dirName[PLATFORM_MAX_PATH],
				fileName[PLATFORM_MAX_PATH],
				dirEntry[PLATFORM_MAX_PATH];

			File_GetDirName(path, dirName, sizeof(dirName));
			File_GetFileName(path, fileName, sizeof(fileName));
			StrCat(fileName, sizeof(fileName), ".");

			Handle __dir = OpenDirectory(dirName);
			while (ReadDirEntry(__dir, dirEntry, sizeof(dirEntry))) {

				if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) {
					continue;
				}

				if (strncmp(dirEntry, fileName, strlen(fileName)) == 0) {
					Format(dirEntry, sizeof(dirEntry), "%s/%s", dirName, dirEntry);
					File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
				}
			}

			CloseHandle(__dir);
		}
	}

	return;
}

stock void GetPlayerEye(int client, float pos[3])
{
	float vAngles[3], vOrigin[3];
 
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayers);
	TR_GetEndPosition(pos);
}

public bool TraceEntityFilterPlayers(int ent, int Mask)
{
	return (!(0 < ent <= MaxClients));
}

stock bool File_ReadDownloadList(const char[] path)
{
	Handle file = OpenFile(path, "r");
	
	if (file  == INVALID_HANDLE) return false;

	char buffer[PLATFORM_MAX_PATH];
	while (!IsEndOfFile(file)) 
	{
		ReadFileLine(file, buffer, sizeof(buffer));
		
		int pos;
		pos = StrContains(buffer, "//");
		if (pos != -1) buffer[pos] = '\0';
		
		pos = StrContains(buffer, "#");
		if (pos != -1) buffer[pos] = '\0';

		pos = StrContains(buffer, ";");
		if (pos != -1) buffer[pos] = '\0';
		
		TrimString(buffer);
		
		if (buffer[0] == '\0') continue;

		File_AddToDownloadsTable(buffer);
	}

	CloseHandle(file);
	
	return true;
}

stock void File_GetExtension(const char[] path, char[] buffer, int size)
{
	int extpos = FindCharInString(path, '.', true);
	
	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}

	strcopy(buffer, size, path[++extpos]);
}

stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();
	
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock int Array_FindString(const char[][] array, int size, const char[] str, bool caseSensitive=true, int start=0)
{
	if (start < 0) start = 0;

	for (int i=start; i < size; i++) {

		if (StrEqual(array[i], str, caseSensitive)) return i;
	}
	
	return -1;
}

stock void File_GetFileName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') 
	{
		buffer[0] = '\0';
		return;
	}
	
	File_GetBaseName(path, buffer, size);
	
	int pos_ext = FindCharInString(buffer, '.', true);

	if (pos_ext != -1) buffer[pos_ext] = '\0';
}

stock void File_GetDirName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') 
	{
		buffer[0] = '\0';
		return;
	}
	
	int pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) 
	{
		pos_start = FindCharInString(path, '\\', true);
		
		if (pos_start == -1) 
		{
			buffer[0] = '\0';
			return;
		}
	}
	
	strcopy(buffer, size, path);
	buffer[pos_start] = '\0';
}

stock void File_GetBaseName(const char[] path, char[] buffer, int size)
{	
	if (path[0] == '\0') 
	{
		buffer[0] = '\0';
		return;
	}
	
	int pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) pos_start = FindCharInString(path, '\\', true);
	
	pos_start++;
	
	strcopy(buffer, size, path[pos_start]);
}
