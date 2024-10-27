#! /bin/bash

USER_HOME_DIR="$HOME"
DATAROOM_KEY_DIR="${USER_HOME_DIR}/.dracoon_wormhole"

check_access_token(){
  mkdir -p $DATAROOM_KEY_DIR && chmod 700 $DATAROOM_KEY_DIR
  if [ -f ${DATAROOM_KEY_DIR}/.${DRACOON_DOMAIN}.access_token ]; then
    source ${DATAROOM_KEY_DIR}/.${DRACOON_DOMAIN}.access_token
    if [ $(date +"%s") -gt $(($EXPIRES_IN + 3600)) ]; then
      login
    fi
  else
    login
  fi
}

login(){
  # input: - , output: ACCESS_TOKEN
  read -p 'username: ' USERNAME
  read -sp 'password: ' USER_PASSWORD
  echo ""

  local HTTP_RESPONSE=$(curl -s -XPOST -u dracoon_legacy_scripting: -d 'grant_type=password' -d "username=${USERNAME}" --data-urlencode "password=${USER_PASSWORD}" "https://${DRACOON_DOMAIN}/oauth/token" -w '&%{http_code}')

  unset USER_PASSWORD

  if [ ${HTTP_RESPONSE##*&} -eq 200 ] ; then
    ACCESS_TOKEN=$(echo ${HTTP_RESPONSE%&*} | jq -r '.access_token')
    local EXPIRES_IN=$(echo ${HTTP_RESPONSE%&*} | jq -r '.expires_in')
    echo "ACCESS_TOKEN=${ACCESS_TOKEN}" > "${DATAROOM_KEY_DIR}/.${DRACOON_DOMAIN}.access_token"
    echo "EXPIRES_IN=$(($(date +"%s") + $EXPIRES_IN))" >> "${DATAROOM_KEY_DIR}/.${DRACOON_DOMAIN}.access_token"
    chmod 600 "${DATAROOM_KEY_DIR}/.${DRACOON_DOMAIN}.access_token"
    echo "Login: success"
  else
    echo "Login failed with response code: ${HTTP_RESPONSE%&*}"
    exit 1
  fi
}

get_node_id(){
  # input: DRACOON_DOMAIN, ACCESS_TOKEN, NODE_PATH; output: NODE_ID, NODE_NAME, PARENT_NODE_PATH
  NODE_PATH="/${NODE_PATH#/}" && NODE_PATH=${NODE_PATH%/} # ergänzt links "/" und schneidet rechts "/" falls vorhanden: a/b/ -> /a/b
  NODE_NAME=${NODE_PATH##*/} && NODE_NAME=${NODE_NAME// /%20} # get node name of full node path and replace whitespace with %20
  PARENT_NODE_PATH=${NODE_PATH%/*} && PARENT_NODE_PATH=${PARENT_NODE_PATH// /%20} # get parent node path of full node path replace whitespace with %20

  local HTTP_RESPONSE=$(curl -s -G -X GET "https://${DRACOON_DOMAIN}/api/v4/nodes/search" -d "search_string=${NODE_NAME}" -d "depth_level=-1" -d "filter=parentPath:eq:${PARENT_NODE_PATH}/" -H  "accept: application/json" -H  "Authorization: Bearer ${ACCESS_TOKEN}" -w '&%{http_code}')
  
  if [ ${HTTP_RESPONSE##*&} -eq 200 ] ; then
    NODE_ID=$(echo ${HTTP_RESPONSE%&*} | jq -c ".items" | jq -c '.[]' | jq -c ".id")
    if [ -z "$NODE_ID" ]; then
      echo "ERROR: Node $NODE_PATH not found"
      exit 1
    fi
  else
    echo ${HTTP_RESPONSE%&*}
    exit 1
  fi
}

create_download_url(){
  # input: DRACOON_DOMAIN, ACCESS_TOKEN, NODE_ID; output: ACCESS_KEY
  local HTTP_RESPONSE=$(curl -s -XPOST "https://${DRACOON_DOMAIN}/api/v4/nodes/files/${NODE_ID}/downloads" -H  "accept: application/json" -H  "Content-Type: application/json" -H  "Authorization: Bearer ${ACCESS_TOKEN}" -w '&%{http_code}')

  if [ ${HTTP_RESPONSE##*&} -eq 200 ] ; then
    DOWNLOAD_URL="curl "\'"$(echo ${HTTP_RESPONSE%&*} | jq -r ".downloadUrl")"\'" --output $NODE_NAME"
  else
    echo ${HTTP_RESPONSE%&*}
    exit 1
  fi
}

cmd_usage(){
  cat <<EOF
    Usage:
      dracoon_wormhole downloadurl -D,--domain DRACOON DOMAIN -s,--src SOURCE
        Generate Download curl command for file SOURCE
      dracoon_wormhole send -D,--domain DRACOON DOMAIN -s,--src SOURCE
        Send a Download Url via Magic Wormhole
      dracoon_wormhole receive CODE
        Receive Download Url via Magic Wormhole and use Download Url
      dracoon_wormhole help
        Print this help.
EOF
exit 0
}

cmd_downloadurl(){
  while [[ $# -gt 0 ]]; do
    case $1 in
      -D|--domain) local DRACOON_DOMAIN="$2"; shift 2 ;;
      -s|--src) local SOURCE="$2"; shift 2 ;;
      -h|--help) cmd_usage ;;
      *) echo "Invalid parameter"; cmd_usage ;;
    esac
  done

  [[ -z "$DRACOON_DOMAIN" ]] && echo "Domain cannot be empty." && cmd_usage
  [[ -z "$SOURCE" ]] && echo "Source file cannot be empty." &&  cmd_usage

  local NODE_PATH="$SOURCE"
  check_access_token
  get_node_id
  create_download_share
  create_download_url
  echo "$DOWNLOAD_URL"
}

cmd_send(){
  while [[ $# -gt 0 ]]; do
    case $1 in
      -D|--domain) local DRACOON_DOMAIN="$2"; shift 2 ;;
      -s|--src) local SOURCE="$2"; shift 2 ;;
      -h|--help) cmd_usage ;;
      *) echo "Invalid parameter"; cmd_usage ;;
    esac
  done

  [[ -z "$DRACOON_DOMAIN" ]] && echo "Domain cannot be empty." && cmd_usage
  [[ -z "$SOURCE" ]] && echo "Source file cannot be empty." &&  cmd_usage

  local NODE_PATH="$SOURCE"
  check_access_token
  get_node_id
  create_download_share
  create_download_url
  wormhole send --text "$DOWNLOAD_URL"  2>&1 | sed 's/[w,W]ormhole/dracoon_wormhole/g'
}

cmd_receive(){
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help) cmd_usage ;;
      *) local DOWNLOAD_URL="$(wormhole receive $1)"; shift ;;
    esac
  done

  if [ -n "$DOWNLOAD_URL" ];  then
    eval "$DOWNLOAD_URL"
  fi
}

case $1 in
  downloadurl) shift;       cmd_downloadurl "$@" ;;
  send) shift;              cmd_send "$@" ;;
  receive) shift;           cmd_receive "$@" ;;
  *)                        cmd_usage ;;
esac

exit 0
