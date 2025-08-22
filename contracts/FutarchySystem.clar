;; Futarchy System Contract
;; Prediction market-based governance decisions implementation

;; Define the prediction token
(define-fungible-token prediction-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-proposal (err u101))
(define-constant err-insufficient-stake (err u102))
(define-constant err-proposal-ended (err u103))
(define-constant err-invalid-vote (err u104))

;; Data variables
(define-data-var proposal-counter uint u0)
(define-data-var minimum-stake uint u1000) ;; Minimum STX to create proposal

;; Proposal structure
(define-map proposals uint {
  creator: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  end-block: uint,
  total-yes-stake: uint,
  total-no-stake: uint,
  executed: bool
})

;; User predictions tracking
(define-map user-predictions {proposal-id: uint, user: principal} {
  vote: bool, ;; true for YES, false for NO
  stake: uint
})

;; Function 1: Create Prediction Proposal
;; Allows users to create governance proposals with prediction markets
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (duration-blocks uint))
  (let (
    (proposal-id (+ (var-get proposal-counter) u1))
    (end-block (+ stacks-block-height duration-blocks))
  )
    ;; Validate inputs
    (asserts! (> duration-blocks u0) err-invalid-proposal)
    (asserts! (> (len title) u0) err-invalid-proposal)
    
    ;; Require minimum STX stake to create proposal
    (try! (stx-transfer? (var-get minimum-stake) tx-sender (as-contract tx-sender)))
    
    ;; Store proposal
    (map-set proposals proposal-id {
      creator: tx-sender,
      title: title,
      description: description,
      end-block: end-block,
      total-yes-stake: u0,
      total-no-stake: u0,
      executed: false
    })
    
    ;; Increment counter
    (var-set proposal-counter proposal-id)
    
    ;; Print event
    (print {event: "proposal-created", proposal-id: proposal-id, creator: tx-sender})
    
    (ok proposal-id)
  )
)

;; Function 2: Place Prediction Bet
;; Allows users to stake STX on YES/NO predictions for proposals
(define-public (place-prediction (proposal-id uint) (vote bool) (stake-amount uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) err-invalid-proposal))
    (current-prediction (map-get? user-predictions {proposal-id: proposal-id, user: tx-sender}))
  )
    ;; Validate proposal exists and is active
    (asserts! (<= stacks-block-height (get end-block proposal)) err-proposal-ended)
    (asserts! (> stake-amount u0) err-insufficient-stake)
    
    ;; Ensure user hasn't already predicted on this proposal
    (asserts! (is-none current-prediction) err-invalid-vote)
    
    ;; Transfer stake to contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    ;; Record user's prediction
    (map-set user-predictions 
      {proposal-id: proposal-id, user: tx-sender}
      {vote: vote, stake: stake-amount}
    )
    
    ;; Update proposal totals
    (if vote
      ;; YES vote
      (map-set proposals proposal-id 
        (merge proposal {total-yes-stake: (+ (get total-yes-stake proposal) stake-amount)})
      )
      ;; NO vote  
      (map-set proposals proposal-id
        (merge proposal {total-no-stake: (+ (get total-no-stake proposal) stake-amount)})
      )
    )
    
    ;; Print event
    (print {
      event: "prediction-placed",
      proposal-id: proposal-id,
      user: tx-sender,
      vote: vote,
      stake: stake-amount
    })
    
    (ok true)
  )
)

;; Read-only functions for querying data

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-user-prediction (proposal-id uint) (user principal))
  (map-get? user-predictions {proposal-id: proposal-id, user: user})
)

(define-read-only (get-proposal-count)
  (var-get proposal-counter)
)

(define-read-only (get-minimum-stake)
  (var-get minimum-stake)
)