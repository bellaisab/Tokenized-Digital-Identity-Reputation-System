;; Interaction Tracking Contract
;; Records and analyzes identity usage patterns

(define-constant ERR_INVALID_INTERACTION (err u300))
(define-constant ERR_IDENTITY_NOT_FOUND (err u301))

;; Data structures
(define-map interactions
  { interaction-id: uint }
  {
    identity-id: (string-ascii 64),
    service-provider: principal,
    interaction-type: (string-ascii 20),
    timestamp: uint,
    success: bool,
    risk-score: uint
  }
)

(define-map identity-stats
  { identity-id: (string-ascii 64) }
  {
    total-interactions: uint,
    successful-interactions: uint,
    failed-interactions: uint,
    last-interaction: uint,
    average-risk-score: uint
  }
)

(define-data-var next-interaction-id uint u1)

;; Record a new interaction
(define-public (record-interaction
  (identity-id (string-ascii 64))
  (service-provider principal)
  (interaction-type (string-ascii 20))
  (success bool)
  (risk-score uint)
)
  (let ((interaction-id (var-get next-interaction-id)))
    (asserts! (<= risk-score u100) ERR_INVALID_INTERACTION)

    ;; Record the interaction
    (map-set interactions
      { interaction-id: interaction-id }
      {
        identity-id: identity-id,
        service-provider: service-provider,
        interaction-type: interaction-type,
        timestamp: block-height,
        success: success,
        risk-score: risk-score
      }
    )

    ;; Update identity statistics
    (match (map-get? identity-stats { identity-id: identity-id })
      current-stats
      (let (
        (new-total (+ (get total-interactions current-stats) u1))
        (new-successful (if success (+ (get successful-interactions current-stats) u1) (get successful-interactions current-stats)))
        (new-failed (if success (get failed-interactions current-stats) (+ (get failed-interactions current-stats) u1)))
        (new-avg-risk (/ (+ (* (get average-risk-score current-stats) (get total-interactions current-stats)) risk-score) new-total))
      )
        (map-set identity-stats
          { identity-id: identity-id }
          {
            total-interactions: new-total,
            successful-interactions: new-successful,
            failed-interactions: new-failed,
            last-interaction: block-height,
            average-risk-score: new-avg-risk
          }
        )
      )
      ;; First interaction for this identity
      (map-set identity-stats
        { identity-id: identity-id }
        {
          total-interactions: u1,
          successful-interactions: (if success u1 u0),
          failed-interactions: (if success u0 u1),
          last-interaction: block-height,
          average-risk-score: risk-score
        }
      )
    )

    (var-set next-interaction-id (+ interaction-id u1))
    (ok interaction-id)
  )
)

;; Get interaction details
(define-read-only (get-interaction (interaction-id uint))
  (map-get? interactions { interaction-id: interaction-id })
)

;; Get identity statistics
(define-read-only (get-identity-stats (identity-id (string-ascii 64)))
  (map-get? identity-stats { identity-id: identity-id })
)

;; Calculate success rate
(define-read-only (get-success-rate (identity-id (string-ascii 64)))
  (match (map-get? identity-stats { identity-id: identity-id })
    stats
    (if (> (get total-interactions stats) u0)
      (some (/ (* (get successful-interactions stats) u100) (get total-interactions stats)))
      none
    )
    none
  )
)

;; Check if identity is active (interacted recently)
(define-read-only (is-identity-active (identity-id (string-ascii 64)) (blocks-threshold uint))
  (match (map-get? identity-stats { identity-id: identity-id })
    stats
    (>= (get last-interaction stats) (- block-height blocks-threshold))
    false
  )
)
