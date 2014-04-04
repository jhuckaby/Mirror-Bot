## Overview

**Mirror Bot** is an [Internet Relay Chat](http://en.wikipedia.org/wiki/Internet_Relay_Chat) bot designed to mirror all the activity from one IRC channel to another on a different IRC server, and visa-versa.  Meaning, the bot monitors all activity in a channel on two different servers, and repeats everything said by all users into the other.  One potential use of this is to mirror your [Twitch.TV](http://twitch.tv) channel (which has its own IRC chat) onto your own IRC server.  You can also pass commands through the mirror to the other bot for kicking / banning users remotely.

## Single-Command Auto-Install

To install MirrorBot, execute this command as root on your server:

    curl -s "http://pixlcore.com/software/mirrorbot/install-latest-stable.txt" | bash

Or, if you don't have curl, you can use wget:

    wget -O - "http://pixlcore.com/software/mirrorbot/install-latest-stable.txt" | bash

This will install the latest stable version of MirrorBot into the `/opt/mirrorbot/` directory.  Change the word "stable" to "dev" in the above command to install the development branch.  This single command installer should work fine on any modern Linux RedHat (RHEL, Fedora, CentOS) or Debian (Ubuntu) operating system.  Basically, anything that has "yum" or "apt-get" should be happy.  See the [Manual Installation Instructions](#manual-installation) for other OSes, or if the single-command installer doesn't work for you.

After installation, you will be provided instructions for configuring and connecting to your servers.

## Features

Here are some of the features in Mirror Bot:

### Commands

While the bot is designed to run relatively unmanaged, you can send a variety of commands to it.  Some commands also run *through* the mirror, to the bot on the other side.  For commands to be detected and executed by the bot, they need to be prefixed with a special activator symbol (defaults to "`!`"), and your user needs to have a high enough access level (op, admin, etc. -- this is configurable).

Here are the available bot commands you can send:

#### !timeout (Remote, Twitch Only)

This command times out the specified Twitch user out of the mirrored channel.  Specify the nickname of the user after the command: `!timeout some_bad_nick`;

#### !ban (Remote, Twitch Only)

This command bans the specified user from the Twitch channel on the other side of the mirror, so they can no longer login.  Specify the nickname of the user after the command: `!ban some_bad_nick`.

#### !unban (Remote, Twitch Only)

This command reverses a Twitch ban, and restores access to the specified user on the other side of the mirror.  Specify the nickname of the user after the command: `!unban some_bad_nick`.

#### !msg (Remote)

Use this command to have the bot send private messages to users on the other side of the mirror.  This can only be done by the bot owner.  Example: `!msg some_nick Hello there I am a bot.`

#### !say (Remote)

Use this command to have the bot repeat the specified text into the channel on the other side of the mirror.  This doesn't really have any use except to test the bot, to make sure it is still listening.  Example: `!say Hello, I am a bot.`

#### !kick (Remote)

This command kicks the specified user out of the channel on the other side of the mirror.  Specify the nickname of the user after the command: `!kick some_bad_nick`.  Note that this command is only for standard IRC servers, not Twitch.  Twitch does not have a "kick" command.

#### !quit

This command quits the bot (affects both sides of the mirror).  Aliases include: `exit`, `shutdown` and `die`.

#### !restart

This command reloads the bot (affects both sides of the mirror), meaning it will disconnect and reconnect to both servers.  Aliases include: `reload` and `cycle`.

#### !identify

This command tells the bot to attempt to identify itself via NickServ.  Note that this should happen automatically upon login, and should only need to be manually invoked in special situations.  This command can only be entered by the bot owner.

#### !eval

This is an advanced command, which can only be used if the bot is running in "debug" mode (see [Configuration](#configuration) below), and can only be entered by the bot owner.  This allows you to enter raw Perl code to be executed by the bot.  This is only provided for debugging and troubleshooting during development, and has no real world use.  Example: `!eval 2 + 2`

## Twitch.TV Support

So, you have your own [Twitch.TV](http://twitch.tv) channel, but you have your own IRC server, and you want your Twitch viewers to be able to participate in your chat?  No problem!  Mirror Bot can "connect" the two together, because Twitch's web chat is actually built on IRC.  Your viewers' chat messages can appear on your own IRC channel, and visa-versa.  See the [Twitch Setup](#twitch-setup) section below for how to set this up.

## Configuration

Mirror Bot is configured via an XML file which lives here: `/opt/mirrorbot/conf/config.xml`

```xml
<?xml version="1.0"?>
<BotConfig>
	<Common>
		<owner>YOUR_NICK</owner>
		<flood>1</flood>
		<access>op</access>
		<activator>!</activator>
		<ignore>chanserv, vaughn, moobot, nightbot</ignore>
	</Common>
	<Left>
		<mirror_name>MY_NETWORK_NAME</mirror_name>
		<server>my.irc.network.com</server>
		<port>6667</port>
		<channel>#mychannel</channel>
		<nick>TwitchChat</nick>
		<password>YOUR_NICK_PASS</password>
		<sync_topic>0</sync_topic>
		<nick_decoration>&lt;&gt;</nick_decoration>
		<prevent_dupes>1</prevent_dupes>
	</Left>
	<Right>
		<mirror_name>Twitch</mirror_name>
		<server>irc.twitch.tv</server>
		<port>6667</port>
		<channel>#YOUR_TWITCH_CHANNEL</channel>
		<nick>YOUR_TWITCH_NICK</nick>
		<server_password>oauth:YOUR_OAUTH_HASH</server_password>
		<nick_decoration>[]</nick_decoration>
		<throttle>1</throttle>
		<queue_length>5</queue_length>
		<prevent_dupes>1</prevent_dupes>
	</Right>
</BotConfig>
```

The file is split up into three main sections, `<Common>`, `<Left>` and `<Right>`.  The left and right sections contain configuration parameters specific to each side of the mirror, including which IRC server to connect to, which channel to join, and how to identify the bot.  Any elements placed into the common area are effectively shared by both mirrors.

Here are descriptions of the elements which may live in any section:

#### debug

If set to "1", the bot will run in debug mode.  This means that it will not fork a daemon process on startup, and instead run as a command-line script, echoing all debug log rows to the console.  In this mode, you can hit Ctrl-C to cause the bot to shutdown.  This mode is only intended for debugging and troubleshooting.

#### log_file

This specifies the location on disk of the bot debug log.  It defaults to `/opt/mirrorbot/logs/debug.log`.

#### owner

This IRC nickname will be able to control special bot commands (eval, identify, etc.).

#### flood

This is a flag passed to the underlying [Bot::BasicBot](http://search.cpan.org/perldoc?Bot::BasicBot) class, which, when set to "1", sends traffic to the IRC server in real time (i.e. at full speed).  If set to "0", however, the traffic will be throttled using an algorithm.  If your bot is getting kicked for flooding, set this param to "0".  Also see the [Throttle](#throttle) option below.

For more information, see the [POE::Component::IRC](http://search.cpan.org/perldoc?POE::Component::IRC) documentation on CPAN (Bot::BasicBot extends this module).  Search for "flood" on the page.

#### access

This specifies the minimum user access level required to control the bot.  Meaning, if the value is set to "`op`", then users must be ops (or higher) to issue commands that the bot will respond to.  Should be set to one of: "`voice`", "`half`", "`op`", "`admin`", or "`founder`".  Remember that the bot owner user must also have this access level or above.

#### activator

This is the activator symbol that needs to prefix bot commands.  For example, if the activator is set to "`!`", then the bot will only respond to commands that begin with that symbol, e.g. "`!quit`", "`!reload`" or "`!kick somebaduser`".  See the command reference below for the complete list of commands.

#### ignore

This is an optional list of user nicknames to ignore, in comma-separated syntax.  Ignored users are not mirrored through the bot.  Typical usage of this is to ignore other bots.  Names are matched case-insensitively.

#### mirror_name

This is just a label for the mirror, which is used in notification messages sent between the bots, and in the log file.

#### server

The IRC server hostname or IP address to connect to.  Should be different for each side of the mirror.

#### port

The IRC server port to connect to.  The default IRC port is 6667.

#### channel

The name of the IRC channel to join, e.g. `#mychannel`.

#### nick

The IRC nickname to use for the bot.  Make sure you pre-register the nickname with your IRC server beforehand.

#### password

If the mirror bot is a registered username, specify its password here.  The bot will try to auto-identify itself via NickServ when logging in.  This is not required for Twitch.TV, which uses an OAuth server password instead.

#### server_password

If the IRC requires a server password (i.e. Twitch.TV OAuth token), specify it here.

#### sync_topic

When set to "1", the IRC channel topic is synchronized (copied to) the other side of the mirror.  This way you only have to set the topic on one side of the mirror, and it will be automatically copied to the other.  Not used for Twitch.

#### nick_decoration

This param specifies which characters to print before and after nicknames as decoration, when the bot emits messages on each side of the channel.  Specify them as exactly two characters, back-to-back.  For example, to use square brackets:

```xml
	<nick_decoration>[]</nick_decoration>
```

This would decorate nicknames like this:

```
	[david34] When will Joe get here?
	[gamerdude] Soon, he's writing code.
	[joe121] I'm here guys!
```

It is common to use angle brackets, but note that these must be specified as entities in XML, so use this syntax:

```xml
	<nick_decoration>&lt;&gt;</nick_decoration>
```

This would decorate nicknames like this:

```
	<david34> When will Joe get here?
	<gamerdude> Soon, he's writing code.
	<joe121> I'm here guys!
```

Please do not use angle brackets for Twitch, as their web chat seems to really not like them.  You can leave this parameter blank to have no nickname decoration at all.

#### throttle

This param activates throttling on the side of the mirror where it appears, meaning, only the specified number of messages is allowed per second.  So for example, if you set the param to "1", only one message will be allowed to be posted per second.  Additional messages will be queued up and flushed in subsequent seconds.

This should be used for Twitch, which will ban your bot if you post more than one message per second.

#### queue_length

When the `throttle` option is enabled (see above), this param specifies how many messages can be queued up before new ones start getting dropped.  For example, if you have the throttle set to "1" (message per sec) and queue length set to "5", and someone floods the channel with 20 messages all within the same second, only the first 5 will be emitted.  The remaining 15 will be skipped.  This is designed to prevent floods from causing a situation where the bot is stuck slowly posting flooded messages one at a time, while everyone has to wait.

It is highly recommended to use both `throttle` and `queue_length` for Twitch.  Set throttle to "1" and queue length to "5":

```xml
	<throttle>1</throttle>
	<queue_length>5</queue_length>
```

#### prevent_dupes

This param, when set to "1", prevents repeat messages from being posted on whichever side of the mirror the param appears in the config.  Meaning, if the same user posts the same message multiple times, the bot will *only* mirror the first occurrence.  This is designed to control spam / floods, and is highly recommended for all IRC servers, especially Twitch, which can ban for the bot for flooding.

```xml
	<prevent_dupes>1</prevent_dupes>
```

## Twitch Setup

For connecting one side of MirrorBot to Twitch.TV's IRC system, please follow these instructions.  Note that Twitch has a very strange IRC setup that doesn't use a standard user password.  Instead, you have to generate an OAuth token and specify that as the *server password*.

First, I recommend you read Twitch's own instructions for connecting via IRC, so you can see generally what will be involved: [Twitch IRC Setup Instructions](http://help.twitch.tv/customer/portal/articles/1302780-twitch-irc).

Next, create a new Twitch account specifically for your bot (do **not** have the bot connect as you): [Twitch New Account Signup Page](http://www.twitch.tv/signup).  It is recommended you pick a username as short as possible, perhaps an abbreviation of your channel name, because **all IRC users** mirrored through the bot will appear to speak as the bot user.

Next, generate an OAuth token to put into the MirrotBot's `<server_password>` config param: [Twitch OAuth Token Generator](http://www.twitchapps.com/tmi).  I recommend you do this in an "Incognito Window" (Chrome), or Private Browsing session (Firefox / Safari), because you want to connect to Twitch as the bot's user, **not your own user account**.

Now, fill out the Twitch side of the mirror in the config file accordingly:

```xml
	<mirror_name>Twitch</mirror_name>
	<server>irc.twitch.tv</server>
	<port>6667</port>
	<channel>#YOUR_TWITCH_CHANNEL</channel>
	<nick>BOT_TWITCH_USERNAME</nick>
	<server_password>oauth:YOUR_OAUTH_HASH</server_password>
	<nick_decoration>[]</nick_decoration>
	<throttle>1</throttle>
	<queue_length>5</queue_length>
	<prevent_dupes>1</prevent_dupes>
```

When the bot connects for the first time and you see the bot's user in the viewer list, make sure you mod the bot (make the bot a mod in your Twitch channel).  This is **extremely important**, because Twitch **highly throttles** standard users so they can only post a message every few seconds.  You want the bot to be able to post messages much quicker, because it is posting for ALL IRC users.  Only mods of your channel can do this.

## Starting / Stopping

Mirror Bot comes with an init.d script to start and stop the service (and also starts it automatically on server reboot).  It normally forks a daemon process unless running in debug mode.  To start it:

```bash
/etc/init.d/mirrorbotd start
```

And to stop it:

```bash
/etc/init.d/mirrorbotd stop
```

## Manual Installation

If the single-command auto-install doesn't work on your server, you can manually install MirrorBot from source.  Before you install, please make sure you have the following dependencies:

* [Perl](http://perl.org)
* [POE::Component::IRC](http://search.cpan.org/perldoc?POE::Component::IRC)
* [Bot::BasicBot](http://search.cpan.org/perldoc?Bot::BasicBot)

Then, grab the source tarball from GitHub and decompress into the `/opt` directory of your server:

```bash
mkdir -p /opt
cd /opt
wget -O mirrorbot.tar.gz "https://github.com/jhuckaby/Mirror-Bot/tarball/master"
tar zxf mirrorbot.tar.gz
rm mirrorbot.tar.gz
mv jhuckaby-Mirror-Bot-* mirrorbot
chmod 755 mirrorbot/bin/*.*
```

Make sure the bot has permission to write to its PID and log files (see [Configuration](#configuration) for locations of files).  Often `/var/log` and `/var/run` have restrictive permissions on Unix, and the bot needs to write to both (by default -- you can change the location of its log and PID files).

## Troubleshooting

If you are having trouble getting the bot to start, try running it in debug mode.  This will prevent the daemon fork, and it will run as a simple command-line script, and dump out debugging information to the console.  You can either set the `<debug>` element to "1" in your config file, or pass it as a command-line argument:

```bash
/opt/mirrorbot/bin/mirrorbotd.pl --debug 1
```

## Copyright and Legal

MirrorBot is copyright (c) 2011 - 2014 by Joseph Huckaby and PixlCore.com.  It is released under the MIT License (see below).

SimpleBot relies on the following non-core Perl modules, which are automatically installed, along with their prerequisites, using [cpanm](http://cpanmin.us):

* POE
* Bot::BasicBot
* URI::Escape
* HTTP::Date

### MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
