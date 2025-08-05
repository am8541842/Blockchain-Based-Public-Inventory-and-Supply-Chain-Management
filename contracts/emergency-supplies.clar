;; Emergency Supply Stockpile Management Contract
;; Maintains reserves of medical supplies, food, and disaster response equipment

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-SUPPLY-NOT-FOUND (err u402))
(define-constant ERR-INSUFFICIENT-STOCK (err u403))
(define-constant ERR-EXPIRED-SUPPLIES (err u404))
(define-constant ERR-EMERGENCY-NOT-ACTIVE (err u405))

;; Data Variables
(define-data-var next-supply-id uint u1)
(define-data-var next-emergency-id uint u1)
(define-data-var emergency-status bool false)

;; Data Maps
(define-map emergency-supplies
  uint
  {
    name: (string-ascii 128),
    category: (string-ascii 64),
    description: (string-ascii 256),
    current-stock: uint,
    minimum-required: uint,
    maximum-capacity: uint,
    unit: (string-ascii 32),
    expiration-date: (optional uint),
    storage-location: (string-ascii 128),
    supplier: principal,
    last-restocked: uint,
    cost-per-unit: uint
  }
)

(define-map emergency-events
  uint
  {
    event-type: (string-ascii 64),
    severity-level: uint,
    location: (string-ascii 256),
    start-time: uint,
    end-time: (optional uint),
    status: (string-ascii 32),
    supplies-deployed: (list 20 uint),
    coordinator: principal
  }
)

(define-map supply-deployments
  {emergency-id: uint, supply-id: uint}
  {
    quantity-deployed: uint,
    deployment-time: uint,
    destination: (string-ascii 256),
    deployed-by: principal,
    return-expected: bool
  }
)

(define-map authorized-coordinators principal bool)
(define-map storage-facilities
  (string-ascii 128)
  {
    name: (string-ascii 128),
    address: (string-ascii 256),
    capacity: uint,
    current-utilization: uint,
    security-level: uint,
    climate-controlled: bool
  }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-coordinator)
  (or (is-contract-owner) (default-to false (map-get? authorized-coordinators tx-sender)))
)

;; Admin Functions
(define-public (add-authorized-coordinator (coordinator principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-set authorized-coordinators coordinator true)
    (ok true)
  )
)

(define-public (add-storage-facility
  (facility-id (string-ascii 128))
  (name (string-ascii 128))
  (address (string-ascii 256))
  (capacity uint)
  (security-level uint)
  (climate-controlled bool)
)
  (begin
    (asserts! (is-authorized-coordinator) ERR-NOT-AUTHORIZED)
    (asserts! (> capacity u0) ERR-INVALID-INPUT)
    (asserts! (<= security-level u5) ERR-INVALID-INPUT)

    (map-set storage-facilities facility-id
      {
        name: name,
        address: address,
        capacity: capacity,
        current-utilization: u0,
        security-level: security-level,
        climate-controlled: climate-controlled
      }
    )
    (ok true)
  )
)

;; Core Supply Management Functions
(define-public (add-emergency-supply
  (name (string-ascii 128))
  (category (string-ascii 64))
  (description (string-ascii 256))
  (minimum-required uint)
  (maximum-capacity uint)
  (unit (string-ascii 32))
  (expiration-date (optional uint))
  (storage-location (string-ascii 128))
  (supplier principal)
  (cost-per-unit uint)
)
  (let
    (
      (supply-id (var-get next-supply-id))
    )
    (asserts! (is-authorized-coordinator) ERR-NOT-AUTHORIZED)
    (asserts! (> minimum-required u0) ERR-INVALID-INPUT)
    (asserts! (> maximum-capacity minimum-required) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? storage-facilities storage-location)) ERR-INVALID-INPUT)

    (map-set emergency-supplies supply-id
      {
        name: name,
        category: category,
        description: description,
        current-stock: u0,
        minimum-required: minimum-required,
        maximum-capacity: maximum-capacity,
        unit: unit,
        expiration-date: expiration-date,
        storage-location: storage-location,
        supplier: supplier,
        last-restocked: block-height,
        cost-per-unit: cost-per-unit
      }
    )

    (var-set next-supply-id (+ supply-id u1))
    (ok supply-id)
  )
)

(define-public (restock-supply (supply-id uint) (quantity uint))
  (let
    (
      (supply (unwrap! (map-get? emergency-supplies supply-id) ERR-SUPPLY-NOT-FOUND))
      (new-stock (+ (get current-stock supply) quantity))
    )
    (asserts! (is-authorized-coordinator) ERR-NOT-AUTHORIZED)
    (asserts! (> quantity u0) ERR-INVALID-INPUT)
    (asserts! (<= new-stock (get maximum-capacity supply)) ERR-INVALID-INPUT)

    (map-set emergency-supplies supply-id
      (merge supply {
        current-stock: new-stock,
        last-restocked: block-height
      })
    )
    (ok true)
  )
)

(define-public (declare-emergency
  (event-type (string-ascii 64))
  (severity-level uint)
  (location (string-ascii 256))
)
  (let
    (
      (emergency-id (var-get next-emergency-id))
    )
    (asserts! (is-authorized-coordinator) ERR-NOT-AUTHORIZED)
    (asserts! (<= severity-level u5) ERR-INVALID-INPUT)
    (asserts! (> severity-level u0) ERR-INVALID-INPUT)

    (var-set emergency-status true)
    (map-set emergency-events emergency-id
      {
        event-type: event-type,
        severity-level: severity-level,
        location: location,
        start-time: block-height,
        end-time: none,
        status: "active",
        supplies-deployed: (list),
        coordinator: tx-sender
      }
    )

    (var-set next-emergency-id (+ emergency-id u1))
    (ok emergency-id)
  )
)

(define-public (deploy-emergency-supplies
  (emergency-id uint)
  (supply-id uint)
  (quantity uint)
  (destination (string-ascii 256))
)
  (let
    (
      (supply (unwrap! (map-get? emergency-supplies supply-id) ERR-SUPPLY-NOT-FOUND))
      (emergency (unwrap! (map-get? emergency-events emergency-id) ERR-SUPPLY-NOT-FOUND))
      (current-stock (get current-stock supply))
      (new-stock (- current-stock quantity))
    )
    (asserts! (is-authorized-coordinator) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status emergency) "active") ERR-EMERGENCY-NOT-ACTIVE)
    (asserts! (> quantity u0) ERR-INVALID-INPUT)
    (asserts! (>= current-stock quantity) ERR-INSUFFICIENT-STOCK)

    (map-set emergency-supplies supply-id
      (merge supply { current-stock: new-stock })
    )

    (map-set supply-deployments {emergency-id: emergency-id, supply-id: supply-id}
      {
        quantity-deployed: quantity,
        deployment-time: block-height,
        destination: destination,
        deployed-by: tx-sender,
        return-expected: false
      }
    )
    (ok true)
  )
)

(define-public (end-emergency (emergency-id uint))
  (let
    (
      (emergency (unwrap! (map-get? emergency-events emergency-id) ERR-SUPPLY-NOT-FOUND))
    )
    (asserts! (is-authorized-coordinator) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status emergency) "active") ERR-EMERGENCY-NOT-ACTIVE)

    (map-set emergency-events emergency-id
      (merge emergency {
        end-time: (some block-height),
        status: "resolved"
      })
    )

    (var-set emergency-status false)
    (ok true)
  )
)

(define-public (rotate-expired-supplies (supply-id uint))
  (let
    (
      (supply (unwrap! (map-get? emergency-supplies supply-id) ERR-SUPPLY-NOT-FOUND))
      (expiration (get expiration-date supply))
    )
    (asserts! (is-authorized-coordinator) ERR-NOT-AUTHORIZED)
    (asserts! (is-some expiration) ERR-INVALID-INPUT)
    (asserts! (<= (unwrap-panic expiration) block-height) ERR-EXPIRED-SUPPLIES)

    (map-set emergency-supplies supply-id
      (merge supply {
        current-stock: u0,
        last-restocked: block-height
      })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-emergency-supply (supply-id uint))
  (map-get? emergency-supplies supply-id)
)

(define-read-only (get-emergency-event (emergency-id uint))
  (map-get? emergency-events emergency-id)
)

(define-read-only (get-supply-deployment (emergency-id uint) (supply-id uint))
  (map-get? supply-deployments {emergency-id: emergency-id, supply-id: supply-id})
)

(define-read-only (check-supply-levels (supply-id uint))
  (match (map-get? emergency-supplies supply-id)
    supply
    {
      current-stock: (get current-stock supply),
      minimum-required: (get minimum-required supply),
      below-minimum: (< (get current-stock supply) (get minimum-required supply))
    }
    { current-stock: u0, minimum-required: u0, below-minimum: false }
  )
)

(define-read-only (is-emergency-active)
  (var-get emergency-status)
)

(define-read-only (get-storage-facility (facility-id (string-ascii 128)))
  (map-get? storage-facilities facility-id)
)

(define-read-only (is-coordinator-authorized (coordinator principal))
  (or (is-eq coordinator CONTRACT-OWNER) (default-to false (map-get? authorized-coordinators coordinator)))
)
