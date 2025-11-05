load ./bats_setup
load ./bats_utils

@test "Zenroom is executable installed" {
    zenroom="$(which zenroom)"
    assert_file_executable "$zenroom"
}
@test "Holder read cred_iss well-known from qr" {
    jq '."!external-qr-code-content"' $WALLET/holder_qr_to_well-known.data.json > $BATS_FILE_TMPDIR/offer.json
    zexe $WALLET/holder_qr_to_well-known_1_read_issuer.zen offer.json
    save_tmp_output read_credential_issuer.output.json
    url=$(jq_extract_raw "credential_issuer" read_credential_issuer.output.json)
    curl -X GET $url | jq -c '.' 1> $TMP/out
    save_tmp_output credential_issuer_well-known.output.json
    assert_output --partial '"credential_issuer":"http://localhost:3001/credential_issuer"'
    assert_output --partial '"test_credential":'
    assert_output --partial '"UniversityDegree_LDP_VC":'
    echo "{\"result\":$(cat $BATS_FILE_TMPDIR/credential_issuer_well-known.output.json)}" > $TMP/out
    save_tmp_output cred_issuer.output.json
    jq_insert_json "credential_offer" offer.json cred_issuer.output.json
}

@test "Holder read authz_server well-known" {
    zexe $WALLET/holder_qr_to_well-known_2_extract_authz_server.zen cred_issuer.output.json
    save_tmp_output read_authz_server.output.json
    url=$(jq_extract_raw "authorization_server" read_authz_server.output.json)
    curl -X GET $url | jq -c '.' 1> $TMP/out
    save_tmp_output authz_server_well-known.output.json
    assert_output --partial '"authorization_endpoint":"http://localhost:3000/authz_server/authorize"'
}

@test "Holder output credential_requested and credential_parameters" {
    echo "{}" >$TMP/out
    save_tmp_output holder_qr_to_well-known.data.json 
    jq_insert_json extract_authz_server_out read_authz_server.output.json holder_qr_to_well-known.data.json
    tmp=$(mktemp)
    jq --arg key "authorization_server_well-known" '.[$key].result = input' $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json $BATS_FILE_TMPDIR/authz_server_well-known.output.json > $tmp && mv $tmp  $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json
    jq --arg key "credential_issuer_well-known" '.[$key].result = input' $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json $BATS_FILE_TMPDIR/credential_issuer_well-known.output.json > $tmp && mv $tmp  $BATS_FILE_TMPDIR/holder_qr_to_well-known.data.json
    zexe $WALLET/holder_qr_to_well-known.zen $WALLET/holder_qr_to_well-known.keys.json holder_qr_to_well-known.data.json
    save_tmp_output holder_qr_to_well-known.output.json
    assert_output --partial '{"credential_issuer_information":{"authorization_servers":["http://localhost:3000/authz_server"],"credential_endpoint":"http://localhost:3001/credential_issuer/credential","credential_issuer":"http://localhost:3001/credential_issuer","display":[{"locale":"en-US","name":"DIDroom_Test_Issuer"}],"jwks":{"keys":[{"alg":"ES256","crv":"P-256","kid":"did:dyne:sandbox.genericissuer:'
    assert_output --partial 'es256_public_key","kty":"EC"}]},"nonce_endpoint":"http://localhost:3001/credential_issuer/nonce"},"credential_parameters":{"authorization_endpoint":"http://localhost:3000/authz_server/authorize","authorization_server_endpoint_par":"http://localhost:3000/authz_server/par","code_challenge_method":"S256","credential_configuration_id":"test_credential","credential_endpoint":"http://localhost:3001/credential_issuer/credential","credential_issuer":"http://localhost:3001/credential_issuer","format":"dc+sd-jwt","grant_type":"authorization_code","nonce_endpoint":"http://localhost:3001/credential_issuer/nonce","response_type":"code","token_endpoint":"http://localhost:3000/authz_server/token"},"credential_requested":{"claims":[{"display":[{"locale":"en-US","name":"Is tested"}],"mandatory":true,"path":["tested"]}],"credential_signing_alg_values_supported":["ES256"],"cryptographic_binding_methods_supported":["jwk","did:dyne:sandbox.signroom"],"display":[{"background_color":"#12107c","description":"a description","locale":"en-US","logo":{"alt_text":"Test Logo","uri":"https://www.connetweb.com/wp-content/uploads/2021/06/canstockphoto22402523-arcos-creator.com_-1024x1024-1.jpg"},"name":"Tested Credential","text_color":"#FFFFFF"}],"format":"dc+sd-jwt","proof_types_supported":{"jwt":{"proof_signing_alg_values_supported":["ES256"]}},"vct":"test_credential"}}'
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
    echo "form_input_and_params=$(urlencode '{"params":{"request_uri":"'"${request_uri}"'","client_id":"'"${client_id}"'"},"data":{"email":"test@email.com","password":"password"},"custom_code":"'"${cci}"'"}')" > $TMP/out
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
    dpop=$(jq_extract_raw "DPoP" pre_token.output.json)
    curl -X POST $url -H 'Content-Type: application/x-www-form-urlencoded' -H "DPoP: ${dpop}" -d ''"$(echo $data)"'' 1> $TMP/out
    save_tmp_output post_token.output.json
    # if --regexp resolve modify also here
    assert_output --partial '{"token_type":"bearer","access_token":"eyJhbGciOiJFUzI1NiIsImp3ayI6eyJrdHkiOiJFQyIsIngiO'
    assert_output --partial ',"authorization_details":[{"credential_configuration_id":"test_credential","locations":["http://localhost:3001/credential_issuer"],"type":"openid_credential","claims":{"id":"123456789"}}]}'
}

@test "Holder get to credantial_issuer/nonce" {
    nonce_endpoint=$(jq_extract_raw "nonce_endpoint" credential_issuer_well-known.output.json)
    curl -X GET $nonce_endpoint | jq -c '.' 1> $TMP/out
    save_tmp_output post_nonce.output.json
    assert_output --partial '{"c_nonce":"'
}

@test "Holder post to credantial_issuer/credential [pre_credential.zen]" {
    json_join_two holder_qr_to_well-known.output.json post_token.output.json
    json_join_two post_nonce.output.json post_token.output.json
    zexe $WALLET/pre_credential.zen $WALLET/call_token_and_credential.keys.json post_token.output.json
    save_tmp_output pre_credential.output.json
    url=$(jq_extract_raw "credential_endpoint" pre_credential.output.json)
    data=$(jq_extract_raw "data" pre_credential.output.json)
    headers=$(jq_extract_raw "headers" pre_credential.output.json)
    curl -H 'Authorization: '"$(echo $headers | jq -r '.Authorization')"'' -H 'Content-Type: application/json' -X POST $url -d ''"$(echo $data)"'' 1> $TMP/out
    save_tmp_output post_credential.output.json
    # if --regexp resolve modify also here
    assert_output --partial '{"credentials":[{"credential":"eyJhbGciOiAiRVMyNTYiLCAidHlwIjogImRjK3NkLWp3dCJ9'
}

@test "Verifier generate qr" {
    curl -H 'Content-Type: application/json' -X POST "http://localhost:3002/verifier/generate_authorization_request" -d '{"response_mode":"direct_post","response_type":"vp_token","dcql_query":{"credentials":[{"id":"test_presentation","format":"dc+sd-jwt","meta":{"vct_values":["test_credential"]},"claims":[{"path":["tested"]}]}]},"url":"http://localhost:3002/verifier/"}' 1> $TMP/out
    save_tmp_output qr.output.json
}

@test "Holder scan qr [openid4vp_qr_to_info.zen]" {
    request_url=$(jq -r ".params_json.request_uri" $BATS_FILE_TMPDIR/qr.output.json)
    request=$(curl -X GET "$request_url")
    cred=$(jq -r ".credentials[0].credential" $BATS_FILE_TMPDIR/post_credential.output.json)
    jq_extract_raw "params_json" qr.output.json > $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json

    tmp=$(mktemp)
    jq ".credentials.ldp_vc = []" $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json
    jq --arg cred $cred '.credentials["dc+sd-jwt"] = [$cred]' $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json
    jq ".request.result = \"$request\"" $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json
    jq ".rdfs_base64.serializations = []" $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json
    jq ".obj = []" $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json
    # scan_ver_qr_1 (did)
    echo "{}" > $BATS_FILE_TMPDIR/openid4vp_qr_to_info_1_did.data.json
    jq ".result = \"$request\"" $BATS_FILE_TMPDIR/openid4vp_qr_to_info_1_did.data.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/openid4vp_qr_to_info_1_did.data.json
    zexe $WALLET/openid4vp_qr_to_info_1_did.zencode openid4vp_qr_to_info_1_did.data.json
    save_tmp_output openid4vp_qr_to_info_1_did.output.json
    id=$(jq_extract_raw "id" openid4vp_qr_to_info_1_did.output.json)
    p=$(jq -c ".payload" $BATS_FILE_TMPDIR/openid4vp_qr_to_info_1_did.output.json)
    did=$(curl -X GET "https://did.dyne.org/dids/${id}")
    jq --arg did $did ".client_id_did = $did" $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json
    jq --arg p $p ".payload = $p" $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json
    # scan_ver_qr_2 (dcql)
    zexe $WALLET/openid4vp_qr_to_info_2_dcql.zencode openid4vp_qr_to_info.data.json
    save_tmp_output openid4vp_qr_to_info_2_dcql.output.json
    mc=$(jq -c ".matching_credentials" $BATS_FILE_TMPDIR/openid4vp_qr_to_info_2_dcql.output.json)
    jq --arg mc $mc ".matching_credentials_out.matching_credentials = $mc" $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json
    # scan_ver_qr
    jq ".pre_canon_out.serialization_map = {}" $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json > $tmp && mv $tmp $BATS_FILE_TMPDIR/openid4vp_qr_to_info.data.json
    zexe $WALLET/openid4vp_qr_to_info.zen openid4vp_qr_to_info.data.json $WALLET/openid4vp_qr_to_info.keys.json
    save_tmp_output openid4vp_qr_to_info.output.json
    assert_output --regexp '\{"dcql_query":\{"credentials":\[\{"claims":\[\{"path":\["tested"]\}\],"format":"dc+sd-jwt","id":"test_presentation","meta":\{"vct_values":\["test_credential"\]\}\}\]\},"post_url":"http://localhost:3002/verifier/response/.*","vps":\[\{"matching_credential_sets":\[\{"test_presentation":\[\{"card":".*","signed":".*"\}\]\}\],"required":true\}\]\}'
}

@test "Holder present the vp" {
    sleep 2
    vp=$(jq -r '.vps[0].matching_credential_sets[0].test_presentation[0].signed' $BATS_FILE_TMPDIR/openid4vp_qr_to_info.output.json)
    url=$(jq_extract_raw "post_url" openid4vp_qr_to_info.output.json)
    echo "{\"body\": {\"vp_token\": {\"test_presentation\": [\"${vp}\"]}}, \"url\": \"${url}\"}" > $BATS_FILE_TMPDIR/openid4vp_response.data.json
    zexe $WALLET/openid4vp_response.zen $WALLET/openid4vp_response.keys.json openid4vp_response.data.json
    save_tmp_output openid4vp_response.output.json
    body=$(jq_extract_raw "http_get_parameters" openid4vp_response.output.json)
    curl -H 'Content-Type: application/x-www-form-urlencoded' -X POST $url -d "${body}" 1> $TMP/out
    save_tmp_output verifier_response.output.json
    assert_output '{"redirect_uri":"https://redirect.example.org/path","transaction_result":[{"path":["tested"],"value":"true"}]}'
}

@test "checks transaction id" {
    id=$(jq_extract_raw "transaction_id" qr.output.json)
    curl -X GET "http://localhost:3002/verifier/$id" 1> $TMP/out
    save_tmp_output card_to_qr.output.json
    assert_output '[{"path":["tested"],"value":"true"}]'
}
