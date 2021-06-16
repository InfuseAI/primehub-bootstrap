#!/bin/bash
# This is an integration test for kcadm.
#
# Test by https://github.com/kward/shunit2

KCADM="./kcadm"

debug() {
  set -x; "$@"; set +x
}

################################################
# shunit2 callbacks
oneTimeSetUp() {
  if [[ -z "$KC_URL"  || -z "$KC_USER"  || -z "$KC_PASSWORD" ]]; then
    echo "Please define KC_URL, KC_USER, KC_PASSWORD "
    exit
  fi
  KC_REALM=${KC_REALM:-kcadm-it}

  # Remove keycloak config
  rm ~/.keycloak/kcadm.config

  # Login
  $KCADM config credentials \
    --server "$KC_URL" \
    --realm master \
    --user "$KC_USER" \
    --password "$KC_PASSWORD"
}

setUp() {
  echo "======================"
  echo -n "> "
}

tearDown() {
  echo
}

################################################
# Test cases
current_config_get() {
  cat ~/.keycloak/kcadm.config | jq -r ".endpoints[\"${KC_URL}\"].master"
}

current_config_set_attr() {
  local attr=$1
  local value=$2
  local config=$(cat ~/.keycloak/kcadm.config)
  echo "$config" | jq -r ".endpoints[\"${KC_URL}\"].master.${attr} = ${value}" > ~/.keycloak/kcadm.config
}

test_login() {
  local last_login=$(cat ~/.keycloak/kcadm.config)
  local access_token=$(current_config_get | jq -r ".token")
  local refresh_token=$(current_config_get | jq -r ".refreshToken")
  local -i expired
  local -i refresh_expired

  # test login
  assertTrue "access token" "[ -n $access_token ]"
  assertTrue "refresh token" "[ -n $refresh_token ]"
  result=$($KCADM get realms | jq -r '.[] | select(.realm == "master") | .realm')
  assertEquals "master" "$result"

  # check token not changed
  local new_token=$(current_config_get | jq -r ".token")
  assertEquals "check token not changed" "$access_token" "$new_token"

  # check token auto refresh
  local now=$(date +%s)
  expired=$((now - 1))
  current_config_set_attr expiresAt $expired
  $KCADM get realms > /dev/null
  new_token=$(current_config_get | jq -r ".token")
  assertNotEquals "check token not changed" "$access_token" "$new_token"

  # check token expired
  expired=$((now - 1))
  refresh_expired=$((now - 1))
  current_config_set_attr expiresAt $expired
  current_config_set_attr refreshExpiresAt $expired
  $KCADM get realms &> /dev/null
  assertNotEquals "ensure token: expried" 0 $?

  # Recover the login state
  echo "$last_login" > ~/.keycloak/kcadm.config
}

test_realm() {
  if $KCADM get "realms/${KC_REALM}" &> /dev/null ; then
    echo "realm ${KC_REALM} found. delete it"
    $KCADM delete "realms/${KC_REALM}"
    assertEquals "delete realm" 0 $?
  fi

  #create realm
  $KCADM create realms \
      -s realm="$KC_REALM" \
      -s enabled=true
  assertEquals "create realm" 0 $?
}

test_kcadm_add_user_and_group() {
  local jsondata
  #create group
  read -r -d '' jsondata <<'EOF'
{
  "name": "phusers",
  "attributes": {
    "canUseGpu": [
      "false"
    ],
    "cpuQuota": [
      "20"
    ],
    "quota-gpu": [
      "0"
    ],
    "displayName": [
      "auto generated by bootstrap"
    ],
    "diskQuota": [
      "20G"
    ],
    "project-quota-gpu": [
      "0"
    ]
  }
}
EOF

  GROUP_PHUSERS_ID=$(echo "${jsondata}" | $KCADM create groups -r $KC_REALM --id -f -)
  assertTrue "create group" "[ -n $GROUP_PHUSERS_ID ]"
  assertEquals "get created group" phusers $($KCADM get -r $KC_REALM groups/${GROUP_PHUSERS_ID} | jq -r .name)

  GROUP_TEAM1_ID=$($KCADM create "groups/${GROUP_PHUSERS_ID}/children" -s name=team1 -r $KC_REALM --id)
  assertTrue "create subgroup" "[ -n $GROUP_TEAM1_ID ]"
  assertEquals "get created subgroup" team1 $($KCADM get -r $KC_REALM groups/${GROUP_TEAM1_ID} | jq -r .name)

  #create user
  USER_PHADMIN_ID=$(
  $KCADM create users \
    -r $KC_REALM \
    -s username=phadmin \
    -s enabled=true \
    -s email=phadmin@primehub.local \
    -s emailVerified=true \
    --id)
  assertTrue "create user" "[ -n $USER_PHADMIN_ID ]"
  assertEquals "get created user" phadmin $($KCADM get -r $KC_REALM users/${USER_PHADMIN_ID} | jq -r .username)

  #set password
  $KCADM 'set-password' \
    -r $KC_REALM \
    --username phadmin \
    --new-password phadmin
  assertEquals "set password" 0 $?
}

test_client() {
  local jsondata
  #create group
  read -r -d '' jsondata \
<<EOF
{
  "clientId": "test",
  "enabled": true,
  "clientAuthenticatorType": "client-secret",
  "redirectUris": [],
  "webOrigins": [],
  "publicClient": false,
  "serviceAccountsEnabled": true,
  "protocol": "openid-connect",
  "fullScopeAllowed": false,
  "redirectUris": [
    "/abcde2",
    "/abcdf2"
  ]
}
EOF

  CLIENT_TEST_ID=$(echo "${jsondata}" | $KCADM create clients -r $KC_REALM -s redirectUris+=/foo --id -f -)
  assertTrue "create client" "[ -n $CLIENT_TEST_ID ]"

  CLIENT_TEST=$($KCADM get -r $KC_REALM clients/${CLIENT_TEST_ID})
  assertEquals "get created client" \
    test \
    $(echo "$CLIENT_TEST" | jq -r .clientId)

  assertEquals "get redirectUris" \
    '/foo' \
    $(echo "$CLIENT_TEST" | jq -r ".redirectUris[] | select( . == \"/foo\")")

  CLIENT_TEST_SECRET=$($KCADM get -r $KC_REALM clients/${CLIENT_TEST_ID}/client-secret | jq -r '.value')
  assertTrue "get client secret" "[ -n $CLIENT_TEST_SECRET ]"

  assertEquals "get service acccount user" \
    service-account-test \
    $($KCADM get -r $KC_REALM clients/${CLIENT_TEST_ID}/service-account-user | jq -r .username)

  CLIENT_REALM_MANGEMENT_ID=$($KCADM get -r $KC_REALM clients -q clientId=realm-management | jq -c '.[]' | head -1 | jq -r '.id')
}

test_role() {
  # create roles
  $KCADM create roles -r $KC_REALM -s name=hello
  $KCADM create roles -r $KC_REALM -s name=world
  assertEquals "create realm role" 0 $?
  assertEquals "create realm role" \
    hello \
    $($KCADM get -r $KC_REALM roles/hello | jq  -r .name)
}

test_role_binding() {
  assertEquals "create realm role" \
    hello \
    $($KCADM get -r $KC_REALM roles/hello | jq  -r .name)

  # add realm role
  $KCADM add-roles \
    -r $KC_REALM \
    --uusername phadmin \
    --rolename hello \
    --rolename world
  assertEquals "add roles" 0 $?
  assertEquals "add roles" \
    'hello' \
    $($KCADM get-roles -r $KC_REALM --uid $USER_PHADMIN_ID | jq -r '.[] | select( .name == "hello") | .name')

  # add realm role to group name
  $KCADM add-roles \
    -r $KC_REALM \
    --gname phusers \
    --rolename hello
  assertEquals "add roles" 0 $?
  assertEquals "add roles" \
    'hello' \
    $($KCADM get-roles -r $KC_REALM --gid $GROUP_PHUSERS_ID | jq -r '.[] | select( .name == "hello") | .name')

  # add realm role to group path
  $KCADM add-roles \
    -r $KC_REALM \
    --gpath '/phusers/team1' \
    --rolename world
  assertEquals "add roles" 0 $?
  assertEquals "add roles" \
    'world' \
    $($KCADM get-roles -r $KC_REALM --gid $GROUP_TEAM1_ID | jq -r '.[] | select( .name == "world") | .name')

  # add client role
  $KCADM add-roles \
    -r $KC_REALM \
    --uusername phadmin \
    --cclientid realm-management \
    --rolename realm-admin
  assertEquals "add client roles" 0 $?
  $KCADM get-roles -r $KC_REALM --uid $USER_PHADMIN_ID --cid $CLIENT_REALM_MANGEMENT_ID | jq -r '.[] | select( .name == "realm-admin") | .name'
  assertEquals "add client roles" \
    'realm-admin' \
    $($KCADM get-roles -r $KC_REALM --uid $USER_PHADMIN_ID --cid $CLIENT_REALM_MANGEMENT_ID | jq -r '.[] | select( .name == "realm-admin") | .name')


  # add client role to service account
  $KCADM add-roles \
    -r $KC_REALM \
    --uusername service-account-test \
    --cclientid realm-management \
    --rolename realm-admin
  assertEquals "add client roles to service account" 0 $?
  assertEquals "add client roles to service account" \
    'realm-admin' \
    $($KCADM get-roles -r $KC_REALM --uusername service-account-test --cid $CLIENT_REALM_MANGEMENT_ID | jq -r '.[] | select( .name == "realm-admin") | .name')
}

test_member() {

  $KCADM add-members -r "$KC_REALM" --uusername phadmin --gname phusers
  assertEquals "add member" 0 $?
  assertEquals "add member result" \
    1 \
    "$($KCADM get-members -r "$KC_REALM" --uid $USER_PHADMIN_ID --gid $GROUP_PHUSERS_ID | jq '. | select(.[].username == "phadmin") | length')"
}

test_scope_mapping() {
  # add realm role
  $KCADM add-scopes \
    -r $KC_REALM \
    --clientid test \
    --rolename hello \
    --rolename world
  assertEquals "add roles" 0 $?
  assertEquals "add roles" \
    'hello' \
    $($KCADM get-scopes -r $KC_REALM --cid $CLIENT_TEST_ID | jq -r '.[] | select( .name == "hello") | .name')

  # add client role
  $KCADM add-scopes \
    -r $KC_REALM \
    --clientid test \
    --roleclientid realm-management \
    --rolename realm-admin
  assertEquals "add client roles" 0 $?
  assertEquals "add client roles" \
    'realm-admin' \
    $($KCADM get-scopes -r $KC_REALM --cid $CLIENT_TEST_ID --rolecid $CLIENT_REALM_MANGEMENT_ID | jq -r '.[] | select( .name == "realm-admin") | .name')
}

test_login_by_service_account() {
  $KCADM config credentials \
        --server $KC_URL \
        --realm $KC_REALM \
        --client test \
        --secret "$CLIENT_TEST_SECRET"
  assertEquals "login by service account" 0 $?

  result=$($KCADM get realms | jq -r ".[] | select(.realm == \"$KC_REALM\") | .realm")
  assertEquals "login by service account" "$KC_REALM" "$result"
}

# Uncomment the following code if we want to test specific test.
suite() {
  suite_addTest test_login
  suite_addTest test_realm
  suite_addTest test_kcadm_add_user_and_group
  suite_addTest test_client
  suite_addTest test_member
  suite_addTest test_role
  suite_addTest test_role_binding
  suite_addTest test_scope_mapping
  suite_addTest test_login_by_service_account
}

command -v shunit2 >> /dev/null || { echo "shunit2 not found."; exit 1; }
source $(which shunit2)
