# KCADM

A [keycloak admin](https://www.keycloak.org/docs-api/6.0/rest-api/index.html) client implemented by bash.

Basically, the way to use is 99% the same as [kcadm.sh](https://www.keycloak.org/docs/latest/server_admin/index.html#the-admin-cli). But in `kcadm.sh`, it delegate the command to java application. However, in some environment, JVM is too heavy to execute.

# Features

- Pure bash. Few dependencies. (bash, curl, and jq)
- Refresh token automatically
- Support login by user and service account
- Same configuration as `kcadm.sh` provides
- More high level commands than `kcadm.sh`. (e.g. manage roles, members, scopes)

# Prerequisites

- curl - as http client
- [jq](https://stedolan.github.io/jq/) - json processor


# Getting Started

1. Login 

    ```
    kcadm config credentials \
        --server https://<keycloak>/auth \
        --realm master \
        --user keycloak \
        --password <password>
    ```
    
1. get the resources

    ```
    kcadm get realms
    ```    
    
1. For more detail, please see the help

    ```
    kcadm help
    kcadm help <command>
    kcadm <command> --help
    ```

# Test

Based on [shunit2](https://github.com/kward/shunit2).Please put `shunit2` to $PATH variable

## Unit test

```
make test
```

## Integration test 

Run integration test against the $KC_URL. It will create a realm 'kcadm-it' by default.

```
export KC_URL="https://<keycloak>/auth"
export KC_USER="keycloak"
export KC_PASSWORD="<password>"
make integration-test
```

# Reference

- [kcadm.sh documentation](https://www.keycloak.org/docs/latest/server_admin/index.html#the-admin-cli)
- [keycloak Admin REST API](https://www.keycloak.org/docs-api/6.0/rest-api/index.html)