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
  
  RegAdminCmd("sm_cltest_filter", CMD_TestFilterParams, ADMFLAG_ROOT, "Test Chat Library colour filtering");
  RegAdminCmd("sm_cltest_print",  CMD_TestPrints, ADMFLAG_ROOT, "Test each the print functions for Chat Library");
  RegAdminCmd("sm_cltest_mc",     CMD_TestMoreColors, ADMFLAG_ROOT, "Test MoreColors Natives");

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

/**
 * Test the effects of varying the parameters for SFHCL_RemoveColours() on a large,
 * catch-major-cases string.
 */
public Action CMD_TestFilterParams(int client, int args)
{
  if(client == 0 || GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
  {
    ReplyToCommand(client, "%t", "SFHCL_TestInGame");
    return Plugin_Handled;
  }
  
  // It's important that this test only uses native sourcemod print functions

  // Testing string (minus colours)
  // "Engine Colours: Lime Team Invalid Olive Default AA00AAMagenta AA00AA77Translucent Gold -- MoreColors: Cyan Invalid Gold"
  PrintToChat(client, "Testing SFHCL_RemoveColours on string:");
  PrintToChat(client, "\\x04Lime \\x03Team \\x02Invalid \\x05Olive \\x01Default \\x07AA00AAMagenta \\x08AA00AA77Translucent \\x06Gold -- {cyan}Cyan {invlid}Invalid {gold}Gold");
  PrintToChat(client, "---\n");
  
  char strEmpty[105]      = "NoColours: 'Lime Team Invalid Olive Default AA00AAMagenta AA00AA77Translucent Gold -- Cyan Invalid Gold'";
  char strNone[152]       = "None: '\x04Lime \x03Team \x02Invalid \x05Olive \x01Default \x07AA00AAMagenta \x08AA00AA77Translucent \x06Gold -- {cyan}Cyan {invlid}Invalid {gold}Gold'";
  char strAll[151]        = "All: '\x04Lime \x03Team \x02Invalid \x05Olive \x01Default \x07AA00AAMagenta \x08AA00AA77Translucent \x06Gold -- {cyan}Cyan {invlid}Invalid {gold}Gold'";
  char strSingle[154]     = "Single: '\x04Lime \x03Team \x02Invalid \x05Olive \x01Default \x07AA00AAMagenta \x08AA00AA77Translucent \x06Gold -- {cyan}Cyan {invlid}Invalid {gold}Gold'";
  char strMulti[153]      = "Multi: '\x04Lime \x03Team \x02Invalid \x05Olive \x01Default \x07AA00AAMagenta \x08AA00AA77Translucent \x06Gold -- {cyan}Cyan {invlid}Invalid {gold}Gold'";
  char strMoreColors[158] = "MoreColors: '\x04Lime \x03Team \x02Invalid \x05Olive \x01Default \x07AA00AAMagenta \x08AA00AA77Translucent \x06Gold -- {cyan}Cyan {invlid}Invalid {gold}Gold'";
  char strNesting[41]     = "NestingMC: '{{}}{}{gold}}}}{{cyan}{{{}}'";
  
  int emptyResult   = SFHCL_RemoveColours(strEmpty,       true,   true,   true);
  int noneResult    = SFHCL_RemoveColours(strNone,        false,  false,  false);
  int allResult     = SFHCL_RemoveColours(strAll,         true,   true,   true);
  int singleResult  = SFHCL_RemoveColours(strSingle,      true,   false,  false);
  int multiResult   = SFHCL_RemoveColours(strMulti,       false,  true,   false);
  int mcResult      = SFHCL_RemoveColours(strMoreColors,  false,  false,  true);
  int nestingResult = SFHCL_RemoveColours(strNesting,     true,   true,   true);
  
  bool emptyPass    = (emptyResult == 0 && StrEqual(strEmpty,       "NoColours: 'Lime Team Invalid Olive Default AA00AAMagenta AA00AA77Translucent Gold -- Cyan Invalid Gold'", true));
  bool nonePass     = (noneResult == 0 && StrEqual(strNone,         "None: '\x04Lime \x03Team \x02Invalid \x05Olive \x01Default \x07AA00AAMagenta \x08AA00AA77Translucent \x06Gold -- {cyan}Cyan {invlid}Invalid {gold}Gold'", true));
  bool allPass      = (allResult == 33 && StrEqual(strAll,          "All: 'Lime Team \x02Invalid Olive Default Magenta Translucent Gold -- Cyan {invlid}Invalid Gold'", true));
  bool singlePass   = (singleResult == 5 && StrEqual(strSingle,     "Single: 'Lime Team \x02Invalid Olive Default \x07AA00AAMagenta \x08AA00AA77Translucent Gold -- {cyan}Cyan {invlid}Invalid {gold}Gold'", true));
  bool multiPass    = (multiResult == 16 && StrEqual(strMulti,      "Multi: '\x04Lime \x03Team \x02Invalid \x05Olive \x01Default Magenta Translucent \x06Gold -- {cyan}Cyan {invlid}Invalid {gold}Gold'", true));
  bool mcPass       = (mcResult == 12 && StrEqual(strMoreColors,    "MoreColors: '\x04Lime \x03Team \x02Invalid \x05Olive \x01Default \x07AA00AAMagenta \x08AA00AA77Translucent \x06Gold -- Cyan {invlid}Invalid Gold'", true));
  bool nestingPass  = (nestingResult == 12 && StrEqual(strNesting,  "NestingMC: '{{}}{}}}}{{{{}}'"));
  
  PrintToChat(client, "TESTS PASSED: Empty:%i|None:%i|All:%i|Single:%i|Multi:%i|MoreColors:%i|Nesting:%i\n---\n", emptyPass, nonePass, allPass, singlePass, multiPass, mcPass, nestingPass);
  PrintToChat(client, "R:%i|%s", emptyResult,   strEmpty);
  PrintToChat(client, "R:%i|%s", noneResult,    strNone);
  PrintToChat(client, "R:%i|%s", allResult,     strAll);
  PrintToChat(client, "R:%i|%s", singleResult,  strSingle);
  PrintToChat(client, "R:%i|%s", multiResult,   strMulti);
  PrintToChat(client, "R:%i|%s", mcResult,      strMoreColors);
  PrintToChat(client, "R:%i|%s", nestingResult, strNesting);
  return Plugin_Handled;
}


/**
 * Test all individual native print commands to check functionality in isolation.
 * Usage: sm_cltest_print <Target/"RCON"> <Author> <Native Name> <Message>
 * If print message doesnt require author, the value is ignored.
 */
public Action CMD_TestPrints(int client, int args)
{
  if(args < 4)
  {
    ReplyToCommand(client, "Usage: sm_cltest_print <Target/\"RCON\"> <Author> <Native Name> <Message>");
    return Plugin_Handled;
  }

  char arg1[MAX_NAME_LENGTH], arg2[MAX_NAME_LENGTH], arg3[24];
  char argFull[256];
  
  GetCmdArg(1, arg1, sizeof(arg1));
  GetCmdArg(2, arg2, sizeof(arg2));
  GetCmdArg(3, arg3, sizeof(arg3));
  GetCmdArgString(argFull, sizeof(argFull));
  
  int messageIdx = StrContains(argFull, arg3, true) + strlen(arg3) + 1;
  
  int target = 0;
  if(!StrEqual(arg1, "RCON", true)) // Only really useful for TagPrintToClient and TagPrintToClientEx
    target = FindTarget(client, arg1, false); // Bots allowed, but will likely not work in most cases. Just for testing.
  if(target == -1)
    return Plugin_Handled; // FindTarget prints message
  
  int author = FindTarget(client, arg2, false);
  if(author == -1)
    return Plugin_Handled;
  
  
  // Older SFP Natives
  if(StrEqual(arg3, "TagReply", true))
    TagReply(target, argFull[messageIdx]);
  else if(StrEqual(arg3, "TagReplyUsage", true))
    TagReplyUsage(target, argFull[messageIdx]);
  else if(StrEqual(arg3, "TagPrintChat", true))
    TagPrintChat(target, argFull[messageIdx]);
  else if(StrEqual(arg3, "TagActivity2", true)) // TagActivityEx and TagActivity2 have identical code
    TagActivity2(target, argFull[messageIdx]);
  else if(StrEqual(arg3, "TagPrintServer", true))
    TagPrintServer(argFull[messageIdx]);
  
  
  // New natives added for complete API
  else if(StrEqual(arg3, "TagReplyUsageEx", true))
    TagReplyUsageEx(target, author, argFull[messageIdx]);
  else if(StrEqual(arg3, "TagPrintChatAll", true))
    TagPrintChatAll(argFull[messageIdx]);
  else if(StrEqual(arg3, "TagPrintChatEx", true))
    TagPrintChatEx(target, author, argFull[messageIdx]);
  else if(StrEqual(arg3, "TagPrintChatAllEx", true))
    TagPrintChatAllEx(author, argFull[messageIdx]);
  else if(StrEqual(arg3, "TagReplyEx", true))
    TagReplyEx(target, author, argFull[messageIdx]);
    
  // MoreColors Print Natives
  else if(StrEqual(arg3, "CPrintToChat", true))
    CPrintToChat(target, argFull[messageIdx]);
  else if(StrEqual(arg3, "CPrintToChatAll", true))
    CPrintToChatAll(argFull[messageIdx]);
  else if(StrEqual(arg3, "CPrintToChatEx", true))
    CPrintToChatEx(target, author, argFull[messageIdx]);
  else if(StrEqual(arg3, "CPrintToChatAllEx", true))
    CPrintToChatAllEx(author, argFull[messageIdx]);
  else if(StrEqual(arg3, "CReplyToCommand", true))
    CReplyToCommand(target, argFull[messageIdx]);
  else if(StrEqual(arg3, "CReplyToCommandEx", true))
    CReplyToCommandEx(target, author, argFull[messageIdx]);
  else if(StrEqual(arg3, "CShowActivity", true))
    CShowActivity(target, argFull[messageIdx]);
  else if(StrEqual(arg3, "CShowActivity2", true)) // CShowActivityEx and CShowActivity2 have identical code
    CShowActivity2(target, "{green}TAG {default}", argFull[messageIdx]);
  else if(StrEqual(arg3, "CSendMessage", true))
    CSendMessage(target, author, argFull[messageIdx]);
  
  
  else
    ReplyToCommand(client, "Usage: sm_cltest_print <Target/\"RCON\"> <Author> <Native Name> <Message>");

  return Plugin_Handled;
}



public Action CMD_TestMoreColors(int client, int args)
{
  /**
   * I'll be honest, these are pretty much useless as tests.
   * But I don't know how to do it better
   * Also dont run this on a normal server because it's awfully laggy
   */
   
  PrintToChat(client, "1. Regular");
  CPrintToChat(client, "{gold}AB{default}CD");
  CPrintToChat(client, "<8 Custom:{default}AB{gold}CD");          // Short custom
  CPrintToChat(client, ">8 Custom:{default}AB{yellowgreen}CD");   // Long custom (>8)
  CPrintToChat(client, "Custom Inv:{default}AB{!gold}CD");        // Custom Invert
  CPrintToChat(client, "Hex:{default}AB{#FF00FF}CD");             // Hex
  CPrintToChat(client, "Hex Invert:{default}AB{!#FF00FF}CD");     // Hex Invert
  CPrintToChat(client, "Hex ^Inv:{default}AB{^#FF00FF}CD");       // Hex Full Invert (should be same as regular invert)
  CPrintToChat(client, "Hex+A:{default}AB{#FF00FF66}CD");         // Hex+Alpha
  CPrintToChat(client, "Hex+A Inv:{default}AB{!#FF00FF66}CD");    // Hex+Alpha Invert
  CPrintToChat(client, "Hex+A ^Inv:{default}AB{^#FF00FF66}CD");   // Hex+Alpha Full Invert
  CPrintToChat(client, "{default}AB{teamcolor}CD");
  CPrintToChat(client, "{gold}AB{teamcolor}CD");
  
  PrintToChat(client, "2. Regular Trail");
  CPrintToChat(client, "AB{gold}CD{default}");
  CPrintToChat(client, "<8 Custom:AB{default}CD{gold}");          // Short custom
  CPrintToChat(client, ">8 Custom:AB{default}CD{yellowgreen}");   // Long custom (>8)
  CPrintToChat(client, "Custom Inv:AB{default}CD{!gold}");        // Custom Invert
  CPrintToChat(client, "Hex:AB{default}CD{#FF00FF}");             // Hex
  CPrintToChat(client, "Hex Inv:AB{default}CD{!#FF00FF}");        // Hex Invert
  CPrintToChat(client, "Hex ^Inv:AB{default}CD{^#FF00FF}");       // Hex Full Invert (should be same as regular invert)
  CPrintToChat(client, "Hex+A:AB{default}CD{#FF00FF66}");         // Hex+Alpha
  CPrintToChat(client, "Hex+A Inv:AB{default}CD{!#FF00FF66}");    // Hex+Alpha Invert
  CPrintToChat(client, "Hex+A ^Inv:AB{default}CD{^#FF00FF66}");   // Hex+Alpha Full Invert
  CPrintToChat(client, "AB{default}CD{teamcolor}");
  CPrintToChat(client, "AB{gold}CD{teamcolor}");
  
  PrintToChat(client, "3. Invalid");
  CPrintToChat(client, "{geld}AB{}CD{!default}EF{t}GH");
  CPrintToChat(client, "AB{geld}CD{}EF{!default}GH{t}");
  CPrintToChat(client, "AB{geld}CD{}EF{^default}GH{t}");

  PrintToChat(client, "4. Combo + Combo Trail");
  CPrintToChat(client, "{teamcolor}AB{geld}CD{gold}EF{default}GH");
  CPrintToChat(client, "AB{teamcolor}CD{geld}EF{gold}GH{default}");
  
  
  PrintToChat(client, "5. Gibberish Parsing");
  char msg[] = "{teamcolor}{teamcolor}{teamcolor}a{DEFaULT}AB{-{}a}}}s}]\x01]{a{}}}[[-}43}}{geld}CD{{gold}}EF{default}{yellowgreen}GH{yellowgreen}";
  char correct[] = "\x03\x03\x03a{DEFaULT}AB{-{}a}}}s}]\x01]{a{}}}[[-}43}}{geld}CD{\x07FFD700}EF\x01\x079ACD32GH";
  CReplaceColorCodes(msg);
  PrintToChat(client, "GIBBERISH EQUAL: %i", StrEqual(msg, correct, true));
  CPrintToChat(client, "PARSE:\n%s", msg);
  CPrintToChat(client, "VALID:\n%s", correct);
  
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
