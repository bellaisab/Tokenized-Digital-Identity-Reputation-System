;; Reputation Portability Contract
;; Enables reputation transfer between platforms and services

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INVALID_TRANSFER (err u501))
(define-constant ERR_TRANSFER_EXISTS (err u502))

;; Data structures
(define-map reputation-exports
  { export-id: uint }
  {
    identity-id: (string-ascii 64),
    source-platform: principal,
    target-platform: principal,
    reputation-data: (string-ascii 500),
    export-timestamp: uint,
    verified: bool,
    expiry-block: uint
  }
)

(define-map platform-integrations
  { platform: principal }
  {
    name: (string-ascii 50),
    verified: bool,
    integration-type: (string-ascii 20),
    api-endpoint: (string-ascii 100)
  }
)

(define-map identity-portability-settings
  { identity-id: (string-ascii 64) }
  {
    allow-export: bool,
    auto-sync: bool,
    privacy-level: uint,
    authorized-platforms: (list 10 principal)
  }
)

(define-data-var next-export-id uint u1)

;; Register a platform for reputation integration
(define-public (register-platform
  (name (string-ascii 50))
  (integration-type (string-ascii 20))
  (api-endpoint (string-ascii 100))
)
  (begin
    (map-set platform-integrations
      { platform: tx-sender }
      {
        name: name,
        verified: false,
        integration-type: integration-type,
        api-endpoint: api-endpoint
      }
    )
    (ok true)
  )
)

;; Configure portability settings for an identity
(define-public (configure-portability
  (identity-id (string-ascii 64))
  (allow-export bool)
  (auto-sync bool)
  (privacy-level uint)
  (authorized-platforms (list 10 principal))
)
  (begin
    (map-set identity-portability-settings
      { identity-id: identity-id }
      {
        allow-export: allow-export,
        auto-sync: auto-sync,
        privacy-level: privacy-level,
        authorized-platforms: authorized-platforms
      }
    )
    (ok true)
  )
)

;; Export reputation data
(define-public (export-reputation
  (identity-id (string-ascii 64))
  (target-platform principal)
  (reputation-data (string-ascii 500))
  (expiry-blocks uint)
)
  (let ((export-id (var-get next-export-id)))
    (match (map-get? identity-portability-settings { identity-id: identity-id })
      settings
      (begin
        (asserts! (get allow-export settings) ERR_UNAUTHORIZED)
        (asserts! (is-some (index-of (get authorized-platforms settings) target-platform)) ERR_UNAUTHORIZED)

        (map-set reputation-exports
          { export-id: export-id }
          {
            identity-id: identity-id,
            source-platform: tx-sender,
            target-platform: target-platform,
            reputation-data: reputation-data,
            export-timestamp: block-height,
            verified: false,
            expiry-block: (+ block-height expiry-blocks)
          }
        )

        (var-set next-export-id (+ export-id u1))
        (ok export-id)
      )
      ERR_UNAUTHORIZED
    )
  )
)

;; Verify reputation export
(define-public (verify-export (export-id uint))
  (match (map-get? reputation-exports { export-id: export-id })
    export-data
    (begin
      (asserts! (is-eq tx-sender (get target-platform export-data)) ERR_UNAUTHORIZED)
      (asserts! (< block-height (get expiry-block export-data)) ERR_INVALID_TRANSFER)

      (map-set reputation-exports
        { export-id: export-id }
        (merge export-data { verified: true })
      )
      (ok true)
    )
    ERR_INVALID_TRANSFER
  )
)

;; Get export details
(define-read-only (get-export (export-id uint))
  (map-get? reputation-exports { export-id: export-id })
)

;; Get platform integration info
(define-read-only (get-platform-integration (platform principal))
  (map-get? platform-integrations { platform: platform })
)

;; Get portability settings
(define-read-only (get-portability-settings (identity-id (string-ascii 64)))
  (map-get? identity-portability-settings { identity-id: identity-id })
)

;; Check if export is valid and not expired
(define-read-only (is-export-valid (export-id uint))
  (match (map-get? reputation-exports { export-id: export-id })
    export-data
    (and
      (get verified export-data)
      (< block-height (get expiry-block export-data))
    )
    false
  )
)
