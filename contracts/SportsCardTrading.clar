;; Sports Card Trading Contract
;; A digital sports card marketplace with verified authenticity and dynamic statistics

;; Define the non-fungible token for sports cards
(define-non-fungible-token sports-card uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-card-not-found (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-card-not-for-sale (err u104))
(define-constant err-insufficient-funds (err u105))

;; Data variables
(define-data-var next-card-id uint u1)

;; Card metadata structure
(define-map card-metadata uint { 
  player-name: (string-ascii 50),
  sport: (string-ascii 20),
  team: (string-ascii 30),
  year: uint,
  rarity: (string-ascii 15),
  verified: bool,
  statistics: (string-ascii 200)
})

;; Marketplace data
(define-map cards-for-sale uint {
  seller: principal,
  price: uint,
  listed-at: uint
})

;; Function 1: Mint a new sports card with verification
(define-public (mint-sports-card 
  (player-name (string-ascii 50))
  (sport (string-ascii 20))
  (team (string-ascii 30))
  (year uint)
  (rarity (string-ascii 15))
  (statistics (string-ascii 200))
  (recipient principal))
  (let ((card-id (var-get next-card-id)))
    (begin
      ;; Only contract owner can mint cards (verification authority)
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      
      ;; Mint the NFT
      (try! (nft-mint? sports-card card-id recipient))
      
      ;; Store card metadata with verified status
      (map-set card-metadata card-id {
        player-name: player-name,
        sport: sport,
        team: team,
        year: year,
        rarity: rarity,
        verified: true,
        statistics: statistics
      })
      
      ;; Increment card ID for next mint
      (var-set next-card-id (+ card-id u1))
      
      ;; Return the minted card ID
      (ok card-id))))

;; Function 2: Buy a sports card from the marketplace
(define-public (buy-sports-card (card-id uint))
  (let ((card-sale-data (unwrap! (map-get? cards-for-sale card-id) err-card-not-for-sale))
        (seller (get seller card-sale-data))
        (price (get price card-sale-data)))
    (begin
      ;; Ensure card exists
      (asserts! (is-some (map-get? card-metadata card-id)) err-card-not-found)
      
      ;; Transfer STX from buyer to seller
      (try! (stx-transfer? price tx-sender seller))
      
      ;; Transfer NFT from seller to buyer
      (try! (nft-transfer? sports-card card-id seller tx-sender))
      
      ;; Remove card from marketplace
      (map-delete cards-for-sale card-id)
      
      ;; Log the transaction
      (print {
        event: "card-sold",
        card-id: card-id,
        seller: seller,
        buyer: tx-sender,
        price: price,
        block-height: stacks-block-height
      })
      
      (ok true))))

;; Read-only function to get card metadata
(define-read-only (get-card-info (card-id uint))
  (map-get? card-metadata card-id))

;; Read-only function to get card sale info
(define-read-only (get-sale-info (card-id uint))
  (map-get? cards-for-sale card-id))

;; Read-only function to get card owner
(define-read-only (get-card-owner (card-id uint))
  (nft-get-owner? sports-card card-id))

;; Helper function to list a card for sale (for future use)
(define-public (list-card-for-sale (card-id uint) (price uint))
  (let ((card-owner (unwrap! (nft-get-owner? sports-card card-id) err-card-not-found)))
    (begin
      ;; Only card owner can list for sale
      (asserts! (is-eq tx-sender card-owner) err-not-authorized)
      (asserts! (> price u0) err-invalid-price)
      
      ;; List the card
      (map-set cards-for-sale card-id {
        seller: tx-sender,
        price: price,
        listed-at: stacks-block-height
      })
      
      (ok true))))