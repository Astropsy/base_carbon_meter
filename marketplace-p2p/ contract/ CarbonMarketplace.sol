// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * CarbonMarketplace.sol
 * ---------------------
 * Simple peer-to-peer marketplace for BaseCarbon (BC) tokens.
 *
 * Features:
 *  - Producers list BC tokens for sale
 *  - Buyers can Buy Now at list price
 *  - Buyers can submit offers (volume discounts / negotiation)
 *  - Sellers can accept offers on-chain
 *  - 95% BC to buyer, 5% BC to treasury (protocol fee)
 *  - ETH payment -> forwarded to the seller
 *
 * Designed for:
 *  - ESG buyers (airlines, exporters, corporates)
 *  - Farmers / solar producers / off-grid assets
 *  - Buyers using any currency (fiat or crypto) via CDP swap before purchase
 */

interface IBaseCarbonToken {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract CarbonMarketplace {
    // ------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------

    IBaseCarbonToken public immutable bcToken;
    address public immutable treasury;

    uint256 public listingCounter;
    uint256 public offerCounter;

    struct Listing {
        uint256 id;
        address seller;
        uint256 amountBC;    // full BC amount seller is offering
        uint256 priceEth;    // price in wei for full amount
        bool active;
    }

    struct Offer {
        uint256 id;
        uint256 listingId;
        address buyer;
        uint256 amountBC;
        uint256 offerEth;    // buyer’s ETH offer (total)
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer)   private offers with private handles;

    // ------------------------------------------------------------
    // Events
    // ------------------------------------------------------------

    event ListingCreated(uint256 listingId, address seller, uint256 amountBC, uint256 priceEth);
    event ListingPurchased(uint256 listingId, address buyer, uint256 amountBC, uint256 priceEth);

    event OfferMade(uint256 offerId, uint256 listingId, address buyer, uint256 amountBC, uint256 offerEth);
    event OfferAccepted(uint256 offerId, uint256 listingId, address seller, address buyer);

    // ------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------

    constructor(address tokenAddress, address treasuryAddress) {
        require(tokenAddress != address(0), "Zero token");
        require(treasuryAddress != address(0), "Zero treasury");

        bcToken = IBaseCarbonToken(tokenAddress);
        treasury = treasuryAddress;
    }

    // ------------------------------------------------------------
    // Listing: Seller posts BC for sale
    // ------------------------------------------------------------

    function createListing(uint256 amountBC, uint256 priceEth) external returns (uint256 listingId) {
        require(amountBC > 0, "Zero amount");
        require(priceEth > 0, "Zero price");

        listingCounter++;
        listingId = listingCounter;

        listings[listingId] = Listing({
            id: listingId,
            seller: msg.sender,
            amountBC: amountBC,
            priceEth: priceEth,
            active: true
        });

        emit ListingCreated(listingId, msg.sender, amountBC, priceEth);
    }

    // ------------------------------------------------------------
    // BUY NOW
    // ------------------------------------------------------------

    function buyNow(uint256 listingId) external payable {
        Listing storage lst = listings[listingId];
        require(lst.active, "Listing inactive");
        require(msg.value == lst.priceEth, "Incorrect ETH");

        lst.active = false;

        uint256 amountBC = lst.amountBC;

        // 95% BC to buyer, 5% to treasury
        uint256 buyerBC = (amountBC * 95) / 100;
        uint256 feeBC   = amountBC - buyerBC;

        // Token transfers
        require(bcToken.transferFrom(lst.seller, msg.sender, buyerBC), "Transfer fail");
        require(bcToken.transferFrom(lst.seller, treasury,   feeBC),   "Fee fail");

        // ETH → seller (full amount)
        payable(lst.seller).transfer(msg.value);

        emit ListingPurchased(listingId, msg.sender, amountBC, msg.value);
    }

    // ------------------------------------------------------------
    // OFFERS: Buyer wants a discount or better rate
    // ------------------------------------------------------------

    function makeOffer(uint256 listingId, uint256 amountBC, uint256 offerEth)
        external
        payable
        returns (uint256 offerId)
    {
        Listing memory lst = listings[listingId];
        require(lst.active, "Listing inactive");
        require(amountBC > 0, "Zero BC");
        require(offerEth > 0, "Zero offer");
        require(msg.value == offerEth, "ETH mismatch");

        offerCounter++;
        offerId = offerCounter;

        offers[offerId] = Offer({
            id: offerId,
            listingId: listingId,
            buyer: msg.sender,
            amountBC: amountBC,
            offerEth: offerEth,
            active: true
        });

        emit OfferMade(offerId, listingId, msg.sender, amountBC, offerEth);
    }

    // ------------------------------------------------------------
    // ACCEPT OFFER (Seller decides to take it)
    // ------------------------------------------------------------

    function acceptOffer(uint256 offerId) external {
        Offer storage off = offers[offerId];
        require(off.active, "Offer inactive");

        Listing storage lst = listings[off.listingId];
        require(lst.active, "Listing inactive");
        require(lst.seller == msg.sender, "Not seller");

        // Mark both closed
        lst.active = false;
        off.active = false;

        uint256 amountBC = off.amountBC;

        // 95/5 split
        uint256 buyerBC = (amountBC * 95) / 100;
        uint256 feeBC   = amountBC - buyerBC;

         // ETH to seller (agreement price)
        payable(lst.seller).transfer(off.offerEth);

        // Transfer BC tokens
        require(bcToken.transferFrom(lst.seller, off.buyer, buyerBC), "Transfer fail");
        require(bcToken.transferFrom(lst.seller, treasury,   feeBC),  "Fee fail");

        emit OfferAccepted(offerId, lst.id, lst.seller, off.buyer);
    }
}
