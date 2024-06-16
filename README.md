# nu-telegram-bot

[![No Maintenance Intended](http://unmaintained.tech/badge.svg)](http://unmaintained.tech/)

A basic Nushell module for interacting with the Telegram Bot API.

![nutgb-demo](https://github.com/nushell-prophet/nu-telegram-bot/assets/4896754/ab93a871-54a8-4c5c-99c9-1ae54fce19e2)

# Quick start

1. Clone this repository

```nu no-run
> git clone https://github.com/nushell-prophet/nu-telegram-bot
> cd nu-telegram-bot
> use nutgb.nu
```
2. Obtain the token for your bot from [@botfather](https://t.me/botfather) and add it to `nutgb`

```nu no-run
nutgb add-bot <your-token>
```
3. Send any message to your new bot from the account that will later receive messages from the bot.
(optionally, you can add this bot to the group or channel).

4. Receive updates (sent messages to the bot or events of adding him to groups).
Mind that you can use `tab` auto-completion for the bot's name here.

```nu no-run
nutgb get-updates <bot-name>
```

5. If the previous command gave you some data, it means that now you can send messages using `nutgb send-message`

```nu no-run
nutgb send-message 'some message' --recipient <tab-completed-recipient-name>
```

`nutgb` saves tokens and conversations with users:
1. If `$env.nutgb-path` is set - in that folder.
2. If `$env.XDG_CONFIG_HOME` is set, then in `nutgb` folder inside.
3. Otherwise, in `.nutgb` folder in home `$nu.home-path`.

You are welcome to read the code and make your understanding.
The part about locating needed files is described [here](https://github.com/nushell-prophet/nu-telegram-bot/blob/a4528eef02de23e9faa0054304cce46f35ef584e/nutgb.nu#L167).

# commands help

```nushell
use nutgb.nu
nutgb add-bot -h
```

Output:

```
add a Telegram bot using the provided token and optionally return bot information

Usage:
  > add-bot {flags} <bot_token>

Flags:
  --return_info - if set, returns bot information instead of saving it
  --default - make this bot default for sending messages from
  -h, --help - Display the help message for this command

Parameters:
  bot_token <string>: the bot token provided by Telegram's Botfather https://t.me/botfather
```

```nushell
nutgb get-updates -h
```

Output:

```
retrieve messages sent to a bot by users in last hours and save them locally

Usage:
  > get-updates <bot_name>

Flags:
  -h, --help - Display the help message for this command

Parameters:
  bot_name <string>: the name of the bot to retrieve updates for
```

```nushell
nutgb send-message -h
```

Output:

```
send a text message to a recipient via a bot

Usage:
  > send-message {flags} (message_text)

Flags:
  --silent_notification - if set, disables notification for the recipient
  --text_format <CompleterWrapper(String, 2076)> - the mode for parsing the message - 'MarkdownV2', 'Markdown', 'HTML' (default: '')
  --recipient_id <CompleterWrapper(String, 2077)> - the recipient of the message
  --reply_to_id <String> - the message ID to reply to (default: '')
  --suppress_output - don't output send details
  -h, --help - Display the help message for this command

Parameters:
  message_text <string>: the message text to be sent (optional)
```

```nushell
nutgb send-image -h
```

Output:

```
send an image or animation file to a recipient via a bot

Usage:
  > send-image {flags} (media_path)

Flags:
  --recipient_id <CompleterWrapper(String, 2077)> - the recipient of the message
  --text_format <CompleterWrapper(String, 2076)> - the mode for parsing the message caption (default: '')
  --media_caption <String> - the caption for the image or animation (default: '')
  --reply_to_id <String> - the message ID to reply to (default: '')
  --silent_notification - if set, disables notification for the recipient
  --suppress_output - don't output send details
  -h, --help - Display the help message for this command

Parameters:
  media_path <path>: the path to the image or animation file to be sent (optional)
```

```nushell
nutgb get-recipients -h
```

Output:

```
get a list of recipients for a bot, optionally updating the list

Usage:
  > get-recipients {flags} (bot_name)

Flags:
  --refresh_chat_list - if set, updates the recipient list by making a request
  --set-default - set default recipient to omit setting in other commands
  -h, --help - Display the help message for this command

Parameters:
  bot_name <string>: the name of the bot to retrieve recipients for (optional)
```
