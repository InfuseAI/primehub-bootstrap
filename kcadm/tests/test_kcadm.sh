#!/bin/bash
#
# Test by https://github.com/kward/shunit2

KCADM_TEST=true
source kcadm

################################################
# Test cases
test_require_env() {
  unset KC_ACCESS_TOKEN

  # Test if env not found
  assertEquals \
    "env not found" \
    "$(kcadm::require_env KC_ACCESS_TOKEN 2> /dev/null || echo "env not found")"

  # Test if env not found
  local TOKEN="token"
  assertEquals \
    "token" \
    "$(kcadm::require_env TOKEN && echo "$TOKEN")"
  unset KC_ACCESS_TOKEN
}


test_json_modify_key() {
  assertEquals \
    '["abc"]' \
    "$(json::modify_key abc)"

  assertEquals \
    '["abc"]["project-quota-cpu"]' \
    "$(json::modify_key abc.project-quota-cpu)"
}

test_json_modify_value() {
  assertEquals \
    '"abc"' \
    "$(json::modify_value abc)"

  assertEquals \
    '"abc"' \
    "$(json::modify_value 'abc')"

  assertEquals \
    '"abc"' \
    "$(json::modify_value \"abc\")"

  assertEquals \
    '["abc"]' \
    "$(json::modify_value [\"abc\"])"

  assertEquals \
    '{"abc":"bar"}' \
    "$(json::modify_value {\"abc\":\"bar\"})"

  assertEquals \
    'null' \
    "$(json::modify_value '')"
}

test_json_set() {
  # Set
  assertEquals \
    '{"foo":"bar"}' \
    $(echo '{}' | json::set foo bar)

  assertEquals \
    '{"foo":"bar2"}' \
    $(echo '{"foo":"bar"}' | json::set foo bar2)


  read -d '' -r json <<EOF
{
  "attributes": {
    "project-quota-cpu": [
      "0"
    ]
  }
}
EOF
  assertEquals \
    '{"attributes":{"project-quota-cpu":["false"]}}' \
    "$(echo "${json}" | json::set "attributes.project-quota-cpu" "[\"false\"]")"
}

test_json_append() {
  # Append list
  assertEquals \
    '{"foo":["a"]}' \
    $(echo '{}' | json::append foo a)

  assertEquals \
    '{"foo":["a","b"]}' \
    $(echo '{}' | json::append foo a | json::append foo b)
}

test_json_delete() {
  # Delete
  assertEquals \
    '{}' \
    $(echo '{"foo":"bar"}' | json::delete foo)

  assertEquals \
    '{"foo":"bar"}' \
    $(echo '{"foo":"bar"}' | json::delete foo2)
}

test_json_merge() {
  assertEquals \
    '{"a":{"b":"x","c":"x"}}' \
    $(json::merge '{"a":{"b":"x"}}' '{"a":{"c":"x"}}')

  assertEquals \
    '{"a":{"b":"y"}}' \
    $(json::merge '{"a":{"b":"x"}}' '{"a":{"b":"y"}}')
}

test_curl() {
  local resp
  local body
  local code

  # 200
  read -r -d '' resp \
<<EOF
HTTP/1.1 200 OK
Date: Sat, 10 Aug 2019 08:30:33 GMT
Expires: -1
Cache-Control: private, max-age=0
Content-Type: text/html; charset=ISO-8859-1

This is the body
This is the second
EOF

  body=$(curl::parse_response <<< "$resp")
  assertEquals 0 "$?"
  assertEquals \
    $'This is the body\nThis is the second' \
    "$body"

  # 302
  read -r -d '' resp \
<<EOF
HTTP/1.1 302 Temporary Redirect
Location: https://www-temp.example.org/

HTTP/1.1 200 OK
Date: Sat, 10 Aug 2019 08:30:33 GMT
Expires: -1
Cache-Control: private, max-age=0
Content-Type: text/html; charset=ISO-8859-1

This is the body
This is the second
EOF

  body=$(curl::parse_response <<< "$resp")
  assertEquals 0 "$?"
  assertEquals \
    $'This is the body\nThis is the second' \
    "$body"

  # 400
  read -r -d '' resp \
<<EOF
HTTP/1.1 400 This is testing error
Content-Type: text/plain

This is error
EOF

  body=$(curl::parse_response <<< "$resp" 2> /dev/null )
  assertEquals 1 "$?"
  assertEquals "400" \
    $'This is error' \
    "$body"

  # 100
  read -r -d '' resp \
<<EOF
HTTP/1.1 100 Continue

HTTP/1.1 201 Created
Server: nginx/1.15.10
Date: Mon, 26 Aug 2019 16:22:43 GMT
Content-Length: 0
Connection: keep-alive
Location: https://id.celu.dev.primehub.io/auth/admin/realms/bootstrap/clients/2c849e2a-2ebf-4dd9-8581-56d130021a6f
Strict-Transport-Security: max-age=15724800; includeSubDomains
EOF
  body=$(curl::parse_response <<< "$resp")
  assertEquals 0 "$?"
  assertEquals \
    $'' \
    "$body"

}

source $(which shunit2)
