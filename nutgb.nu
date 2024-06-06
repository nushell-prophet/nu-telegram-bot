# add a Telegram bot using the provided token and optionally return bot information
export def add-bot [
    token: string # the bot token provided by Telegram
    --info # if set, returns bot information instead of saving it
] {
    http get $'https://api.telegram.org/bot($token)/getMe'
    | if $info {
        return $in
    } else {
        let $bot_name = get result.username

        authentification --path
        | if ($in | path exists) {
            open
        } else {{}}
        | merge {$bot_name: {token: $token}}
        | save -f (authentification --path)

        echo $'($bot_name) was added'
    }
}

# send a text message to a recipient via a bot
export def send-message [
    text?: string # the message text to be sent
    --disable_user_notification # if set, disables notification for the recipient
    --parse_mode: string@nu-complete-parse-modes = '' # the mode for parsing the message (e.g., Markdown, HTML)
    --recipient: string@nu-complete-recipients # the recipient of the message
    --reply_to_message_id: string = '' # the message ID to reply to
    --quiet # don't output send details
] {
    let $message_text = $in | default $text

    let $chat_bot = $recipient | split row '@'

    {}
    | add-param chat_id $chat_bot.0
    | add-param text $message_text
    | add-param disable_notification $disable_user_notification
    | add-param parse_mode $parse_mode
    | add-param reply_to_message_id $reply_to_message_id
    | http post --content-type application/json ( tg-url $chat_bot.1 'sendMessage' ) $in
    | if $in.ok {
        tee {
            let $sent_message = get result.0

            $sent_message
            | save (
                nutgb-path --ensure_folders $chat_bot.1 sent_messages --file $'($sent_message.message_id).json'
            )
        }
    } else {}
    | if $quiet {null} else {}
}

# send an image or animation file to a recipient via a bot
export def send-image [
    file_path?: path # the path to the image or animation file to be sent
    --recipient: string@nu-complete-recipients # the recipient of the message
    --parse_mode: string@nu-complete-parse-modes = '' # the mode for parsing the message caption
    --caption: string = '' # the caption for the image or animation
    --reply_to_message_id: string = '' # the message ID to reply to
    --disable_user_notification # if set, disables notification for the recipient
    --quiet # don't output send details
] {
    let $file_message = $in | default $file_path

    if not ($file_message | path exists) {
        error make {msg: $'There is no ($file_message) file'}
    }

    let $chat_bot = $recipient | split row '@'

    let $request_params = add-param chat_id $chat_bot.0
        | add-param disable_notification ($disable_user_notification | into string)
        | add-param parse_mode $parse_mode
        | add-param caption $caption
        | add-param reply_to_message_id $reply_to_message_id

    let $api_method = if ($file_message | path parse | get extension) in ['gif' 'mp4'] {
            ['sendAnimation' 'animation']
        } else {
            ['sendPhoto' 'photo']
        }

    curl (tg-url $chat_bot.1 $api_method.0 $request_params) -H 'Content-Type: multipart/form-data' -F $'($api_method.1)=@($file_message)' -s
    | from json
    | if $in.ok {
        tee {
            let $sent_message = get result.0

            $sent_message
            | save (
                nutgb-path --ensure_folders $chat_bot.1 sent_messages --file $'($sent_message.message_id).json'
            )
        }
    } else {}
    | if $quiet {null} else {}
}

# retrieve messages sent to a bot by users in last hours and save them locally
export def get-updates [
    bot_name: string@nu-complete-bots # the name of the bot to retrieve updates for
    --all_data # if set, retrieves all data instead of just the message data
] {
    http get (tg-url $bot_name getUpdates)
    | get result
    | tee {
        each {|update|
            let $update_path = nutgb-path --ensure_folders $bot_name updates --file $'($update.update_id).json'

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
    --update_chats # if set, updates the recipient list by making a request
] {
    $bot_name
    | if $in == null {
        nu-complete-bots
    } else {
        [$in]
    }
    | each {
        get-recipient $in --update_chats=$update_chats
    }
    | flatten
}

# get recipient details for a bot, optionally updating the chat list
def get-recipient [
    bot_name: string@nu-complete-bots # the name of the bot to retrieve recipient details for
    --update_chats # if set, updates the chat list by making a request
] {
    open-updates $bot_name
    | if $update_chats or ($in | is-empty) {
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
    glob (nutgb-path $bot_name updates --file '*.json')
    | each {open}
}

# construct a file path within the nutgb directory, optionally ensuring folders exist
def nutgb-path [
    ...rest: string # folders to append
    --file: string = '' # the file name to append
    --ensure_folders # if set, ensures the folders exist
] {
    $env.nutgb-path?
    | default (
        $env.XDG_CONFIG_HOME?
        | if ($in != null) {
            path join 'nutgb'
        } else {
            $nu.home-path | path join '.nutgb'
        }
    )
    | if $rest == [] {} else {
        path join ...$rest
    }
    | if not ($in | path exists) and $ensure_folders {
        let $constructed_path = $in; mkdir $constructed_path; $constructed_path
    } else { }
    | path join $file
}

# manage the path and opening of the bot authentication file
def authentification [
    --path # if set, returns the path of the authentication file instead of opening it
] {
    nutgb-path --file 'bots-auth.yaml'
    | if $path {} else {
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
