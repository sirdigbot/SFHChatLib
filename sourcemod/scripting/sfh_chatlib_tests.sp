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
#pragma newdecls required // After libraries or you get warnings


//=================================
// Constants
#define PLUGIN_VERSION  "1.0.0"
#define PLUGIN_URL      "https://sirdigbot.github.io/SFHChatLib/"
#define UPDATE_URL      "https://sirdigbot.github.io/SFHChatLib/sourcemod/sfh_chatlib_tests.txt"


//=================================
// Globals
Handle  h_bUpdate     = null;
bool    g_bUpdate;



public Plugin myinfo =
{
  name =        "[TF2] Satan's Fun House - Chat Library Tests",
  author =      "SirDigby",
  description = "Basic Test Functions for ChatLib",
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
 
  return APLRes_Success;
}


public void OnPluginStart()
{
  LoadTranslations("sfh.chatlib.phrases");
  LoadTranslations("common.phrases");
  LoadTranslations("core.phrases");
  
  h_bUpdate = FindConVar("sm_sfh_chatlib_update"); // Requires sfh_chatlib
  g_bUpdate = GetConVarBool(h_bUpdate);
  HookConVarChange(h_bUpdate, UpdateCvars);
  
  RegAdminCmd("sm_chatlib_testfilter", CMD_TestFilter, ADMFLAG_ROOT, "Test Chat Library colour filtering");
  RegAdminCmd("sm_chatlib_print", CMD_TestPrints, ADMFLAG_ROOT, "Test each the print functions for Chat Library");

  PrintToServer("%T", "SFHCL_TestsLoaded", LANG_SERVER);
}

public void UpdateCvars(Handle cvar, const char[] oldValue, const char[] newValue)
{
  if(cvar == h_bUpdate)
  {
    g_bUpdate = GetConVarBool(h_bUpdate);
    if(LibraryExists("updater"))
      (g_bUpdate) ? Updater_AddPlugin(UPDATE_URL) : Updater_RemovePlugin();
  }
}



//=================================
// Commands
 
public Action CMD_TestFilter(int client, int args)
{
  if(client == 0 || GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
  {
    ReplyToCommand(client, "%t", "SFHCL_TestInGame");
    return Plugin_Handled;
  }
  
  // It's important that this test only uses native sourcemod print functions
  
  // "Engine: Lime Team Olive Default AA0000 AA00AA77 Gold -- MoreColors: Cyan Invalid Gold"
  PrintToChat(client, "Testing filter on the following string:");
  PrintToChat(client, "\\x04Lime \\x03Team \\x05Olive \\x01Default \\x07AA0000 \\x08AA00AA77 \\x06Gold\x01 -- {cyan}Cyan {invlid}Invalid {gold}Gold");
  PrintToChat(client, "------");
  
  char str1 = "Rem All: \x04Lime \x03Team \x05Olive \x01Default \x07AA0000 \x08AA00AA77 \x06Gold\x01 -- {cyan}Cyan {invlid}Invalid {gold}Gold\n---\n";
  char str2 = "Rem Single: \x04Lime \x03Team \x05Olive \x01Default \x07AA0000 \x08AA00AA77 \x06Gold\x01 -- {cyan}Cyan {invlid}Invalid {gold}Gold\n---\n";
  char str3 = "Rem Multi: \x04Lime \x03Team \x05Olive \x01Default \x07AA0000 \x08AA00AA77 \x06Gold\x01 -- {cyan}Cyan {invlid}Invalid {gold}Gold\n---\n";
  char str4 = "Rem MC: \x04Lime \x03Team \x05Olive \x01Default \x07AA0000 \x08AA00AA77 \x06Gold\x01 -- {cyan}Cyan {invlid}Invalid {gold}Gold\n------";
  SFHCL_RemoveColours(str1, true,   true,   true);
  SFHCL_RemoveColours(str2, true,   false,  false);
  SFHCL_RemoveColours(str3, false,  true,   false);
  SFHCL_RemoveColours(str4, false,  false,  true);
  
  PrintToChatEx(client, client, str1); // Note the "\n---\n" at the end of each
  PrintToChatEx(client, client, str2);
  PrintToChatEx(client, client, str3);
  PrintToChatEx(client, client, str4);
  return Plugin_Handled;
}


/**
 * Usage: sm_chatlib_print <Target/"RCON"> <Author> <Native Name> <Message>
 * If print message doesnt require author, the value is ignored.
 */
public Action CMD_TestPrints(int client, int args)
{
  if(args < 4)
  {
    ReplyToCommand(client, "Usage: sm_chatlib_print <Target/\"RCON\"> <Author> <Native Name> <Message>");
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH], arg2[MAX_NAME_LENGTH], arg3[24];
  char argFull;
  
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));
  GetCmdArg(3, arg3, sizeof(arg3));
  GetCmdArgString(argFull, sizeof(argFull));
  
  int messageIdx = StrContains(argFull, arg3, true) + strlen(arg3) + 1;
  
  int target = 0;
  if(!StrEqual(arg1, "RCON", true)) // Only really useful for TagPrintToClient and TagPrintToClientEx
    FindTarget(client, arg1, true);
  int author = FindTarget(client, arg2, true);
  
  
  // Older SFP Natives
  if(StrEqual(arg3, "TagReply", false))
    TagReply(target, argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagReplyUsage", false))
    TagReplyUsage(target, argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagPrintChat", false))
    TagPrintChat(target, argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagActivity2", false))
    TagActivity2(target, argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagPrintServer", false))
    TagPrintServer(argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagPrintToClient", false))
    TagPrintToClient(target, argFull[messageIdx]);
  
  
  // New natives added for complete API
  else if(StrEqual(arg3, "TagReplyUsageEx", false))
    TagReplyUsageEx(target, author, argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagPrintChatAll", false))
    TagPrintChatAll(argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagPrintChatEx", false))
    TagPrintChatEx(target, author, argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagPrintChatAllEx", false))
    TagPrintChatAllEx(author, argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagReplyEx", false))
    TagReplyEx(target, author, argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagActivityEx", false))
    TagActivityEx(target, argFull[messageIdx]);
    
  else if(StrEqual(arg3, "TagPrintToClientEx", false))
    TagPrintToClientEx(target, author, argFull[messageIdx]);
  
  
  else
    ReplyToCommand(client, "Usage: sm_chatlib_print <Target/\"RCON\"> <Author> <Native Name> <Message>");

  return Plugin_Handled;
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
