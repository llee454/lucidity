#!/bin/bash

root_dir='./'

# standard file paths.
config="${root_dir}database_queries.yml"
database="${root_dir}database/database.sqlite"

function hash_password() {
  local password="$1"
  echo "$password" | sha1sum - | cut -d' ' -f1
}

function gen_session_key() {
  hash_password "$RANDOM"
}

# Example: parse_query path; echo ${path[1]}
#
# Accepts one argument: path, a Bash variable; parses the
# QUERY_STRING environment variable and returns the path components
# as a Bash array in path.
function get_url_path() {
  local -n _path=$1

  local OIFS=$IFS
  IFS='&'
  local -a params
  read -a params <<< "$QUERY_STRING"
  IFS='='
  local -a param
  read -a param <<< "$params"
  if [ "${param[0]}" != 'q' ]
  then
    echo '{"error": "Error: the 'q' argument is missing."}'
    exit 1
  fi 
  IFS='/'
  read -a _path <<< "${param[1]}"
  IFS=$OIFS
}

# Parses the HTTP_COOKIE environment variable; and returns the session key.
function get_session_cookie() {
  local -a cookies
  IFS=';'; read -a cookies <<< "$HTTP_COOKIE"; IFS=$OIFS
  for cookie in "${cookies[@]}"
  do
    local -a cookie_name_value
    IFS='='; read -a cookie_name_value <<< "$cookie"; IFS=$OIFS
    if [ "${cookie_name_value[0]}" == 'session' ]
    then
      session_key="${cookie_name_value[1]}"
    fi
  done
  echo "$session_key"
}

# Reads the POST request body and returns it.
function get_post_body() {
  local post
  [ -z "$post" -a "$REQUEST_METHOD" = "POST" -a ! -z "$CONTENT_LENGTH" ] && read -t 10 -n $CONTENT_LENGTH post
  # read -t1 post 
  echo "$post"
}

# Accepts one argument: post, the POST request body; and returns
# the configuration arguments JSON object.
function get_config_args() {
  local session="$1"
  local post="$2"
  local -a path
  get_url_path path
  echo '{"session": "'"$session"'", "1": "'"${path[1]}"'", "2": "'"${path[2]}"'", "3": "'"${path[3]}"'"}'"$post" | jq -s add
}

# Accepts two arguments: config, a YAML configuration file containing
# Amina variables; and post, the POST request body; substitutes
# the configuration argument values for the Amina variables;
# and returns the resulting YAML file content.
function get_config_params() {
  local config_file="$1"
  local session="$2"
  local post="$3"
  local args=$(get_config_args "$session" "$post")
  echo "$args" | amina --warn --template="$config_file" --init="${root_dir}cgi-bin/init.scm"
}

# Accepts two arguments: path, a YAML path string; and params,
# a YAML string; and returns the value in params referenced by path.
function get_config_param() {
  local path="$1"
  local params="$2"
  echo "$params" | yq 'eval' "$path" -
}

# Accepts two arguments: path, a YAML path string; and params,
# a YAML string; and returns 1 iff the value referenced by path
# exists and 0 otherwise.
# Note: this function is intended to be used in if..then blocks.
function config_param_exists() {
  local path="$1"
  local params="$2"
  local param=$(get_config_param "$path" "$params")
  [[ "$param" != 'null' ]]
}

# Accepts two arguments: path, a YAML path string; and params,
# a YAML string; and returns 1 iff the value referenced by path
# is false and 0 otherwise.
# Note: this function is intended to be used in if..then blocks.
function config_param_false() {
  local path="$1"
  local params="$2"
  local param=$(get_config_param "$path" "$params")
  [[ "$param" == 'false' ]]
}

# Outputs the standard HTTP headers after all other headers (such
# as Set-Cookie) have been sent, and before the response body has
# been sent.
function http_respond() {
  echo "Content-type: text/plain"
  echo ""
}

function get_request_op() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.op" "$params"
}

function get_request_query() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.query" "$params"
}

function get_request_table() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.table" "$params"
}

function get_request_pk() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.primary_key" "$params"
}

function get_request_resource() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.resource" "$params"
}

function get_request_perm() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.permission" "$params"
}

function request_create_file_exists() {
  local request="$1"
  local params="$2"
  config_param_exists ".$request.create_file" "$params"
}

function get_request_create_file_name() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.create_file.name" "$params"
}

function get_request_create_file_dir() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.create_file.dir" "$params"
}

function get_request_create_file_content() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.create_file.content" "$params"
}

function request_delete_file_exists() {
  local request="$1"
  local params="$2"
  config_param_exists ".$request.delete_file" "$params"
}

function get_request_delete_file_name() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.delete_file.name" "$params"
}

function get_request_delete_file_dir() {
  local request="$1"
  local params="$2"
  get_config_param ".$request.delete_file.dir" "$params"
}

# Accepts three arguments: table, the name of a table in the database;
# and json, a JSON string that represents a row in table; and inserts
# the row into the database.
function insert() {
  local db="$1"
  local table="$2"
  local json="$3"
  echo "$json" | sqlite-utils 'insert' "$db" "$table" -
}

# Accepts three arguments: table, the name of a table in db; json, a
# JSON string that represents a row in table; and primary_key, the name
# of the primary key; and updates or inserts the row into the database.
function update() {
  local db="$1"
  local table="$2"
  local primary_key="$3"
  local json="$4"
  echo "json: $json"
  echo "$json" | sqlite-utils 'upsert' --pk="$primary_key" "$db" "$table" -
}

# Accepts two arguments: file_path, a local file path; and
# file_content, base64 encoded content; and creates a file with the
# given name and decoded content.
function create_file() {
  local file_path="$1"
  local file_content="$2"
  echo "$file_content" | base64 --decode - > "$file_path"
}

function exec_insert_request() {
  local db="$1"
  local request="$2"
  local params="$3"
  local json="$4"
  local table=$(get_request_table "$request" "$params")
  insert "$db" "$table" "$json"
}

function exec_update_request() {
  local db="$1"
  local request="$2"
  local params="$3"
  local json="$4"
  local table=$(get_request_table "$request" "$params")
  local primary_key=$(get_request_pk "$request" "$params")
  update "$db" "$table" "$primary_key" "$json"
}

# Accepts one argument: filename, a string that represents a file
# name; and removes those characters that could be used to jump into
# other file directories or embed BASH code.
function clean_file_name() {
  local file_name="$1"
  echo "$file_name" | tr --delete '/'
}

# Accepts two arguments: request, a request code; and params,
# the current configuration parameters. If the current request's
# configuration parameters tells us to create a file, this function
# reads the filename and content, checks that the file name does
# not already exist, and creates a new file using the name and
# content.
#
# Note: that the content must be base64 encoded.
# Note: if the file name contains characters such /, this function
# will throw an error.
function exec_create_file() {
  local request="$1"
  local params="$2"
  if request_create_file_exists "$request" "$params"
  then
    local file_dir=$(get_request_create_file_dir "$request" "$params")

    local file_name=$(get_request_create_file_name "$request" "$params")
    local safe_file_name=$(clean_file_name "$file_name")
    if [[ "$file_name" != "$safe_file_name" ]]
    then
      echo '{"error": "Error: an error occured while trying to create a file. The file name contains invalid characters."}'
      exit 1
    fi

    local file_path="${file_dir}/${file_name}"
    local file_content=$(get_request_create_file_content "$request" "$params")
    if [ -e "$file_path" ]
    then
      echo '{"error": "Error: an error occured while trying to create a file. The file already exists."}'
      exit 1
    fi
    create_file "$file_path" "$file_content"
  fi
}

# Accepts two arguments: request, a request code; and params,
# the current configuration parameters. If the current request's
# configuration parameters tells us to delete a file, this function
# deletes the named file.
function exec_delete_file() {
  local request="$1"
  local params="$2"
  if request_delete_file_exists "$request" "$params"
  then
    local file_dir=$(get_request_delete_file_dir "$request" "$params")
    local file_name=$(get_request_delete_file_name "$request" "$params")
    local safe_file_name=$(clean_file_name "$file_name")
    if [[ "$file_name" != "$safe_file_name" ]]
    then
      echo '{"error": "Error: an error occured while trying to delete a file. The file name contains invalid characters."}'
      exit 1
    fi
    local file_path="${file_dir}/${file_name}"
    rm -f "$file_path"
  fi
}

# Accepts three arguments: request, an request code; session,
# the current session key; and params, the current configuration
# parameters; checks whether or not the current session has permission
# to perform the given request on the current resource. If not
# return an error message and exit immediately.
#
# Note: params is expected to follow the site configuration scheme.
function check_perms() {
  local request="$1"
  local session="$2"
  local params="$3"

  local perm=$(get_request_perm "$request" "$params")
  if [ "$perm" != 'null' ]
  then
    if [ -z "$session" ]
    then
      http_respond
      echo '{"log_in": true}'
      exit 0
    fi
    local resource=$(get_request_resource "$request" "$params")
    if [ "$resource" == 'null' ]
    then
      resource='IS NULL'
    else
      resource="= '$resource'"
    fi
    read -r -d '' query <<EOF
SELECT
  JSON_OBJECT (
    'has_permission', EXISTS (
      SELECT true
      FROM permissions AS p
      INNER JOIN group_account AS ga ON ga.grp = p.grp
      INNER JOIN sessions AS s ON s.account = ga.account
      WHERE
        s.key = '$session'
        AND p.operation = '$perm'
        AND p.resource $resource
    ),
    'has_session', EXISTS (
      SELECT true
      FROM sessions AS s
      WHERE s.key = '$session'
    )
  );
EOF
    perms=$(sqlite3 "$database" "$query")
    if [[ $(get_config_param '.has_session' "$perms") == '0' ]]
    then
      http_respond
      echo '{"log_in": true}'
      exit 0
    fi
    if [[ $(get_config_param '.has_permission' "$perms") == '0' ]]
    then
      http_respond
      echo '{"access_denied": true}'
      exit 0
    fi
  fi
}

# Accepts two arguments: user_name, a user name string; and password,
# a password string; and creates an account with the given user name
# and password. If the user name is already taken, it returns an
# error and immediately returns.
function register() {
  user_name="$1"
  password="$2"
  password_hash=$(hash_password $password)
  account_id=$(sqlite3 "$database" "SELECT id FROM accounts WHERE name = '$user_name';")
  if [ -z "$account_id" ]
  then
    json='{"name": "'"$user_name"'", "password_hash": "'"$password_hash"'"}'
    insert "$database" 'accounts' "$json"
  else
    http_respond
    echo '{"invalid_user_name": true}'
    exit 0
  fi
}

# Accepts two arguments: user_name, a user name string; and password,
# a password string; and creates a session for the account that has
# the given user name. If the password is incorrect, this function
# returns an error message and exits immediately. If the password is
# correct, this function emits the Set-Cookie header to set the
# session cookie.
function login() {
  user_name="$1"
  password="$2"
  password_hash=$(hash_password "$password")
  correct_password_hash=$(sqlite3 "$database" "SELECT password_hash FROM accounts WHERE name = '$user_name';")
  if [ "$password_hash" == "$correct_password_hash" ]
  then
    account=$(sqlite3 "$database" "SELECT id FROM accounts WHERE name = '$user_name';")
    session_key=$(gen_session_key)
    json='{"account": "'"$account"'", "key": "'"$session_key"'"}'
    insert "$database" 'sessions' "$json"
    echo "Set-Cookie: session=$session_key"
  else
    http_respond
    echo '{"invalid_password": true}'
    exit 0
  fi
}
