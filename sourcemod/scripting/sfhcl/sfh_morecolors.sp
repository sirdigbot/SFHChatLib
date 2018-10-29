/***********************************************************************
 * This Source Code Form is subject to the terms of the Mozilla Public *
 * License, v. 2.0. If a copy of the MPL was not distributed with this *
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.            *
 *                                                                     *
 * Copyright (C) 2018 SirDigbot                                        *
 ***********************************************************************/


//=================================
// MoreColors 1.9.1 Reimplementation
//
// PARTIAL PLUGIN INCLUDE
// Part of sfh_chatlib.sp
// Wont compile on its own.
//=================================

#if defined _sfh_morecolors_included
 #endinput
#endif

#define _sfh_morecolors_included


#include <regex>


#define MORE_COLORS_VERSION   "1.9.1-sfhcl"
#define MAX_MESSAGE_LENGTH    256
#define BUFFER_MULTIPLIER     4 // Multiplier to guarantee tags + format rules can be processed for any given string length.
#define MAX_BUFFER_LENGTH     (MAX_MESSAGE_LENGTH * BUFFER_MULTIPLIER)

// As long as a buffer is made with BUFFER_MULTIPLIER >= 3, any string will be able to store
// its color bytes correctly (which are either 7 or 1 bytes + \0. 0x08 would be 9 bytes but it's unused.)
//
// The smallest possible tag (which expands the most) is "{a}".
// This expands 2.3333 times into "\x07ABCABC". As long as any string processes color into a buffer
// >2.3333x the source string length (plus \0) it will always fit.
// 4 is used instead of 3 because you may also use the buffer for string formatting.
//
// e.g.
//  "{a}{a}{a}{a}{a}{a}"  ->  "\x07ABCABC\x07ABCABC\x07ABCABC\x07ABCABC\x07ABCABC\x07ABCABC"
//  Size 19                   Size 43 (19 * 3 = 57)



// TF2/CS/Dota Colors
#define COLOR_RED     0xFF4040  // These also set some values in g_Colors
#define COLOR_BLUE    0x99CCFF
#define COLOR_GRAY    0xCCCCCC
#define COLOR_GREEN   0x3EFF3E

#define GAME_DEFAULT  0
#define GAME_DODS     1

// Constants that determine how tags are formatted
#define TAG_OPEN_CHAR     '{'
#define TAG_CLOSE_CHAR    '}'
#define TAG_DEFAULTCOLOR  "{default}"
#define TAG_TEAMCOLOR     "{teamcolor}"
#define TAG_REGEX         "{[a-zA-Z0-9]+}"    // Must not allow TAG_OPEN/CLOSE_CHAR

static bool       g_SkipList[MAXPLAYERS + 1]; // Whether or not to skip a player for PrintToChatAll/Ex
static StringMap  g_Colors;
static Regex      g_TagRegex;

// For games that don't support SayText2, team colors must be done manually.
// First index is GAME_* index.
// Second index is team: 0 = Spectator, 1 = Team1, 2 = Team2
// Unassigned is generally done with 0x04, the others use 0x07.
static int g_TeamColors[][] = {
  {COLOR_GRAY, COLOR_RED, COLOR_BLUE},  // GAME_DEFAULT. Here for completeness with CGetTeamColor
  {COLOR_GRAY, 0x4D7942, COLOR_RED}     // GAME_DODS
};


UserMsg         g_SayTextMsgId;
UserMessageType g_UserMsgType;



//=================================
// Init Functions
// Called in sfh_chatlib.sp


void SFHCL_MC_OnPluginStart()
{
  g_SayTextMsgId = GetUserMessageId("SayText2");
  if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available)
    g_UserMsgType = GetUserMessageType();
  else
    g_UserMsgType = UM_BitBuf; // Safe default. Only newer games use ProtoBuf.
    
  g_TagRegex = CompileRegex(TAG_REGEX);
  if(g_TagRegex == INVALID_HANDLE)
    ThrowError("%T", "SFHCL_RegexFail", LANG_SERVER);
    
  Internal_InitColors();
  return;
}



void SFHCL_MC_CreateNatives()
{
  CreateNative("CPrintToChat",        Native_CPrintToChat);
  CreateNative("CPrintToChatAll",     Native_CPrintToChatAll);
  CreateNative("CPrintToChatEx",      Native_CPrintToChatEx);
  CreateNative("CPrintToChatAllEx",   Native_CPrintToChatAllEx);
  CreateNative("CSkipNextClient",     Native_CSkipNextClient);
  CreateNative("CReplyToCommand",     Native_CReplyToCommand);
  CreateNative("CReplyToCommandEx",   Native_CReplyToCommandEx);
  CreateNative("CShowActivity",       Native_CShowActivity);
  CreateNative("CShowActivityEx",     Native_CShowActivityEx);
  CreateNative("CShowActivity2",      Native_CShowActivity2);
  CreateNative("CColorExists",        Native_CColorExists);
  CreateNative("CGetTeamColor",       Native_CGetTeamColor);
  CreateNative("CAddColor",           Native_CAddColor);
  CreateNative("CRemoveTags",         Native_CRemoveTags);
  CreateNative("CReplaceColorCodes",  Native_CReplaceColorCodes);
  return;
}




//=================================
// Natives

/* native void CPrintToChat(const int client, const char[] message, any ...); */
public int Native_CPrintToChat(Handle plugin, int numParams)
{
  // Get and Verify client
  int client = GetNativeCell(1);
  
  if(client < 1 || client > MaxClients)     // Can't PrintTochat the server
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_InvalidClient", LANG_SERVER, client);
  if(!IsClientInGame(client))
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "Target is not in game", LANG_SERVER); // Common.phrases.txt
    
  // Set translation target before formatting message
  SetGlobalTransTarget(client);
  
  char message[MAX_BUFFER_LENGTH] = "\x01"; // First byte must be default color
  if(FormatNativeString(0, 2, 3, sizeof(message) - 1, _, message[1]) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "CPrintToChat");

  Internal_ReplaceColors(message, sizeof(message));
  Internal_SendMessage(client, message);
  return 0;
}



/* native void CPrintToChatAll(const char[] message, any ...); */
public int Native_CPrintToChatAll(Handle plugin, int numParams)
{
  char message[MAX_BUFFER_LENGTH] = "\x01"; // First byte must be default color
  
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(!IsClientInGame(i) || g_SkipList[i])
    {
      g_SkipList[i] = false;
      continue;
    }
    
    SetGlobalTransTarget(i);
    if(FormatNativeString(0, 1, 2, sizeof(message) - 1, _, message[1]) != SP_ERROR_NONE)
      return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "CPrintToChatAll");

    Internal_ReplaceColors(message, sizeof(message));
    Internal_SendMessage(i, message);
  }
  return 0;
}



/* native void CPrintToChatEx(const int client, const int author, const char[] message, any ...); */
public int Native_CPrintToChatEx(Handle plugin, int numParams)
{
  // Get and Verify client/author
  int client = GetNativeCell(1);
  int author = GetNativeCell(2);
  
  if(client < 1 || client > MaxClients)     // Can't PrintTochat the server
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_InvalidClient", LANG_SERVER, client);
  if(!IsClientInGame(client))
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "Target is not in game", LANG_SERVER); // Common.phrases.txt
    
  if(author < 1 || author > MaxClients)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_InvalidClient", LANG_SERVER, author);
  if(!IsClientInGame(author))
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "Target is not in game", LANG_SERVER);

  // Set translation target before formatting message
  SetGlobalTransTarget(client);
  
  char message[MAX_BUFFER_LENGTH] = "\x01"; // First byte must be default color
  if(FormatNativeString(0, 3, 4, sizeof(message) - 1, _, message[1]) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "CPrintToChatEx");

  Internal_ReplaceColors(message, sizeof(message));
  Internal_SendMessage(client, message, author);
  return 0;
}



/* native void CPrintToChatAllEx(const int author, const char[] message, any ...); */
public int Native_CPrintToChatAllEx(Handle plugin, int numParams)
{
  int author = GetNativeCell(1);
  
  if(author < 1 || author > MaxClients)     // Can't PrintTochat the server
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_InvalidClient", LANG_SERVER, author);
  if(!IsClientInGame(author))
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "Target is not in game", LANG_SERVER);
  
  char message[MAX_BUFFER_LENGTH] = "\x01"; // First byte must be default color
  
  for(int i = 1; i <= MaxClients; ++i)
  {
    if(!IsClientInGame(i) || g_SkipList[i])
    {
      g_SkipList[i] = false;
      continue;
    }
    
    SetGlobalTransTarget(i);
    if(FormatNativeString(0, 2, 3, sizeof(message) - 1, _, message[1]) != SP_ERROR_NONE)
      return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "CPrintToChatAllEx");

    Internal_ReplaceColors(message, sizeof(message));
    Internal_SendMessage(i, message, author);
  }
  return 0;
}



/* native void CSkipNextClient(const int client); */
public int Native_CSkipNextClient(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  if(client < 1 || client > MaxClients)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_InvalidClient", LANG_SERVER, client);
  g_SkipList[client] = true;
  return 0;
}



/* native void CReplyToCommand(const int client, const char[] message, any ...); */
public int Native_CReplyToCommand(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  SetGlobalTransTarget(client);
  
  char message[MAX_BUFFER_LENGTH]; // No offset/default color since we're passing to other functions
  if(FormatNativeString(0, 2, 3, sizeof(message), _, message) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "CReplyToCommand");

  if(GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
  {
    // MoreColors uses CRemoveTags, which only removes "{these}" for legacy-compatability.
    // SFHCL_RemoveColours removes colour bytes too (\x01, \x07ABCABC, etc.).
    SFHCL_RemoveColours(message); 
    PrintToConsole(client, message);
  }
  else
    CPrintToChat(client, message);
  return 0;
}


/* native void CReplyToCommandEx(const int client, const int author, const char[] message, any ...); */
public int Native_CReplyToCommandEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  int author = GetNativeCell(2);
  SetGlobalTransTarget(client);
  
  char message[MAX_BUFFER_LENGTH]; // No offset/default color since we're passing to other functions
  if(FormatNativeString(0, 3, 4, sizeof(message), _, message) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "CReplyToCommandEx");

  if(GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
  {
    // MoreColors uses CRemoveTags, which only removes "{these}" for legacy-compatability.
    // SFHCL_RemoveColours removes colour bytes too (\x01, \x07ABCABC, etc.).
    SFHCL_RemoveColours(message); 
    PrintToConsole(client, message);
  }
  else
    CPrintToChatEx(client, author, message);
  return 0;
}



/* native void CShowActivity(const int client, const char[] message, any ...); */
public int Native_CShowActivity(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  
  if(client < 0 || client > MaxClients)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_InvalidClient", LANG_SERVER, client);
  if(client != 0 && !IsClientInGame(client))
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "Target is not in game", LANG_SERVER); // Common.phrases.txt

  char message[MAX_BUFFER_LENGTH] = "\x01"; // First byte must be default color
  if(FormatNativeString(0, 2, 3, sizeof(message) - 1, _, message[1]) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "CShowActivity");
  
  Internal_ReplaceColors(message, sizeof(message));
  ShowActivity(client, message);
  return 0;
}



/* native void CShowActivityEx(const int client, const char[] tag, const char[] message, any ...); */
public int Native_CShowActivityEx(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  
  if(client < 0 || client > MaxClients)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_InvalidClient", LANG_SERVER, client);
  if(client != 0 && !IsClientInGame(client))
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "Target is not in game", LANG_SERVER); // Common.phrases.txt

  char message[MAX_BUFFER_LENGTH] = "\x01"; // First byte must be default color
  if(FormatNativeString(0, 3, 4, sizeof(message) - 1, _, message[1]) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "CShowActivityEx");
  
  int tagLen;
  GetNativeStringLength(2, tagLen);
  tagLen *= BUFFER_MULTIPLIER;        // Using MAX_BUFFER_LENGTH is a waste since most tags are tiny
  tagLen += 2;                        // +2 is for tagLen=0 + '\0'
  char[] tag = new char[tagLen];  
  GetNativeString(2, tag, tagLen);
  
  Internal_ReplaceColors(message, sizeof(message));
  Internal_ReplaceColors(tag, tagLen);
  ShowActivityEx(client, tag, message);
  return 0;
}



/* native void CShowActivity2(const int client, const char[] tag, const char[] message, any ...); */
public int Native_CShowActivity2(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  
  if(client < 0 || client > MaxClients)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_InvalidClient", LANG_SERVER, client);
  if(client != 0 && !IsClientInGame(client))
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "Target is not in game", LANG_SERVER); // Common.phrases.txt

  char message[MAX_BUFFER_LENGTH] = "\x01"; // First byte must be default color
  if(FormatNativeString(0, 3, 4, sizeof(message) - 1, _, message[1]) != SP_ERROR_NONE)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_FormatError", LANG_SERVER, "CShowActivity2");
  
  int tagLen;
  GetNativeStringLength(2, tagLen);
  tagLen *= BUFFER_MULTIPLIER;        // Using MAX_BUFFER_LENGTH is a waste since most tags are tiny
  tagLen += 2;                        // +2 is for tagLen=0 + '\0'
  char[] tag = new char[tagLen];  
  GetNativeString(2, tag, tagLen);
  
  Internal_ReplaceColors(message, sizeof(message));
  Internal_ReplaceColors(tag, tagLen);
  ShowActivity2(client, tag, message);
  return 0;
}



/* native bool CColorExists(const char[] color); */
public int Native_CColorExists(Handle plugin, int numParams)
{
  int len;
  GetNativeStringLength(1, len);
  if(len <= 0)
    return view_as<int>(false);
  
  char[] color = new char[len + 1]; // '\0'
  GetNativeString(1, color, len + 1);

  int dummy;
  return view_as<int>(g_Colors.GetValue(color, dummy));
}



/* native int CGetTeamColor(const int client); */
public int Native_CGetTeamColor(Handle plugin, int numParams)
{
  int client = GetNativeCell(1);
  
  if(client < 1 || client > MaxClients)
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "SFHCL_InvalidClient", LANG_SERVER, client);
  if(!IsClientInGame(client))
    return ThrowNativeError(SP_ERROR_NATIVE, "%T", "Target is not in game", LANG_SERVER); // Common.phrases.txt

  // Don't initialise g_Colors
  
  int gameColor = GAME_DEFAULT;
  if(g_Engine == Engine_DODS)
    gameColor = GAME_DODS;
  
  int team = GetClientTeam(client) - 1; // 0 = Unassigned, 1 = Spectator, 2 = Team1/RED/T, 3 = Team2/BLU/CT
  if(team < 0 || team > 2)
    return COLOR_GREEN;           // Unassigned (MoreColors uses this for all games)
    
  return g_TeamColors[gameColor][team];
}



/* native bool CAddColor(const char[] name, const int color); */
public int Native_CAddColor(Handle plugin, int numParams)
{
  int color = GetNativeCell(2);
  
  int len;
  GetNativeStringLength(1, len);
  if(len <= 0)
    return view_as<int>(false);
  
  char[] name = new char[len + 1];
  GetNativeString(1, name, len + 1);
  Internal_ToLower(name, len + 1);
  
  return view_as<int>(g_Colors.SetValue(name, color, false)); // false = do not replace
}



/* native void CRemoveTags(char[] message); */
public int Native_CRemoveTags(Handle plugin, int numParams)
{
  int len;
  GetNativeStringLength(1, len);
  if(len <= 0)
    return 0;
  
  char[] msg = new char[len + 1];
  GetNativeString(1, msg, len + 1);

  // Only remove MoreColors tags, as anything else might be unexpected behaviour
  SFHCL_RemoveColours(msg, false, false, true);
  return 0;
}



/* native void CReplaceColorCodes(char[] buffer); */
public int Native_CReplaceColorCodes(Handle plugin, int numParams)
{
  int len;
  GetNativeStringLength(1, len);
  if(len <= 0)
    return 0;
  
  len += 1; // Add '\0'
  char[] msg = new char[len];
  GetNativeString(1, msg, len);
  
  Internal_ReplaceColors(msg, len);
  SetNativeString(1, msg, len);
  return 0;
}




//=================================
// Internals

/**
 * Make a string all lowercase
 * Not Multi-byte safe.
 */
static void Internal_ToLower(char[] str, const int maxlength)
{
  for(int i = 0; i < maxlength; ++i)
    str[i] = CharToLower(str[i]);
}


/**
 * Replaces color tags in a string with color codes
 *
 * @param buffer      String.
 * @param maxlength   Maxium length of string.
 * @noreturn
 */
static void Internal_ReplaceColors(char[] buffer, const int maxlength)
{
  /**
   * Note to any optimisers: Here be dragons. And Un-debuggable Access Violations.
   */

  char tag[32];  
  char colorStr[8]; // TagToColorBytes needs only 8 for output
  
  int matches = g_TagRegex.MatchAll(buffer);
  for(int i = 0; i < matches; ++i)
  {
    if(!g_TagRegex.GetSubString(0, tag, sizeof(tag), i))
    {
      // GetSubString uses match list from regex handle. If it fails something is really broken.
      LogError("%T", "SFHCL_RegexAnomaly", LANG_SERVER);
      break;
    }
    
    // Minor optimisation. Calculate and reuse strlen for ReplaceStringEx
    int tagLen    = strlen(tag);
    int colorLen  = TagToColorBytes(tag, colorStr, sizeof(colorStr), tagLen) - 1; // -1 for len not size

    if(colorLen > 0)
      ReplaceStringEx(buffer, maxlength, tag, colorStr, tagLen, colorLen);
  }
  
  // Trim colours from the end of the message (if replacements were done)
  
  // TODO / BUG: Ending a message on "\x07ABCABC" and no text afterwards wont display the color
  // Instead, it displays the hex code.
  // The control character remains invisible though, so this doesnt happen with {default} or {teamcolor}
  // The below will remove this just for cleanliness
  
  if(matches > 0)
  {
    int colorChar = strlen(buffer) - 7; // Get \x07 index of last color ("\x07ABCABC")
    if(colorChar > -1 && buffer[colorChar] == '\x07')
      buffer[colorChar] = '\0';         // Terminate to 'erase' hex string
  }
  return;
}

/**
 * Convert a MoreColors tag into the bytes needed to display the correct colour.
 *
 * Tags must be lowercase and include opening and closing curly braces. e.g. "{teamcolor}"
 * Maxlength must be at least 8 if the tag is a custom color, or 2 for {default} and {teamcolor}
 *
 * @param tag           Input tag string
 * @param output        String output buffer
 * @param maxlength     Maximum length of output buffer
 * @param tagLen        Optional. If set >0, will use used instead of strlen(tag).
 *
 * Returns SIZE of new tag string (0 if tag was invalid and not replaced).
 */
static int TagToColorBytes(const char[] tag, char[] output, const int maxlength, int tagLen=0)
{
  if(StrEqual(tag, TAG_DEFAULTCOLOR, true))
  {
    strcopy(output, maxlength, "\x01");
    return 2;                     // Return new tag size (Incl '\0')
  }
  else if(StrEqual(tag, TAG_TEAMCOLOR, true))
  {
    strcopy(output, maxlength, "\x03");
    return 2;
  }
  
  // Allow for strlen(tag) override
  if(tagLen <= 0)
    tagLen = strlen(tag);         // tagLen is copy

  int len     = tagLen - 1;       // Remove {}'s (TAG_OPEN/CLOSE_CHAR), Add '\0' 
  char[] name = new char[len];  
  strcopy(name, len, tag[1]);
  
  int color;
  if(g_Colors.GetValue(name, color))
  {
    Format(output, maxlength, "\x07%06X", color);
    return 8;
  }

  return 0;
}


/**
 * Sends a SayText2 usermessage
 *
 * @param client      Client to send usermessage to
 * @param message     Message to send
 * @param author      Optional client index to use for {teamcolor} tags, or 0 for none
 * @noreturn
 */
static void Internal_SendMessage(const int client, const char[] msg, int author=0)
{
  if(author == 0)
    author = client;
  
  // If game doesn't support SayText2..
  if(g_SayTextMsgId == INVALID_MESSAGE_ID) 
  {
    // NOTE: For consistency, we should use MAX_BUFFER_LENGTH, HOWEVER..
    // Because we are potentially expanding 1 byte to 7 (not 3 to 7), BUFFER_MULTIPLIER (and
    // therefore MAX_BUFFER_LENGTH) is no longer valid unless the multiplier >= 7.
    // MAX_MESSAGE_LENGTH * 7 is too much memory to waste per message.
    // So we're just gonna use MAX_BUFFER_LENGTH and hope for the best
    char msgBuff[MAX_BUFFER_LENGTH];
    strcopy(msgBuff, sizeof(msgBuff), msg);
      
    if(g_Engine == Engine_DODS)
      Internal_FixTeamColors(author, GAME_DODS, msgBuff, sizeof(msgBuff));
    
    PrintToChat(client, msgBuff);
    return;
  }

  Handle buf = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
  if(g_UserMsgType == UM_Protobuf)
  {
    PbSetInt(buf, "ent_idx", author);
    PbSetBool(buf, "chat", true);
    PbSetString(buf, "msg_name", msg);
    PbAddString(buf, "params", "");
    PbAddString(buf, "params", "");
    PbAddString(buf, "params", "");
    PbAddString(buf, "params", "");
  }
  else
  {
    BfWriteByte(buf, author);
    BfWriteByte(buf, true);   // Chat message
    BfWriteString(buf, msg);
  }
  EndMessage(); // Closes Handle
  return;
}

/**
 * For games that don't support SayText2, team colors (0x03) must be set manually
 * Unassigned is 0x04, other teams use 0x07<Hex>
 *
 * @param author      Client index to use for {teamcolor} tags, or 0 for none.
 * @param game        GAME_* index to specify the color set to use
 * @param msg         String.
 * @param maxlength   Maxium length of string.
 * @noreturn
 */
static void Internal_FixTeamColors(const int author, const int game, char[] msg, const int maxlength)
{
  int team = GetClientTeam(author);
  switch(team)
  {
    case 1, 2, 3: 
    {
      char color[8];
      Format(color, sizeof(color), "\x07%06X", g_TeamColors[game][team - 1]); // g_TeamColors excludes unassigned
      ReplaceString(msg, maxlength, "\x03", color, true);
    }
    
    default: // 0 = Unassigned. Use Green (0x04)
    {
      for(int i = 0; i < maxlength; ++i)
      {
        if(msg[i] == '\x03')
          msg[i] = '\x04';
      }
    }
  }
}


/**
 * If not already initialised, creates and fills the g_Colors StringMap
 */
static void Internal_InitColors()
{
  if(g_Colors != null)
    return;
    
  g_Colors = new StringMap();
  g_Colors.SetValue("aliceblue", 0xF0F8FF);
  g_Colors.SetValue("allies", 0x4D7942);          // same as Allies team in DoD:S
  g_Colors.SetValue("ancient", 0xEB4B4B);         // same as Ancient item rarity in Dota 2
  g_Colors.SetValue("antiquewhite", 0xFAEBD7);
  g_Colors.SetValue("aqua", 0x00FFFF);
  g_Colors.SetValue("aquamarine", 0x7FFFD4);
  g_Colors.SetValue("arcana", 0xADE55C);          // same as Arcana item rarity in Dota 2
  g_Colors.SetValue("axis", COLOR_RED);           // same as Axis team in DoD:S
  g_Colors.SetValue("azure", 0x007FFF);
  g_Colors.SetValue("beige", 0xF5F5DC);
  g_Colors.SetValue("bisque", 0xFFE4C4);
  g_Colors.SetValue("black", 0x000000);
  g_Colors.SetValue("blanchedalmond", 0xFFEBCD);
  g_Colors.SetValue("blue", COLOR_BLUE);          // same as BLU/Counter-Terrorist team color
  g_Colors.SetValue("blueviolet", 0x8A2BE2);
  g_Colors.SetValue("brown", 0xA52A2A);
  g_Colors.SetValue("burlywood", 0xDEB887);
  g_Colors.SetValue("cadetblue", 0x5F9EA0);
  g_Colors.SetValue("chartreuse", 0x7FFF00);
  g_Colors.SetValue("chocolate", 0xD2691E);
  g_Colors.SetValue("collectors", 0xAA0000);      // same as Collector's item quality in TF2
  g_Colors.SetValue("common", 0xB0C3D9);          // same as Common item rarity in Dota 2
  g_Colors.SetValue("community", 0x70B04A);       // same as Community item quality in TF2
  g_Colors.SetValue("coral", 0xFF7F50);
  g_Colors.SetValue("cornflowerblue", 0x6495ED);
  g_Colors.SetValue("cornsilk", 0xFFF8DC);
  g_Colors.SetValue("corrupted", 0xA32C2E);       // same as Corrupted item quality in Dota 2
  g_Colors.SetValue("crimson", 0xDC143C);
  g_Colors.SetValue("cyan", 0x00FFFF);
  g_Colors.SetValue("darkblue", 0x00008B);
  g_Colors.SetValue("darkcyan", 0x008B8B);
  g_Colors.SetValue("darkgoldenrod", 0xB8860B);
  g_Colors.SetValue("darkgray", 0xA9A9A9);
  g_Colors.SetValue("darkgrey", 0xA9A9A9);
  g_Colors.SetValue("darkgreen", 0x006400);
  g_Colors.SetValue("darkkhaki", 0xBDB76B);
  g_Colors.SetValue("darkmagenta", 0x8B008B);
  g_Colors.SetValue("darkolivegreen", 0x556B2F);
  g_Colors.SetValue("darkorange", 0xFF8C00);
  g_Colors.SetValue("darkorchid", 0x9932CC);
  g_Colors.SetValue("darkred", 0x8B0000);
  g_Colors.SetValue("darksalmon", 0xE9967A);
  g_Colors.SetValue("darkseagreen", 0x8FBC8F);
  g_Colors.SetValue("darkslateblue", 0x483D8B);
  g_Colors.SetValue("darkslategray", 0x2F4F4F);
  g_Colors.SetValue("darkslategrey", 0x2F4F4F);
  g_Colors.SetValue("darkturquoise", 0x00CED1);
  g_Colors.SetValue("darkviolet", 0x9400D3);
  g_Colors.SetValue("deeppink", 0xFF1493);
  g_Colors.SetValue("deepskyblue", 0x00BFFF);
  g_Colors.SetValue("dimgray", 0x696969);
  g_Colors.SetValue("dimgrey", 0x696969);
  g_Colors.SetValue("dodgerblue", 0x1E90FF);
  g_Colors.SetValue("exalted", 0xCCCCCD);         // same as Exalted item quality in Dota 2
  g_Colors.SetValue("firebrick", 0xB22222);
  g_Colors.SetValue("floralwhite", 0xFFFAF0);
  g_Colors.SetValue("forestgreen", 0x228B22);
  g_Colors.SetValue("frozen", 0x4983B3);          // same as Frozen item quality in Dota 2
  g_Colors.SetValue("fuchsia", 0xFF00FF);
  g_Colors.SetValue("fullblue", 0x0000FF);
  g_Colors.SetValue("fullred", 0xFF0000);
  g_Colors.SetValue("gainsboro", 0xDCDCDC);
  g_Colors.SetValue("genuine", 0x4D7455);         // same as Genuine item quality in TF2
  g_Colors.SetValue("ghostwhite", 0xF8F8FF);
  g_Colors.SetValue("gold", 0xFFD700);
  g_Colors.SetValue("goldenrod", 0xDAA520);
  g_Colors.SetValue("gray", COLOR_GRAY);          // same as spectator team color
  g_Colors.SetValue("grey", COLOR_GRAY);
  g_Colors.SetValue("green", COLOR_GREEN);
  g_Colors.SetValue("greenyellow", 0xADFF2F);
  g_Colors.SetValue("haunted", 0x38F3AB);         // same as Haunted item quality in TF2
  g_Colors.SetValue("honeydew", 0xF0FFF0);
  g_Colors.SetValue("hotpink", 0xFF69B4);
  g_Colors.SetValue("immortal", 0xE4AE33);        // same as Immortal item rarity in Dota 2
  g_Colors.SetValue("indianred", 0xCD5C5C);
  g_Colors.SetValue("indigo", 0x4B0082);
  g_Colors.SetValue("ivory", 0xFFFFF0);
  g_Colors.SetValue("khaki", 0xF0E68C);
  g_Colors.SetValue("lavender", 0xE6E6FA);
  g_Colors.SetValue("lavenderblush", 0xFFF0F5);
  g_Colors.SetValue("lawngreen", 0x7CFC00);
  g_Colors.SetValue("legendary", 0xD32CE6);       // same as Legendary item rarity in Dota 2
  g_Colors.SetValue("lemonchiffon", 0xFFFACD);
  g_Colors.SetValue("lightblue", 0xADD8E6);
  g_Colors.SetValue("lightcoral", 0xF08080);
  g_Colors.SetValue("lightcyan", 0xE0FFFF);
  g_Colors.SetValue("lightgoldenrodyellow", 0xFAFAD2);
  g_Colors.SetValue("lightgray", 0xD3D3D3);
  g_Colors.SetValue("lightgrey", 0xD3D3D3);
  g_Colors.SetValue("lightgreen", 0x99FF99);
  g_Colors.SetValue("lightpink", 0xFFB6C1);
  g_Colors.SetValue("lightsalmon", 0xFFA07A);
  g_Colors.SetValue("lightseagreen", 0x20B2AA);
  g_Colors.SetValue("lightskyblue", 0x87CEFA);
  g_Colors.SetValue("lightslategray", 0x778899);
  g_Colors.SetValue("lightslategrey", 0x778899);
  g_Colors.SetValue("lightsteelblue", 0xB0C4DE);
  g_Colors.SetValue("lightyellow", 0xFFFFE0);
  g_Colors.SetValue("lime", 0x00FF00);
  g_Colors.SetValue("limegreen", 0x32CD32);
  g_Colors.SetValue("linen", 0xFAF0E6);
  g_Colors.SetValue("magenta", 0xFF00FF);
  g_Colors.SetValue("maroon", 0x800000);
  g_Colors.SetValue("mediumaquamarine", 0x66CDAA);
  g_Colors.SetValue("mediumblue", 0x0000CD);
  g_Colors.SetValue("mediumorchid", 0xBA55D3);
  g_Colors.SetValue("mediumpurple", 0x9370D8);
  g_Colors.SetValue("mediumseagreen", 0x3CB371);
  g_Colors.SetValue("mediumslateblue", 0x7B68EE);
  g_Colors.SetValue("mediumspringgreen", 0x00FA9A);
  g_Colors.SetValue("mediumturquoise", 0x48D1CC);
  g_Colors.SetValue("mediumvioletred", 0xC71585);
  g_Colors.SetValue("midnightblue", 0x191970);
  g_Colors.SetValue("mintcream", 0xF5FFFA);
  g_Colors.SetValue("mistyrose", 0xFFE4E1);
  g_Colors.SetValue("moccasin", 0xFFE4B5);
  g_Colors.SetValue("mythical", 0x8847FF);        // same as Mythical item rarity in Dota 2
  g_Colors.SetValue("navajowhite", 0xFFDEAD);
  g_Colors.SetValue("navy", 0x000080);
  g_Colors.SetValue("normal", 0xB2B2B2);          // same as Normal item quality in TF2
  g_Colors.SetValue("oldlace", 0xFDF5E6);
  g_Colors.SetValue("olive", 0x9EC34F);
  g_Colors.SetValue("olivedrab", 0x6B8E23);
  g_Colors.SetValue("orange", 0xFFA500);
  g_Colors.SetValue("orangered", 0xFF4500);
  g_Colors.SetValue("orchid", 0xDA70D6);
  g_Colors.SetValue("palegoldenrod", 0xEEE8AA);
  g_Colors.SetValue("palegreen", 0x98FB98);
  g_Colors.SetValue("paleturquoise", 0xAFEEEE);
  g_Colors.SetValue("palevioletred", 0xD87093);
  g_Colors.SetValue("papayawhip", 0xFFEFD5);
  g_Colors.SetValue("peachpuff", 0xFFDAB9);
  g_Colors.SetValue("peru", 0xCD853F);
  g_Colors.SetValue("pink", 0xFFC0CB);
  g_Colors.SetValue("plum", 0xDDA0DD);
  g_Colors.SetValue("powderblue", 0xB0E0E6);
  g_Colors.SetValue("purple", 0x800080);
  g_Colors.SetValue("rare", 0x4B69FF);            // same as Rare item rarity in Dota 2
  g_Colors.SetValue("red", COLOR_RED);            // same as RED/Terrorist team color
  g_Colors.SetValue("rosybrown", 0xBC8F8F);
  g_Colors.SetValue("royalblue", 0x4169E1);
  g_Colors.SetValue("saddlebrown", 0x8B4513);
  g_Colors.SetValue("salmon", 0xFA8072);
  g_Colors.SetValue("sandybrown", 0xF4A460);
  g_Colors.SetValue("seagreen", 0x2E8B57);
  g_Colors.SetValue("seashell", 0xFFF5EE);
  g_Colors.SetValue("selfmade", 0x70B04A);        // same as Self-Made item quality in TF2
  g_Colors.SetValue("sienna", 0xA0522D);
  g_Colors.SetValue("silver", 0xC0C0C0);
  g_Colors.SetValue("skyblue", 0x87CEEB);
  g_Colors.SetValue("slateblue", 0x6A5ACD);
  g_Colors.SetValue("slategray", 0x708090);
  g_Colors.SetValue("slategrey", 0x708090);
  g_Colors.SetValue("snow", 0xFFFAFA);
  g_Colors.SetValue("springgreen", 0x00FF7F);
  g_Colors.SetValue("steelblue", 0x4682B4);
  g_Colors.SetValue("strange", 0xCF6A32);         // same as Strange item quality in TF2
  g_Colors.SetValue("tan", 0xD2B48C);
  g_Colors.SetValue("teal", 0x008080);
  g_Colors.SetValue("thistle", 0xD8BFD8);
  g_Colors.SetValue("tomato", 0xFF6347);
  g_Colors.SetValue("turquoise", 0x40E0D0);
  g_Colors.SetValue("uncommon", 0xB0C3D9);        // same as Uncommon item rarity in Dota 2
  g_Colors.SetValue("unique", 0xFFD700);          // same as Unique item quality in TF2
  g_Colors.SetValue("unusual", 0x8650AC);         // same as Unusual item quality in TF2
  g_Colors.SetValue("valve", 0xA50F79);           // same as Valve item quality in TF2
  g_Colors.SetValue("vintage", 0x476291);         // same as Vintage item quality in TF2
  g_Colors.SetValue("violet", 0xEE82EE);
  g_Colors.SetValue("wheat", 0xF5DEB3);
  g_Colors.SetValue("white", 0xFFFFFF);
  g_Colors.SetValue("whitesmoke", 0xF5F5F5);
  g_Colors.SetValue("yellow", 0xFFFF00);
  g_Colors.SetValue("yellowgreen", 0x9ACD32);
}
