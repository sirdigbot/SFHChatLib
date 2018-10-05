# Satan's Fun House - Chat Library  
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)  

A set of shortcut functions to print coloured messages to chat with a prepended `[SM]` tag, which can be customised.  
Automatically removes colours when printing to rcon/console.  

*Colours and Core Functionality are from an included version of [MoreColors](https://forums.alliedmods.net/showthread.php?t=185016) modified for Sourcemod 1.7+ support.*  

The *\_Ex* natives are essentially identical, but with support for `{teamcolor}`  

| Native                                  | Description |
| ----------------------------------------- | --- | 
| **TagReply**(const int client, const char[] msg, any ...) | Prepend coloured `[SM]` tag to *CReplyToCommand* |
| **TagReplyUsage**(const int client, const char[] msg, any ...) |  Prepend coloured `[SM] Usage:` tag to *CReplyToCommand* |
| **TagPrintChat**(const int client, const char[] msg, any ...) | Prepend coloured `[SM]` tag to *CPrintToChat* |
| **TagActivity2**(const int client, const char[] msg, any ...) | Prepend coloured `[SM]` tag to *CShowActivity2* |
| **TagPrintServer**(const char[] msg, any ...) | Prepend uncoloured `[SM]` tag to *PrintToServer* |
| **TagPrintToClient**(const int client, const char[] msg, any ...) | Chooses between *CPrintToChat* and *PrintToServer* based on the client supplied *(without requiring a ReplySource)* |
| **TagReplyUsageEx**(const int client, const int author, const char[] msg, any ...) | Prepend coloured `[SM] Usage:` tag to *CReplyToCommandEx* |
| **TagPrintChatAll**(const char[] msg, any ...) | Prepend coloured `[SM]` tag to *CPrintToChatAll* |
| **TagPrintChatEx**(const int client, const int author, const char[] msg, any ...) | Prepend coloured `[SM]` tag to *CPrintToChatEx* |
| **TagPrintChatAllEx**(const int author, const char[] msg, any ...) | Prepend coloured `[SM]` tag to *CPrintToChatAllEx* |
| **TagReplyEx**(const int client, const int author, const char[] msg, any ...) | Prepend coloured `[SM]` tag to *CReplyToCommand* |
| **TagActivityEx**(const int client, const char[] msg, any ...) | Prepend coloured `[SM]` tag to *CShowActivityEx* |
| **TagPrintToClientEx**(const int client, const int author, const char[] msg, any ...) | Chooses between *CPrintToChatEx* and *PrintToServer* based on the client supplied *(without requiring a ReplySource)* |
| **SFHCL_RemoveColours**(char[] str, const bool singleBytes=true, const bool multiBytes=true, const bool moreColorsTags=true) | Remove all engine-colour bytes *(TF2 Only)* and MoreColors tags |
| **SFHCL_IsSingleByteColour**(const char byte) | Check if a char/byte is a single-byte engine-colour *(TF2 Only)* |  

