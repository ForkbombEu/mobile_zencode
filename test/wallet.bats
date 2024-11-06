load ./bats_setup
load ./bats_utils

@test "Zenroom is executable installed" {
    zenroom="$(which zenroom)"
    assert_file_executable "$zenroom"
}
@test "Holder read cred_iss well-known from qr" {
    zexe $WALLET/read_credential_issuer.zen $WALLET/holder_qr_to_well-known.data.json
    save_tmp_output read_credential_issuer.output.json
    url=$(jq_extract_raw "credential_issuer" read_credential_issuer.output.json)
    curl -X GET $url | jq -c '.' 1> $TMP/out
    save_tmp_output credential_issuer_well-known.output.json
    assert_output --partial '{"credential_issuer":"http://localhost:3001/credential_issuer","credential_endpoint":"http://localhost:3001/credential_issuer/credential","authorization_servers":["http://localhost:3000/authz_server"],"display":[{"name":"DIDroom_Test_Issuer","locale":"en-US"}],"jwks":{"keys":[{"kid":"did:dyne:sandbox.genericissuer:'
    assert_output --partial 'es256_public_key","crv":"P-256","alg":"ES256","kty":"EC"}]},"credential_configurations_supported":{"test_credential":{"format":"vc+sd-jwt","cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"credential_signing_alg_values_supported":["ES256"],"proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}},"display":[{"name":"Tested Credential","locale":"en-US","logo":{"uri":"https://www.connetweb.com/wp-content/uploads/2021/06/canstockphoto22402523-arcos-creator.com_-1024x1024-1.jpg","alt_text":"Test Logo"},"description":"a description","background_color":"#12107c","text_color":"#FFFFFF"}],"vct":"test_credential","claims":{"tested":{"mandatory":true,"display":[{"name":"Is tested","locale":"en-US"}]}}}}}'
    authorization_server=$(jq_extract_raw "authorization_servers" credential_issuer_well-known.output.json | jq -r '.[0]')
    jq_insert "authorization_server" $authorization_server read_credential_issuer.output.json
    credential_configurations_supported=$(jq_extract_raw "credential_configurations_supported" credential_issuer_well-known.output.json | jq -c '.')
    echo $credential_configurations_supported >$TMP/out
    save_tmp_output credential_supported.json 
    jq_insert_json "credential_configurations_supported" credential_supported.json read_credential_issuer.output.json
}

@test "Holder read authz_server well-known" {
    zexe $WALLET/read_authz_server.zen read_credential_issuer.output.json
    save_tmp_output read_authz_server.output.json
    url=$(jq_extract_raw "authorization_server" read_authz_server.output.json)
    curl -X GET $url | jq -c '.' 1> $TMP/out
    save_tmp_output authz_server_well-known.output.json
    assert_output --partial '{"authorization_endpoint":"http://localhost:3000/authz_server/authorize","pushed_authorization_request_endpoint":"http://localhost:3000/authz_server/par","token_endpoint":"http://localhost:3000/authz_server/token","introspection_endpoint":"http://localhost:3000/authz_server/introspection","issuer":"http://localhost:3000/authz_server","require_pushed_authorization_requests":true,"jwks":{"keys":[{"kid":"did:dyne:sandbox.genericissuer:'
    assert_output --partial '#es256_public_key","crv":"P-256","alg":"ES256","kty":"EC"}]},"scopes_supported":["{{ as_scopes }}"],"dpop_signing_alg_values_supported":["ES256"],"client_registration_types_supported":["automatic"],"code_challenge_methods_supported":["S256"],"authorization_details_types_supported":["openid_credential"],"grant_types_supported":["authorization_code"],"request_parameter_supported":true,"request_uri_parameter_supported":false,"response_types_supported":["code"],"subject_types_supported":["pairwise"],"token_endpoint_auth_methods_supported":["attest_jwt_client_auth"],"token_endpoint_auth_signing_alg_values_supported":["ES256"],"request_object_signing_alg_values_supported":["ES256"]}'
}

@test "Holder output credential_requested and credential_parameters" {
    echo "{}" >$TMP/out
    save_tmp_output holder_qr_to_well-known.data.json 
    jq_insert_json zen_2_output read_authz_server.output.json holder_qr_to_well-known.data.json
    tmp=$(mktemp)
    jq --arg key "authorization_server_well-known" '.[$key].result = input' $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json $BATS_FILE_TMPDIR/authz_server_well-known.output.json > $tmp && mv $tmp  $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json
    jq --arg key "credential_issuer_well-known" '.[$key].result = input' $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json $BATS_FILE_TMPDIR/credential_issuer_well-known.output.json > $tmp && mv $tmp  $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json
    zexe $WALLET/holder_qr_to_well-known.zen $WALLET/holder_qr_to_well-known.keys.json holder_qr_to_well-known.data.json
    save_tmp_output holder_qr_to_well-known.output.json
    assert_output --partial '{"credential_issuer_information":{"authorization_servers":["http://localhost:3000/authz_server"],"credential_endpoint":"http://localhost:3001/credential_issuer/credential","credential_issuer":"http://localhost:3001/credential_issuer","display":[{"locale":"en-US","name":"DIDroom_Test_Issuer"}],"jwks":{"keys":[{"alg":"ES256","crv":"P-256","kid":"did:dyne:sandbox.genericissuer:'
    assert_output --partial 'es256_public_key","kty":"EC"}]}},"credential_parameters":{"authorization_endpoint":"http://localhost:3000/authz_server/authorize","authorization_server_endpoint_par":"http://localhost:3000/authz_server/par","code_challenge_method":"S256","credential_endpoint":"http://localhost:3001/credential_issuer/credential","credential_issuer":"http://localhost:3001/credential_issuer","format":"vc+sd-jwt","grant_type":"authorization_code","response_type":"code","token_endpoint":"http://localhost:3000/authz_server/token","vct":"test_credential"},"credential_requested":{"claims":{"tested":{"display":[{"locale":"en-US","name":"Is tested"}],"mandatory":true}},"credential_signing_alg_values_supported":["ES256"],"cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"display":[{"background_color":"#12107c","description":"a description","locale":"en-US","logo":{"alt_text":"Test Logo","uri":"https://www.connetweb.com/wp-content/uploads/2021/06/canstockphoto22402523-arcos-creator.com_-1024x1024-1.jpg"},"name":"Tested Credential","text_color":"#FFFFFF"}],"format":"vc+sd-jwt","proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}},"vct":"test_credential"}}'
}

@test "Holder post to authz_server/par [call_par.zen]" {
    jq_insert "redirect_uri" "openid-credential-offer://example.com/" holder_qr_to_well-known.output.json
    zexe $WALLET/call_par.zen $WALLET/call_par.keys.json holder_qr_to_well-known.output.json
    save_tmp_output call_par.output.json
    url=$(jq_extract_raw "authorization_server_endpoint_par" call_par.output.json)
    data=$(jq_extract_raw "url_encoded_data" call_par.output.json)
    curl -X POST $url -H 'Content-Type: application/x-www-form-urlencoded' -d ''"$(echo $data)"'' 1> $TMP/out
    save_tmp_output post_par.output.json
    # (Invalid extended regular expression?) assert_output --regexp '{"request_uri":"urn:ietf:params:oauth:request_uri.*","expires_in":600}
    assert_output --partial '{"request_uri":"urn:ietf:params:oauth:request_uri'
    assert_output --partial '","expires_in":600}'
}

@test "simulate authz_server/authorize page" {
    authorization_endpoint=$(jq_extract_raw "authorization_endpoint" call_par.output.json)
    baseUrl=${authorization_endpoint%"authorize"}
    ru_to_toc=${baseUrl}ru_to_toc
    authorize_backend=${baseUrl}authorize_backend
    client_id=$(jq_extract_raw "client_id" call_par.output.json)
    request_uri=$(jq_extract_raw "request_uri" post_par.output.json)
    data_toc="{\"request_uri\": \"${request_uri}\", \"client_id\": \"${client_id}\"}"
    curl -X POST $ru_to_toc -H 'Content-Type: application/json' -d ''"$(echo $data_toc)"'' 1> $TMP/out
    save_tmp_output ru_to_toc.output.json
    assert_output '{"auth_details":[{"credential_configuration_id":"test_credential","locations":["http://localhost:3001/credential_issuer"],"type":"openid_credential","claims":[]}],"credential_configuration_id":"test_credential"}'
    cci=$(jq_extract_raw "credential_configuration_id" ru_to_toc.output.json)
    echo "form_input_and_params=$(urlencode '{"params":{"request_uri":"'"${request_uri}"'","client_id":"'"${client_id}"'"},"data":{"email":"email@email.com","password":"password"},"custom_code":"'"${cci}"'"}')" > $TMP/out
    save_tmp_output form.data.json
    curl -sS -D - -X POST $authorize_backend -H 'Content-Type: application/x-www-form-urlencoded' -d ''"$(cat $BATS_FILE_TMPDIR/form.data.json)"'' -o /dev/null 1> $TMP/out
    save_tmp_output authorize.output.json
    assert_output --partial 'HTTP/1.1 302'
    assert_output --partial 'Location: openid-credential-offer://example.com/?code='
}

@test "Holder post to authz_server/token [pre_token.zen]" {
    credential_parameters=$(jq_extract_raw "credential_parameters" holder_qr_to_well-known.output.json)
    code=$(grep -oP '(?<=Location: openid-credential-offer://example.com/\?code=)[^\s]+' $BATS_FILE_TMPDIR/authorize.output.json)
    code_verifier=$(jq_extract_raw "code_verifier" call_par.output.json)
    echo "{\"credential_parameters\": ${credential_parameters}, \"code\": \"$code\", \"code_verifier\": \"$code_verifier\", \"redirect_uri\": \"openid-credential-offer://example.com/\"}" > $TMP/out
    save_tmp_output pre_token.data.json
    zexe $WALLET/pre_token.zen $WALLET/call_token_and_credential.keys.json pre_token.data.json 
    save_tmp_output pre_token.output.json
    url=$(jq_extract_raw "token_endpoint" pre_token.output.json)
    data=$(jq_extract_raw "data" pre_token.output.json)
    curl -X POST $url -H 'Content-Type: application/x-www-form-urlencoded' -d ''"$(echo $data)"'' 1> $TMP/out
    save_tmp_output post_token.output.json
    # if --regexp resolve modify also here
    assert_output --partial '{"token_type":"bearer","access_token":"eyJhbGciOiJFUzI1NiIsImp3ayI6eyJrdHkiOiJFQyIsIngiO'
    assert_output --partial '","c_nonce":"'
    assert_output --partial '","c_nonce_expires_in":3600,"expires_in":'
    assert_output --partial ',"authorization_details":[{"credential_configuration_id":"test_credential","locations":["http://localhost:3001/credential_issuer"],"type":"openid_credential","claims":{"id":"123456789"}}]}'
}

@test "Holder post to credantial_issuer/credential [pre_credential.zen]" {
    json_join_two holder_qr_to_well-known.output.json post_token.output.json
    zexe $WALLET/pre_credential.zen $WALLET/call_token_and_credential.keys.json post_token.output.json
    save_tmp_output pre_credential.output.json
    url=$(jq_extract_raw "credential_endpoint" pre_credential.output.json)
    data=$(jq_extract_raw "data" pre_credential.output.json)
    headers=$(jq_extract_raw "headers" pre_credential.output.json)
    curl -H 'Authorization: '"$(echo $headers | jq -r '.Authorization')"'' -H 'Content-Type: application/json' -X POST $url -d ''"$(echo $data)"'' 1> $TMP/out
    save_tmp_output post_credential.output.json
    # if --regexp resolve modify also here
    assert_output --partial '{"c_nonce":"'
    assert_output --partial '","c_nonce_expires_in":600,"credential":"eyJhbGciOiAiRVMyNTYiLCAidHlwIjogInZjK3NkLWp3dCJ9'
}

@test "Verifier generate qr [card_to_qr.zen]" {
    zexe $VERIFIER/card_to_qr.zen $VERIFIER/card_to_qr.data.json $VERIFIER/card_to_qr.keys.json
    save_tmp_output card_to_qr.output.json
    assert_output --regexp '^\{"intent-url":".*,"params_json":\{"exp":[0-9]{10},"id":"hn20gz30ync7sng","m":"f","rp":"http://localhost:3002/relying_party","ru":"https://admin\.didroom\.com/api/collections/templates_public_data/records\?filter=%28id%3D%224tusaoh7g5y6wyw%22%29&expand=organization","sid":"[A-Z2-9]{5}","t":"ehUYkktwQVWy_v9MXeTaf9:APA91bG28isX0dJJEzW6K5qA8N67-V7bZjYhEXYsWNyL_7xiJsBVTuKgEalgK_ajlK_6u2hY3tFlq0e649F4lhb909VHVfHGKrWFVb0uBdY61RmnLcxhwkltm2yyxxdXje1qWCavb281"\},"ru":"https://admin\.didroom\.com/api/collections/templates_public_data/records\?filter=%28id%3D%224tusaoh7g5y6wyw%22%29&expand=organization","sid":"[A-Z2-9]{5}"\}'
}

@test "Holder scan qr [ver_qr_to_info.zen]" {
    cred=$(jq ".credential" $BATS_FILE_TMPDIR/post_credential.output.json)
    jq_extract_raw "params_json" card_to_qr.output.json > $BATS_FILE_TMPDIR/temp_temp_vp.data.json
    jq ".credential_array = [$cred]" $BATS_FILE_TMPDIR/temp_temp_vp.data.json > $BATS_FILE_TMPDIR/ver_qr_to_info_test.data.json
    # scan_ver_qr_1
    zexe $WALLET/ver_qr_to_info_1_qr_checks.zen ver_qr_to_info_test.data.json $WALLET/ver_qr_to_info.keys.json
    save_tmp_output ver_qr_to_info_1_qr_checks.output.json
    # get rp_wk
    url=$(jq_extract_raw "rp_wk_endpoint" ver_qr_to_info_1_qr_checks.output.json)
    curl -X GET $url | jq -c '.' 1> $TMP/out
    save_tmp_output rp_wk_endpoint_response.json
    assert_output --partial '{"relying_party":"http://localhost:3002/relying_party","verification_endpoint":"http://localhost:3002/relying_party/verify","trusted_credential_issuers":["http://localhost:3001/credential_issuer"],"display":[{"name":"DIDroom_Test_RP","locale":"en-US"}],"jwks":{"keys":[{"kid":"did:dyne:sandbox.genericissuer:'
    assert_output --partial '#es256_public_key","crv":"P-256","alg":"ES256","kty":"EC"}]},"credential_configurations_supported":[{"format":"vc+sd-jwt","cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"credential_signing_alg_values_supported":["ES256"],"proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}}}]}'
    # get claims
    request_uri=$(jq_extract_raw "ru" ver_qr_to_info_test.data.json)
    curl -X GET $request_uri | jq -c '.' 1> $TMP/out
    save_tmp_output request_uri_response.json
    assert_output '{"page":1,"perPage":30,"totalItems":1,"totalPages":1,"items":[{"collectionId":"pnlj0s6ft78lewd","collectionName":"templates_public_data","description":"DO NOT DELETE!!! Used in test in DIDRoom_microservices and mobile_zencode","expand":{"organization":{"avatar":"canstockphoto22402523_arcos_creator_ugyRxVNFPN.com_-1024x1024-1.jpg","collectionId":"aako88kt3br4npt","collectionName":"organizations","created":"2024-06-13 12:27:25.636Z","description":"DO NOT DELETE! Used ot host test_credetial templates for tests on mobile_zencodde and DIDRoom_microservices","id":"2gxhjxdoonw8qjk","name":"Test credential organzation","updated":"2024-06-13 12:28:13.984Z"}},"id":"4tusaoh7g5y6wyw","name":"test_template","organization":"2gxhjxdoonw8qjk","public":false,"schema":{"type":"object","required":["tested"],"properties":{"tested":{"type":"string","title":"Is tested"}}},"type":"issuance"}]}'
    # prepare input for second script
    cat $BATS_FILE_TMPDIR/request_uri_response.json | jq '{"asked_claims": .items[0].schema}' > $TMP/out
    save_tmp_output asked_claims.json
    save_tmp_output ver_qr_to_info_2_vp.data.json
    json_join_two ver_qr_to_info_test.data.json ver_qr_to_info_2_vp.data.json
    jq_insert_json rp_wk rp_wk_endpoint_response.json ver_qr_to_info_2_vp.data.json
    # scan_ver_qr_2
    zexe $WALLET/ver_qr_to_info_2_vp.zen ver_qr_to_info_2_vp.data.json
    save_tmp_output ver_qr_to_info_2_vp.output.json
    assert_output --partial '{"vps":["eyJhbGciOiAiRVMyNTYiLCAidHlwIjogInZjK3NkLWp3dCJ9.'
    # prepare input for third script
    json_join_two ver_qr_to_info_test.data.json ver_qr_to_info_2_vp.output.json
    rp_name=$(jq -r '.display[0].name' $BATS_FILE_TMPDIR/rp_wk_endpoint_response.json)
    jq_insert "rp_name" $rp_name ver_qr_to_info_2_vp.output.json
    rp_verification_endpoint=$(jq -r '.verification_endpoint' $BATS_FILE_TMPDIR/rp_wk_endpoint_response.json)
    jq_insert "rp_verification_endpoint" $rp_verification_endpoint ver_qr_to_info_2_vp.output.json
    verifier_name="didroom microservices ci (DO NOT DELETE!)"
    jq_insert "verifier_name" "$verifier_name" ver_qr_to_info_2_vp.output.json
    org_avatar=$(jq -r '.items[0].expand.organization.avatar' $BATS_FILE_TMPDIR/request_uri_response.json)
    jq_insert "org_avatar" $org_avatar ver_qr_to_info_2_vp.output.json
    org_id=$(jq -r '.items[0].expand.organization.id' $BATS_FILE_TMPDIR/request_uri_response.json)
    jq_insert "org_id" $org_id ver_qr_to_info_2_vp.output.json
    org_collection_id=$(jq -r '.items[0].expand.organization.collectionId' $BATS_FILE_TMPDIR/request_uri_response.json)
    jq_insert "org_collection_id" $org_collection_id ver_qr_to_info_2_vp.output.json
    json_join_two asked_claims.json ver_qr_to_info_2_vp.output.json
    zexe $WALLET/ver_qr_to_info.zen ver_qr_to_info_2_vp.output.json
    save_tmp_output ver_qr_to_info.output.json
    assert_output --regexp '\{"info":\{"asked_claims":\{"properties":\{"tested":\{"title":"Is tested","type":"string"\}\},"required":\["tested"\],"type":"object"\},"avatar":\{"collection":"aako88kt3br4npt","fileName":"canstockphoto22402523_arcos_creator_ugyRxVNFPN\.com_-1024x1024-1\.jpg","id":"2gxhjxdoonw8qjk"\},"rp_name":"DIDroom_Test_RP","verifier_name":"didroom microservices ci \(DO NOT DELETE\!\)"\},"post_without_vp":\{"body":\{"id":"[A-Z2-9]{5}","m":"f","registrationToken":"ehUYkktwQVWy_v9MXeTaf9:APA91bG28isX0dJJEzW6K5qA8N67\-V7bZjYhEXYsWNyL_7xiJsBVTuKgEalgK_ajlK_6u2hY3tFlq0e649F4lhb909VHVfHGKrWFVb0uBdY61RmnLcxhwkltm2yyxxdXje1qWCavb281"\},"url":"http://localhost:3002/relying_party/verify"\},"vps":\["eyJhbGciOiAiRVMyNTYiLCAidHlwIjogInZjK3NkLWp3dCJ9\..*\]\}$'
}

@test "Holder send the vp" {
    vp=$(jq -r '.vps[0]' $BATS_FILE_TMPDIR/ver_qr_to_info.output.json)
    tmp=$(mktemp)
    jq --arg value "$vp" '.post_without_vp.body.vp = $value' $BATS_FILE_TMPDIR/ver_qr_to_info.output.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/ver_qr_to_info.output.json
    url=$(jq -r '.post_without_vp.url' $BATS_FILE_TMPDIR/ver_qr_to_info.output.json)
    body=$(jq -r '.post_without_vp.body' $BATS_FILE_TMPDIR/ver_qr_to_info.output.json)
    echo "$body"
    curl -X POST $url -H 'Content-Type: application/json' -d "$body" 1> $TMP/out
    save_tmp_output rp_response.json
    assert_output --regexp '\{"server_response":\{"result":\{"message":"eyJhbGciOiJFUzI1NiIsImp3ayI6eyJhbGciOiJFUzI1NiIsImNydiI6IlAtMjU2Iiwia2lkIjoiZGlkOmR5bmU6c2FuZGJveC5nZW5lcmljaXNzdWVyO.*","registrationToken":"ehUYkktwQVWy_v9MXeTaf9:APA91bG28isX0dJJEzW6K5qA8N67-V7bZjYhEXYsWNyL_7xiJsBVTuKgEalgK_ajlK_6u2hY3tFlq0e649F4lhb909VHVfHGKrWFVb0uBdY61RmnLcxhwkltm2yyxxdXje1qWCavb281"\},"status":"200"\}\}'
    message=$(jq -r '.server_response.result.message' $BATS_FILE_TMPDIR/rp_response.json)
    echo "{}" >$TMP/out
    save_tmp_output clear_rp_response.out.json
    jq_insert "message" $message clear_rp_response.out.json
}

@test "Verifier retrieve id from message [jws_to_id.zen]" {
    id=$(jq_extract_raw "sid" card_to_qr.output.json)
    zexe $VERIFIER/jws_to_id.zen clear_rp_response.out.json
    save_tmp_output jws_to_id.output.json
    assert_output "{\"id\":\"$id\"}"
}

@test "Verifier verify jws [verify.zen]" {
    # verify_1
    claim_url=$(jq_extract_raw "ru" card_to_qr.output.json)
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
