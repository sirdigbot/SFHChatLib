/***********************************************************************
 * This Source Code Form is subject to the terms of the Mozilla Public *
 * License, v. 2.0. If a copy of the MPL was not distributed with this *
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.            *
 *                                                                     *
 * Copyright (C) 2018 SirDigbot                                        *
 ***********************************************************************/
 
#if defined _sfh_chatlib_included
  #endinput
#endif
#define _sfh_chatlib_included


//=================================
// SFH ChatLib Natives

/**
 * Prepends ReplyToCommand with a coloured command ("[SM]") tag.
 * Removes colour if printing to console.
 *
 * @param client  Client who issued command
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagReply(const int client, const char[] msg, any ...);

/**
 * Prepends ReplyToCommand with a coloured command ("[SM]") tag.
 * Removes colour if printing to console.
 *
 * @param client  Client who issued command
 * @param author  Client to use for team colour/{teamcolor}
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagReplyEx(const int client, const int author, const char[] msg, any ...);

/**
 * Prepends ReplyToCommand with a coloured command usage ("[SM] Usage:") tag.
 * Removes colour if printing to console.
 *
 * @param client  Client who issued command
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagReplyUsage(const int client, const char[] msg, any ...);

/**
 * Prepends ReplyToCommand with a coloured command usage ("[SM] Usage:") tag.
 * Removes colour if printing to console.
 *
 * @param client  Client who issued command
 * @param author  Client to use for team colour/{teamcolor}
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagReplyUsageEx(const int client, const int author, const char[] msg, any ...);



/**
 * Prepends PrintToChat with a coloured command ("[SM]") tag.
 *
 * @param client  Client who issued command
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagPrintChat(const int client, const char[] msg, any ...);

/**
 * Prepends PrintToChatEx with a coloured command ("[SM]") tag.
 *
 * @param client  Client who issued command
 * @param author  Client to use for team colour/{teamcolor}
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagPrintChatEx(const int client, const int author, const char[] msg, any ...);

/**
 * Prepends PrintToChatAll with a coloured command ("[SM]") tag.
 *
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagPrintChatAll(const char[] msg, any ...);

/**
 * Prepends PrintToChatAllEx with a coloured command ("[SM]") tag.
 *
 * @param author  Client to use for team colour/{teamcolor}
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagPrintChatAllEx(const int author, const char[] msg, any ...);



/**
 * Prepends ShowActivity2 with a coloured command ("[SM]") tag.
 *
 * @param client  Client who issued command
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagActivity2(const int client, const char[] msg, any ...);

// TagActivity is pointless because CShowActivity does not allow custom tags,
// AND we cant filter colours for the ShowActivity functions.

/**
 * Prepends ShowActivityEx with a coloured command ("[SM]") tag.
 *
 * @param client  Client who issued command
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagActivityEx(const int client, const char[] msg, any ...);



/**
 * Prepends PrintToServer with a command ("[SM]") tag.
 *
 * @param msg     String to print
 * @param ...     Optional. Format-Class Function
 * @noreturn
 */
native void TagPrintServer(const char[] msg, any ...);

/**
 * Prepends CPrintToAdmins with a coloured command ("[SM]") tag.
 * Client is also considered admin if they have access to the sm_sfhcl_admin override.
 * 
 * @param flags           ADMFLAG_ bitfield
 * @param rootOverride    If true, root-access will be allowed regardless of flags
 * @param message         Message to send (formatting rules)
 * @noreturn
 */
native void TagPrintToAdmins(const int flags, const bool rootOverride, const char[] message, any ...);

/**
 * Prepends CPrintToAdminsEx with a coloured command ("[SM]") tag.
 * Client is also considered admin if they have access to the sm_sfhcl_admin override.
 *
 * @param author          Client to use for {teamcolor}
 * @param flags           ADMFLAG_ bitfield
 * @param rootOverride    If true, root-access will be allowed regardless of flags
 * @param message         Message to send (formatting rules)
 * @noreturn
 * 
 * On error/Errors:     If the author is not connected an error will be thrown.
 */
native void TagPrintToAdminsEx(const int author, const int flags, const bool rootOverride, const char[] message, any ...);



/**
 * Remove all the source-engine-native chat colours from a string (TF2 Only).
 * Specifically this can remove:
 * - Single-byte Colours: 0x01, 0x03, 0x04, 0x05, 0x06 (and 0x10, which is the removal char and has no function)
 * - Multibyte Colours: 0x07+6 bytes (Hex Colour), and 0x08+8 bytes (Hex+Alpha Colour)
 * - MoreColors tags
 *
 * @param str             String to remove colours from
 * @param singleBytes     Remove single-byte engine colours (0x10 is always removed regardless.)
 * @param multiBytes      Remove multi-byte engine colours
 * @param moreColorsTags  Remove MoreColors tags
 *
 * @return                Number of bytes removed from string
 */
native int SFHCL_RemoveColours(char[] str,
  const bool singleBytes=true,
  const bool multiBytes=true,
  const bool moreColorsTags=true);
  
/**
 * Does character/byte match a single-byte source engine colour code (TF2 Only).
 * @return        True for 0x01, 0x03, 0x04, 0x05, 0x06, false otherwise
 */
native bool SFHCL_IsSingleByteColour(const char byte);




//=================================
// MoreColors 1.9.1 Reimplementation

/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags.
 * 
 * @param client        Client index.
 * @param message       Message (formatting rules).
 * @noreturn
 * 
 * On error/Errors:     If the client is not connected an error will be thrown.
 */
native void CPrintToChat(const int client, const char[] message, any ...);

/**
 * Prints a message to all clients in the chat area.
 * Supports color tags.
 * 
 * @param client        Client index.
 * @param message       Message (formatting rules).
 * @noreturn
 */
native void CPrintToChatAll(const char[] message, any ...);

/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags and teamcolor tag.
 * 
 * @param client        Client index.
 * @param author        Author index whose color will be used for teamcolor tag.
 * @param message       Message (formatting rules).
 * @noreturn
 * 
 * On error/Errors:     If the client or author are not connected an error will be thrown
 */
native void CPrintToChatEx(const int client, const int author, const char[] message, any ...);

/**
 * Prints a message to all clients in the chat area.
 * Supports color tags and teamcolor tag.
 *
 * @param author        Author index whos color will be used for teamcolor tag.
 * @param message       Message (formatting rules).
 * @noreturn
 * 
 * On error/Errors:     If the author is not connected an error will be thrown.
 */
native void CPrintToChatAllEx(const int author, const char[] message, any ...);

/**
 * This function should only be used right in front of
 * CPrintToChatAll or CPrintToChatAllEx. It causes those functions
 * to skip the specified client when printing the message.
 * After printing the message, the client will no longer be skipped.
 * 
 * @param client        Client index
 * @noreturn
 */
native void CSkipNextClient(const int client);

/**
 * Replies to a command with colors
 * 
 * @param client        Client to reply to
 * @param message       Message (formatting rules)
 * @noreturn
 */
native void CReplyToCommand(const int client, const char[] message, any ...);

/**
 * Replies to a command with colors
 * 
 * @param client        Client to reply to
 * @param author        Client to use for {teamcolor}
 * @param message       Message (formatting rules)
 * @noreturn
 */
native void CReplyToCommandEx(const int client, const int author, const char[] message, any ...);

/**
 * Shows admin activity with colors
 * 
 * @param client        Client performing an action
 * @param message       Message (formatting rules)
 * @noreturn
 */
native void CShowActivity(const int client, const char[] message, any ...);

/**
 * Shows admin activity with colors
 * 
 * @param client        Client performing an action
 * @param tag           Tag to prepend to the message (color tags supported)
 * @param message       Message (formatting rules)
 * @noreturn
 */
native void CShowActivityEx(const int client, const char[] tag, const char[] message, any ...);

/**
 * Shows admin activity with colors
 * 
 * @param client        Client performing an action
 * @param tag           Tag to prepend to the message (color tags supported)
 * @param message       Message (formatting rules)
 * @noreturn
 */
native void CShowActivity2(const int client, const char[] tag, const char[] message, any ...);

/**
 * Send a colored SayText2 usermessage to a client (prints to chat)
 *
 * @param client        Client to send usermessage to
 * @param author        Optional client index to use for {teamcolor} tags, or 0 for none
 * @param message       Message to send (formatting rules)
 */
native void CSendMessage(const int client, const int author=0, const char[] message, any ...);

/**
 * Prints a message to all admins in the chat area, specified by flag.
 * Client is also considered admin if they have access to the sm_sfhcl_admin override.
 * Supports color tags.
 * 
 * @param flags           ADMFLAG_ bitfield
 * @param rootOverride    If true, root-access will be allowed regardless of flags
 * @param message         Message to send (formatting rules)
 * @noreturn
 */
native void CPrintToAdmins(const int flags, const bool rootOverride, const char[] message, any ...);

/**
 * Prints a message to all admins in the chat area, specified by flag.
 * Client is also considered admin if they have access to the sm_sfhcl_admin override.
 * Supports color tags and teamcolor tag.
 *
 * @param author          Client to use for {teamcolor}
 * @param flags           ADMFLAG_ bitfield
 * @param rootOverride    If true, root-access will be allowed regardless of flags
 * @param message         Message to send (formatting rules)
 * @noreturn
 * 
 * On error/Errors:     If the author is not connected an error will be thrown.
 */
native void CPrintToAdminsEx(const int author, const int flags, const bool rootOverride, const char[] message, any ...);

/**
 * Determines whether a color name exists
 * 
 * @param color         The color name to check
 * @return              True if the color exists, false otherwise
 */
native bool CColorExists(const char[] color);

/**
 * Returns the hexadecimal representation of a client's team color
 *
 * @param client        Client to get the team color for
 * @return              Client's team color in hexadecimal, or green if unknown
 * On error/Errors:     If the client index passed is invalid or not in game.
 */
native int CGetTeamColor(const int client);

/**
 * Adds a color to the colors trie
 *
 * @param name          Color name, without braces
 * @param color         Hexadecimal representation of the color (0xRRGGBB)
 * @return              True if color was added successfully, false if a color already exists with that name
 */
native bool CAddColor(const char[] name, const int color);

/**
 * Removes color tags from a message
 *
 * Note: This is only kept for full MoreColors API compatability.
 * It's made obsolete by SFHCL_RemoveColours (which it uses internally).
 * 
 * @param message       Message to remove tags from
 * @param maxlen        Maximum buffer length
 * @noreturn
 */
native void CRemoveTags(char[] message);

/**
 * Replaces color tags in a string with color codes
 *
 * @param buffer		  String.
 * @noreturn
 */
native void CReplaceColorCodes(char[] buffer);




/**
 * Required for libraries
 */
public SharedPlugin __pl_sfh_chatlib = 
{
  name = "sfh_chatlib",
  file = "sfh_chatlib.smx",
#if defined REQUIRE_PLUGIN
  required = 1,
#else
  required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_sfh_chatlib_SetNTVOptional()
{
  // Older SFP Natives
  MarkNativeAsOptional("TagReply");
  MarkNativeAsOptional("TagReplyUsage");
  MarkNativeAsOptional("TagPrintChat");
  MarkNativeAsOptional("TagActivity2");
  MarkNativeAsOptional("TagPrintServer");
  
  // New ChatLib natives added for complete API
  MarkNativeAsOptional("TagReplyUsageEx");
  MarkNativeAsOptional("TagPrintChatAll");
  MarkNativeAsOptional("TagPrintChatEx");
  MarkNativeAsOptional("TagPrintChatAllEx");
  MarkNativeAsOptional("TagReplyEx");
  MarkNativeAsOptional("TagActivityEx");
  MarkNativeAsOptional("TagPrintToAdmins");
  MarkNativeAsOptional("TagPrintToAdminsEx");
  
  MarkNativeAsOptional("SFHCL_RemoveColours");
  MarkNativeAsOptional("SFHCL_IsSingleByteColour");
  
  // MoreColors API Reimplementation
  MarkNativeAsOptional("CPrintToChat");
  MarkNativeAsOptional("CPrintToChatAll");
  MarkNativeAsOptional("CPrintToChatEx");
  MarkNativeAsOptional("CPrintToChatAllEx");
  MarkNativeAsOptional("CSkipNextClient");
  MarkNativeAsOptional("CReplyToCommand");
  MarkNativeAsOptional("CReplyToCommandEx");
  MarkNativeAsOptional("CShowActivity");
  MarkNativeAsOptional("CShowActivityEx");
  MarkNativeAsOptional("CShowActivity2");
  MarkNativeAsOptional("CSendMessage");
  MarkNativeAsOptional("CPrintToAdmins");
  MarkNativeAsOptional("CPrintToAdminsEx");
  MarkNativeAsOptional("CColorExists");
  MarkNativeAsOptional("CGetTeamColor");
  MarkNativeAsOptional("CAddColor");
  MarkNativeAsOptional("CRemoveTags");
  MarkNativeAsOptional("CReplaceColorCodes");
}
#endif
