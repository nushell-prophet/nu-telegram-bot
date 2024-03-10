def tg-url [
    bot_name
    method
] {
    auth-token $bot_name
    | $"https://api.telegram.org/bot($in)/($method)"
}


export def get-updates [
    bot_name: string@nu-complete-bots
    --all_data
] {
    http get (tg-url $bot_name getUpdates)
    | get result
    | tee {
        each {|i|
            let $path = nutgb-path --ensure_folders $bot_name results
                | path join $'($i.update_id).json'

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
    glob (nutgb-path $bot_name results --file '*.json')
    | each {open}
    | if $update_chats or ($in | is-empty) {
        append (get-updates $bot_name)
    } else {}
    | parse-messages
    | update id {|i| $'($i.id)@($bot_name)'}
    | uniq-by id
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

def nu-complete-bots [] {
    authentification | columns
}

def auth-token [
    bot_name: string@nu-complete-bots
]: nothing -> string {
    authentification
    | get $bot_name
    | get token
}

export def send-message [
    text?: string
    --recipient: string@nu-complete-recipients
    --parse_mode: string@nu-complete-parse-modes = ''
    --disable_notification
] {
    let $message = $in | default $text

    let $chat_bot = $recipient | split row '@'

    {
        "chat_id": $chat_bot.0,
        "text": $message,
        "disable_notification": $disable_notification
    }
    | if $parse_mode != '' {
        insert parse_mode $parse_mode
    } else {}
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
