# add a Telegram bot using the provided token and optionally return bot information.
export def add-bot [
    token: string
    --info
] {
    http get $'https://api.telegram.org/bot($token)/getMe'
    | if $info {
        return $in
    } else {
        let $botname = get result.username

        authentification --path
        | if ($in | path exists) {
            open
        } else {{}}
        | merge {$botname: {token: $token}}
        | save -f (authentification --path)

        echo $'($botname) was added'
    }
}

# send a text message to a recipient via a bot
export def send-message [
    text?: string
    --disable_user_notification
    --parse_mode: string@nu-complete-parse-modes = ''
    --recipient: string@nu-complete-recipients
    --reply_to_message_id: string = ''
    --quiet # don't ouput send details
] {
    let $message = $in | default $text

    let $chat_bot = $recipient | split row '@'

    {}
    | add-param chat_id $chat_bot.0
    | add-param text $message
    | add-param disable_notification $disable_user_notification
    | add-param parse_mode $parse_mode
    | add-param reply_to_message_id $reply_to_message_id
    | http post --content-type application/json ( tg-url $chat_bot.1 'sendMessage' ) $in
    | if $in.ok {
        tee {
            let $input = get result.0

            $input
            | save (
                nutgb-path --ensure_folders $chat_bot.1 sent_messages --file $'($input.message_id).json'
            )
        }
    } else {}
    | if $quiet {null} else {}
}

# send an image or animation file to a recipient via a bot
export def send-image [
    file_path?: path
    --recipient: string@nu-complete-recipients
    --parse_mode: string@nu-complete-parse-modes = ''
    --caption: string = ''
    --reply_to_message_id: string = ''
    --disable_user_notification
    --quiet # don't ouput send details
] {
    let $message = $in | default $file_path

    if not ($message | path exists) {
        error make {msg: $'There is no ($message) file'}
    }

    let $chat_bot = $recipient | split row '@'

    let $params = add-param chat_id $chat_bot.0
        | add-param disable_notification ($disable_user_notification | into string)
        | add-param parse_mode $parse_mode
        | add-param caption $caption
        | add-param reply_to_message_id $reply_to_message_id

    let $method = if ($message | path parse | get extension) in ['gif' 'mp4'] {
            ['sendAnimation' 'animation']
        } else {
            ['sendPhoto' 'photo']
        }

    curl (tg-url $chat_bot.1 $method.0 $params) -H 'Content-Type: multipart/form-data' -F $'($method.1)=@($message)' -s
    | from json
    | if $in.ok {
        tee {
            let $input = get result.0

            $input
            | save (
                nutgb-path --ensure_folders $chat_bot.1 sent_messages --file $'($input.message_id).json'
            )
        }
    } else {}
    | if $quiet {null} else {}
}

# retrieve messages sent to a bot by users in last hours and save them locally
export def get-updates [
    bot_name: string@nu-complete-bots
    --all_data
] {
    http get (tg-url $bot_name getUpdates)
    | get result
    | tee {
        each {|i|
            let $path = nutgb-path --ensure_folders $bot_name updates --file $'($i.update_id).json'

            if not ($path  | path exists) {
                $i | reject update_id | save $path
            }
        }
    }
}

# parse messages from updates to extract chat information
def parse-messages [] {
    get message.chat -i
    | compact
    | upsert name {|i| $i.username? | default $i.title?}
    | select id name type
}

# get a list of recipients for a bot, optionally updating the list
export def get-recipients [
    bot_name?: string@nu-complete-bots
    --update_chats # make request to update receivers list
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
    bot_name: string@nu-complete-bots
    --update_chats # make request to update receivers list
] {
    open-updates $bot_name
    | if $update_chats or ($in | is-empty) {
        append (get-updates $bot_name)
    } else {}
    | parse-messages
    | update id {|i| $'($i.id)@($bot_name)@($i.name)'}
    | uniq-by id
}

# open locally saved updates for a bot
export def open-updates [
    bot_name: string@nu-complete-bots
] {
    glob (nutgb-path $bot_name updates --file '*.json')
    | each {open}
}

# construct a file path within the nutgb directory, optionally ensuring folders exist
def nutgb-path [
    ...rest: string # folders to append
    --file: string = ''
    --ensure_folders
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
        let $input = $in; mkdir $input; $input
    } else { }
    | path join $file
}

# manage the path and opening of the bot authentication file
def authentification [
    --path
] {
    nutgb-path --file 'bots-auth.yaml'
    | if $path {} else {
        open
    }
}

# retrieve the authentication token for a bot
def auth-token [
    bot_name: string@nu-complete-bots
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
    bot_name
    method
    params: record = {}
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
    name: string
    value: any
] {
    default {}
    | if $value != '' {
        insert $name $value
    } else {}
}
