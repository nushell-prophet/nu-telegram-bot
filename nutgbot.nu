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
            let $path = nutgb-path $bot_name results
                | path join $'($i.update_id).json'

            if not ($path  | path exists) {
                $i | reject update_id | save $path
            }
        }
    }
}

def parse-updates [] {
    get message.chat -i | compact
    | upsert name {|i| $i.username? | default $i.title?}
    | select id name type
}

export def get-chats [
    bot_name: string@nu-complete-bots
    --update
] {
    glob (nutgb-path $bot_name results | path join '*.json')
    | each {open}
    | if $update or ($in | is-empty) {
        append (get-updates $bot_name)
    } else {}
    | parse-updates
    | uniq-by id
}

def nutgb-path [
    ...folders: string # folders to append
    --auth
] {
    $env.nutgb-path?
    | default (
        $env.XDG_CONFIG_HOME? | if ($in != null) {
            path join 'nutgb'
        } else {
            '~' | path join '.nutgb'
        }
    )
    | path expand
    | if $folders == [] {} else {
        path join ...$folders
    }
    | if ($in | path exists) {} else {
        let $p = $in
        mkdir $p
        $p
    }
    | if $auth {
        path join 'bots-auth.yaml'
    } else {}
}

def nu-complete-bots [] {
    open ( nutgb-path --auth ) | columns
}

def auth-token [
    bot_name: string@nu-complete-bots
]: nothing -> string {
    open ( nutgb-path --auth )
    | get $bot_name
    | get token
}

export def send-message [
    text?: string
    --bot_name: string@nu-complete-bots
    --chat_id: string
    --parse_mode: string@nu-complete-parse-modes = ''
    --disable_notification
] {
    let $input = $in | default $text

    {
        "chat_id": $chat_id,
        "text": $input,
        "disable_notification": $disable_notification
    }
    | if $parse_mode != '' {
        insert parse_mode $parse_mode
    } else {}
    | http post --content-type application/json ( tg-url $bot_name 'sendMessage' ) $in
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

        nutgb-path --auth
        | if ($in | path exists) {
            open
        } else {{}}
        | merge {$botname: {token: $token}}
        | save -f (nutgb-path --auth)

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
