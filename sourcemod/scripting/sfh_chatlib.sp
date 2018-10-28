/***********************************************************************
 * This Source Code Form is subject to the terms of the Mozilla Public *
 * License, v. 2.0. If a copy of the MPL was not distributed with this *
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.            *
 *                                                                     *
 * Copyright (C) 2018 SirDigbot                                        *
 ***********************************************************************/
 
#pragma semicolon 1
//=================================
// Libraries/Modules
#include <sourcemod>
#include <sfh_chatlib>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required



//=================================
// Constants
#define PLUGIN_VERSION  "1.1.0"
#define PLUGIN_URL      "https://sirdigbot.github.io/SFHChatLib/"
#define UPDATE_URL      "https://sirdigbot.github.io/SFHChatLib/sourcemod/sfh_chatlib.txt"

#define MAX_TAG_LENGTH    32
#define DEFAULT_TAG_VALUE "DEFAULT" // Value to set the tag cvars to to indicate default
#define DEFAULT_TAG       "\x04[SM]\x01"
#define DEFAULT_USAGE_TAG "\x04[SM]\x05"



//=================================
// Globals
Handle  h_bUpdate     = null;
bool    g_bUpdate;
EngineVersion g_Engine; // Used by MoreColors

Handle  h_szTag       = null;
char    g_szTag[MAX_TAG_LENGTH];
Handle  h_szUsageTag  = null;
char    g_szUsageTag[MAX_TAG_LENGTH];



#include "sfhcl/sfh_morecolors.sp" // Add MoreColors Native Reimplementation



public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun House - Chat Library",
  author =      "SirDigby",
  description = "Colour Message Library",
  version =     PLUGIN_VERSION,
  url =         PLUGIN_URL
};



//=================================
// Forwards/Events
public APLRes AskPluginLoad2(Handle self, bool late, char[] err, int err_max)
{
  g_Engine = GetEngineVersion();
  if(g_Engine != Engine_TF2)
  {
    Format(err, err_max, "Satan's Fun House - Chat Library is only compatible with Team Fortress 2.");
    return APLRes_Failure;
  }

  // Older SFP Natives
  CreateNative("TagReply",            Native_TagReply);
  CreateNative("TagReplyUsage",       Native_TagReplyUsage);
  CreateNative("TagPrintChat",        Native_TagPrintChat);
  CreateNative("TagActivity2",        Native_TagActivity2);
  CreateNative("TagPrintServer",      Native_TagPrintServer);
  CreateNative("TagPrintToClient",    Native_TagPrintToClient);
  
  // New natives added for complete API
  CreateNative("TagReplyUsageEx",     Native_TagReplyUsageEx);
  CreateNative("TagPrintChatAll",     Native_TagPrintChatAll);
  CreateNative("TagPrintChatEx",      Native_TagPrintChatEx);
  CreateNative("TagPrintChatAllEx",   Native_TagPrintChatAllEx);
  CreateNative("TagReplyEx",          Native_TagReplyEx);
  CreateNative("TagActivityEx",       Native_TagActivityEx);
  CreateNative("TagPrintToClientEx",  Native_TagPrintToClientEx);
  
  // Misc Natives
  CreateNative("SFHCL_RemoveColours",       Native_SFHCL_RemoveColours);
  CreateNative("SFHCL_IsSingleByteColour",  Native_SFHCL_IsSingleByteColour);
  
  // MoreColors
  SFHCL_MC_CreateNatives();
  MarkNativeAsOptional("GetUserMessageType"); // MoreColors needs this for extra compatability
  
  RegPluginLibrary("sfh_chatlib"); // Determined inside sfh_chatlib.inc
 
  return APLRes_Success;
}


public void OnPluginStart()
{
  LoadTranslations("sfh.chatlib.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases");
  
  CreateConVar("satansfunhouse_chat_version", PLUGIN_VERSION, "Satan's Fun House - Chat Library version. Do Not Touch!", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
  
  h_bUpdate = CreateConVar("sm_sfh_chatlib_update", "1", "Update Satan's Fun House - Chat Library Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);
  
  // MoreColors can't set \x04 so to save bytes the empty tag cvar defaults to "\x04[SM]\x01" instead of "\x07ABCABC[SM]\x01"
  h_szTag = CreateConVar("sm_sfh_chatlib_tag", DEFAULT_TAG_VALUE, "Tag Override for Chat Library.\nSetting to \"DEFAULT\" will default to the standard lime \"[SM]\"\nMax Length is 31.\n(Default: \"DEFAULT\")", FCVAR_NONE);
  UpdateTag();
  HookConVarChange(h_szTag, UpdateCvars);
  
  h_szUsageTag = CreateConVar("sm_sfh_chatlib_usage", DEFAULT_TAG_VALUE, "Usage Tag Override for Chat Library (Excluding \"Usage\").\nSetting to \"DEFAULT\" will default to lime with trailing pale green text \"[SM]\"\nMax Length is 31.\n(Default: \"DEFAULT\")", FCVAR_NONE);
  UpdateUsageTag();
  HookConVarChange(h_szUsageTag, UpdateCvars);
  
  SFHCL_MC_OnPluginStart();

  PrintToServer("%T", "SFHCL_PluginLoaded", LANG_SERVER);
}

public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
  else if(cvar == h_szTag)
    UpdateTag();
  else if(cvar == h_szUsageTag)
    UpdateUsageTag();
  return;
}

void UpdateTag()
{
  GetConVarString(h_szTag, g_szTag, sizeof(g_szTag));
  if(StrEqual(g_szTag, DEFAULT_TAG_VALUE, true))
    strcopy(g_szTag, sizeof(g_szTag), DEFAULT_TAG);
  else
    CReplaceColorCodes(g_szTag); // Process colour codes in advance for minor optimisation
}

void UpdateUsageTag()
{
  GetConVarString(h_szUsageTag, g_szUsageTag, sizeof(g_szUsageTag));
  if(StrEqual(g_szUsageTag, DEFAULT_TAG_VALUE, true))
    strcopy(g_szUsageTag, sizeof(g_szUsageTag), DEFAULT_USAGE_TAG);
  else
    CReplaceColorCodes(g_szUsageTag);
}




/* native void TagReply(const int client, const char[] msg, any ...); */
public int Native_TagReply(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 2, 3, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagReply");

  CReplyToCommandEx(client, client, "%s %s", g_szTag, msg); // Native MoreColors does cleaning
  return 0;
}

/* native void TagReplyEx(const int client, const int author, const char[] msg, any ...); */
public int Native_TagReplyEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int author = GetNativeCell(2);
  int len;
  
  GetNativeStringLength(3, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 3, 4, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagReplyEx");

  CReplyToCommandEx(client, author, "%s %s", g_szTag, msg); // Native MoreColors does cleaning
  return 0;
}

/* native void TagReplyUsage(const int client, const char[] msg, any ...); */
public int Native_TagReplyUsage(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 2, 3, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagReplyUsage");

  CReplyToCommandEx(client, client, "%s %t\x01: %s", g_szUsageTag, "SFHCL_Usage", msg); // %t not %T. Native MoreColors does cleaning
  return 0;
}

/* native void TagReplyUsageEx(const int client, const int author, const char[] msg, any ...); */
public int Native_TagReplyUsageEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int author = GetNativeCell(2);
  int len;
  
  GetNativeStringLength(3, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 3, 4, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagReplyUsageEx");

  CReplyToCommandEx(client, author, "%s %t\x01: %s", g_szUsageTag, "SFHCL_Usage", msg); // %t not %T. Native MoreColors does cleaning
  return 0;
}



/* native void TagPrintChat(const int client, const char[] msg, any ...); */
public int Native_TagPrintChat(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 2, 3, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintChat");

  CPrintToChatEx(client, client, "%s %s", g_szTag, msg); // Native MoreColors does cleaning
  return 0;
}

/* native void TagPrintChatEx(const int client, const int author, const char[] msg, any ...); */
public int Native_TagPrintChatEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int author = GetNativeCell(2);
  int len;
  
  GetNativeStringLength(3, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 3, 4, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintChatEx");

  CPrintToChatEx(client, author, "%s %s", g_szTag, msg); // Native MoreColors does cleaning
  return 0;
}

/* native void TagPrintChatAll(const char[] msg, any ...); */
public int Native_TagPrintChatAll(Handle plugin, int numParams)
{
  int len;
  
  GetNativeStringLength(1, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 1, 2, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintChatAll");

  CPrintToChatAll("%s %s", g_szTag, msg); // Native MoreColors does cleaning
  return 0;
}

/* native void TagPrintChatAllEx(const int author, const char[] msg, any ...); */
public int Native_TagPrintChatAllEx(Handle plugin, int numParams)
{
  int author = GetNativeCell(1);
  int len;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 2, 3, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintChatAllEx");

  CPrintToChatAllEx(author, "%s %s", g_szTag, msg); // Native MoreColors does cleaning
  return 0;
}




/* native void TagActivity2(const int client, const char[] msg, any ...); */
public int Native_TagActivity2(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 2, 3, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagActivity2");

  // Get tag and append a space (so it displays properly)
  int size = strlen(g_szTag) + 2; // +2 = Space + '\0'
  char[] tag = new char[size];
  Format(tag, size, "%s ", g_szTag);
  
  CShowActivity2(client, tag, msg);  // Native MoreColors does cleaning
  return 0;
}

/* native void TagActivityEx(const int client, const char[] msg, any ...); */
public int Native_TagActivityEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 2, 3, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagActivityEx");

  // Get tag and append a space (so it displays properly)
  int size = strlen(g_szTag) + 2; // +2 = Space + '\0'
  char[] tag = new char[size];
  Format(tag, size, "%s ", g_szTag);
  
  CShowActivityEx(client, tag, msg);  // Native MoreColors does cleaning
  return 0;
}



/* native void TagPrintServer(const char[] msg, any ...); */
public int Native_TagPrintServer(Handle plugin, int numParams)
{
  int len;
  
  GetNativeStringLength(1, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 1, 2, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintServer");

  int buffSize = len + MAX_TAG_LENGTH + 1; // +Space
  char[] buff = new char[buffSize]; 
  Format(buff, buffSize, "%s %s", g_szTag, msg);
  RemoveChatColours(buff, buffSize);
  PrintToServer(buff);
  return 0;
}



/* native void TagPrintToClient(const int client, const char[] msg, any ...); */
public int Native_TagPrintToClient(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 2, 3, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintToClient");

  // This Print function has no native equivalent:
  // It's basically ReplyToCommand but it doesnt use a ReplySource
  if(client == 0)
  {
    int buffSize = len + MAX_TAG_LENGTH + 1; // +Space
    char[] buff = new char[buffSize]; 
    Format(buff, buffSize, "%s %s", g_szTag, msg);
    RemoveChatColours(buff, buffSize);
    PrintToServer(buff);
  }
  else
    CPrintToChatEx(client, client, "%s %s", g_szTag, msg); // Native MoreColors does cleaning
  return 0;
}

/* native void TagPrintToClientEx(const int client, const int author, const char[] msg, any ...); */
public int Native_TagPrintToClientEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int author = GetNativeCell(2);
  int len;
  
  GetNativeStringLength(3, len);
  if(len <= 0)
    return 0;
    
  len += 255; // For formatting
  char[] msg = new char[len];
  if(FormatNativeString(0, 3, 4, len, _, msg) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintToClientEx");

  // This Print function has no native equivalent:
  // It's basically ReplyToCommand but it doesnt use a ReplySource
  if(client == 0)
  {
    int buffSize = len + MAX_TAG_LENGTH + 1; // +Space
    char[] buff = new char[buffSize]; 
    Format(buff, buffSize, "%s %s", g_szTag, msg);
    RemoveChatColours(buff, buffSize);
    PrintToServer(buff);
  }
  else
    CPrintToChatEx(client, author, "%s %s", g_szTag, msg); // Native MoreColors does cleaning
  return 0;
}



/* native int SFHCL_RemoveColours(char[] str, const bool singleBytes=true, const bool multiBytes=true, const bool moreColorsTags=true); */
public int Native_SFHCL_RemoveColours(Handle plugin, int numParams)
{
  int len;
  
  GetNativeStringLength(1, len);
  if(len <= 0)
    return 0;
    
  len += 1; // Include '\0' so len is maxlength/sizeof()
  
  // Get string
  char[] strBuff = new char[len];
  GetNativeString(1, strBuff, len);
  
  // Get bool flags
  bool singleBytes  = view_as<bool>(GetNativeCell(2));
  bool multiBytes   = view_as<bool>(GetNativeCell(3));
  bool moreColors   = view_as<bool>(GetNativeCell(4));

  int result = RemoveChatColours(strBuff, len, singleBytes, multiBytes, moreColors);
  SetNativeString(1, strBuff, len, false);
  return result;
}

/* native bool SFHCL_IsSingleByteColour(const char byte); */
public int Native_SFHCL_IsSingleByteColour(Handle plugin, int numParams)
{
  return view_as<int>(IsSingleByteColour(GetNativeCell(1)));
}




/**
 * Remove all the source-engine-native chat colours from a string (TF2 Only).
 * Specifically this can remove:
 * - Single-byte Colours: 0x01, 0x03, 0x04, 0x05, 0x06
 * - Multibyte Colours: 0x07+6 bytes (Hex Colour), and 0x08+8 bytes (Hex+Alpha Colour)
 * - MoreColors tags
 *
 * @param str             String to remove colours from
 * @param maxlength       Maximum length of string
 * @param singleBytes     Remove single-byte engine colours (0x10 is always removed regardless.)
 * @param multiBytes      Remove multi-byte engine colours
 * @param moreColorsTags  Remove MoreColors tags
 *
 * @return number of bytes removed from string
 */
stock int RemoveChatColours(char[] str,
  const int maxlength,
  const bool singleBytes=true,
  const bool multiBytes=true,
  const bool moreColorsTags=true)
{
  // Turn all single-byte and multi-byte engine colours into the same value to slate for removal
  //
  // Simultaneously, search for any text between {}'s and if it's a valid MoreColors tag
  // change each byte of the tag string into 0x01 to also slate for removal.
 
  int startingBraceIdx  = -1;       // Index of '{'
  int endingBraceIdx    = -1;       // Index of the '}' that follows the '{' (startingBraceIdx)
  const char removalByte = '\x10';  // 0x10 (NOT 0x01) does nothing in any game's chat, so it's always safe to remove
  
  for(int i = 0; i < maxlength; ++i)
  {
    if(str[i] == removalByte)
      continue;
      
    else if(singleBytes && IsSingleByteColour(str[i]))
      str[i] = removalByte;
    else if(multiBytes && (str[i] == '\x07' || str[i] == '\x08'))
    {
      int loopMax = (str[i] == '\x07') ? 7 : 9;
      
      // Replace Hex Colour (\x07ABCABC -- 7 characters) or Hex+Alpha (\x08ABCABCAB -- 9 characters)
      for(int j = 0; j < loopMax; ++j)
      {
        int offset = i + j;
        if(offset < maxlength)
          str[offset] = removalByte; // The offset bytes are ignored when checked in outer loop.
        else
          break;
      }
      
      
    }

    // Replace MoreColors Tags
    else if(moreColorsTags && str[i] == '{')
    {
      // Always reset starting brace. Tags always match "{[a-zA-Z0-9]+}" and cant nest {}'s
      startingBraceIdx = i;
    }
    else if(moreColorsTags && str[i] == '}')
    {
      endingBraceIdx = i;
      
      // If pattern matching "{<Text>}" found.
      if(endingBraceIdx > startingBraceIdx && startingBraceIdx > -1)
      {
        // Get text between tag
        int size = endingBraceIdx - startingBraceIdx;     // Minus {}'s, but Plus Zero Terminator
        char[] tagText = new char[size];
        strcopy(tagText, size, str[startingBraceIdx+1]);  // Skip starting brace
        
        if(CColorExists(tagText) || StrEqual(tagText, "default", false) || StrEqual(tagText, "teamcolor", false))
        {
          for(int j = startingBraceIdx; j < endingBraceIdx + 1; ++j)
            str[j] = removalByte;
          
          // Tag removed. Reset brace indexes
          startingBraceIdx = -1;
          endingBraceIdx = -1;
        }
      }
    }    
  }
  
  // Replace all instances of 0x01/removalByte
  // TODO: Verify if doing this manually is faster/more efficient
  char dummyString[2] = removalByte; // Must use char[] in ReplaceString
  return ReplaceString(str, maxlength, dummyString, "", true);
}

/**
 * Does character/byte match a single-byte source engine colour code (TF2 Only).
 * @return        True for 0x01, 0x03, 0x04, 0x05, 0x06, false otherwise
 */
stock bool IsSingleByteColour(const char byte)
{
  switch(byte)
  {
    case '\x01': return true;
    case '\x03': return true;
    case '\x04': return true;
    case '\x05': return true;
    case '\x06': return true;
  }
  return false;
}




//=================================
// Updater
public void OnConfigsExecuted()
{
  if(LibraryExists("updater") && g_bUpdate)
    Updater_AddPlugin(UPDATE_URL);
  return;
}

public void OnLibraryAdded(const char[] name)
{
  if(StrEqual(name, "updater") && g_bUpdate)
    Updater_AddPlugin(UPDATE_URL);
  return;
}

public void OnLibraryRemoved(const char[] name)
{
  if(StrEqual(name, "updater"))
    Updater_RemovePlugin();
  return;
}