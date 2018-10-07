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



/**
 * Prepends CReplyToCommand with a coloured command ("[SM]") tag.
 * Removes colour if printing to console.
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagReply(const int client, const char[] msg, any ...);

/**
 * Prepends CReplyToCommand with a coloured command ("[SM]") tag.
 * Removes colour if printing to console.
 *
 * @param client	Client who issued command
 * @param author  Client to use for team colour/{teamcolor}
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagReplyEx(const int client, const int author, const char[] msg, any ...);

/**
 * Prepends CReplyToCommand with a coloured command usage ("[SM] Usage:") tag.
 * Removes colour if printing to console.
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagReplyUsage(const int client, const char[] msg, any ...);

/**
 * Prepends CReplyToCommand with a coloured command usage ("[SM] Usage:") tag.
 * Removes colour if printing to console.
 *
 * @param client	Client who issued command
 * @param author  Client to use for team colour/{teamcolor}
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagReplyUsageEx(const int client, const int author, const char[] msg, any ...);



/**
 * Prepends CPrintToChat with a coloured command ("[SM]") tag.
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagPrintChat(const int client, const char[] msg, any ...);

/**
 * Prepends CPrintToChatEx with a coloured command ("[SM]") tag.
 *
 * @param client	Client who issued command
 * @param author	Client to use for team colour/{teamcolor}
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagPrintChatEx(const int client, const int author, const char[] msg, any ...);

/**
 * Prepends CPrintToChatAll with a coloured command ("[SM]") tag.
 *
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagPrintChatAll(const char[] msg, any ...);

/**
 * Prepends CPrintToChatAllEx with a coloured command ("[SM]") tag.
 *
 * @param author	Client to use for team colour/{teamcolor}
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagPrintChatAllEx(const int author, const char[] msg, any ...);



/**
 * Prepends CShowActivity2 with a coloured command ("[SM]") tag.
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagActivity2(const int client, const char[] msg, any ...);

// TagActivity is pointless because CShowActivity does not allow custom tags,
// AND we cant filter colours for the ShowActivity functions.

/**
 * Prepends CShowActivityEx with a coloured command ("[SM]") tag.
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagActivityEx(const int client, const char[] msg, any ...);



/**
 * Prepends PrintToServer with a command ("[SM]") tag.
 *
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagPrintServer(const char[] msg, any ...);

/**
 * Print a message to a client when you don't have a known ReplySource,
 * Prepending with a command ("[SM]") tag which is only coloured in chat.
 * Prints to chat for players and to console for the rcon.
 *
 * @param client	Client who issued command
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagPrintToClient(const int client, const char[] msg, any ...);

/**
 * Print a message to a client when you don't have a known ReplySource,
 * Prepending with a command ("[SM]") tag which is only coloured in chat.
 * Prints to chat for players and to console for the rcon.
 *
 * @param client	Client who issued command
 * @param author	Client to use for team colour/{teamcolor}
 * @param msg	    String to print
 * @param ...   	Optional. Format-Class Function
 */
native void TagPrintToClientEx(const int client, const int author, const char[] msg, any ...);



/**
 * Remove all the source-engine-native chat colours from a string (TF2 Only).
 * Specifically this can remove:
 * - Single-byte Colours: 0x01, 0x03, 0x04, 0x05, 0x06 (and 0x10, which is the removal char and has no function)
 * - Multibyte Colours: 0x07+6 bytes (Hex Colour), and 0x08+8 bytes (Hex+Alpha Colour)
 * - MoreColors tags
 *
 * @param str	            String to remove colours from
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
	MarkNativeAsOptional("TagPrintToClient");
  
  // New natives added for complete API
  MarkNativeAsOptional("TagReplyUsageEx");
  MarkNativeAsOptional("TagPrintChatAll");
  MarkNativeAsOptional("TagPrintChatEx");
  MarkNativeAsOptional("TagPrintChatAllEx");
  MarkNativeAsOptional("TagReplyEx");
  MarkNativeAsOptional("TagActivityEx");
  MarkNativeAsOptional("TagPrintToClientEx");
  
  MarkNativeAsOptional("SFHCL_RemoveColours");
  MarkNativeAsOptional("SFHCL_IsSingleByteColour");
}
#endif
