load ./bats_setup
load ./bats_utils

@test "Zenroom is executable installed" {
    zenroom="$(which zenroom)"
    assert_file_executable "$zenroom"
}

@test "Holder post to authz_server/par" {
    zexe $WALLET/1_holder_to_par_on_authz_server.zen $WALLET_KEYS $WALLET/holder_request_authorizationCode.data.json
    save_tmp_output 1_holder_to_par_on_authz_server.output.json
    url=$(jq_extract_raw "authorization_server_endpoint_par" 1_holder_to_par_on_authz_server.output.json)
    data=$(jq_extract_raw "data" 1_holder_to_par_on_authz_server.output.json)
    curl -X POST $url -d ''"$(echo $data)"'' 2>/dev/null 1> $TMP/out 
    save_tmp_output post_1_response.output.json
    # (Invalid extended regular expression?) assert_output --regexp '{"request_uri":"urn:ietf:params:oauth:request_uri.*","expires_in":600}
    assert_output --partial '{"request_uri":"urn:ietf:params:oauth:request_uri'
    assert_output --partial '","expires_in":600}'
}

@test "Holder post to authz_server/authorize" {
    json_join_two $WALLET/holder_request_authorizationCode.data.json post_1_response.output.json
    zexe $WALLET/3_holder_fetch_request_uri.zen $WALLET_KEYS post_1_response.output.json
    save_tmp_output 3_holder_fetch_request_uri.output.json
    url=$(jq_extract_raw "authorization_server_authorize_endpoint" 3_holder_fetch_request_uri.output.json)
    data=$(jq_extract_raw "data" 3_holder_fetch_request_uri.output.json)
    curl -X POST $url -d ''"$(echo $data)"'' 2>/dev/null 1> $TMP/out 
    save_tmp_output post_3_response.output.json
    # if --regexp resolve modify also here
    assert_output --partial '{"code":"eyJhbGciOiJFUzI1NiIsImp3ayI6eyJrdHkiOiJFQyIsIngiOiJoLXlLRFRpVUttb0ZNcHdXR2tMcG42QksyU2pLeHdQYlVRMGVUaXpWeExrIiwieSI6Ii1VekQ0TlJtY2t0Qk5Db0dSUkNJWERuOUYwcUQzNDJVZlF5WTFSdG10TEEiLCJjcnYiOiJQLTI1NiJ9fQ.'
}

@test "Holder post to authz_server/token" {
    json_join_two $WALLET/holder_request_authorizationCode.data.json post_3_response.output.json
    code_verifier=$(jq_extract_raw "code_verifier" 1_holder_to_par_on_authz_server.output.json)
    jq_insert "code_verifier" $code_verifier post_3_response.output.json
    zexe $WALLET/5_holder_sends_authorizationCode_and_more_to_api_token.zen $WALLET_KEYS post_3_response.output.json
    save_tmp_output 5_holder_sends_authorizationCode_and_more_to_api_token.output.json
    url=$(jq_extract_raw "!authorization_server_token_endpoint" 5_holder_sends_authorizationCode_and_more_to_api_token.output.json)
    data=$(jq_extract_raw "data" 5_holder_sends_authorizationCode_and_more_to_api_token.output.json)
    curl -X POST $url -d ''"$(echo $data)"'' 2>/dev/null 1> $TMP/out 
    save_tmp_output post_5_response.output.json
    # if --regexp resolve modify also here
    assert_output --partial '{"token_type":"bearer","access_token":"eyJhbGciOiJFUzI1NiIsImp3ayI6eyJrdHkiOiJFQyIsIngiOiJoLXlLRFRpVUttb0ZNcHdXR2tMcG42QksyU2pLeHdQYlVRMGVUaXpWeExrIiwieSI6Ii1VekQ0TlJtY2t0Qk5Db0dSUkNJWERuOUYwcUQzNDJVZlF5WTFSdG10TEEiLCJjcnYiOiJQLTI1NiJ9fQ.'
    assert_output --partial '","c_nonce":"'
    assert_output --partial '","c_nonce_expires_in":3600,"expires_in":'
    assert_output --partial ',"authorization_details":[{"credential_configuration_id":"Auth1","family_name":"Peppe","given_name":"Pippo","is_human":true,"locations":["http://localhost:3001/"],"type":"openid_credential"}]}'
}

@test "Holder post to credantial_issuer/credential" {
    json_join_two $WALLET/holder_request_authorizationCode.data.json post_5_response.output.json
    zexe $WALLET/7_holder_sends_credential_request_to_api_credential.zen $WALLET_KEYS post_5_response.output.json
    save_tmp_output 7_holder_sends_credential_request_to_api_credential.output.json
    url=$(jq_extract_raw "authorization_server_credential_endpoint" 7_holder_sends_credential_request_to_api_credential.output.json)
    data=$(jq_extract_raw "data" 7_holder_sends_credential_request_to_api_credential.output.json)
    curl -X POST $url -d ''"$(echo $data)"'' 2>/dev/null 1> $TMP/out
    save_tmp_output post_7_response.output.json
    # if --regexp resolve modify also here
    assert_output --partial '{"credential_identifier":"ab8c936e-b9ab-4cf5-9862-c3a25bb82996","proof":{"jwt":"eyJhbGciOiAiRVMyNTYiLCAidHlwIjogInZjK3NkLWp3dCJ9.'
    assert_output --partial '","proof_type":"jwt"}}'
}
