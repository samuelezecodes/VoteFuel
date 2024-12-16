;; Decentralized Crowdfunding Platform Smart Contract

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-FUNDS (err u101))
(define-constant ERR-PROJECT-NOT-FOUND (err u102))
(define-constant ERR-CAMPAIGN-CLOSED (err u103))
(define-constant ERR-MILESTONE-ALREADY-APPROVED (err u104))
(define-constant ERR-INVALID-MILESTONE-INDEX (err u105))
(define-constant ERR-NO-REFUND-ELIGIBLE (err u106))
(define-constant ERR-ALREADY-REFUNDED (err u107))
(define-constant ERR-PROJECT-SUCCESSFUL (err u108))
(define-constant ERR-INVALID-INPUT (err u109))
(define-constant ERR-NOT-ALL-MILESTONES-COMPLETE (err u110))

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
    is-complete: bool,
    milestones: (list 5 { description: (string-utf8 200), amount: uint, approved: bool })
  }
)

;; Contributions tracking with refund status
(define-map contributions 
  { project-id: uint, contributor: principal } 
  { 
    amount: uint,
    refunded: bool 
  }
)

;; Unique project ID counter
(define-data-var next-project-id uint u0)

;; Helper function to check if all milestones are approved
(define-read-only (all-milestones-approved? (milestones (list 5 { description: (string-utf8 200), amount: uint, approved: bool })))
  (is-eq (len (filter is-milestone-approved milestones)) (len milestones))
)

;; Helper function to check if a milestone is approved
(define-read-only (is-milestone-approved (milestone { description: (string-utf8 200), amount: uint, approved: bool }))
  (get approved milestone)
)

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
    ;; Validate inputs
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> target-amount u0) ERR-INVALID-INPUT)
    (asserts! (> deadline block-height) ERR-INVALID-INPUT)
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
        is-complete: false,
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

;; Get milestone by index
(define-private (get-milestone-by-index 
  (project-milestones (list 5 { description: (string-utf8 200), amount: uint, approved: bool })) 
  (milestone-index uint)
)
  (element-at project-milestones milestone-index)
)

;; Update milestone in list
(define-private (update-milestone-list 
  (milestones (list 5 { description: (string-utf8 200), amount: uint, approved: bool })) 
  (milestone-index uint)
  (updated-milestone { description: (string-utf8 200), amount: uint, approved: bool })
)
  (let
    (
      (prefix (unwrap! (slice? milestones u0 milestone-index) milestones))
      (suffix (unwrap! (slice? milestones (+ milestone-index u1) (len milestones)) milestones))
    )
    (unwrap-panic 
      (as-max-len? 
        (concat
          prefix
          (unwrap-panic 
            (as-max-len? 
              (concat 
                (list updated-milestone)
                suffix
              )
              u5
            )
          )
        )
        u5
      )
    )
  )
)

;; Check if project is eligible for refunds
(define-read-only (is-refund-eligible (project-id uint))
  (match (map-get? projects { project-id: project-id })
    project (and 
      (>= block-height (get deadline project))
      (< (get raised-amount project) (get target-amount project))
      (get is-active project)
    )
    false
  )
)

;; Contribute to a project
(define-public (contribute (project-id uint) (stx-transferred uint))
  (let 
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (current-contribution (default-to { amount: u0, refunded: false } 
        (map-get? contributions { project-id: project-id, contributor: tx-sender })))
    )
    ;; Validate inputs
    (asserts! (> project-id u0) ERR-INVALID-INPUT)
    (asserts! (> stx-transferred u0) ERR-INVALID-INPUT)
    
    ;; Validate project is active and not past deadline
    (asserts! (get is-active project) ERR-CAMPAIGN-CLOSED)
    (asserts! (< block-height (get deadline project)) ERR-CAMPAIGN-CLOSED)
    
    ;; Update contributions
    (map-set contributions 
      { project-id: project-id, contributor: tx-sender }
      { amount: (+ (get amount current-contribution) stx-transferred), refunded: false }
    )
    
    ;; Update project raised amount
    (map-set projects 
      { project-id: project-id }
      (merge project { raised-amount: (+ (get raised-amount project) stx-transferred) })
    )
    
    (ok true)
  )
)

;; Request refund for a failed project
(define-public (request-refund (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
      (contribution (unwrap! (map-get? contributions { project-id: project-id, contributor: tx-sender }) 
        ERR-NO-REFUND-ELIGIBLE))
    )
    ;; Validate input
    (asserts! (> project-id u0) ERR-INVALID-INPUT)
    
    ;; Check refund eligibility
    (asserts! (is-refund-eligible project-id) ERR-PROJECT-SUCCESSFUL)
    (asserts! (not (get refunded contribution)) ERR-ALREADY-REFUNDED)
    
    ;; Process refund
    (try! (stx-transfer? (get amount contribution) tx-sender CONTRACT-OWNER))
    
    ;; Mark contribution as refunded
    (map-set contributions
      { project-id: project-id, contributor: tx-sender }
      (merge contribution { refunded: true })
    )
    
    (ok true)
  )
)

;; Close failed project and enable refunds
(define-public (close-failed-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
    )
    ;; Validate input
    (asserts! (> project-id u0) ERR-INVALID-INPUT)
    
    ;; Verify project has failed
    (asserts! (>= block-height (get deadline project)) ERR-CAMPAIGN-CLOSED)
    (asserts! (< (get raised-amount project) (get target-amount project)) ERR-PROJECT-SUCCESSFUL)
    (asserts! (get is-active project) ERR-CAMPAIGN-CLOSED)
    
    ;; Update project status
    (map-set projects
      { project-id: project-id }
      (merge project { is-active: false })
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
      (milestone-opt (get-milestone-by-index milestones milestone-index))
      (milestone (unwrap! milestone-opt ERR-INVALID-MILESTONE-INDEX))
    )
    ;; Validate inputs
    (asserts! (> project-id u0) ERR-INVALID-INPUT)
    (asserts! (< milestone-index (len milestones)) ERR-INVALID-INPUT)
    
    ;; Only project creator can approve milestones
    (asserts! (is-eq tx-sender (get creator project)) ERR-UNAUTHORIZED)
    (asserts! (not (get approved milestone)) ERR-MILESTONE-ALREADY-APPROVED)
    
    ;; Update milestone approval
    (map-set projects 
      { project-id: project-id }
      (merge project { milestones: (update-milestone-list milestones milestone-index (merge milestone { approved: true })) })
    )
    
    (ok true)
  )
)

;; Complete project function
(define-public (complete-project (project-id uint))
  (let
    (
      (project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
    )
    ;; Validate inputs
    (asserts! (> project-id u0) ERR-INVALID-INPUT)
    
    ;; Only project creator can complete the project
    (asserts! (is-eq tx-sender (get creator project)) ERR-UNAUTHORIZED)
    
    ;; Check if project is active
    (asserts! (get is-active project) ERR-CAMPAIGN-CLOSED)
    
    ;; Check if all milestones are approved
    (asserts! (all-milestones-approved? (get milestones project)) ERR-NOT-ALL-MILESTONES-COMPLETE)
    
    ;; Update project status
    (map-set projects
      { project-id: project-id }
      (merge project 
        { 
          is-active: false,
          is-complete: true
        }
      )
    )
    
    (ok true)
  )
)