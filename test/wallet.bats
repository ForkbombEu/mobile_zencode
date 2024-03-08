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
    assert_output --partial '{"code":"eyJhbGciOiJFUzI1NiJ9.'
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
    assert_output --partial '{"token_type":"bearer","access_token":"eyJhbGciOiJFUzI1NiJ9.'
    assert_output --partial '","c_nonce":"'
    assert_output --partial '","c_nonce_expires_in":3600,"expires_in":'
    assert_output --partial ',"resource":"https://issuer1.zenswarm.forkbomb.eu/credential_issuer","scope":["Auth1"]}'
}
