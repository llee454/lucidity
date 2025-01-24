#!/bin/bash
#
# This file illustrates the absolute simplest backend that returns data from a
# database backend in JSON.
#
# Example Usage:
#
# View Plants:
# env QUERY_STRING='q=plants' ./cgi-bin/database.sh
#
# Create plant:
# echo -e '{"botanical_name": "test_bot", "common_name": "test"}\n' | env REQUEST_METHOD='POST' CONTENT_LENGTH=55 QUERY_STRING='q=create-plant' ./cgi-bin/database.sh

root_dir='./'
source "${root_dir}cgi-bin/common.sh"

get_url_path path

session=$(get_session_cookie)

post=$(get_post_body)

params=$(get_config_params "$config" "$session" "$post")

request="${path[0]}"

case $(get_request_op "$request" "$params") in
  create_account)
    user_name=$(get_config_param '.user_name' "$post")
    password=$(get_config_param '.password' "$post")
    register "$user_name" "$password"
    http_respond
    query=$(get_request_query "$request" "$params")
    sqlite3 "$database" "$query"
    ;;
  create_session)
    user_name=$(get_config_param '.user_name' "$post")
    password=$(get_config_param '.password' "$post")
    login "$user_name" "$password"
    http_respond
    ;;
  select)
    check_perms "$request" "$session" "$params"
    http_respond
    query=$(get_request_query "$request" "$params")
    response=$(sqlite3 "$database" "$query" | sed 's/\\\\n/\\n/g' -)
    if [[ -z "$response" ]]
    then
      response='{"no_results": true}'
    fi
    echo "$response"
    ;;
  # Example configuration file:
  # 
  # example:
  #   op: execute
  #   query: |
  #     SELECT '{{expr:pi}}'
  #   create_file:
  #     name: test.png
  #     dir: uploads
  #     content: |
  #       {{data:root.file-content}}
  #   delete_file:
  #     name: test.png
  #     dir: uploads
  execute)
    check_perms "$request" "$session" "$params"
    http_respond
    query=$(get_request_query "$request" "$params")
    echo "post: $post" 1>&2
    echo "query: $query" 1>&2
    exec_delete_file "$request" "$params"
    exec_create_file "$request" "$params"
    sqlite3 "$database" "$query" | sed 's/\\\\n/\\n/g' -
    ;;
  insert)
    check_perms "$request" "$session" "$params"
    http_respond
    exec_insert_request "$database" "$request" "$params" "$post"
    ;;
  upsert)
    check_perms "$request" "$session" "$params"
    http_respond
    exec_update_request "$database" "$request" "$params" "$post"
    ;;
  *)
    http_respond
    echo '{"error": "invalid request code"}'
    exit 1;;
esac
