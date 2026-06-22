#!/bin/bash

# Panteao BDI Shell SDK

get_free_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()' 2>/dev/null || \
    python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()' 2>/dev/null || \
    echo 44444
}

find_binary() {
    local bin_name="panteao-engine"
    if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        bin_name="panteao-engine.exe"
    fi
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$script_dir/$bin_name" ]; then
        echo "$script_dir/$bin_name"
    elif [ -f "$script_dir/bin/$bin_name" ]; then
        echo "$script_dir/bin/$bin_name"
    elif [ -f "./$bin_name" ]; then
        echo "$(pwd)/$bin_name"
    elif [ -f "./bin/$bin_name" ]; then
        echo "$(pwd)/bin/$bin_name"
    else
        echo "$bin_name"
    fi
}

panteao_connect() {
    local host="$1"
    local port="${2:-0}"
    local project="$3"

    if [ -n "$project" ]; then
        if [ "$port" -eq 0 ]; then
            port=$(get_free_port)
        fi
        local bin=$(find_binary)
        $bin "$project" --port "$port" >/dev/null 2>&1 &
        panteao_pid=$!
        sleep 0.8
    elif [ "$port" -eq 0 ]; then
        port=44444
    fi

    exec 3<>/dev/tcp/"$host"/"$port"

    local line
    while read -t 5 -u 3 line; do
        if [[ "$line" == *"\"type\":\"mas_ready\""* ]]; then
            break
        fi
    done
}

panteao_send_msg() {
    local perf="$1"
    local sender="$2"
    local receiver="$3"
    local content="$4"
    echo "{\"type\":\"message\",\"performative\":\"$perf\",\"sender\":\"$sender\",\"receiver\":\"$receiver\",\"content\":\"$content\"}" >&3
}

panteao_send_perception() {
    local action="$1"
    local perception="$2"
    echo "{\"type\":\"perception\",\"action\":\"$action\",\"perception\":\"$perception\"}" >&3
}

panteao_send_action_result() {
    local action_id="$1"
    local success="$2"
    echo "{\"type\":\"action_result\",\"id\":\"$action_id\",\"success\":$success}" >&3
}

panteao_register_action() {
    local action_name="$1"
    local callback_cmd="$2"
    eval "panteao_handler_${action_name}=\"${callback_cmd}\""
}

panteao_process_actions() {
    local timeout="${1:-5}"
    while read -t "$timeout" -u 3 line; do
        line=$(echo "$line" | tr -d '\r\n')
        [ -z "$line" ] && continue

        if [[ "$line" == *"\"type\":\"action\""* ]]; then
            local action_id=$(echo "$line" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
            local raw_action=$(echo "$line" | sed -n 's/.*"action":"\([^"]*\)".*/\1/p')

            if [[ "$raw_action" == *"("* ]]; then
                local action_name="${raw_action%%(*}"
                local args_str="${raw_action#*(}"
                args_str="${args_str%)}"
                
                # Robust nested parser in Bash
                local clean_args=()
                local inside_quotes=0
                local depth_brackets=0
                local depth_parens=0
                local current=""
                
                for (( i=0; i<${#args_str}; i++ )); do
                    local c="${args_str:$i:1}"
                    if [[ "$c" == '"' ]]; then
                        if (( inside_quotes == 0 )); then inside_quotes=1; else inside_quotes=0; fi
                        current+="$c"
                    elif (( inside_quotes == 0 )) && [[ "$c" == '[' ]]; then
                        (( depth_brackets++ ))
                        current+="$c"
                    elif (( inside_quotes == 0 )) && [[ "$c" == ']' ]]; then
                        (( depth_brackets-- ))
                        current+="$c"
                    elif (( inside_quotes == 0 )) && [[ "$c" == '(' ]]; then
                        (( depth_parens++ ))
                        current+="$c"
                    elif (( inside_quotes == 0 )) && [[ "$c" == ')' ]]; then
                        (( depth_parens-- ))
                        current+="$c"
                    elif [[ "$c" == ',' ]] && (( inside_quotes == 0 )) && (( depth_brackets == 0 )) && (( depth_parens == 0 )); then
                        clean_args+=("$(panteao_clean_arg "$current")")
                        current=""
                    else
                        current+="$c"
                    fi
                done
                if [ -n "$current" ]; then
                    clean_args+=("$(panteao_clean_arg "$current")")
                fi
            else
                local action_name="$raw_action"
                local clean_args=()
            fi

            local handler_var="panteao_handler_${action_name}"
            local handler="${!handler_var}"
            if [ -n "$handler" ]; then
                $handler "${clean_args[@]}" "$action_id"
            else
                panteao_send_action_result "$action_id" "true"
            fi
        fi
    done
}

panteao_clean_arg() {
    local s=$(echo "$1" | xargs)
    if [[ "$s" == \"*\" ]] && (( ${#s} >= 2 )); then
        s="${s%\"}"
        s="${s#\"}"
    fi
    echo "$s"
}

panteao_close() {
    exec 3>&-
    exec 3<&-
    if [ -n "$panteao_pid" ]; then
        kill -9 "$panteao_pid" >/dev/null 2>&1 || true
        wait "$panteao_pid" >/dev/null 2>&1 || true
        unset panteao_pid
    fi
}
