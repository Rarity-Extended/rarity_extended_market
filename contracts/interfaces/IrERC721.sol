//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721 {
    event Transfer(uint indexed from, uint indexed to, uint256 indexed tokenId);
    event Approval(uint indexed owner, uint indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(uint indexed owner, uint indexed operator, bool approved);
    function balanceOf(uint owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (uint owner);
    function transferFrom(
        uint operator,
        uint from,
        uint to,
        uint256 tokenId
    ) external;
    function approve(uint from, uint to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (uint operator);
    function setApprovalForAll(uint from, uint operator, bool _approved) external;
    function isApprovedForAll(uint owner, uint operator) external view returns (bool);
}