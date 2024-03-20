load ./bats_setup
load ./bats_utils

@test "Zenroom is executable installed" {
    zenroom="$(which zenroom)"
    assert_file_executable "$zenroom"
}
@test "Holder read cred_iss well-known from qr" {
    zexe $WALLET/read_credential_issuer.zen $WALLET_KEYS $WALLET/holder_request_authorizationCode.data.json
    save_tmp_output read_credential_issuer.output.json
    url=$(jq_extract_raw "credential_issuer" read_credential_issuer.output.json)
    curl -X GET $url | jq -c '.' 1> $TMP/out
    save_tmp_output credential_issuer_well-known.output.json
    assert_output '{"credential_issuer":"http://localhost:3001","credential_endpoint":"http://localhost:3001/credential","authorization_servers":["http://localhost:3000"],"display":[{"name":"DIDroom_Issuer1","locale":"en-US"}],"jwks":{"keys":[{"kid":"did:dyne:sandbox.genericissuer:GPgX3sS1nNp7fgLWvvTSw4jUaEDLuBTNq5eJhvkVD9ER#es256_public_key","crv":"P-256","alg":"ES256","kty":"EC"}]},"credential_configurations_supported":[{"format":"vc+sd-jwt","cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"credential_signing_alg_values_supported":["ES256"],"proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}},"display":[{"name":"Above 18 identity","locale":"en-US","logo":{"url":"https://avatars.githubusercontent.com/u/96812851","alt_text":"Forkbomb Logo"},"background_color":"#12107c","text_color":"#FFFFFF"}],"credential_definition":{"type":["Identity"],"credentialSubject":{"given_name":{"mandatory":true,"display":[{"name":"Current First Name","locale":"en-US"}]},"family_name":{"mandatory":true,"display":[{"name":"Current Family Name","locale":"en-US"}]},"birth_date":{"mandatory":true,"display":[{"name":"Date of Birth","locale":"en-US"}]},"above_18":{"mandatory":true,"display":[{"name":"Is above 18","locale":"en-US"}]}}}},{"format":"vc+sd-jwt","cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"credential_signing_alg_values_supported":["ES256"],"proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}},"display":[{"name":"Proof of humanity","locale":"en-US","logo":{"url":"https://avatars.githubusercontent.com/u/96812851","alt_text":"Forkbomb Logo"},"background_color":"#12107c","text_color":"#FFFFFF"}],"credential_definition":{"type":["Auth1"],"credentialSubject":{"given_name":{"mandatory":true,"display":[{"name":"Current First Name","locale":"en-US"}]},"family_name":{"mandatory":true,"display":[{"name":"Current Family Name","locale":"en-US"}]},"is_human":{"mandatory":true,"display":[{"name":"Proof of humanity","locale":"en-US"}]}}}}]}'
    authorization_server=$(jq_extract_raw "authorization_servers" credential_issuer_well-known.output.json| jq -r '.[0]')
    jq_insert "authorization_server" $authorization_server read_credential_issuer.output.json
    credential_configurations_supported=$(jq_extract_raw "credential_configurations_supported" credential_issuer_well-known.output.json | jq -c '.')
    echo $credential_configurations_supported >$TMP/out
    save_tmp_output credential_supported.json 
    jq_insert_json "credential_configurations_supported" credential_supported.json read_credential_issuer.output.json
}

@test "Holder read authz_server well-known" {
    zexe $WALLET/read_authz_server.zen $WALLET_KEYS read_credential_issuer.output.json
    save_tmp_output read_authz_server.output.json
    url=$(jq_extract_raw "authorization_server" read_authz_server.output.json)
    curl -X GET $url | jq -c '.' 1> $TMP/out
    save_tmp_output authz_server_well-known.output.json
    assert_output '{"authorization_endpoint":"http://localhost:3000/authorize","pushed_authorization_request_endpoint":"http://localhost:3000/par","token_endpoint":"http://localhost:3000/token","issuer":"http://localhost:3000","jwks":{"keys":[{"kid":"did:dyne:sandbox.genericissuer:6Cp8mPUvJmQaMxQPSnNyhb74f9Ga4WqfXCkBneFgikm5#es256_public_key","crv":"P-256","alg":"ES256","kty":"EC"}]},"scopes_supported":["Identity","Auth1"],"dpop_signing_alg_values_supported":["ES256"],"client_registration_types_supported":["automatic"],"code_challenge_methods_supported":["S256"],"authorization_details_types_supported":["openid_credential"],"grant_types_supported":["authorization_code"],"request_parameter_supported":true,"request_uri_parameter_supported":false,"response_types_supported":["code"],"subject_types_supported":["pairwise"],"token_endpoint_auth_methods_supported":["attest_jwt_client_auth"],"token_endpoint_auth_signing_alg_values_supported":["ES256"],"request_object_signing_alg_values_supported":["ES256"]}'
}

@test "Holder output credential_requested and credential_parameters" {
    echo "{}" >$TMP/out
    save_tmp_output holder_qr_to_well-known.data.json 
    jq_insert_json zen_2_output read_authz_server.output.json holder_qr_to_well-known.data.json
    jq_insert_json authorization_server_well-known authz_server_well-known.output.json holder_qr_to_well-known.data.json
    jq_insert_json credential_issuer_well-known credential_issuer_well-known.output.json holder_qr_to_well-known.data.json
    zexe $WALLET/holder_qr_to_well-known.zen $WALLET_KEYS holder_qr_to_well-known.data.json
    save_tmp_output holder_qr_to_well-known.output.json
    assert_output '{"credential_parameters":{"authorization_endpoint":"http://localhost:3000/authorize","authorization_server_endpoint_par":"http://localhost:3000/par","code_challenge_method":"S256","credential_endpoint":"http://localhost:3001/credential","credential_issuer":"http://localhost:3001","format":"vc+sd-jwt","grant_type":"authorization_code","response_type":"code","token_endpoint":"http://localhost:3000/token","vct":"Auth1"},"credential_requested":{"credential_definition":{"credentialSubject":{"family_name":{"display":[{"locale":"en-US","name":"Current Family Name"}],"mandatory":true},"given_name":{"display":[{"locale":"en-US","name":"Current First Name"}],"mandatory":true},"is_human":{"display":[{"locale":"en-US","name":"Proof of humanity"}],"mandatory":true}},"type":["Auth1"]},"credential_signing_alg_values_supported":["ES256"],"cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"display":[{"background_color":"#12107c","locale":"en-US","logo":{"alt_text":"Forkbomb Logo","url":"https://avatars.githubusercontent.com/u/96812851"},"name":"Proof of humanity","text_color":"#FFFFFF"}],"format":"vc+sd-jwt","proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}}}}'
}

@test "Holder post to authz_server/par" {
    json_join_two $WALLET/holder_request_authorizationCode.data.json holder_qr_to_well-known.output.json
    zexe $WALLET/1_holder_to_par_on_authz_server.zen $WALLET_KEYS holder_qr_to_well-known.output.json
    save_tmp_output 1_holder_to_par_on_authz_server.output.json
    url=$(jq_extract_raw "authorization_server_endpoint_par" 1_holder_to_par_on_authz_server.output.json)
    data=$(jq_extract_raw "data" 1_holder_to_par_on_authz_server.output.json)
    curl -X POST $url -d ''"$(echo $data)"'' 1> $TMP/out
    save_tmp_output post_1_response.output.json
    # (Invalid extended regular expression?) assert_output --regexp '{"request_uri":"urn:ietf:params:oauth:request_uri.*","expires_in":600}
    assert_output --partial '{"request_uri":"urn:ietf:params:oauth:request_uri'
    assert_output --partial '","expires_in":600}'
}

@test "Holder post to authz_server/authorize" {
    json_join_two holder_qr_to_well-known.output.json post_1_response.output.json
    zexe $WALLET/3_holder_fetch_request_uri.zen $WALLET_KEYS post_1_response.output.json
    save_tmp_output 3_holder_fetch_request_uri.output.json
    url=$(jq_extract_raw "authorization_server_authorize_endpoint" 3_holder_fetch_request_uri.output.json)
    data=$(jq_extract_raw "data" 3_holder_fetch_request_uri.output.json)
    curl -X POST $url -d ''"$(echo $data)"'' 1> $TMP/out
    save_tmp_output post_3_response.output.json
    # if --regexp resolve modify also here
    assert_output --partial '{"code":"eyJhbGciOiJFUzI1NiIsImp3ayI6eyJrdHkiOiJFQyIsIngiOiJoLXlLRFRpVUttb0ZNcHdXR2tMcG42QksyU2pLeHdQYlVRMGVUaXpWeExrIiwieSI6Ii1VekQ0TlJtY2t0Qk5Db0dSUkNJWERuOUYwcUQzNDJVZlF5WTFSdG10TEEiLCJjcnYiOiJQLTI1NiJ9fQ.'
}

@test "Holder post to authz_server/token" {
    json_join_two $WALLET/holder_request_authorizationCode.data.json post_3_response.output.json
    json_join_two holder_qr_to_well-known.output.json post_3_response.output.json
    code_verifier=$(jq_extract_raw "code_verifier" 1_holder_to_par_on_authz_server.output.json)
    jq_insert "code_verifier" $code_verifier post_3_response.output.json
    zexe $WALLET/5_holder_sends_authorizationCode_and_more_to_api_token.zen $WALLET_KEYS post_3_response.output.json
    save_tmp_output 5_holder_sends_authorizationCode_and_more_to_api_token.output.json
    url=$(jq_extract_raw "!authorization_server_token_endpoint" 5_holder_sends_authorizationCode_and_more_to_api_token.output.json)
    data=$(jq_extract_raw "data" 5_holder_sends_authorizationCode_and_more_to_api_token.output.json)
    curl -X POST $url -d ''"$(echo $data)"'' 1> $TMP/out
    save_tmp_output post_5_response.output.json
    # if --regexp resolve modify also here
    assert_output --partial '{"token_type":"bearer","access_token":"eyJhbGciOiJFUzI1NiIsImp3ayI6eyJrdHkiOiJFQyIsIngiOiJoLXlLRFRpVUttb0ZNcHdXR2tMcG42QksyU2pLeHdQYlVRMGVUaXpWeExrIiwieSI6Ii1VekQ0TlJtY2t0Qk5Db0dSUkNJWERuOUYwcUQzNDJVZlF5WTFSdG10TEEiLCJjcnYiOiJQLTI1NiJ9fQ.'
    assert_output --partial '","c_nonce":"'
    assert_output --partial '","c_nonce_expires_in":3600,"expires_in":'
    assert_output --partial ',"authorization_details":[{"credential_configuration_id":"Auth1","family_name":"Peppe","given_name":"Pippo","is_human":true,"locations":["http://localhost:3001"],"type":"openid_credential"}]}'
}

@test "Holder post to credantial_issuer/credential" {
    json_join_two $WALLET/holder_request_authorizationCode.data.json post_5_response.output.json
    json_join_two holder_qr_to_well-known.output.json post_5_response.output.json
    zexe $WALLET/7_holder_sends_credential_request_to_api_credential.zen $WALLET_KEYS post_5_response.output.json
    save_tmp_output 7_holder_sends_credential_request_to_api_credential.output.json
    url=$(jq_extract_raw "authorization_server_credential_endpoint" 7_holder_sends_credential_request_to_api_credential.output.json)
    data=$(jq_extract_raw "data" 7_holder_sends_credential_request_to_api_credential.output.json)
    headers=$(jq_extract_raw "headers" 7_holder_sends_credential_request_to_api_credential.output.json)
    curl -H 'Authorization: '"$(echo $headers | jq -r '.Authorization')"'' -X POST $url -d ''"$(echo $data)"'' 1> $TMP/out
    save_tmp_output post_7_response.output.json
    # if --regexp resolve modify also here
    assert_output --partial '{"c_nonce":"'
    assert_output --partial '","c_nonce_expires_in":600,"credential":"eyJhbGciOiAiRVMyNTYiLCAidHlwIjogInZjK3NkLWp3dCJ9'
}
