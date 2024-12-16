;; Decentralized Crowdfunding Platform Smart Contract

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))
(define-constant ERR-PROJECT-NOT-FOUND (err u102))
(define-constant ERR-CAMPAIGN-CLOSED (err u103))
(define-constant ERR-MILESTONE-ALREADY-APPROVED (err u104))

;; Project structure
(define-map projects
  { project-id: uint }
  {
    creator: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    target-amount: uint,
    raised-amount: uint,
    deadline: uint,
    is-active: bool,
    milestones: (list 5 { description: (string-utf8 200), amount: uint, approved: bool })
  }
)

;; Contributions tracking
(define-map contributions 
  { project-id: uint, contributor: principal } 
  { amount: uint }
)

;; Unique project ID counter
(define-data-var next-project-id uint u0)

;; Create a new crowdfunding project
(define-public (create-project 
  (title (string-utf8 100))
  (description (string-utf8 500))
  (target-amount uint)
  (deadline uint)
  (milestones (list 5 { description: (string-utf8 200), amount: uint }))
)
  (let 
    (
      (project-id (var-get next-project-id))
      (total-milestone-amount (fold + (map get-milestone-amount milestones) u0))
    )
    ;; Validate milestone amounts
    (asserts! (>= target-amount total-milestone-amount) ERR-INSUFFICIENT-FUNDS)
    
    ;; Create project map entry
    (map-set projects 
      { project-id: project-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        target-amount: target-amount,
        raised-amount: u0,
        deadline: deadline,
        is-active: true,
        milestones: (map prepare-milestone milestones)
      }
    )
    
    ;; Increment project ID
    (var-set next-project-id (+ project-id u1))
    
    ;; Return project ID
    (ok project-id)
  )
)

;; Helper function to get milestone amount
(define-read-only (get-milestone-amount (milestone { description: (string-utf8 200), amount: uint }))
  (get amount milestone)
)

;; Helper function to prepare milestone
(define-read-only (prepare-milestone (milestone { description: (string-utf8 200), amount: uint }))
  { description: (get description milestone), amount: (get amount milestone), approved: false }
)

;; Contribute to a project
(define-public (contribute (project-id uint))
  (let 
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (current-contribution (default-to { amount: u0 } (map-get? contributions { project-id: project-id, contributor: tx-sender })))
    )
    ;; Validate project is active and not past deadline
    (asserts! (get is-active project) ERR-CAMPAIGN-CLOSED)
    (asserts! (> block-height (get deadline project)) ERR-CAMPAIGN-CLOSED)
    
    ;; Update contributions
    (map-set contributions 
      { project-id: project-id, contributor: tx-sender }
      { amount: (+ (get amount current-contribution) stx-transferred) }
    )
    
    ;; Update project raised amount
    (map-set projects 
      { project-id: project-id }
      (merge project { raised-amount: (+ (get raised-amount project) stx-transferred) })
    )
    
    (ok true)
  )
)

;; Approve milestone
(define-public (approve-milestone (project-id uint) (milestone-index uint))
  (let 
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (milestones (get milestones project))
      (milestone (unwrap! (list-at? milestones milestone-index) ERR-PROJECT-NOT-FOUND))
    )
    ;; Only project creator can approve milestones
    (asserts! (is-eq tx-sender (get creator project)) ERR-UNAUTHORIZED)
    (asserts! (not (get approved milestone)) ERR-MILESTONE-ALREADY-APPROVED)
    
    ;; Update milestone approval
    (map-set projects 
      { project-id: project-id }
      (merge project 
        { 
          milestones: (replace milestones milestone-index 
            (merge milestone { approved: true })
          ) 
        }
      )
    )
    
    (ok true)
  )
)

;; Withdraw funds for an approved milestone
(define-public (withdraw-milestone-funds (project-id uint) (milestone-index uint))
  (let 
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (milestones (get milestones project))
      (milestone (unwrap! (list-at? milestones milestone-index) ERR-PROJECT-NOT-FOUND))
    )
    ;; Validate milestone is approved
    (asserts! (get approved milestone) ERR-UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get creator project)) ERR-UNAUTHORIZED)
    
    ;; Transfer milestone funds
    (try! (stx-transfer? (get amount milestone) tx-sender (get creator project)))
    
    (ok true)
  )
)

;; Get project details
(define-read-only (get-project-details (project-id uint))
  (map-get? projects { project-id: project-id })
)