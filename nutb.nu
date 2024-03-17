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

export def send-message [
    text?: string
    --recipient: string@nu-complete-recipients
    --parse_mode: string@nu-complete-parse-modes = ''
    --disable_notification
] {
    let $message = $in | default $text

    let $chat_bot = $recipient | split row '@'

    {}
    | add-param chat_id $chat_bot.0
    | add-param text $message
    | add-param disable_notification $disable_notification
    | add-param parse_mode $parse_mode
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
}

export def send-photo [
    file_path?: path
    --recipient: string@nu-complete-recipients
    --parse_mode: string@nu-complete-parse-modes = ''
    --caption: string = ''
    --reply_to_message_id: string = ''
    --disable_notification
] {
    let $message = $in | default $file_path

    let $chat_bot = $recipient | split row '@'

    let $params = (
        add-param chat_id $chat_bot.0
        | add-param disable_notification ($disable_notification | into string)
        | add-param parse_mode $parse_mode
        | add-param caption $caption
        | add-param reply_to_message_id $reply_to_message_id
    )

    curl (tg-url $chat_bot.1 'sendPhoto' $params) -H 'Content-Type: multipart/form-data' -F $'photo=@($message)'
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
}

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

def parse-messages [] {
    get message.chat -i
    | compact
    | upsert name {|i| $i.username? | default $i.title?}
    | select id name type
}

export def get-recipients [
    bot_name?: string@nu-complete-bots
    --update_chats
] {
    $bot_name
    | if $in == null {
        nu-complete-bots
    } else {[$in]}
    | each {
        get-recipient $in --update_chats=$update_chats
    }
    | flatten
}

def get-recipient [
    bot_name: string@nu-complete-bots
    --update_chats
] {
    open-updates $bot_name
    | if $update_chats or ($in | is-empty) {
        append (get-updates $bot_name)
    } else {}
    | parse-messages
    | update id {|i| $'($i.id)@($bot_name)'}
    | uniq-by id
}

export def open-updates [
    bot_name: string@nu-complete-bots
] {
    glob (nutgb-path $bot_name updates --file '*.json')
    | each {open}
}

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

def authentification [
    --path
] {
    nutgb-path --file 'bots-auth.yaml'
    | if $path {} else {
        open
    }
}

def auth-token [
    bot_name: string@nu-complete-bots
]: nothing -> string {
    authentification
    | get $bot_name
    | get token
}

def nu-complete-bots [] {
    authentification | columns
}

def nu-complete-parse-modes [] {
    [
        'MarkdownV2'
        'Markdown'
        'HTML'
    ]
}

def nu-complete-recipients [] {
    get-recipients
    | each {
        {value: $in.id, description: ($in | reject id | to nuon)}
    }
}

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

def add-param [
    name: string
    value: any
] {
    default {}
    | if $value != '' {
        insert $name $value
    } else {}
}
