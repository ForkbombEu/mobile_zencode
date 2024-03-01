### OpenID4VC flow

```mermaid 
sequenceDiagram 
autonumber
  participant H as Holder Wallet
  participant S1 as Script 1 to /par
  participant S3 as Script 3 to /token
  participant A as API /authorize
  participant P as API /par
  participant T as API /token
  participant DID as W3C-DID service
  
  H->>H: Scans QR code with CI url  
  H->>S1: Send QR code content to "!external-qr-code-content"
  S1->>S1: Read "keyring"
  S1->>S1: Read "client_id" (DID)
  S1->>S1: Read "credential_request_specific_data" 

  S1->>S1: Execute zencode and produce "client" and "request" and "code verifier"
  S1->>H: Store "code verifier" in a state
  S1->>P: Pass "client" and "request"
  P->>H: return "request_uri" and "expires_in" 


```
Glossary: 

Script 1: [Script 1](https://github.com/ForkbombEu/mobile_zencode/blob/main/wallet/1_holder_to_authorize_on_authz_server.zen)

# Auth Flow Chart

## Script 1
```mermaid
flowchart LR
    A[CI url QR] -->|!external-qr-code-content| B
    D[Holder DID] -->|client_id| B
    K[Keyring] --> B
    R[Cred Req] -->|cred_req_spec_data| B
    B{Holder wallet}
    B ==>|script 1| code_ver>code verifier]
    B -->|script 1| client -->|http| par{API /par\nauthz server}
    B -->|script 1| request -->|http| par
    par --> exp[expires_in] .->|http| B
    par --> requr>request_uri] ==>|http| B
```

## Script 3
```mermaid
flowchart LR
    requri -->|http| requri
    requri[request uri] -->|authCode_jwt| W
    W{Holder Wallet}
    codever[code verifier] --> W
    D[holder DID] -->|client_id| W
    K[keyring] --> W
    trsd((token request\nspecific data)) --> W
    A[CI url QR] -->|!external-qr-code-content| W
    W .->|timestamp| W
    W -->|script 3| acj[authCode_jwt] -->|http| authz{API /token\nauthz server}
    W -->|script 3| req[request] -->|http| authz
    authz ==> tok>accessToken_jwt] ==>|http| W
```
