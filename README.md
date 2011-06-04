# Overview

**Mirrot Bot** is an [Internet Relay Chat](http://en.wikipedia.org/wiki/Internet_Relay_Chat) bot designed to mirror all the activity from one IRC channel to another on a different IRC server, and visa-versa.  Meaning, the bot monitors all activity in a channel on two different servers, and repeats everything said by all users into the other.  The bot can either repeat everything by speaking itself, or it can actually create and control "virtual users" for each real user on the other side of the mirror.  One potential use of this is to mirror your [Justin.TV](http://justin.tv) channel (which has its own IRC chat) onto your own IRC server.  You can also pass commands through the mirror to the other bot for kicking / banning users remotely.

# Features

Here are some of the features in Mirror Bot:

## Commands

While the bot is designed to run relatively unmanaged, you can send a variety of commands to it.  You can also send commands *through* the mirror, to the bot on the other side (see **Relaying Commands** below).  For commands to be detected and executed by the bot, they need to be prefixed with a special activator symbol (defaults to "`!`"), and your user needs to have a high enough access level (op, admin, etc. -- this is configurable), or you need to be the bot owner.

Here are the available bot commands you can send:

### quit

This command quits the bot (affects both sides of the mirror).  Aliases include: `exit`, `shutdown` and `die`.

### reload

This command reloads the bot (affects both sides of the mirror), meaning it will disconnect and reconnect to both servers.  Aliases include: `restart` and `cycle`.

### kick

This command kicks the specified user out of the channel.  Typical usage of this is to relay the command to the other side of the mirror (see below).  Specify the nickname of the user after the command: `!kick some_bad_nick`.

### ban

This command bans the specified user from the channel, so they can no longer login.  Typical usage of this is to relay the command to the other side of the mirror (see below).  Specify the nickname of the user after the command: `!ban some_bad_nick`.

### unban

This command reverses a ban, and restores access to the specified user.  Typical usage of this is to relay the command to the other side of the mirror (see below).  Specify the nickname of the user after the command: `!unban some_bad_nick`.

### register

This command tells the bot to attempt to register its nickname, e-mail and password with NickServ.  This command must be entered by the bot owner, and only needs to be done once.  Registered nicks can be set to become ops automatically, for example if you wanted your mirror bot to be an op, use this.

### identify

This command tells the bot to attempt to identify itself via NickServ.  Note that this should happen automatically upon login, and should only need to be manually invoked in special situations.  This command can only be entered by the bot owner.

### msg

Use this command to have the bot send private messages to users or service bots.  For example, if you need the bot to send a message to NickServ, ChanServ, HostServ, BotServ, or another special bot, you can use this command.  This can only be done by the bot owner.  Example: `!msg NickServ REGISTER botpassword botemail@myserver.com`

### say

Use this command to have the bot repeat the specified text into the channel.  This doesn't really have any use except to test the bot, to make sure it is still listening.  Example: `!say Hello, I am a bot.`

### eval

This is an advanced command, which can only be used if the bot is running in "debug" mode (see **Configuration** below), and can only be entered by the bot owner.  This allows you to enter raw Perl code to be executed by the bot.  This is only provided for debugging and troubleshooting during development, and has no real world use.  Example: `!eval 2 + 2`

## Relaying Commands

All the bot commands are executed on the channel in which they are entered.  However, they also can be "relayed" to the other side of the mirror, to be executed by the mirror bot running on the *other* server.  To do this, simply prefix your command with the word "`mirror`" just after the activator symbol.  Example: `!mirror kick some_bad_nick`

This allows you to kick remote users without having to be logged into both IRC servers.  Note that the mirror bot will need to be an "op" in the remote channel to have permission to actually kick or ban real users.  Use with caution.

## Virtual Users

This feature, when enabled, causes the bot to spawn multiple "virtual users", which appear in your channel as if they were real people.  So instead of having the bot doing all the talking itself, the virtual users actuall speak for themselves, mirroring what their real user counterparts say on the other side of the mirror.  See the **Configuration** section below for instructions on how to set this up.

Note that in order to do this, the bot has to connect to the server multiple times, once for each virtual user.  However, many IRC servers limit the maximum number of connections from a single IP address.  You will likely have to crank up this configuration setting to allow enough virtual users for your channels.  For example, if you are using the popular [Inspircd](http://www.inspircd.org/) IRC server software, this can be found in the `inspircd.conf` file in the `<connect>` configuration setting.  Crank up the `localmax` and `globalmax` attributes to hold enough virtual users for your channels.

One cool feature about virtual users is that if you kick them out of your channel, the mirror bot can be configured to detect this, and automatically tell the *other* side of the mirror to kick the real user out.  See the `real_kicks` option below for details.

## Justin.TV Support

So, you have your own [Justin.TV](http://justin.tv) channel, but you have your own IRC server, and you want your JTV viewers to be able to participate in your chat?  No problem!  Mirror Bot can "connect" the two together, because Justin's web chat is actually built on IRC.  Your JTV viewers can appear as real users on your own IRC server.  See the **Configuration** section below for how to set this up.

Mirror Bot knows that Justin.TV IRC commands are non-standard, and does the translation for you.  So you can continue to use standard bot commands such as `!mirror kick some_bad_nick`, and the bot will perform the necessary JTV IRC command on the other side.  Topic sync is also supported, so the JTV topic can match the channel topic on your own server (just enable the `push_topic` option, detailed below).

Remember that Justin.TV doesn't allow anonymous users to enter their web chat, so you will have to actually create a real Justin.TV account for the bot.  Then, you'll have to setup the configuration using `myjtvchannel.jtvirc.com` as the IRC server hostname (replace `myjtvchannel` with your actual JTV channel name), and include `<server_password>` set to the bot's JTV account password.  Leave `<password>` blank, as JTV doesn't use NickServ.

# Installation

Before you install, please make sure you have the following dependencies:

* [Perl](http://perl.org)
* [POE::Component::IRC](http://search.cpan.org/perldoc?POE::Component::IRC)
* [Bot::BasicBot](http://search.cpan.org/perldoc?Bot::BasicBot)

Then, grab the source tarball from GitHub and decompress into the root directory of your server:

```bash
cd /
wget "https://github.com/jhuckaby/Mirror-Bot/tarball/master"
tar zxf jhuckaby-Mirror-Bot-*.tar.gz
rm jhuckaby-Mirror-Bot-*.tar.gz
chmod 755 /mirrorbot/bin/*.*
```

Make sure the bot has permission to write to its PID and log files (see **Configuration*** below for locations of files).  Often `/var/log` and `/var/run` have restrictive permissions on Unix, and the bot needs to write to both (by default -- you can change the location of its log and PID files).

# Configuration

Mirror Bot is configured via an XML file which lives here: `/mirrorbot/conf/config.xml`

```xml
<?xml version="1.0"?>
<BotConfig>
	<Common>
		<debug>0</debug>
		<main_debug_log_file>/var/log/mirrorbot-debug.log</main_debug_log_file>
		<drone_debug_log_file>/var/log/mirrorbot-drone-debug.log</drone_debug_log_file>
		<drone_command_log_file>/var/log/mirrorbot-drone-commands.log</drone_command_log_file>
		<pid_file>/var/run/mirrorbot.pid</pid_file>
		<owner>your_irc_nick</owner>
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
		<push_topic>1</push_topic>
	</Left>
	<Right>
		<mirror_name>JTV</mirror_name>
		<server>myjtvchannel.jtvirc.com</server>
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

The file is split up into three main sections, `<Common>`, `<Left>` and `<Right>`.  The left and right sections contain configuration parameters specific to each side of the mirror, including which IRC server to connect to, which channel to join, and how to identify the bot.  Any elements placed into the common area are effectively shared by both mirrors.

Here are descriptions of the elements which may live in any section:

#### debug

If set to "1", the bot will run in debug mode.  This means that it will not fork a daemon process on startup, and instead run as a command-line script, echoing all debug log rows to the console.  In this mode, you can hit Ctrl-C to cause the bot to shutdown.  This mode is only intended for debugging and troubleshooting.

#### main_debug_log_file

This specifies the location on disk of the main bot debug log.

#### drone_debug_log_file

This specifies the location on disk of the drone (virtual user) debug log.  This is only used if you enable virtual users in your configuration.

#### drone_command_log_file

This specifies the location on disk of the drone command queue file.  This file is used to send commands to the drones (virtual users), if applicable.

#### pid_file

This specifies the location on disk of the bot daemon PID (Process ID) file.  This is used by the startup / shutdown control script.

#### owner

This IRC nickname will *always* be able to control the bot, regardless of his/her access level, and can perform advanced debugging commands (see below).

#### flood

This is a flag passed to the underlying [Bot::BasicBot](http://search.cpan.org/perldoc?Bot::BasicBot) class, which, when set to "1", sends traffic to the IRC server in real time (i.e. at full speed).  If set to "0", however, the traffic will be throttled using an algorithm.  If your bot is getting kicked for flooding, disable this param.

For more information, see the [POE::Component::IRC](http://search.cpan.org/perldoc?POE::Component::IRC) documentation on CPAN (Bot::BasicBot extends this module).  Search for "flood" on the page.

#### access

This specifies the minimum user access level required to control the bot.  Meaning, if the value is set to "`op`", then users must be ops (or higher) to issue commands that the bot will respond to.  Should be set to one of: "`voice`", "`half`", "`op`", "`admin`", or "`founder`".  Remember that the bot owner user can *always* control the bot, regardless of his/her access level.

#### activator

This is the activator symbol that needs to prefix bot commands.  For example, if the activator is set to "`!`", then the bot will only respond to commands that begin with that symbol, e.g. "`!quit`", "`!reload`" or "`!mirror kick somebaduser`".  See the command reference below for the complete list of commands.

#### ignore

This is an optional list of user nicknames to ignore, in comma-separated syntax.  Ignored users are not mirrored through the bot.

#### mirror_name

This is just a visual label for the mirror, which is used in notification messages sent between the bots.  For example, when users join or leave channels, the mirror on the *other* room posts a notice, including the mirror name.

#### server

The IRC server hostname or IP address to connect to.  Should be different for each side of the mirror.

#### port

The IRC server port to connect to.  The default IRC port is 6667.  Should be different for each side of the mirror.

#### channel

The IRC channel to join.  Should be different for each side of the mirror.

#### nick

The IRC nickname to use for the mirror bot.

#### username

The IRC username the bot should login as.

#### name

The "real name" for the bot to use when logging in to the IRC server.

#### password

If the mirror bot is a registered username, specify its password here.  The bot will try to auto-identify itself via NickServ when logging in.

#### server_password

If the IRC requires a server password (a la Justin.TV), specify it here.

#### email

The e-mail address to use when registering the bot via NickServ.

#### virtual_users

When set to "1", will create "virtual users" on one side of the mirror, meaning the bot will login multiple times, once for each user on the *other* side of the mirror.

#### virtual_nick_prefix

When virtual user mode is active, each virtual user's nickname will contain this prefix.  This differentiates them from "real" users, so you can easily tell them apart.  While you *can* remove this value, it is not recommended.

#### push_topic

When set to "1", the IRC channel topic is "pushed" (copied to) the other side of the mirror.  This way you only have to set the topic on one side of the mirror, and it will be automatically copied to the other.

#### real_kicks

When set to "1", and the opposing mirror has virtual users enabled, and one of the virtual users gets kicked out of the channel, the bots will detect this, and attempt to kick out the "real" user on the other side of the mirror.  This is an advanced feature, and requires the mirror bot to be an "op" in the channel.

# Starting / Stopping

Mirror Bot comes with a simple shell script to start and stop the service.  It normally forks a daemon process unless running in debug mode.  To start it:

```bash
/mirrorbot/bin/mirrorbotctl.sh start
```

And to stop it:

```bash
/mirrorbot/bin/mirrorbotctl.sh stop
```

# Troubleshooting

If you are having trouble getting the bot to start, try running it in debug mode.  This will prevent the daemon fork, and it will run as a simple command-line script, and dump out debugging information to the console.  You can either change the `<debug>` element to "1" in your config file, or pass it as a command-line argument:

```bash
/mirrorbot/bin/mirrorbot.pl --debug 1
```

# Legal

Copyright (c) 2011 Joseph Huckaby

Source Code released under the MIT License: http://www.opensource.org/licenses/mit-license.php
