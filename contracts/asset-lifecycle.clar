;; Asset Lifecycle Management Contract
;; Tracks government property from purchase through disposal

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-INPUT (err u501))
(define-constant ERR-ASSET-NOT-FOUND (err u502))
(define-constant ERR-INVALID-STATUS-TRANSITION (err u503))
(define-constant ERR-MAINTENANCE-OVERDUE (err u504))

;; Data Variables
(define-data-var next-asset-id uint u1)
(define-data-var next-maintenance-id uint u1)
(define-data-var next-transfer-id uint u1)

;; Data Maps
(define-map assets
  uint
  {
    name: (string-ascii 128),
    description: (string-ascii 256),
    category: (string-ascii 64),
    serial-number: (string-ascii 128),
    purchase-date: uint,
    purchase-price: uint,
    current-value: uint,
    depreciation-rate: uint,
    status: (string-ascii 32),
    location: (string-ascii 128),
    assigned-department: principal,
    condition: (string-ascii 32),
    last-maintenance: uint,
    next-maintenance-due: uint,
    warranty-expiry: (optional uint)
  }
)

(define-map maintenance-records
  uint
  {
    asset-id: uint,
    maintenance-type: (string-ascii 64),
    description: (string-ascii 256),
    cost: uint,
    performed-by: (string-ascii 128),
    maintenance-date: uint,
    next-due-date: uint,
    parts-replaced: (list 10 (string-ascii 128)),
    performed-by-principal: principal
  }
)

(define-map asset-transfers
  uint
  {
    asset-id: uint,
    from-department: principal,
    to-department: principal,
    transfer-date: uint,
    reason: (string-ascii 256),
    approved-by: principal,
    transfer-value: uint,
    condition-at-transfer: (string-ascii 32)
  }
)

(define-map authorized-managers principal bool)
(define-map department-assets principal (list 100 uint))
(define-map asset-disposal-records
  uint
  {
    disposal-date: uint,
    disposal-method: (string-ascii 64),
    disposal-value: uint,
    approved-by: principal,
    disposal-reason: (string-ascii 256)
  }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-manager)
  (or (is-contract-owner) (default-to false (map-get? authorized-managers tx-sender)))
)

;; Admin Functions
(define-public (add-authorized-manager (manager principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-set authorized-managers manager true)
    (ok true)
  )
)

;; Core Asset Management Functions
(define-public (register-asset
  (name (string-ascii 128))
  (description (string-ascii 256))
  (category (string-ascii 64))
  (serial-number (string-ascii 128))
  (purchase-price uint)
  (depreciation-rate uint)
  (location (string-ascii 128))
  (assigned-department principal)
  (warranty-expiry (optional uint))
)
  (let
    (
      (asset-id (var-get next-asset-id))
      (current-dept-assets (default-to (list) (map-get? department-assets assigned-department)))
    )
    (asserts! (is-authorized-manager) ERR-NOT-AUTHORIZED)
    (asserts! (> purchase-price u0) ERR-INVALID-INPUT)
    (asserts! (<= depreciation-rate u100) ERR-INVALID-INPUT)

    (map-set assets asset-id
      {
        name: name,
        description: description,
        category: category,
        serial-number: serial-number,
        purchase-date: block-height,
        purchase-price: purchase-price,
        current-value: purchase-price,
        depreciation-rate: depreciation-rate,
        status: "active",
        location: location,
        assigned-department: assigned-department,
        condition: "new",
        last-maintenance: block-height,
        next-maintenance-due: (+ block-height u8760),
        warranty-expiry: warranty-expiry
      }
    )

    (map-set department-assets assigned-department
      (unwrap! (as-max-len? (append current-dept-assets asset-id) u100) ERR-INVALID-INPUT)
    )

    (var-set next-asset-id (+ asset-id u1))
    (ok asset-id)
  )
)

(define-public (schedule-maintenance
  (asset-id uint)
  (maintenance-type (string-ascii 64))
  (description (string-ascii 256))
  (cost uint)
  (performed-by (string-ascii 128))
  (parts-replaced (list 10 (string-ascii 128)))
)
  (let
    (
      (asset (unwrap! (map-get? assets asset-id) ERR-ASSET-NOT-FOUND))
      (maintenance-id (var-get next-maintenance-id))
      (next-due (+ block-height u4380))
    )
    (asserts! (is-authorized-manager) ERR-NOT-AUTHORIZED)
    (asserts! (> cost u0) ERR-INVALID-INPUT)

    (map-set maintenance-records maintenance-id
      {
        asset-id: asset-id,
        maintenance-type: maintenance-type,
        description: description,
        cost: cost,
        performed-by: performed-by,
        maintenance-date: block-height,
        next-due-date: next-due,
        parts-replaced: parts-replaced,
        performed-by-principal: tx-sender
      }
    )

    (map-set assets asset-id
      (merge asset {
        last-maintenance: block-height,
        next-maintenance-due: next-due,
        condition: "maintained"
      })
    )

    (var-set next-maintenance-id (+ maintenance-id u1))
    (ok maintenance-id)
  )
)

(define-public (transfer-asset
  (asset-id uint)
  (to-department principal)
  (reason (string-ascii 256))
  (transfer-value uint)
)
  (let
    (
      (asset (unwrap! (map-get? assets asset-id) ERR-ASSET-NOT-FOUND))
      (transfer-id (var-get next-transfer-id))
      (from-department (get assigned-department asset))
    )
    (asserts! (is-authorized-manager) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status asset) "active") ERR-INVALID-STATUS-TRANSITION)
    (asserts! (not (is-eq from-department to-department)) ERR-INVALID-INPUT)

    (map-set asset-transfers transfer-id
      {
        asset-id: asset-id,
        from-department: from-department,
        to-department: to-department,
        transfer-date: block-height,
        reason: reason,
        approved-by: tx-sender,
        transfer-value: transfer-value,
        condition-at-transfer: (get condition asset)
      }
    )

    (map-set assets asset-id
      (merge asset {
        assigned-department: to-department,
        current-value: transfer-value
      })
    )

    (var-set next-transfer-id (+ transfer-id u1))
    (ok transfer-id)
  )
)

(define-public (update-asset-condition (asset-id uint) (new-condition (string-ascii 32)))
  (let
    (
      (asset (unwrap! (map-get? assets asset-id) ERR-ASSET-NOT-FOUND))
    )
    (asserts! (is-authorized-manager) ERR-NOT-AUTHORIZED)
    (map-set assets asset-id
      (merge asset { condition: new-condition })
    )
    (ok true)
  )
)

(define-public (dispose-asset
  (asset-id uint)
  (disposal-method (string-ascii 64))
  (disposal-value uint)
  (disposal-reason (string-ascii 256))
)
  (let
    (
      (asset (unwrap! (map-get? assets asset-id) ERR-ASSET-NOT-FOUND))
    )
    (asserts! (is-authorized-manager) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status asset) "active") ERR-INVALID-STATUS-TRANSITION)

    (map-set assets asset-id
      (merge asset {
        status: "disposed",
        current-value: disposal-value
      })
    )

    (map-set asset-disposal-records asset-id
      {
        disposal-date: block-height,
        disposal-method: disposal-method,
        disposal-value: disposal-value,
        approved-by: tx-sender,
        disposal-reason: disposal-reason
      }
    )
    (ok true)
  )
)

(define-public (calculate-depreciation (asset-id uint))
  (let
    (
      (asset (unwrap! (map-get? assets asset-id) ERR-ASSET-NOT-FOUND))
      (age (- block-height (get purchase-date asset)))
      (annual-depreciation (/ (* (get purchase-price asset) (get depreciation-rate asset)) u100))
      (years-passed (/ age u8760))
      (total-depreciation (* annual-depreciation years-passed))
      (new-value (if (> total-depreciation (get purchase-price asset))
                    u0
                    (- (get purchase-price asset) total-depreciation)))
    )
    (asserts! (is-authorized-manager) ERR-NOT-AUTHORIZED)
    (map-set assets asset-id
      (merge asset { current-value: new-value })
    )
    (ok new-value)
  )
)

;; Read-only Functions
(define-read-only (get-asset (asset-id uint))
  (map-get? assets asset-id)
)

(define-read-only (get-maintenance-record (maintenance-id uint))
  (map-get? maintenance-records maintenance-id)
)

(define-read-only (get-asset-transfer (transfer-id uint))
  (map-get? asset-transfers transfer-id)
)

(define-read-only (get-department-assets (department principal))
  (map-get? department-assets department)
)

(define-read-only (check-maintenance-due (asset-id uint))
  (match (map-get? assets asset-id)
    asset (>= block-height (get next-maintenance-due asset))
    false
  )
)

(define-read-only (get-asset-value (asset-id uint))
  (match (map-get? assets asset-id)
    asset (get current-value asset)
    u0
  )
)

(define-read-only (get-disposal-record (asset-id uint))
  (map-get? asset-disposal-records asset-id)
)

(define-read-only (is-manager-authorized (manager principal))
  (or (is-eq manager CONTRACT-OWNER) (default-to false (map-get? authorized-managers manager)))
)
