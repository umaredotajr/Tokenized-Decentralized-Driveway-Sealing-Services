;; Application Verification Contract
;; Ensures proper coverage and curing processes

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_APPLICATION_NOT_FOUND (err u401))
(define-constant ERR_INVALID_COVERAGE (err u402))
(define-constant ERR_INVALID_THICKNESS (err u403))
(define-constant ERR_CURING_NOT_COMPLETE (err u404))
(define-constant ERR_QUALITY_CHECK_FAILED (err u405))

;; Data Variables
(define-data-var next-application-id uint u1)
(define-data-var total-applications uint u0)

;; Data Maps
(define-map applications
  { application-id: uint }
  {
    property-id: uint,
    order-id: uint,
    applicator: principal,
    start-time: uint,
    end-time: uint,
    surface-area-covered: uint,
    sealant-thickness: uint,
    coverage-percentage: uint,
    application-method: (string-ascii 30),
    weather-conditions: (string-ascii 50),
    temperature-during-application: uint,
    is-complete: bool,
    applied-at: uint
  }
)

(define-map quality-checks
  { application-id: uint, check-id: uint }
  {
    inspector: principal,
    coverage-uniformity: uint,
    edge-sealing: bool,
    crack-filling: bool,
    surface-preparation: uint,
    adhesion-test: uint,
    thickness-compliance: bool,
    overall-grade: uint,
    notes: (string-ascii 200),
    checked-at: uint
  }
)

(define-map curing-progress
  { application-id: uint }
  {
    start-curing: uint,
    expected-completion: uint,
    current-stage: (string-ascii 20),
    temperature-log: (list 10 uint),
    humidity-log: (list 10 uint),
    is-cured: bool,
    curing-quality: uint
  }
)

(define-map application-check-count
  { application-id: uint }
  { count: uint }
)

;; Public Functions

;; Record application start
(define-public (start-application
  (property-id uint)
  (order-id uint)
  (surface-area-covered uint)
  (application-method (string-ascii 30))
  (weather-conditions (string-ascii 50))
  (temperature-during-application uint)
)
  (let
    (
      (application-id (var-get next-application-id))
    )
    (asserts! (> surface-area-covered u0) ERR_INVALID_COVERAGE)
    (asserts! (and (>= temperature-during-application u50) (<= temperature-during-application u85)) ERR_INVALID_COVERAGE)

    (map-set applications
      { application-id: application-id }
      {
        property-id: property-id,
        order-id: order-id,
        applicator: tx-sender,
        start-time: block-height,
        end-time: u0,
        surface-area-covered: surface-area-covered,
        sealant-thickness: u0,
        coverage-percentage: u0,
        application-method: application-method,
        weather-conditions: weather-conditions,
        temperature-during-application: temperature-during-application,
        is-complete: false,
        applied-at: block-height
      }
    )
    (map-set application-check-count
      { application-id: application-id }
      { count: u0 }
    )
    (var-set next-application-id (+ application-id u1))
    (var-set total-applications (+ (var-get total-applications) u1))
    (ok application-id)
  )
)

;; Complete application
(define-public (complete-application
  (application-id uint)
  (sealant-thickness uint)
  (coverage-percentage uint)
)
  (let
    (
      (application (unwrap! (map-get? applications { application-id: application-id }) ERR_APPLICATION_NOT_FOUND))
    )
    (asserts! (is-eq (get applicator application) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (get is-complete application)) ERR_APPLICATION_NOT_FOUND)
    (asserts! (and (>= sealant-thickness u2) (<= sealant-thickness u8)) ERR_INVALID_THICKNESS)
    (asserts! (and (>= coverage-percentage u90) (<= coverage-percentage u100)) ERR_INVALID_COVERAGE)

    (map-set applications
      { application-id: application-id }
      (merge application {
        end-time: block-height,
        sealant-thickness: sealant-thickness,
        coverage-percentage: coverage-percentage,
        is-complete: true
      })
    )

    ;; Initialize curing process
    (map-set curing-progress
      { application-id: application-id }
      {
        start-curing: block-height,
        expected-completion: (+ block-height u144), ;; ~24 hours
        current-stage: "initial",
        temperature-log: (list),
        humidity-log: (list),
        is-cured: false,
        curing-quality: u0
      }
    )
    (ok true)
  )
)

;; Conduct quality check
(define-public (conduct-quality-check
  (application-id uint)
  (coverage-uniformity uint)
  (edge-sealing bool)
  (crack-filling bool)
  (surface-preparation uint)
  (adhesion-test uint)
  (thickness-compliance bool)
  (notes (string-ascii 200))
)
  (let
    (
      (application (unwrap! (map-get? applications { application-id: application-id }) ERR_APPLICATION_NOT_FOUND))
      (check-count (default-to { count: u0 } (map-get? application-check-count { application-id: application-id })))
      (new-check-id (+ (get count check-count) u1))
      (overall-grade (/ (+ coverage-uniformity surface-preparation adhesion-test) u3))
    )
    (asserts! (get is-complete application) ERR_APPLICATION_NOT_FOUND)
    (asserts! (and (>= coverage-uniformity u1) (<= coverage-uniformity u10)) ERR_INVALID_COVERAGE)
    (asserts! (and (>= surface-preparation u1) (<= surface-preparation u10)) ERR_INVALID_COVERAGE)
    (asserts! (and (>= adhesion-test u1) (<= adhesion-test u10)) ERR_INVALID_COVERAGE)

    (map-set quality-checks
      { application-id: application-id, check-id: new-check-id }
      {
        inspector: tx-sender,
        coverage-uniformity: coverage-uniformity,
        edge-sealing: edge-sealing,
        crack-filling: crack-filling,
        surface-preparation: surface-preparation,
        adhesion-test: adhesion-test,
        thickness-compliance: thickness-compliance,
        overall-grade: overall-grade,
        notes: notes,
        checked-at: block-height
      }
    )
    (map-set application-check-count
      { application-id: application-id }
      { count: new-check-id }
    )
    (ok new-check-id)
  )
)

;; Update curing progress
(define-public (update-curing-progress
  (application-id uint)
  (current-stage (string-ascii 20))
  (temperature uint)
  (humidity uint)
)
  (let
    (
      (application (unwrap! (map-get? applications { application-id: application-id }) ERR_APPLICATION_NOT_FOUND))
      (curing (unwrap! (map-get? curing-progress { application-id: application-id }) ERR_APPLICATION_NOT_FOUND))
      (is-cured (>= block-height (get expected-completion curing)))
      (curing-quality (if is-cured u8 u0))
    )
    (asserts! (is-eq (get applicator application) tx-sender) ERR_UNAUTHORIZED)

    (map-set curing-progress
      { application-id: application-id }
      (merge curing {
        current-stage: current-stage,
        is-cured: is-cured,
        curing-quality: curing-quality
      })
    )
    (ok true)
  )
)

;; Certify application completion
(define-public (certify-completion (application-id uint))
  (let
    (
      (application (unwrap! (map-get? applications { application-id: application-id }) ERR_APPLICATION_NOT_FOUND))
      (curing (unwrap! (map-get? curing-progress { application-id: application-id }) ERR_APPLICATION_NOT_FOUND))
    )
    (asserts! (get is-complete application) ERR_APPLICATION_NOT_FOUND)
    (asserts! (get is-cured curing) ERR_CURING_NOT_COMPLETE)
    (asserts! (>= (get coverage-percentage application) u95) ERR_QUALITY_CHECK_FAILED)

    (ok true)
  )
)

;; Read-only Functions

;; Get application details
(define-read-only (get-application (application-id uint))
  (map-get? applications { application-id: application-id })
)

;; Get quality check
(define-read-only (get-quality-check (application-id uint) (check-id uint))
  (map-get? quality-checks { application-id: application-id, check-id: check-id })
)

;; Get curing progress
(define-read-only (get-curing-progress (application-id uint))
  (map-get? curing-progress { application-id: application-id })
)

;; Get application check count
(define-read-only (get-application-check-count (application-id uint))
  (default-to { count: u0 } (map-get? application-check-count { application-id: application-id }))
)

;; Check if application is certified
(define-read-only (is-application-certified (application-id uint))
  (match (map-get? applications { application-id: application-id })
    application
      (match (map-get? curing-progress { application-id: application-id })
        curing
          (ok (and
            (get is-complete application)
            (get is-cured curing)
            (>= (get coverage-percentage application) u95)
          ))
        (ok false)
      )
    ERR_APPLICATION_NOT_FOUND
  )
)

;; Get total applications
(define-read-only (get-total-applications)
  (var-get total-applications)
)

;; Get next application ID
(define-read-only (get-next-application-id)
  (var-get next-application-id)
)
