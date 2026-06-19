#!/bin/bash

# Panteao BDI Shell SDK

panteao_connect() {
    local host="$1"
    local port="$2"
    # Open read/write file descriptor 3 to the TCP socket
    exec 3<>/dev/tcp/"$host"/"$port"
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
            local action_id=$(echo "$line" | grep -oP '"id":"\K[^"]+')
            local raw_action=$(echo "$line" | grep -oP '"action":"\K[^"]+')

            if [[ "$raw_action" == *"("* ]]; then
                local action_name="${raw_action%%(*}"
                local args_str="${raw_action#*(}"
                args_str="${args_str%)}"
                IFS=',' read -r -a args_array <<< "$args_str"
                local clean_args=()
                for arg in "${args_array[@]}"; do
                    arg=$(echo "$arg" | xargs | tr -d '"')
                    clean_args+=("$arg")
                done
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

panteao_close() {
    exec 3>&-
    exec 3<&-
}
