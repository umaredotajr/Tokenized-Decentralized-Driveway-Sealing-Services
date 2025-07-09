;; Longevity Tracking Contract
;; Monitors seal effectiveness over time

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_RECORD_NOT_FOUND (err u501))
(define-constant ERR_INVALID_PERFORMANCE_SCORE (err u502))
(define-constant ERR_INVALID_DATE (err u503))
(define-constant ERR_WARRANTY_EXPIRED (err u504))

;; Data Variables
(define-data-var next-tracking-id uint u1)
(define-data-var total-tracking-records uint u0)

;; Data Maps
(define-map performance-records
  { tracking-id: uint }
  {
    application-id: uint,
    property-id: uint,
    installation-date: uint,
    warranty-period: uint,
    expected-lifespan: uint,
    current-condition: uint,
    last-inspection: uint,
    maintenance-count: uint,
    weather-exposure: uint,
    traffic-level: uint,
    created-by: principal,
    created-at: uint
  }
)

(define-map inspection-history
  { tracking-id: uint, inspection-id: uint }
  {
    inspector: principal,
    inspection-date: uint,
    condition-score: uint,
    crack-development: uint,
    color-retention: uint,
    adhesion-quality: uint,
    wear-patterns: (string-ascii 100),
    maintenance-needed: bool,
    estimated-remaining-life: uint,
    notes: (string-ascii 200)
  }
)

(define-map maintenance-records
  { tracking-id: uint, maintenance-id: uint }
  {
    maintenance-type: (string-ascii 50),
    maintenance-date: uint,
    cost: uint,
    performed-by: principal,
    materials-used: (string-ascii 100),
    condition-before: uint,
    condition-after: uint,
    notes: (string-ascii 200)
  }
)

(define-map warranty-claims
  { tracking-id: uint, claim-id: uint }
  {
    claim-date: uint,
    claim-type: (string-ascii 50),
    issue-description: (string-ascii 200),
    claim-amount: uint,
    is-approved: bool,
    resolution-date: uint,
    claimant: principal
  }
)

(define-map tracking-counters
  { tracking-id: uint }
  {
    inspection-count: uint,
    maintenance-count: uint,
    claim-count: uint
  }
)

;; Public Functions

;; Create performance tracking record
(define-public (create-performance-record
  (application-id uint)
  (property-id uint)
  (installation-date uint)
  (warranty-period uint)
  (expected-lifespan uint)
  (traffic-level uint)
)
  (let
    (
      (tracking-id (var-get next-tracking-id))
    )
    (asserts! (> warranty-period u0) ERR_INVALID_DATE)
    (asserts! (> expected-lifespan warranty-period) ERR_INVALID_DATE)
    (asserts! (and (>= traffic-level u1) (<= traffic-level u5)) ERR_INVALID_PERFORMANCE_SCORE)

    (map-set performance-records
      { tracking-id: tracking-id }
      {
        application-id: application-id,
        property-id: property-id,
        installation-date: installation-date,
        warranty-period: warranty-period,
        expected-lifespan: expected-lifespan,
        current-condition: u10,
        last-inspection: installation-date,
        maintenance-count: u0,
        weather-exposure: u0,
        traffic-level: traffic-level,
        created-by: tx-sender,
        created-at: block-height
      }
    )
    (map-set tracking-counters
      { tracking-id: tracking-id }
      {
        inspection-count: u0,
        maintenance-count: u0,
        claim-count: u0
      }
    )
    (var-set next-tracking-id (+ tracking-id u1))
    (var-set total-tracking-records (+ (var-get total-tracking-records) u1))
    (ok tracking-id)
  )
)

;; Record inspection
(define-public (record-inspection
  (tracking-id uint)
  (condition-score uint)
  (crack-development uint)
  (color-retention uint)
  (adhesion-quality uint)
  (wear-patterns (string-ascii 100))
  (maintenance-needed bool)
  (estimated-remaining-life uint)
  (notes (string-ascii 200))
)
  (let
    (
      (record (unwrap! (map-get? performance-records { tracking-id: tracking-id }) ERR_RECORD_NOT_FOUND))
      (counters (default-to { inspection-count: u0, maintenance-count: u0, claim-count: u0 }
                 (map-get? tracking-counters { tracking-id: tracking-id })))
      (new-inspection-id (+ (get inspection-count counters) u1))
    )
    (asserts! (and (>= condition-score u1) (<= condition-score u10)) ERR_INVALID_PERFORMANCE_SCORE)
    (asserts! (and (>= crack-development u1) (<= crack-development u5)) ERR_INVALID_PERFORMANCE_SCORE)
    (asserts! (and (>= color-retention u1) (<= color-retention u10)) ERR_INVALID_PERFORMANCE_SCORE)
    (asserts! (and (>= adhesion-quality u1) (<= adhesion-quality u10)) ERR_INVALID_PERFORMANCE_SCORE)

    (map-set inspection-history
      { tracking-id: tracking-id, inspection-id: new-inspection-id }
      {
        inspector: tx-sender,
        inspection-date: block-height,
        condition-score: condition-score,
        crack-development: crack-development,
        color-retention: color-retention,
        adhesion-quality: adhesion-quality,
        wear-patterns: wear-patterns,
        maintenance-needed: maintenance-needed,
        estimated-remaining-life: estimated-remaining-life,
        notes: notes
      }
    )

    ;; Update performance record
    (map-set performance-records
      { tracking-id: tracking-id }
      (merge record {
        current-condition: condition-score,
        last-inspection: block-height
      })
    )

    ;; Update counters
    (map-set tracking-counters
      { tracking-id: tracking-id }
      (merge counters { inspection-count: new-inspection-id })
    )
    (ok new-inspection-id)
  )
)

;; Record maintenance
(define-public (record-maintenance
  (tracking-id uint)
  (maintenance-type (string-ascii 50))
  (cost uint)
  (materials-used (string-ascii 100))
  (condition-before uint)
  (condition-after uint)
  (notes (string-ascii 200))
)
  (let
    (
      (record (unwrap! (map-get? performance-records { tracking-id: tracking-id }) ERR_RECORD_NOT_FOUND))
      (counters (default-to { inspection-count: u0, maintenance-count: u0, claim-count: u0 }
                 (map-get? tracking-counters { tracking-id: tracking-id })))
      (new-maintenance-id (+ (get maintenance-count counters) u1))
    )
    (asserts! (and (>= condition-before u1) (<= condition-before u10)) ERR_INVALID_PERFORMANCE_SCORE)
    (asserts! (and (>= condition-after u1) (<= condition-after u10)) ERR_INVALID_PERFORMANCE_SCORE)
    (asserts! (>= condition-after condition-before) ERR_INVALID_PERFORMANCE_SCORE)

    (map-set maintenance-records
      { tracking-id: tracking-id, maintenance-id: new-maintenance-id }
      {
        maintenance-type: maintenance-type,
        maintenance-date: block-height,
        cost: cost,
        performed-by: tx-sender,
        materials-used: materials-used,
        condition-before: condition-before,
        condition-after: condition-after,
        notes: notes
      }
    )

    ;; Update performance record
    (map-set performance-records
      { tracking-id: tracking-id }
      (merge record {
        current-condition: condition-after,
        maintenance-count: (+ (get maintenance-count record) u1)
      })
    )

    ;; Update counters
    (map-set tracking-counters
      { tracking-id: tracking-id }
      (merge counters { maintenance-count: new-maintenance-id })
    )
    (ok new-maintenance-id)
  )
)

;; Submit warranty claim
(define-public (submit-warranty-claim
  (tracking-id uint)
  (claim-type (string-ascii 50))
  (issue-description (string-ascii 200))
  (claim-amount uint)
)
  (let
    (
      (record (unwrap! (map-get? performance-records { tracking-id: tracking-id }) ERR_RECORD_NOT_FOUND))
      (counters (default-to { inspection-count: u0, maintenance-count: u0, claim-count: u0 }
                 (map-get? tracking-counters { tracking-id: tracking-id })))
      (new-claim-id (+ (get claim-count counters) u1))
      (warranty-end (+ (get installation-date record) (get warranty-period record)))
    )
    (asserts! (< block-height warranty-end) ERR_WARRANTY_EXPIRED)
    (asserts! (> claim-amount u0) ERR_INVALID_PERFORMANCE_SCORE)

    (map-set warranty-claims
      { tracking-id: tracking-id, claim-id: new-claim-id }
      {
        claim-date: block-height,
        claim-type: claim-type,
        issue-description: issue-description,
        claim-amount: claim-amount,
        is-approved: false,
        resolution-date: u0,
        claimant: tx-sender
      }
    )

    ;; Update counters
    (map-set tracking-counters
      { tracking-id: tracking-id }
      (merge counters { claim-count: new-claim-id })
    )
    (ok new-claim-id)
  )
)

;; Approve warranty claim
(define-public (approve-warranty-claim (tracking-id uint) (claim-id uint))
  (let
    (
      (claim (unwrap! (map-get? warranty-claims { tracking-id: tracking-id, claim-id: claim-id }) ERR_RECORD_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set warranty-claims
      { tracking-id: tracking-id, claim-id: claim-id }
      (merge claim {
        is-approved: true,
        resolution-date: block-height
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get performance record
(define-read-only (get-performance-record (tracking-id uint))
  (map-get? performance-records { tracking-id: tracking-id })
)

;; Get inspection history
(define-read-only (get-inspection (tracking-id uint) (inspection-id uint))
  (map-get? inspection-history { tracking-id: tracking-id, inspection-id: inspection-id })
)

;; Get maintenance record
(define-read-only (get-maintenance-record (tracking-id uint) (maintenance-id uint))
  (map-get? maintenance-records { tracking-id: tracking-id, maintenance-id: maintenance-id })
)

;; Get warranty claim
(define-read-only (get-warranty-claim (tracking-id uint) (claim-id uint))
  (map-get? warranty-claims { tracking-id: tracking-id, claim-id: claim-id })
)

;; Get tracking counters
(define-read-only (get-tracking-counters (tracking-id uint))
  (default-to { inspection-count: u0, maintenance-count: u0, claim-count: u0 }
              (map-get? tracking-counters { tracking-id: tracking-id }))
)

;; Check warranty status
(define-read-only (check-warranty-status (tracking-id uint))
  (match (map-get? performance-records { tracking-id: tracking-id })
    record
      (let
        (
          (warranty-end (+ (get installation-date record) (get warranty-period record)))
        )
        (ok {
          is-under-warranty: (< block-height warranty-end),
          warranty-end: warranty-end,
          days-remaining: (if (< block-height warranty-end) (- warranty-end block-height) u0)
        })
      )
    ERR_RECORD_NOT_FOUND
  )
)

;; Calculate performance score
(define-read-only (calculate-performance-score (tracking-id uint))
  (match (map-get? performance-records { tracking-id: tracking-id })
    record
      (let
        (
          (age (- block-height (get installation-date record)))
          (expected-age (get expected-lifespan record))
          (condition (get current-condition record))
          (maintenance-factor (if (> (get maintenance-count record) u3) u8 u10))
        )
        (ok {
          current-condition: condition,
          age-factor: (/ (* age u10) expected-age),
          maintenance-factor: maintenance-factor,
          overall-score: (/ (+ condition maintenance-factor) u2)
        })
      )
    ERR_RECORD_NOT_FOUND
  )
)

;; Get total tracking records
(define-read-only (get-total-tracking-records)
  (var-get total-tracking-records)
)

;; Get next tracking ID
(define-read-only (get-next-tracking-id)
  (var-get next-tracking-id)
)
