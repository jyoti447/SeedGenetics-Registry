;; SeedGenetics Registry Contract
;; Track seed varieties and genetic modifications with farmer rights and patent management

;; Define NFT for unique seed varieties
(define-non-fungible-token seed-variety uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-seed-exists (err u102))
(define-constant err-seed-not-found (err u103))
(define-constant err-invalid-data (err u104))

;; Data variables
(define-data-var next-seed-id uint u1)
(define-data-var total-registered-seeds uint u0)

;; Seed registry data structure
(define-map seed-registry uint {
  variety-name: (string-ascii 64),
  genetic-modifications: (string-ascii 256),
  farmer-address: principal,
  patent-holder: (optional principal),
  registration-date: uint,
  farmer-rights-protected: bool,
  origin-location: (string-ascii 128)
})

;; Farmer rights tracking
(define-map farmer-rights principal {
  total-seeds: uint,
  last-registration: uint,
  verified-farmer: bool
})

;; Function 1: Register a new seed variety
(define-public (register-seed-variety 
  (variety-name (string-ascii 64))
  (genetic-modifications (string-ascii 256))
  (patent-holder (optional principal))
  (origin-location (string-ascii 128)))
  (let 
    ((seed-id (var-get next-seed-id))
     (current-block stacks-block-height))
    (begin
      ;; Validate input data
      (asserts! (> (len variety-name) u0) err-invalid-data)
      (asserts! (> (len origin-location) u0) err-invalid-data)
      
      ;; Register the seed variety
      (try! (nft-mint? seed-variety seed-id tx-sender))
      
      ;; Store seed information
      (map-set seed-registry seed-id {
        variety-name: variety-name,
        genetic-modifications: genetic-modifications,
        farmer-address: tx-sender,
        patent-holder: patent-holder,
        registration-date: current-block,
        farmer-rights-protected: true,
        origin-location: origin-location
      })
      
      ;; Update farmer rights record
      (map-set farmer-rights tx-sender {
        total-seeds: (+ (get total-seeds (default-to {total-seeds: u0, last-registration: u0, verified-farmer: false} 
                                         (map-get? farmer-rights tx-sender))) u1),
        last-registration: current-block,
        verified-farmer: true
      })
      
      ;; Update counters
      (var-set next-seed-id (+ seed-id u1))
      (var-set total-registered-seeds (+ (var-get total-registered-seeds) u1))
      
      (print {
        event: "seed-registered",
        seed-id: seed-id,
        farmer: tx-sender,
        variety: variety-name
      })
      
      (ok seed-id))))

;; Function 2: Get seed variety information with farmer rights verification
(define-read-only (get-seed-info (seed-id uint))
  (match (map-get? seed-registry seed-id)
    seed-data (ok {
      seed-id: seed-id,
      variety-name: (get variety-name seed-data),
      genetic-modifications: (get genetic-modifications seed-data),
      farmer-address: (get farmer-address seed-data),
      patent-holder: (get patent-holder seed-data),
      registration-date: (get registration-date seed-data),
      farmer-rights-protected: (get farmer-rights-protected seed-data),
      origin-location: (get origin-location seed-data),
      farmer-stats: (map-get? farmer-rights (get farmer-address seed-data))
    })
    err-seed-not-found))

;; Read-only helper functions
(define-read-only (get-total-registered-seeds)
  (ok (var-get total-registered-seeds)))

(define-read-only (get-farmer-rights (farmer principal))
  (ok (map-get? farmer-rights farmer)))

(define-read-only (get-seed-owner (seed-id uint))
  (ok (nft-get-owner? seed-variety seed-id)))
  