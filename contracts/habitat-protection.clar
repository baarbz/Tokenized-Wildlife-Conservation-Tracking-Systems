;; Habitat Protection Contract
;; Manages conservation area boundaries and environmental monitoring

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_INVALID_INPUT (err u202))
(define-constant ERR_ALREADY_EXISTS (err u203))

;; Data Variables
(define-data-var next-habitat-id uint u1)
(define-data-var next-monitoring-id uint u1)
(define-data-var next-threat-id uint u1)

;; Data Maps
(define-map protected-habitats
  { habitat-id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    area-hectares: uint,
    habitat-type: (string-ascii 50),
    protection-level: (string-ascii 30),
    established-date: uint,
    manager: principal,
    status: (string-ascii 20)
  }
)

(define-map habitat-boundaries
  { habitat-id: uint, point-id: uint }
  {
    latitude: int,
    longitude: int,
    elevation: int,
    boundary-type: (string-ascii 20)
  }
)

(define-map environmental-monitoring
  { monitoring-id: uint }
  {
    habitat-id: uint,
    monitoring-date: uint,
    temperature: int,
    humidity: uint,
    air-quality-index: uint,
    water-quality-ph: uint,
    vegetation-coverage: uint,
    wildlife-count: uint,
    recorded-by: principal,
    notes: (string-ascii 300)
  }
)

(define-map habitat-threats
  { threat-id: uint }
  {
    habitat-id: uint,
    threat-type: (string-ascii 50),
    severity-level: uint,
    detected-date: uint,
    location-description: (string-ascii 200),
    mitigation-status: (string-ascii 30),
    reported-by: principal,
    resolved-date: (optional uint)
  }
)

(define-map habitat-managers
  { manager: principal }
  { authorized: bool, managed-habitats: (list 10 uint) }
)

;; Read-only functions
(define-read-only (get-habitat (habitat-id uint))
  (map-get? protected-habitats { habitat-id: habitat-id })
)

(define-read-only (get-boundary-point (habitat-id uint) (point-id uint))
  (map-get? habitat-boundaries { habitat-id: habitat-id, point-id: point-id })
)

(define-read-only (get-monitoring-record (monitoring-id uint))
  (map-get? environmental-monitoring { monitoring-id: monitoring-id })
)

(define-read-only (get-threat (threat-id uint))
  (map-get? habitat-threats { threat-id: threat-id })
)

(define-read-only (is-habitat-manager (manager principal))
  (default-to false (get authorized (map-get? habitat-managers { manager: manager })))
)

(define-read-only (get-next-habitat-id)
  (var-get next-habitat-id)
)

(define-read-only (get-next-monitoring-id)
  (var-get next-monitoring-id)
)

(define-read-only (get-next-threat-id)
  (var-get next-threat-id)
)

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-authorized-for-habitat (habitat-id uint))
  (or
    (is-contract-owner)
    (is-habitat-manager tx-sender)
    (match (get-habitat habitat-id)
      habitat (is-eq tx-sender (get manager habitat))
      false
    )
  )
)

;; Public functions
(define-public (authorize-habitat-manager (manager principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (ok (map-set habitat-managers
      { manager: manager }
      { authorized: true, managed-habitats: (list) }
    ))
  )
)

(define-public (revoke-habitat-manager (manager principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (ok (map-delete habitat-managers { manager: manager }))
  )
)

(define-public (create-protected-habitat
  (name (string-ascii 100))
  (location (string-ascii 100))
  (area-hectares uint)
  (habitat-type (string-ascii 50))
  (protection-level (string-ascii 30)))
  (let
    ((habitat-id (var-get next-habitat-id)))
    (asserts! (or (is-contract-owner) (is-habitat-manager tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (> (len location) u0) ERR_INVALID_INPUT)
    (asserts! (> area-hectares u0) ERR_INVALID_INPUT)
    (map-set protected-habitats
      { habitat-id: habitat-id }
      {
        name: name,
        location: location,
        area-hectares: area-hectares,
        habitat-type: habitat-type,
        protection-level: protection-level,
        established-date: block-height,
        manager: tx-sender,
        status: "active"
      }
    )
    (var-set next-habitat-id (+ habitat-id u1))
    (ok habitat-id)
  )
)

(define-public (add-boundary-point
  (habitat-id uint)
  (point-id uint)
  (latitude int)
  (longitude int)
  (elevation int)
  (boundary-type (string-ascii 20)))
  (begin
    (asserts! (is-authorized-for-habitat habitat-id) ERR_UNAUTHORIZED)
    (asserts! (is-some (get-habitat habitat-id)) ERR_NOT_FOUND)
    (asserts! (> (len boundary-type) u0) ERR_INVALID_INPUT)
    (ok (map-set habitat-boundaries
      { habitat-id: habitat-id, point-id: point-id }
      {
        latitude: latitude,
        longitude: longitude,
        elevation: elevation,
        boundary-type: boundary-type
      }
    ))
  )
)

(define-public (record-environmental-data
  (habitat-id uint)
  (temperature int)
  (humidity uint)
  (air-quality-index uint)
  (water-quality-ph uint)
  (vegetation-coverage uint)
  (wildlife-count uint)
  (notes (string-ascii 300)))
  (let
    ((monitoring-id (var-get next-monitoring-id)))
    (asserts! (is-authorized-for-habitat habitat-id) ERR_UNAUTHORIZED)
    (asserts! (is-some (get-habitat habitat-id)) ERR_NOT_FOUND)
    (asserts! (<= humidity u100) ERR_INVALID_INPUT)
    (asserts! (<= air-quality-index u500) ERR_INVALID_INPUT)
    (asserts! (<= water-quality-ph u14) ERR_INVALID_INPUT)
    (asserts! (<= vegetation-coverage u100) ERR_INVALID_INPUT)
    (map-set environmental-monitoring
      { monitoring-id: monitoring-id }
      {
        habitat-id: habitat-id,
        monitoring-date: block-height,
        temperature: temperature,
        humidity: humidity,
        air-quality-index: air-quality-index,
        water-quality-ph: water-quality-ph,
        vegetation-coverage: vegetation-coverage,
        wildlife-count: wildlife-count,
        recorded-by: tx-sender,
        notes: notes
      }
    )
    (var-set next-monitoring-id (+ monitoring-id u1))
    (ok monitoring-id)
  )
)

(define-public (report-habitat-threat
  (habitat-id uint)
  (threat-type (string-ascii 50))
  (severity-level uint)
  (location-description (string-ascii 200)))
  (let
    ((threat-id (var-get next-threat-id)))
    (asserts! (is-authorized-for-habitat habitat-id) ERR_UNAUTHORIZED)
    (asserts! (is-some (get-habitat habitat-id)) ERR_NOT_FOUND)
    (asserts! (> (len threat-type) u0) ERR_INVALID_INPUT)
    (asserts! (and (>= severity-level u1) (<= severity-level u5)) ERR_INVALID_INPUT)
    (map-set habitat-threats
      { threat-id: threat-id }
      {
        habitat-id: habitat-id,
        threat-type: threat-type,
        severity-level: severity-level,
        detected-date: block-height,
        location-description: location-description,
        mitigation-status: "reported",
        reported-by: tx-sender,
        resolved-date: none
      }
    )
    (var-set next-threat-id (+ threat-id u1))
    (ok threat-id)
  )
)

(define-public (update-threat-status
  (threat-id uint)
  (new-status (string-ascii 30)))
  (let
    ((existing-threat (get-threat threat-id)))
    (asserts! (is-some existing-threat) ERR_NOT_FOUND)
    (asserts! (is-authorized-for-habitat (get habitat-id (unwrap-panic existing-threat))) ERR_UNAUTHORIZED)
    (asserts! (> (len new-status) u0) ERR_INVALID_INPUT)
    (ok (map-set habitat-threats
      { threat-id: threat-id }
      (merge (unwrap-panic existing-threat) { mitigation-status: new-status })
    ))
  )
)

(define-public (resolve-threat
  (threat-id uint))
  (let
    ((existing-threat (get-threat threat-id)))
    (asserts! (is-some existing-threat) ERR_NOT_FOUND)
    (asserts! (is-authorized-for-habitat (get habitat-id (unwrap-panic existing-threat))) ERR_UNAUTHORIZED)
    (ok (map-set habitat-threats
      { threat-id: threat-id }
      (merge (unwrap-panic existing-threat)
        {
          mitigation-status: "resolved",
          resolved-date: (some block-height)
        }
      )
    ))
  )
)

(define-public (update-habitat-status
  (habitat-id uint)
  (new-status (string-ascii 20)))
  (let
    ((existing-habitat (get-habitat habitat-id)))
    (asserts! (is-authorized-for-habitat habitat-id) ERR_UNAUTHORIZED)
    (asserts! (is-some existing-habitat) ERR_NOT_FOUND)
    (asserts! (> (len new-status) u0) ERR_INVALID_INPUT)
    (ok (map-set protected-habitats
      { habitat-id: habitat-id }
      (merge (unwrap-panic existing-habitat) { status: new-status })
    ))
  )
)
