# add a Telegram bot using the provided token and optionally return bot information
export def add-bot [
    bot_token: string # the bot token provided by Telegram's Botfather https://t.me/botfather
    --return_info # if set, returns bot information instead of saving it
    --default # make this bot default for sending messages from
] {
    http get $'https://api.telegram.org/bot($bot_token)/getMe'
    | if $return_info {
        return $in
    } else {
        let $bot_name = get result.username

        authentification --return_path
        | if ($in | path exists) {
            open
        } else {{}}
        # we use this construct to preseve other fields like `default`
        | upsert ([$bot_name token] | into cell-path) $bot_token
        | save -f (authentification --return_path)

        if $default {
            bot-set-default $bot_name
        }

        { botaname: $bot_name status: 'was added'}
        | if $default {
            insert default true
        } else {}
    }
}

# send a text message to a recipient via a bot
export def send-message [
    message_text?: string # the message text to be sent
    --silent_notification # if set, disables notification for the recipient
    --text_format: string@nu-complete-parse-modes = '' # the mode for parsing the message - 'MarkdownV2', 'Markdown', 'HTML'
    --recipient_id: string@nu-complete-recipients # the recipient of the message
    --reply_to_id: string = '' # the message ID to reply to
    --suppress_output # don't output send details
] {
    let $final_message_text = $in | default $message_text

    let $chat_bot = $recipient_id | split row '@'

    {}
    | add-param chat_id $chat_bot.0
    | add-param text $final_message_text
    | add-param disable_notification $silent_notification
    | add-param parse_mode $text_format
    | add-param reply_to_message_id $reply_to_id
    | http post --content-type application/json ( tg-url $chat_bot.1 'sendMessage' ) $in
    | if $in.ok {
        tee {
            let $sent_message = get result.0

            $sent_message
            | save (
                nutgb-path $chat_bot.1 sent_messages --file $'($sent_message.message_id).json'
            )
        }
    } else {}
    | if $suppress_output {null} else {}
}

# send an image or animation file to a recipient via a bot
export def send-image [
    media_path?: path # the path to the image or animation file to be sent
    --recipient_id: string@nu-complete-recipients # the recipient of the message
    --text_format: string@nu-complete-parse-modes = '' # the mode for parsing the message caption
    --media_caption: string = '' # the caption for the image or animation
    --reply_to_id: string = '' # the message ID to reply to
    --silent_notification # if set, disables notification for the recipient
    --suppress_output # don't output send details
] {
    let $final_media_path = $in | default $media_path

    if not ($final_media_path | path exists) {
        error make {msg: $'There is no ($final_media_path) file'}
    }

    let $chat_bot = $recipient_id | split row '@'

    let $request_params = add-param chat_id $chat_bot.0
        | add-param disable_notification ($silent_notification | into string)
        | add-param parse_mode $text_format
        | add-param caption $media_caption
        | add-param reply_to_message_id $reply_to_id

    let $api_method = if ($final_media_path | path parse | get extension) in ['gif' 'mp4'] {
            ['sendAnimation' 'animation']
        } else {
            ['sendPhoto' 'photo']
        }

    curl (tg-url $chat_bot.1 $api_method.0 $request_params) -H 'Content-Type: multipart/form-data' -F $'($api_method.1)=@($final_media_path)' -s
    | from json
    | if $in.ok {
        tee {
            let $sent_message = get result.0

            $sent_message
            | save (
                nutgb-path $chat_bot.1 sent_messages --file $'($sent_message.message_id).json'
            )
        }
    } else {}
    | if $suppress_output {null} else {}
}

# retrieve messages sent to a bot by users in last hours and save them locally
export def get-updates [
    bot_name: string@nu-complete-bots # the name of the bot to retrieve updates for
] {
    http get (tg-url $bot_name getUpdates)
    | get result
    | tee {
        each {|update|
            let $update_path = nutgb-path $bot_name updates --file $'($update.update_id).json'

            if not ($update_path  | path exists) {
                $update | reject update_id | save $update_path
            }
        }
    }
}

# parse messages from updates to extract chat information
def parse-messages [] {
    get message.chat -i
    | compact
    | upsert name {|chat| $chat.username? | default $chat.title?}
    | select id name type
}

# get a list of recipients for a bot, optionally updating the list
export def get-recipients [
    bot_name?: string@nu-complete-bots # the name of the bot to retrieve recipients for
    --refresh_chat_list # if set, updates the recipient list by making a request
    --set-default # set default recipient to omit setting in other commands
] {
    $bot_name
    | if $in == null {
        nu-complete-bots
    } else {
        [$in]
    }
    | each {
        get-recipient $in --refresh_chat_list=$refresh_chat_list
    }
    | flatten
    | if $set_default {
        get id
        | input list
        | recipient-set-default $in
    } else {}
}

# get recipient details for a bot, optionally updating the chat list
def get-recipient [
    bot_name: string@nu-complete-bots # the name of the bot to retrieve recipient details for
    --refresh_chat_list # if set, updates the chat list by making a request
] {
    open-updates $bot_name
    | if $refresh_chat_list or ($in | is-empty) {
        append (get-updates $bot_name)
    } else {}
    | parse-messages
    | update id {|chat| $'($chat.id)@($bot_name)@($chat.name)'}
    | uniq-by id
}

# open locally saved updates for a bot
export def open-updates [
    bot_name: string@nu-complete-bots # the name of the bot to open updates for
] {
    open ...(glob (nutgb-path $bot_name updates --file '*.json'))
}

# construct a file path within the nutgb directory, optionally ensuring folders exist
def nutgb-path [
    ...rest: string # folders to append
    --file: string = '' # the file name to append
] {
    $env.nutgb-path?
    | if $in == null {
        $env.XDG_CONFIG_HOME?
        | if $in != null {
            path join 'nutgb'
        } else {
            $nu.home-path | path join '.nutgb'
        }
    } else {}
    | path join ...$rest
    | if not ($in | path exists) {
        $'(mkdir $in)($in)'
    } else { }
    | path join $file
}

# manage the path and opening of the bot authentication file
def authentification [
    --return_path # if set, returns the path of the authentication file instead of opening it
] {
    nutgb-path --file 'bots-auth.yaml'
    | if $return_path {} else {
        open
    }
}

# retrieve the authentication token for a bot
def auth-token [
    bot_name: string@nu-complete-bots # the name of the bot to retrieve the token for
]: nothing -> string {
    authentification
    | get $bot_name
    | get token
}

# list all bots available for completion
def nu-complete-bots [] {
    authentification | columns
}

# list available parse modes for message formatting
def nu-complete-parse-modes [] {
    [
        'MarkdownV2'
        'Markdown'
        'HTML'
    ]
}

# list available recipients for message sending
def nu-complete-recipients [] {
    get-recipients
    | each {
        {value: $in.id, description: ($in | reject id | to nuon)}
    }
}

# construct a Telegram API URL for a bot and method, optionally including parameters
def tg-url [
    bot_name # the name of the bot to construct the URL for
    method # the method to call on the bot
    params: record = {} # optional parameters to include in the URL
] {
    {
        scheme: 'https'
        host: 'api.telegram.org'
        path: $'bot(auth-token $bot_name)/($method)'
    }
    | if ($params | is-empty) {} else {
        insert params $params
    }
    | url join
}

# add a parameter to a record if the value is not empty
def add-param [
    name: string # the name of the parameter to add
    value: any # the value of the parameter to add
] {
    default {}
    | if $value != '' {
        insert $name $value
    } else {}
}


def bot-set-default [
    name: string
] {
    $name | save (nutgb-path --file default_bot.txt) -f
}

def recipient-set-default [
    name: string
] {
    $name | save (nutgb-path --file default_recipient.txt) -f
}

def bot-get-default [
    name: string
] {
    nutgb-path --file default_bot.txt
    | if ($in | path exists) {open} else {
        print 'there is no default bot set.'
    }
}

def recipient-get-default [] {
    nutgb-path --file default_recipient.txt
    | if ($in | path exists) {open} else {
        print 'there is no default recipient set. Use `nutgb get-recipients --set default`'
    }
}
