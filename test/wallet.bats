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
    assert_output --partial '{"credential_issuer":"http://localhost:3001","credential_endpoint":"http://localhost:3001/credential","authorization_servers":["http://localhost:3000"],"display":[{"name":"DIDroom_Issuer1","locale":"en-US"}],"jwks":{"keys":[{"kid":"did:dyne:sandbox.genericissuer:'
    assert_output --partial 'es256_public_key","crv":"P-256","alg":"ES256","kty":"EC"}]},"credential_configurations_supported":[{"format":"vc+sd-jwt","cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"credential_signing_alg_values_supported":["ES256"],"proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}},"display":[{"name":"Above 18 identity","locale":"en-US","logo":{"url":"https://avatars.githubusercontent.com/u/96812851","alt_text":"Forkbomb Logo"},"background_color":"#12107c","text_color":"#FFFFFF"}],"credential_definition":{"type":["Identity"],"credentialSubject":{"given_name":{"mandatory":true,"display":[{"name":"Current First Name","locale":"en-US"}]},"family_name":{"mandatory":true,"display":[{"name":"Current Family Name","locale":"en-US"}]},"birth_date":{"mandatory":true,"display":[{"name":"Date of Birth","locale":"en-US"}]},"above_18":{"mandatory":true,"display":[{"name":"Is above 18","locale":"en-US"}]}}}},{"format":"vc+sd-jwt","cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"credential_signing_alg_values_supported":["ES256"],"proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}},"display":[{"name":"Proof of humanity","locale":"en-US","logo":{"url":"https://avatars.githubusercontent.com/u/96812851","alt_text":"Forkbomb Logo"},"background_color":"#12107c","text_color":"#FFFFFF"}],"credential_definition":{"type":["Auth1"],"credentialSubject":{"given_name":{"mandatory":true,"display":[{"name":"Current First Name","locale":"en-US"}]},"family_name":{"mandatory":true,"display":[{"name":"Current Family Name","locale":"en-US"}]},"is_human":{"mandatory":true,"display":[{"name":"Proof of humanity","locale":"en-US"}]}}}}]}'
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
    assert_output --partial '{"authorization_endpoint":"http://localhost:3000/authorize","pushed_authorization_request_endpoint":"http://localhost:3000/par","token_endpoint":"http://localhost:3000/token","introspection_endpoint":"http://localhost:3000/introspection","issuer":"http://localhost:3000","jwks":{"keys":[{"kid":"did:dyne:sandbox.genericissuer:'
    assert_output --partial '#es256_public_key","crv":"P-256","alg":"ES256","kty":"EC"}]},"scopes_supported":["Identity","Auth1"],"dpop_signing_alg_values_supported":["ES256"],"client_registration_types_supported":["automatic"],"code_challenge_methods_supported":["S256"],"authorization_details_types_supported":["openid_credential"],"grant_types_supported":["authorization_code"],"request_parameter_supported":true,"request_uri_parameter_supported":false,"response_types_supported":["code"],"subject_types_supported":["pairwise"],"token_endpoint_auth_methods_supported":["attest_jwt_client_auth"],"token_endpoint_auth_signing_alg_values_supported":["ES256"],"request_object_signing_alg_values_supported":["ES256"]}'
}

@test "Holder output credential_requested and credential_parameters" {
    echo "{}" >$TMP/out
    save_tmp_output holder_qr_to_well-known.data.json 
    jq_insert_json zen_2_output read_authz_server.output.json holder_qr_to_well-known.data.json
    tmp=$(mktemp)
    jq --arg key "authorization_server_well-known" '.[$key].result = input' $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json $BATS_FILE_TMPDIR/authz_server_well-known.output.json > $tmp && mv $tmp  $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json
    jq --arg key "credential_issuer_well-known" '.[$key].result = input' $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json $BATS_FILE_TMPDIR/credential_issuer_well-known.output.json > $tmp && mv $tmp  $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json
    zexe $WALLET/holder_qr_to_well-known.zen $WALLET_KEYS holder_qr_to_well-known.data.json
    save_tmp_output holder_qr_to_well-known.output.json
    assert_output --partial '{"credential_issuer_information":{"authorization_servers":["http://localhost:3000"],"credential_endpoint":"http://localhost:3001/credential","credential_issuer":"http://localhost:3001","display":[{"locale":"en-US","name":"DIDroom_Issuer1"}],"jwks":{"keys":[{"alg":"ES256","crv":"P-256","kid":"did:dyne:sandbox.genericissuer:'
    assert_output --partial '#es256_public_key","kty":"EC"}]}},"credential_parameters":{"authorization_endpoint":"http://localhost:3000/authorize","authorization_server_endpoint_par":"http://localhost:3000/par","code_challenge_method":"S256","credential_endpoint":"http://localhost:3001/credential","credential_issuer":"http://localhost:3001","format":"vc+sd-jwt","grant_type":"authorization_code","response_type":"code","token_endpoint":"http://localhost:3000/token","vct":"Auth1"},"credential_requested":{"credential_definition":{"credentialSubject":{"family_name":{"display":[{"locale":"en-US","name":"Current Family Name"}],"mandatory":true},"given_name":{"display":[{"locale":"en-US","name":"Current First Name"}],"mandatory":true},"is_human":{"display":[{"locale":"en-US","name":"Proof of humanity"}],"mandatory":true}},"type":["Auth1"]},"credential_signing_alg_values_supported":["ES256"],"cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"display":[{"background_color":"#12107c","locale":"en-US","logo":{"alt_text":"Forkbomb Logo","url":"https://avatars.githubusercontent.com/u/96812851"},"name":"Proof of humanity","text_color":"#FFFFFF"}],"format":"vc+sd-jwt","proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}}}}'
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
    assert_output --partial '{"code":"eyJhbGciOiJFUzI1NiIsImp3ayI6eyJrdHkiOiJFQyIsIngiO'
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
    assert_output --partial '{"token_type":"bearer","access_token":"eyJhbGciOiJFUzI1NiIsImp3ayI6eyJrdHkiOiJFQyIsIngiO'
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

@test "Holder post to relying_party/verify" {
    # use credential from previous script
    cred=$(jq ".credential" $BATS_FILE_TMPDIR/post_7_response.output.json)
    jq ".credential_array = [$cred]" $WALLET/produce_verifiable_presentation.data.json > $BATS_FILE_TMPDIR/temp_vp.data.json
    # first script
    zexe $WALLET/produce_vp_1.zen temp_vp.data.json
    save_tmp_output produce_vp_1.output.json
    url=$(jq_extract_raw "rp_wk_endpoint" produce_vp_1.output.json)
    curl -X GET $url | jq -c '.' 1> $TMP/out
    save_tmp_output rp_wk_endpoint_response.json
    assert_output --partial '{"relying_party":"http://localhost:3003","verification_endpoint":"http://localhost:3003/verify","trusted_credential_issuers":["https://issuer1.zenswarm.forkbomb.eu","https://generic.issuer1.com","http://localhost:3001"],"display":[{"name":"DIDroom_RelyingParty1","locale":"en-US"}],"jwks":{"keys":[{"kid":"did:dyne:sandbox.genericissuer:'
    assert_output --partial '#es256_public_key","crv":"P-256","alg":"ES256","kty":"EC"}]},"credential_configurations_supported":[{"format":"vc+sd-jwt","cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"credential_signing_alg_values_supported":["ES256"],"proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}}}]}'
    request_uri=$(jq_extract_raw "ru" temp_vp.data.json)
    curl -X GET $request_uri | jq -c '.' 1> $TMP/out
    save_tmp_output request_uri_response.json
    assert_output '{"items":[{"schema":{"properties":{"family_name":{"title":"family name","type":"string"},"given_name":{"title":"given name","type":"string"},"is_human":{"title":"is human","type":"boolean"}},"required":["family_name","given_name","is_human"],"type":"object"}}],"page":1,"perPage":30,"totalItems":1,"totalPages":1}'
    cat $BATS_FILE_TMPDIR/request_uri_response.json | jq '{"asked_claims": .items[0].schema}' > $TMP/out
    save_tmp_output produce_vp_2.data.json
    json_join_two temp_vp.data.json produce_vp_2.data.json
    jq_insert_json rp_wk rp_wk_endpoint_response.json produce_vp_2.data.json
    zexe $WALLET/produce_vp_2.zen produce_vp_2.data.json
    save_tmp_output produce_vp_2.output.json
    assert_output --partial '{"vp":"eyJhbGciOiAiRVMyNTYiLCAidHlwIjogInZjK3NkLWp3dCJ9.'
    verify_endpoint=$(jq_extract_raw "verification_endpoint" rp_wk_endpoint_response.json)
    token=$(jq_extract_raw "t" $WALLET/produce_verifiable_presentation.data.json)
    id=$(jq_extract_raw "id" $WALLET/produce_verifiable_presentation.data.json)
    m=$(jq_extract_raw "m" $WALLET/produce_verifiable_presentation.data.json)
    jq_insert "registrationToken" $token produce_vp_2.output.json
    jq_insert "id" $id produce_vp_2.output.json
    jq_insert "m" $m produce_vp_2.output.json
    curl -X POST $verify_endpoint -d ''"$(cat $BATS_FILE_TMPDIR/produce_vp_2.output.json)"'' 1>$TMP/out
    save_tmp_output verify_endpoint_response.json
    # if --regexp resolve modify also here
    assert_output --partial '"server_response":{"status":"200","result":{"message":"eyJhbGciOiJFUzI1NiIsImp3ayI6eyJhbGciOiJFUzI1NiIsImNydiI6IlAtMjU2Iiwia2lkIjoiZGlkOmR5bmU6c2FuZGJveC5nZW5lcmlja'
    assert_output --partial ',"registrationToken":"ehUYkktwQVWy_v9MXeTaf9:APA91bG28isX0dJJEzW6K5qA8N67-V7bZjYhEXYsWNyL_7xiJsBVTuKgEalgK_ajlK_6u2hY3tFlq0e649F4lhb909VHVfHGKrWFVb0uBdY61RmnLcxhwkltm2yyxxdXje1qWCavb281"}'
    message=$(jq -r '.server_response.result.message' $BATS_FILE_TMPDIR/verify_endpoint_response.json)
    echo "{}" >$TMP/out
    save_tmp_output clear_rp_response.out.json
    jq_insert "message" $message clear_rp_response.out.json
}

@test "Verifier retrieve id from message" {
    id=$(jq_extract_raw "id" $WALLET/produce_verifiable_presentation.data.json)
    zexe $VERIFIER/jws_to_id.zen clear_rp_response.out.json
    save_tmp_output jws_to_id.output.json
    assert_output "{\"id\":\"$id\"}"
}

@test "Verifier verify jws" {
    # verify_1
    claim_url=$(jq_extract_raw "claims_url" $VERIFIER/verify.data.json)
    curl -X GET $claim_url | jq '{"result": .}' 1> $TMP/out
    save_tmp_output claims.json
    zexe $VERIFIER/verify_1.zen clear_rp_response.out.json claims.json
    save_tmp_output verify_1.output.json
    # verfiy_2
    rp_wk_url=$(jq_extract_raw "iss" verify_1.output.json)
    curl -X GET $rp_wk_url | jq '{"result": .}' 1> $TMP/out
    save_tmp_output rp_wk_endpoint_response.json
    zexe $VERIFIER/verify_2.zen verify_1.output.json rp_wk_endpoint_response.json
    save_tmp_output verify_2.output.json
    # verify_3
    did_url=$(jq_extract_raw "did_url" verify_2.output.json)
    curl -X GET $did_url | jq '{"result": .}' 1> $TMP/out
    save_tmp_output did_endpoint_response.json
    zexe $VERIFIER/verify_3.zen clear_rp_response.out.json did_endpoint_response.json
    save_tmp_output verify_3.output.json
    assert_output '{"output":["Signature_verification_successful"]}'
}