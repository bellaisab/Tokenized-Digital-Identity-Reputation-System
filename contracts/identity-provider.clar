;; Identity Provider Verification Contract
;; Validates credential issuers and manages their registration

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_EXISTS (err u101))
(define-constant ERR_PROVIDER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_PROVIDER (err u103))

;; Data structures
(define-map identity-providers
  { provider-id: uint }
  {
    name: (string-ascii 50),
    owner: principal,
    verified: bool,
    registration-block: uint,
    reputation-score: uint
  }
)

(define-map provider-by-principal
  { owner: principal }
  { provider-id: uint }
)

(define-data-var next-provider-id uint u1)

;; Register a new identity provider
(define-public (register-provider (name (string-ascii 50)))
  (let ((provider-id (var-get next-provider-id)))
    (asserts! (is-none (map-get? provider-by-principal { owner: tx-sender })) ERR_PROVIDER_EXISTS)
    (map-set identity-providers
      { provider-id: provider-id }
      {
        name: name,
        owner: tx-sender,
        verified: false,
        registration-block: block-height,
        reputation-score: u50
      }
    )
    (map-set provider-by-principal
      { owner: tx-sender }
      { provider-id: provider-id }
    )
    (var-set next-provider-id (+ provider-id u1))
    (ok provider-id)
  )
)

;; Verify an identity provider (only contract owner)
(define-public (verify-provider (provider-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? identity-providers { provider-id: provider-id })
      provider-data
      (begin
        (map-set identity-providers
          { provider-id: provider-id }
          (merge provider-data { verified: true })
        )
        (ok true)
      )
      ERR_PROVIDER_NOT_FOUND
    )
  )
)

;; Get provider information
(define-read-only (get-provider (provider-id uint))
  (map-get? identity-providers { provider-id: provider-id })
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider-id uint))
  (match (map-get? identity-providers { provider-id: provider-id })
    provider-data (get verified provider-data)
    false
  )
)

;; Get provider by principal
(define-read-only (get-provider-by-principal (owner principal))
  (map-get? provider-by-principal { owner: owner })
)
