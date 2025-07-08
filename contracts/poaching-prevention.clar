;; Poaching Prevention Contract
;; Detects and manages illegal hunting activities

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_INPUT (err u302))
(define-constant ERR_ALREADY_EXISTS (err u303))

;; Data Variables
(define-data-var next-alert-id uint u1)
(define-data-var next-incident-id uint u1)
(define-data-var next-patrol-id uint u1)

;; Data Maps
(define-map poaching-alerts
  { alert-id: uint }
  {
    location: (string-ascii 100),
    latitude: int,
    longitude: int,
    alert-type: (string-ascii 50),
    severity: uint,
    detected-time: uint,
    status: (string-ascii 20),
    reported-by: principal,
    description: (string-ascii 300)
  }
)

(define-map poaching-incidents
  { incident-id: uint }
  {
    alert-id: (optional uint),
    location: (string-ascii 100),
    incident-date: uint,
    species-affected: (string-ascii 50),
    estimated-animals: uint,
    evidence-type: (string-ascii 100),
    investigation-status: (string-ascii 30),
    investigating-officer: (optional principal),
    resolution: (optional (string-ascii 300))
  }
)

(define-map patrol-routes
  { patrol-id: uint }
  {
    route-name: (string-ascii 100),
    start-location: (string-ascii 100),
    end-location: (string-ascii 100),
    patrol-frequency: (string-ascii 20),
    assigned-officer: principal,
    last-patrol-date: (optional uint),
    status: (string-ascii 20)
  }
)

(define-map patrol-logs
  { patrol-id: uint, log-date: uint }
  {
    officer: principal,
    start-time: uint,
    end-time: (optional uint),
    observations: (string-ascii 500),
    alerts-found: uint,
    incidents-reported: uint,
    weather-conditions: (string-ascii 100)
  }
)

(define-map enforcement-officers
  { officer: principal }
  {
    authorized: bool,
    badge-number: (string-ascii 20),
    jurisdiction: (string-ascii 100),
    contact-info: (string-ascii 200)
  }
)

;; Read-only functions
(define-read-only (get-alert (alert-id uint))
  (map-get? poaching-alerts { alert-id: alert-id })
)

(define-read-only (get-incident (incident-id uint))
  (map-get? poaching-incidents { incident-id: incident-id })
)

(define-read-only (get-patrol-route (patrol-id uint))
  (map-get? patrol-routes { patrol-id: patrol-id })
)

(define-read-only (get-patrol-log (patrol-id uint) (log-date uint))
  (map-get? patrol-logs { patrol-id: patrol-id, log-date: log-date })
)

(define-read-only (is-enforcement-officer (officer principal))
  (default-to false (get authorized (map-get? enforcement-officers { officer: officer })))
)

(define-read-only (get-next-alert-id)
  (var-get next-alert-id)
)

(define-read-only (get-next-incident-id)
  (var-get next-incident-id)
)

(define-read-only (get-next-patrol-id)
  (var-get next-patrol-id)
)

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-authorized)
  (or (is-contract-owner) (is-enforcement-officer tx-sender))
)

;; Public functions
(define-public (authorize-enforcement-officer
  (officer principal)
  (badge-number (string-ascii 20))
  (jurisdiction (string-ascii 100))
  (contact-info (string-ascii 200)))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (> (len badge-number) u0) ERR_INVALID_INPUT)
    (ok (map-set enforcement-officers
      { officer: officer }
      {
        authorized: true,
        badge-number: badge-number,
        jurisdiction: jurisdiction,
        contact-info: contact-info
      }
    ))
  )
)

(define-public (revoke-enforcement-officer (officer principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (ok (map-delete enforcement-officers { officer: officer }))
  )
)

(define-public (create-poaching-alert
  (location (string-ascii 100))
  (latitude int)
  (longitude int)
  (alert-type (string-ascii 50))
  (severity uint)
  (description (string-ascii 300)))
  (let
    ((alert-id (var-get next-alert-id)))
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (> (len location) u0) ERR_INVALID_INPUT)
    (asserts! (> (len alert-type) u0) ERR_INVALID_INPUT)
    (asserts! (and (>= severity u1) (<= severity u5)) ERR_INVALID_INPUT)
    (map-set poaching-alerts
      { alert-id: alert-id }
      {
        location: location,
        latitude: latitude,
        longitude: longitude,
        alert-type: alert-type,
        severity: severity,
        detected-time: block-height,
        status: "active",
        reported-by: tx-sender,
        description: description
      }
    )
    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)
  )
)

(define-public (report-poaching-incident
  (alert-id-opt (optional uint))
  (location (string-ascii 100))
  (species-affected (string-ascii 50))
  (estimated-animals uint)
  (evidence-type (string-ascii 100)))
  (let
    ((incident-id (var-get next-incident-id)))
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (> (len location) u0) ERR_INVALID_INPUT)
    (asserts! (> (len species-affected) u0) ERR_INVALID_INPUT)
    (asserts! (> estimated-animals u0) ERR_INVALID_INPUT)
    (map-set poaching-incidents
      { incident-id: incident-id }
      {
        alert-id: alert-id-opt,
        location: location,
        incident-date: block-height,
        species-affected: species-affected,
        estimated-animals: estimated-animals,
        evidence-type: evidence-type,
        investigation-status: "reported",
        investigating-officer: none,
        resolution: none
      }
    )
    (var-set next-incident-id (+ incident-id u1))
    (ok incident-id)
  )
)

(define-public (assign-investigation
  (incident-id uint)
  (investigating-officer principal))
  (let
    ((existing-incident (get-incident incident-id)))
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-some existing-incident) ERR_NOT_FOUND)
    (asserts! (is-enforcement-officer investigating-officer) ERR_UNAUTHORIZED)
    (ok (map-set poaching-incidents
      { incident-id: incident-id }
      (merge (unwrap-panic existing-incident)
        {
          investigating-officer: (some investigating-officer),
          investigation-status: "investigating"
        }
      )
    ))
  )
)

(define-public (create-patrol-route
  (route-name (string-ascii 100))
  (start-location (string-ascii 100))
  (end-location (string-ascii 100))
  (patrol-frequency (string-ascii 20))
  (assigned-officer principal))
  (let
    ((patrol-id (var-get next-patrol-id)))
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (> (len route-name) u0) ERR_INVALID_INPUT)
    (asserts! (> (len start-location) u0) ERR_INVALID_INPUT)
    (asserts! (is-enforcement-officer assigned-officer) ERR_UNAUTHORIZED)
    (map-set patrol-routes
      { patrol-id: patrol-id }
      {
        route-name: route-name,
        start-location: start-location,
        end-location: end-location,
        patrol-frequency: patrol-frequency,
        assigned-officer: assigned-officer,
        last-patrol-date: none,
        status: "active"
      }
    )
    (var-set next-patrol-id (+ patrol-id u1))
    (ok patrol-id)
  )
)

(define-public (start-patrol
  (patrol-id uint)
  (weather-conditions (string-ascii 100)))
  (let
    ((patrol-route (get-patrol-route patrol-id))
     (log-date block-height))
    (asserts! (is-some patrol-route) ERR_NOT_FOUND)
    (asserts! (is-eq tx-sender (get assigned-officer (unwrap-panic patrol-route))) ERR_UNAUTHORIZED)
    (ok (map-set patrol-logs
      { patrol-id: patrol-id, log-date: log-date }
      {
        officer: tx-sender,
        start-time: block-height,
        end-time: none,
        observations: "",
        alerts-found: u0,
        incidents-reported: u0,
        weather-conditions: weather-conditions
      }
    ))
  )
)

(define-public (end-patrol
  (patrol-id uint)
  (log-date uint)
  (observations (string-ascii 500))
  (alerts-found uint)
  (incidents-reported uint))
  (let
    ((existing-log (get-patrol-log patrol-id log-date)))
    (asserts! (is-some existing-log) ERR_NOT_FOUND)
    (asserts! (is-eq tx-sender (get officer (unwrap-panic existing-log))) ERR_UNAUTHORIZED)
    (asserts! (is-none (get end-time (unwrap-panic existing-log))) ERR_INVALID_INPUT)
    (ok (map-set patrol-logs
      { patrol-id: patrol-id, log-date: log-date }
      (merge (unwrap-panic existing-log)
        {
          end-time: (some block-height),
          observations: observations,
          alerts-found: alerts-found,
          incidents-reported: incidents-reported
        }
      )
    ))
  )
)

(define-public (update-alert-status
  (alert-id uint)
  (new-status (string-ascii 20)))
  (let
    ((existing-alert (get-alert alert-id)))
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (is-some existing-alert) ERR_NOT_FOUND)
    (asserts! (> (len new-status) u0) ERR_INVALID_INPUT)
    (ok (map-set poaching-alerts
      { alert-id: alert-id }
      (merge (unwrap-panic existing-alert) { status: new-status })
    ))
  )
)

(define-public (close-investigation
  (incident-id uint)
  (resolution (string-ascii 300)))
  (let
    ((existing-incident (get-incident incident-id)))
    (asserts! (is-some existing-incident) ERR_NOT_FOUND)
    (asserts! (or
      (is-contract-owner)
      (is-eq tx-sender (unwrap-panic (get investigating-officer (unwrap-panic existing-incident))))
    ) ERR_UNAUTHORIZED)
    (asserts! (> (len resolution) u0) ERR_INVALID_INPUT)
    (ok (map-set poaching-incidents
      { incident-id: incident-id }
      (merge (unwrap-panic existing-incident)
        {
          investigation-status: "closed",
          resolution: (some resolution)
        }
      )
    ))
  )
)
