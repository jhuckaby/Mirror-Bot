# Overview

**Mirrot Bot** is an [Internet Relay Chat](http://en.wikipedia.org/wiki/Internet_Relay_Chat) bot designed to mirror all the activity from one IRC channel to another, and visa-versa.  Meaning, the bot monitors all activity in two different channels, and replicates everything said by all users into the other.  The bot can either repeat everything by speaking itself, or it can actually create and control "virtual users" for each real user on the other side of the mirror.  One potential use of this is to mirror your [Justin.TV](http://justin.tv) channel (which has its own IRC interface) onto your own IRC server.  You can also pass commands through the mirror to the other bot for kicking / banning users remotely.

# Installation



# Configuration

Mirror Bot is configured via an XML file which lives here: `/mirrorbot/conf/config.xml`

```xml
<?xml version="1.0"?>
<!-- MirrorBot 1.0 -->
<!-- Copyright (c) 2011 by Joseph Huckaby -->
<!-- Source Code released under the MIT License: -->
<!-- http://www.opensource.org/licenses/mit-license.php -->
<BotConfig>
	<Common>
		<debug>1</debug>
		<main_debug_log_file>/var/log/mirrorbot-debug.log</main_debug_log_file>
		<drone_debug_log_file>/var/log/mirrorbot-drone-debug.log</drone_debug_log_file>
		<drone_command_log_file>/var/log/mirrorbot-drone-commands.log</drone_command_log_file>
		<pid_file>/var/run/mirrorbot.pid</pid_file>
		<owner>jhuckaby</owner>
		<flood>1</flood>
		<access>op</access>
		<activator>!</activator>
		<ignore>chanserv, vaughn</ignore>
	</Common>
	<Left>
		<mirror_name>MyIRCServer</mirror_name>
		<server>irc.myserver.com</server>
		<port>6667</port>
		<channel>#mychannel</channel>
		<nick>mirrorbot</nick>
		<username>mirrorbot</username>
		<name>mirrorbot</name>
		<password></password>
		<email>mirrorbot@myserver.com</email>
		<virtual_users>1</virtual_users>
		<virtual_nick_prefix>JTV-</virtual_nick_prefix>
		<sync_topic>1</sync_topic>
	</Left>
	<Right>
		<mirror_name>JTV</mirror_name>
		<server>myjtvusername.jtvirc.com</server>
		<port>6667</port>
		<channel>#jtvusername</channel>
		<nick>jtvmirror</nick>
		<username>jtvmirror</username>
		<name>jtvmirror</name>
		<server_password>jtvpassword</server_password>
		<email>mirrorbot@myserver.com</email>
		<real_kicks>1</real_kicks>
	</Right>
</BotConfig>
```

The file is split up into three main sections, `<Common>`, `<Left>` and `<Right>`.  Any elements 

Here are descriptions of the elements which may live in any section:

## Level 2

### Level 3

#### Level 4

##### Level 5

Hello

# Starting / Stopping



# Features

## Virtual Users

max user warning

## Justin.TV Support

# IRC Command Reference

# Legal

Copyright (c) 2011 Joseph Huckaby

Source Code released under the MIT License: http://www.opensource.org/licenses/mit-license.php
