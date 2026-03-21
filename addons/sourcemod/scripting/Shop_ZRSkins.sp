// ==============================================================================================================================
// >>> GLOBAL INCLUDES
// ==============================================================================================================================
#pragma newdecls required
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
public Plugin myinfo =
{
	name 			= "[Shop] ZR Skins",
	author 			= "AlexTheRegent, .Rushaway",
	description 	= "Buy ZR skins in the shop",
	version 		= "1.2.1",
	url 			= ""
};

// ==============================================================================================================================
// >>> GLOBAL VARIABLES
// ==============================================================================================================================
#define MAXEDICTS (iMaxEntities - 150)

CategoryId	g_category_zombies;
CategoryId	g_category_humans;

ConVar 		g_shop_skins_zombie;
ConVar 		g_shop_skins_human;

// Menu 		g_team_menu;

char 		g_skin_zombie[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
char 		g_skin_human[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

bool 		g_in_preview[MAXPLAYERS + 1];

static int iMaxEntities;

// ==============================================================================================================================
// >>> FORWARDS
// ==============================================================================================================================
public void OnPluginStart()
{
	iMaxEntities = GetMaxEntities();
	LoadTranslations("Shop_ZRSkins.phrases");

	if ( Shop_IsStarted() ) {
		Shop_Started();
	}

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
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/shop/skins_dlist.txt");
	File_ReadDownloadList(path);
}

public void OnClientPutInServer(int client)
{
	g_skin_zombie[client][0] = 0;
	g_skin_human[client][0] = 0;
}

public void Shop_Started()
{
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
}

// ==============================================================================================================================
// >>>
// ==============================================================================================================================
void PopulateCategory(CategoryId category, const char[] source)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), source);

	KeyValues kv = new KeyValues("Skins");
	if ( !kv.ImportFromFile(path) ) {
		LogError("File \"%s\" not found or broken", source);
		delete kv;
		return;
	}

	if ( !kv.GotoFirstSubKey() ) {
		LogError("File \"%s\" is empty", source);
		delete kv;
		return;
	}

	char name[128], anim[PLATFORM_MAX_PATH];
	do {
		kv.GetSectionName(name, sizeof(name));
		kv.GetString("skin", path, sizeof(path));
		kv.GetString("anim", anim, sizeof(anim));
		if ( !IsModelPrecached(path) ) {
			PrecacheModel(path);
		}

		ItemId existingItemId = Shop_GetItemId(category, name);
		if (existingItemId != INVALID_ITEM && Shop_IsItemExists(existingItemId)) {
			Shop_UnregisterItem(existingItemId);
			LogMessage("Item %s already existed and was removed before re-adding", name);
		}

		if ( !IsModelPrecached(path) ) {
			LogError("Model \"%s\" could not be precached, skipping item \"%s\"", path, name);
			continue;
		}

		Shop_StartItem(category, name);

		Shop_SetInfo(name, "", kv.GetNum("price", 99999999), kv.GetNum("sell_price", -1), Item_Togglable, kv.GetNum("duration", 86400));
		Shop_SetCallbacks(INVALID_FUNCTION, OnSkinSelected, INVALID_FUNCTION, INVALID_FUNCTION, INVALID_FUNCTION, OnPreviewSkin);
		Shop_SetCustomInfoString("skin", path);
		Shop_SetCustomInfoString("anim", anim);

		Shop_EndItem();

	} while ( kv.GotoNextKey() );

	delete kv;
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

		CPrintToChat(client, "%t", "Skin_Changed");
		return Shop_UseOn;
	}

	CPrintToChat(client, "%t", "Skin_Changed");
	return Shop_UseOff;
}

public void OnPreviewSkin(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item)
{
	char anim[PLATFORM_MAX_PATH], skin[PLATFORM_MAX_PATH];
	Shop_GetItemCustomInfoString(item_id, "anim", anim, sizeof(anim), "default");
	Shop_GetItemCustomInfoString(item_id, "skin", skin, sizeof(skin), "");

	if ( IsPlayerAlive(client) && !g_in_preview[client] && skin[0] ) {
		g_in_preview[client] = true;
		PreviewSkins(client, skin, anim);
		CreateTimer(5.0, AlreadyUsedBack, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action AlreadyUsedBack(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	g_in_preview[client] = false;
	return Plugin_Handled;
}

void PreviewSkins(int client, const char[] sModel="", const char[] animation = "")
{
	if ( !IsValidClient(client) ) {
		return;
	}

	if ( !sModel[0] ) {
		CPrintToChat(client, "%t", "Skin_NotFound");
		return;
	}

	if (GetEdictsCount() > MAXEDICTS) {
		CPrintToChat(client, "%t", "Edicts Limit");
		return;
	}

	int entity = CreateEntityByName("prop_dynamic");

	if ( entity == -1 || !IsValidEdict(entity) ) {
		CPrintToChat(client, "%t", "Preview_Failed");
		return;
	}

	float eye[3];
	GetPlayerEye(client, eye);
	DispatchKeyValue(entity, "model", sModel);
	DispatchKeyValue(entity, "DefaultAnim", animation[0] ? animation:"default");
	DispatchSpawn(entity);

	TeleportEntity(entity, eye, NULL_VECTOR, NULL_VECTOR);
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

	SetVariantString("OnUser1 !self:Kill::5.0:1");
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
	if ( !g_shop_skins_zombie.BoolValue && !g_shop_skins_human.BoolValue )
		return;

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if ( !IsValidClient(client) )
		return;

	CreateTimer(0.5, Timer_ChangeSkin, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if ( !g_shop_skins_zombie.BoolValue && !g_shop_skins_human.BoolValue )
		return;

	if ( !IsValidClient(client) )
		return;

	CreateTimer(0.5, Timer_ChangeSkin, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ChangeSkin(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if ( !IsValidClient(client) || !IsPlayerAlive(client) )
		return Plugin_Continue;

	bool isZombie = ZR_IsClientZombie(client);

	if ( isZombie && g_shop_skins_zombie.BoolValue )
		SetSkinSafe(client, g_skin_zombie[client]);
	else if ( !isZombie && g_shop_skins_human.BoolValue )
		SetSkinSafe(client, g_skin_human[client]);

	return Plugin_Continue;
}

void SetSkinSafe(int client, const char[] skin)
{
	if ( skin[0] != 0 && IsModelPrecached(skin) ) {
		SetEntityModel(client, skin);
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

bool IsValidClient(int client, bool bAllowFake = false)
{
	if (client < 1 || client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (!bAllowFake && IsFakeClient(client))
		return false;

	return true;
}

stock int GetEdictsCount()
{
	int iCount = 0;
	for (int entity = 1; entity <= iMaxEntities; entity++)
	{
		if(IsValidEdict(entity))
			iCount++;
	}

	return iCount;
}
