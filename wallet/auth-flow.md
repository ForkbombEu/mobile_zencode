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

  S1->>S1: Execute zencode and produce "clientSecret", "client_id", "code_challenge", "code_challenge_method", "redirect_uri", "resource", "response_type", "scope", "state" and "code_verifier"
  S1->>H: Store "code verifier" in a state
  S1->>P: Pass all the others to PAR endpoint
  P->>H: return "request_uri" and "expires_in" 


```
Glossary: 

Script 1: [Script 1](https://github.com/ForkbombEu/mobile_zencode/blob/main/wallet/1_holder_to_par_on_authz_server.zen)

# Auth Flow Chart

## Script 1
```mermaid
flowchart LR
    A((CI url QR)) -->|!external-qr-code-content| B
    D((Holder DID)) -->|client_id| B
    K((Keyring)) --> B
    R((Oauth Flow\nParameters)) -->|spec_data\nredirect uri| B
    B{Holder wallet\nScript 1}
    B ==>|save| qr>qr-code]
    B ==>|save| id>client id]
    B ==>|save| code_verifier>code verifier]
    B --> par_input[par input] -->|http| par{API /par\nauthz server}
    par --> exp[expires_in] .->|http| B
    B ==>|save| requr>request_uri]
    par -->requr
    par_input-->|copy out|redur
    B ==>|save| redur>redirect uri]
```

## Script 3
```mermaid
flowchart LR
    R((Oauth Flow\nParameters)) -->|auth endpoint| W
    requri>request uri] --> W
    id>client id] --> W
    qr>qr-code] --> W
    W{Holder Wallet\nScript 3}
    W -->|auth server\n + auth endpoint\n + request uri\n + client id| authz{API /authorize\nauthz server}
    authz --> tok>code]
    W ==>|save| tok
```


## Script 5
```mermaid
flowchart LR
    K((Keyring)) --> W
    R((Oauth Flow\nParameters)) --> W
    qr>qr-code] --> W
    jwt>code] --> W
    W{Holder Wallet\nScript 5}
    codever>code verifier] --> W
    id>client id] --> W
    W .->|timestamp| W
    W -->|http| authz{API /token\nauthz server}
    authz --> tok>accessToken_jwt]
    W ==>|save| tok
```


