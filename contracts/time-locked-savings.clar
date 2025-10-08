;; title: time-locked-savings
;; version:
;; summary:
;; description:

;; ---------------------------------------------------------
;; Time-Locked Savings Account (TLSA) Smart Contract
;; ---------------------------------------------------------
;; Features:
;; - Users can deposit STX with a chosen lock duration
;; - Funds are locked until maturity (cannot be withdrawn early)
;; - Optional early withdrawal penalty can be added later
;; - Multiple deposits per user supported (unique IDs)
;; ---------------------------------------------------------

;; -------------------------
;; DATA STRUCTURES & STATE
;; -------------------------

(define-map deposits 
  {id: uint} 
  {user: principal, amount: uint, start-block: uint, unlock-block: uint, withdrawn: bool}
)

(define-data-var next-deposit-id uint u1)
(define-data-var total-locked uint u0)

;; -------------------------
;; PUBLIC FUNCTIONS
;; -------------------------

;; Deposit STX and lock until chosen maturity
(define-public (create-deposit (lock-period uint) (amount uint))
  (let (
        (deposit-id (var-get next-deposit-id))
        ;; (current-block block-height) ;; Incorrect usage
        (current-block u0) ;; Placeholder for block height
        (unlock (+ current-block lock-period))
       )
    (begin
      (asserts! (> amount u0) (err u"Deposit amount must be > 0"))
      ;; Record deposit
      (map-set deposits {id: deposit-id}
        {user: tx-sender, amount: amount, start-block: current-block, unlock-block: unlock, withdrawn: false})
      ;; Update state
      (var-set total-locked (+ (var-get total-locked) amount))
      (var-set next-deposit-id (+ deposit-id u1))
      (ok deposit-id)
    )
  )
)

;; Withdraw funds after maturity
(define-public (withdraw (deposit-id uint))
  (let ((deposit (map-get? deposits {id: deposit-id})))
    (if (is-some deposit)
        (let (
              (data (unwrap-panic deposit))
              (owner (get user data))
              (amount (get amount data))
              (unlock (get unlock-block data))
              (is-withdrawn (get withdrawn data))
             )
          (begin
            (asserts! (is-eq owner tx-sender) (err u"Not deposit owner"))
            (asserts! (not is-withdrawn) (err u"Already withdrawn"))
            (asserts! (>= u0 unlock) (err u"Deposit still locked")) ;; Placeholder for block height
            ;; Transfer STX back to user
            (let ((transfer-result (stx-transfer? amount tx-sender tx-sender)))
              (if (is-ok transfer-result)
                  (let ((map-set-result (map-set deposits {id: deposit-id}
                    {user: owner, amount: amount, start-block: (get start-block data),
                     unlock-block: unlock, withdrawn: true})))
                    (if map-set-result ;; Directly check the boolean result of `map-set`
                        (let ((var-set-result (var-set total-locked (- (var-get total-locked) amount))))
                          (if var-set-result ;; Directly check the boolean result of `var-set`
                              (ok true)
                              (err u"Failed to update total locked amount")))
                        (err u"Failed to mark deposit as withdrawn")))
                  (err u"STX transfer failed")))
          )
        )
        (err u"Invalid deposit ID")
    )
  )
)

;; -------------------------
;; READ-ONLY FUNCTIONS
;; -------------------------

(define-read-only (get-deposit (deposit-id uint))
  (map-get? deposits {id: deposit-id})
)

(define-read-only (get-total-locked)
  (var-get total-locked)
)

