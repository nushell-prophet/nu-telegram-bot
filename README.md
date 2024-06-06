# nu-telegram-bot

[![No Maintenance Intended](http://unmaintained.tech/badge.svg)](http://unmaintained.tech/)

A basic Nushell module for interacting with the Telegram Bot API.

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

`nutgb` saves tokens and other files needed for interactions in:
1. If set in `$env.XDG_CONFIG_HOME? | path join 'nutgb'`
2. Otherwise, in `$nu.home-path | path join '.nutgb'`

You are welcome to read the code and make your understanding.
The part about locating needed files is described [here](https://github.com/nushell-prophet/nu-telegram-bot/blob/a4528eef02de23e9faa0054304cce46f35ef584e/nutgb.nu#L167).
