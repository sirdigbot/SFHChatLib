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
#include <morecolors_new> // Just regular morecolors but syntax is updated to use new declarations
#include <sfh_chatlib>
#undef REQUIRE_PLUGIN
#tryinclude <updater>
#define REQUIRE_PLUGIN
#pragma newdecls required // After libraries or you get warnings



//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL      "https://sirdigbot.github.io/SFHChatLib/"
#define UPDATE_URL      "https://sirdigbot.github.io/SFHChatLib/sourcemod/sfh_chatlib.txt"

#define MAX_TAG_LENGTH 32
#define DEFAULT_TAG       "\x04[SM]\x01"
#define DEFAULT_USAGE_TAG "\x04[SM]\x05"



//=================================
// Globals
Handle  h_bUpdate     = null;
bool    g_bUpdate;

Handle  h_szTag       = null;
char    g_szTag[MAX_TAG_LENGTH];
Handle  h_szUsageTag  = null;
char    g_szUsageTag[MAX_TAG_LENGTH];



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
  EngineVersion engine = GetEngineVersion();
  if(engine != Engine_TF2)
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
  
  MarkNativeAsOptional("GetUserMessageType"); // MoreColors needs this for extra compatability
  
  RegPluginLibrary("sfh_chatlib"); // Determined inside sfh_chatlib.inc
 
  return APLRes_Success;
}


public void OnPluginStart()
{
  LoadTranslations("sfh.chatlib.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases");
  
  h_bUpdate = CreateConVar("sm_sfh_chatlib_update", "1", "Update Satan's Fun Pack - Chat Library Automatically (Requires Updater)\n(Default: 1)", FCVAR_NONE, true, 0.0, true, 1.0);
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);
  
  // There's no \x04 in morecolors so to save bytes we'll default to empty and allow for override instead
  // of setting to "{lime}[SM]{default}" which takes up 8 chars/bytes for colours instead of 2
  h_szTag = CreateConVar("sm_sfh_chatlib_tag", "", "Tag Override for Chat Library.\nLeaving empty will default to the standard lime \"[SM]\"\nMax Length is 31.\n(Default: \"\")", FCVAR_SPONLY);
  GetConVarString(h_szTag, g_szTag, sizeof(g_szTag));
  HookConVarChange(h_szTag, UpdateCvars);
  
  h_szUsageTag = CreateConVar("sm_sfh_chatlib_usage", "", "Usage Tag Override for Chat Library.\nLeaving empty will default to lime with trailing pale green text \"[SM]\"\nMax Length is 31.\n(Default: \"\")", FCVAR_SPONLY);
  GetConVarString(h_szUsageTag, g_szUsageTag, sizeof(g_szUsageTag));
  HookConVarChange(h_szUsageTag, UpdateCvars);

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
    GetConVarString(h_szTag, g_szTag, sizeof(g_szTag));
  else if(cvar == h_szUsageTag)
    GetConVarString(h_szUsageTag, g_szUsageTag, sizeof(g_szUsageTag));
  return;
}




public void Native_TagReply(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  int written;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen];
  if(!FormatNativeString(0, 2, 3, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagReply");
    return;
  }
   
  // Buffer Tag string
  char tagBuff[MAX_TAG_LENGTH];
  Format(tagBuff, sizeof(tagBuff), (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag);

  if(GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
  {
    RemoveChatColours(outStr, outStrLen);
    RemoveChatColours(tagBuff, sizeof(tagBuff));
  }
   
  CReplyToCommandEx(client, client, "%s %s", tagBuff, outStr);
  return;
}


public void Native_TagReplyEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int author = GetNativeCell(2);
  int len;
  int written;
  
  GetNativeStringLength(3, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen];
  if(!FormatNativeString(0, 3, 4, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagReply");
    return;
  }
   
  // Buffer Tag string
  char tagBuff[MAX_TAG_LENGTH];
  Format(tagBuff, sizeof(tagBuff), (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag);

  if(GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
  {
    RemoveChatColours(outStr, outStrLen);
    RemoveChatColours(tagBuff, sizeof(tagBuff));
  }
   
  CReplyToCommandEx(client, author, "%s %s", tagBuff, outStr);
  return;
}



public void Native_TagReplyUsage(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  int written;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen];
  if(!FormatNativeString(0, 2, 3, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagReplyUsage");
    return;
  }
  
  // Buffer Usage Tag string
  char tagBuff[MAX_TAG_LENGTH];
  Format(tagBuff, sizeof(tagBuff), (strlen(g_szUsageTag) <= 0) ? DEFAULT_USAGE_TAG : g_szUsageTag);
   
  if(GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
  {
    RemoveChatColours(outStr, outStrLen);
    RemoveChatColours(tagBuff, sizeof(tagBuff));
  }
  
  CReplyToCommandEx(client, client, "%s %t: %s", tagBuff, "SFHCL_Usage", outStr); // %t not %T
  return;
}

public void Native_TagReplyUsageEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int author = GetNativeCell(2);
  int len;
  int written;
  
  GetNativeStringLength(3, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen];
  if(!FormatNativeString(0, 3, 4, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagReplyUsage");
    return;
  }
  
  // Buffer Usage Tag string
  char tagBuff[MAX_TAG_LENGTH];
  Format(tagBuff, sizeof(tagBuff), (strlen(g_szUsageTag) <= 0) ? DEFAULT_USAGE_TAG : g_szUsageTag);
   
  if(GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
  {
    RemoveChatColours(outStr, outStrLen);
    RemoveChatColours(tagBuff, sizeof(tagBuff));
  }
  
  CReplyToCommandEx(client, author, "%s %t: %s", tagBuff, "SFHCL_Usage", outStr); // %t not %T
  return;
}



public void Native_TagPrintChat(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  int written;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen]; 
  if(!FormatNativeString(0, 2, 3, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintChat");
    return;
  }
   
  // No need to clean message. PrintToChat shouldnt work on console/rcon.
    
  CPrintToChatEx(client, client, "%s %s", (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag, outStr);
  return;
}

public void Native_TagPrintChatEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int author = GetNativeCell(2);
  int len;
  int written;
  
  GetNativeStringLength(3, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen]; 
  if(!FormatNativeString(0, 3, 4, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintChat");
    return;
  }
   
  // No need to clean message. PrintToChat shouldnt work on console/rcon.
    
  CPrintToChatEx(client, author, "%s %s", (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag, outStr);
  return;
}


public void Native_TagPrintChatAll(Handle plugin, int numParams)
{
  int len;
  int written;
  
  GetNativeStringLength(1, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen]; 
  if(!FormatNativeString(0, 1, 2, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintChat");
    return;
  }
   
  // No need to clean message. PrintToChat shouldnt work on console/rcon.
    
  CPrintToChatAll("%s %s", (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag, outStr);
  return;
}


public void Native_TagPrintChatAllEx(Handle plugin, int numParams)
{
  int author = GetNativeCell(1);
  int len;
  int written;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen]; 
  if(!FormatNativeString(0, 2, 3, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintChat");
    return;
  }
   
  // No need to clean message. PrintToChat shouldnt work on console/rcon.
    
  CPrintToChatAllEx(author, "%s %s", (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag, outStr);
  return;
}



public void Native_TagActivity2(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  int written;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255;          // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen]; 
  if(!FormatNativeString(0, 2, 3, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagActivity2");
    return;
  }

  // Add a space after the tag so it looks right in chat: "[SM] Admin: <Msg>"
  int size        = sizeof(DEFAULT_TAG);
  bool tagIsEmpty = (strlen(g_szTag) <= 0);
  
  // Get EXACT sizeof() of the tag we will be appending to
  if(!tagIsEmpty)
  {
    int tagSizeOf = strlen(g_szTag) + 1;
    size = (size > tagSizeOf) ? size : tagSizeOf;
  }
  
  // Create string that is full tag + 1 space
  char[] tagBuff = new char[size + 1];
  strcopy(tagBuff, size, (tagIsEmpty) ? DEFAULT_TAG : g_szTag);
  tagBuff[size] = " ";
  
  
  // No need to clean message. Engine Handles it I believe.
  // And ShowActivity2 is also handled differently per-client.
  // TODO: Verify this.
  
  CShowActivity2(client, tagBuff, "%s", outStr);
  return;
}


public void Native_TagActivityEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  int written;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255;          // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen]; 
  if(!FormatNativeString(0, 2, 3, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagActivity2");
    return;
  }

  // Add a space after the tag so it looks right in chat: "[SM] Admin: <Msg>"
  int size        = sizeof(DEFAULT_TAG);
  bool tagIsEmpty = (strlen(g_szTag) <= 0);
  
  // Get EXACT sizeof() of the tag we will be appending to
  if(!tagIsEmpty)
  {
    int tagSizeOf = strlen(g_szTag) + 1;
    size = (size > tagSizeOf) ? size : tagSizeOf;
  }
  
  // Create string that is full tag + 1 space
  char[] tagBuff = new char[size + 1];
  strcopy(tagBuff, size, (tagIsEmpty) ? DEFAULT_TAG : g_szTag);
  tagBuff[size] = " ";
  
  
  // No need to clean message. Engine Handles it I believe.
  // And ShowActivity2 is also handled differently per-client.
  // TODO: Verify this.
  
  CShowActivityEx(client, tagBuff, "%s", outStr);
  return;
}



public void Native_TagPrintServer(Handle plugin, int numParams)
{
  int len;
  int written;
  
  GetNativeStringLength(1, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen]; 
  if(!FormatNativeString(0, 1, 2, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintServer");
    return;
  }
  
  // Buffer Tag string
  char tagBuff[MAX_TAG_LENGTH];
  Format(tagBuff, sizeof(tagBuff), (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag);
    
  // Always remove colours when printing to server.
  RemoveChatColours(outStr, outStrLen);
  RemoveChatColours(tagBuff, sizeof(tagBuff));
    
  PrintToServer("%s %s", tagBuff, outStr);
  return;
}



public void Native_TagPrintToClient(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int len;
  int written;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen]; 
  if(!FormatNativeString(0, 2, 3, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintChat");
    return;
  }
   
  // This Print function has no native equivalent:
  // It prints to either chat or server depending on client index alone (No ReplySource)
  // PrintToChat never needs colours removed as it shouldnt work on console/rcon
  if(client == 0)
  {
    // Buffer Tag string
    char tagBuff[MAX_TAG_LENGTH];
    Format(tagBuff, sizeof(tagBuff), (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag);
      
    RemoveChatColours(outStr, outStrLen);
    RemoveChatColours(tagBuff, sizeof(tagBuff));
    
    PrintToServer("%s %s", tagBuff, outStr);
  }
  else
    CPrintToChatEx(client, client, "%s %s", (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag, outStr);
  return;
}

public void Native_TagPrintToClientEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int author = GetNativeCell(2);
  int len;
  int written;
  
  GetNativeStringLength(3, len);
  if(len <= 0)
    return;
  
  // Get message
  int outStrLen = len + 255; // Length + Space for formatting (capped at chat msg length)
  char[] outStr = new char[outStrLen]; 
  if(!FormatNativeString(0, 3, 4, outStrLen, written, outStr))
  {
    ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "TagPrintChat");
    return;
  }
   
  // This Print function has no native equivalent:
  // It prints to either chat or server depending on client index alone (No ReplySource)
  // PrintToChat never needs colours removed as it shouldnt work on console/rcon
  if(client == 0)
  {
    // Buffer Tag string
    char tagBuff[MAX_TAG_LENGTH];
    Format(tagBuff, sizeof(tagBuff), (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag);
      
    RemoveChatColours(outStr, outStrLen);
    RemoveChatColours(tagBuff, sizeof(tagBuff));
    
    PrintToServer("%s %s", tagBuff, outStr);
  }
  else
    CPrintToChatEx(client, author, "%s %s", (strlen(g_szTag) <= 0) ? DEFAULT_TAG : g_szTag, outStr);
  return;
}



public int Native_SFHCL_RemoveColours(Handle plugin, int numParams)
{
  int len;
  
  GetNativeStringLength(2, len);
  if(len <= 0)
    return;
  
  // Get string
  char[] strBuff = new char[len]; 
  GetNativeString(1, strBuff, len);
  
  // Get bool flags
  bool singleBytes  = view_as<bool>(GetNativeCell(2));
  bool multiBytes   = view_as<bool>(GetNativeCell(3));
  bool moreColors   = view_as<bool>(GetNativeCell(4));

  int result = RemoveChatColours(strBuff, singleBytes, multiBytes, moreColors);
  SetNativeString(1, strBuff, len, false);
  return result;
}


public bool Native_SFHCL_IsSingleByteColour(Handle plugin, int numParams)
{
  return IsSingleByteColour(GetNativeCell(1));
}




/**
 * Remove all the source-engine-native chat colours from a string (TF2 Only).
 * Specifically this can remove:
 * - Single-byte Colours: 0x01, 0x03, 0x04, 0x05, 0x06
 * - Multibyte Colours: 0x07+6 bytes (Hex Colour), and 0x08+8 bytes (Hex+Alpha Colour)
 * - MoreColors tags
 *
 * @param str	            String to remove colours from
 * @param maxlength       Maximum length of string
 * @param singleBytes     Remove single-byte engine colours (\x01 is always removed regardless.)
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
  const char removalByte = '\x01';  // 0x01 is safest value in event of failure (Default colour)
  
  for(int i = 0; i < maxlength; ++i)
  {
    if(str[i] == removalByte)
      continue;
      
    else if(singleBytes && IsSingleByteColour(str[i]))
      str[i] = removalByte;
    else if(multiBytes && (str[i] == '\x07' || str[i] == '\x08'))
    {
      // Replace Hex Colour (\x07ABCABC -- 7 characters) or Hex+Alpha (\x08ABCABCAB -- 9 characters)
      for(int j = 0; j <= ((str[i] == '\x07') ? 7 : 9); ++j)
      {
        if(i + j < maxlength)
          str[i + j] = removalByte;
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
        
        if(CColorExists(tagText))
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
  char[2] dummyString = {removalByte, '\0'};              // Must use char[] in ReplaceString
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