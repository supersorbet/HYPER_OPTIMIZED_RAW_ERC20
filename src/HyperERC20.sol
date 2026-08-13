// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.28;

/// @title 1️⃣️3️⃣️3️⃣️7️⃣️
/// @notice OPTIMIZED ERC20 + EIP-2612 PERMIT + EIP-3009 TRANSFER_WITH_AUTHORIZATION
/// @author sorbet

contract navySeal {
    /// @dev Thrown when caller is not authorized for owner-only functions
    error Unauthorized();
    /// @dev Thrown when the total supply overflows
    error TotalSupplyOverflow();
    /// @dev Thrown when account has insufficient balance for operation
    error InsufficientBalance();
    /// @dev Thrown when spender has insufficient allowance for operation
    error InsufficientAllowance();
    /// @dev Thrown when attempting to transfer to or from zero address
    error InvalidAddress();
    /// @dev Thrown when permit deadline has passed
    error PermitExpired();
    /// @dev Thrown when signature is invalid
    error InvalidSignature();
    /// @dev Thrown when nonce has already been used
    error InvalidNonce();
    /// @dev Thrown when authorization is not yet valid
    error AuthorizationNotYetValid();
    /// @dev Thrown when authorization has expired
    error AuthorizationExpired();
    /// @dev Thrown when authorization has already been used or cancelled
    error AuthorizationAlreadyUsed();
    /// @dev Thrown when attempting to decrease allowance below zero
    error AllowanceBelowZero();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CONSTANTS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Token name with decorations
    string public constant name = unicode"navy seal 1️⃣️3️⃣️3️⃣️7️⃣️";
    /// @notice Token symbol with decorations
    string public constant symbol = unicode"N4VY S34L";
    /// @notice Number of decimals for token amounts
    uint8 public constant decimals = 18;
    /// @notice Domain separator for EIP-712 signatures
    bytes32 public immutable DOMAIN_SEPARATOR;
    /// @notice Typehash for permit (EIP-2612)
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    /// @notice Typehash for transferWithAuthorization (EIP-3009)
    bytes32 public constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH =
        keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)");
    /// @notice Typehash for receiveWithAuthorization (EIP-3009)
    bytes32 public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH =
        keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)");
    /// @notice Typehash for cancelAuthorization (EIP-3009)
    bytes32 public constant CANCEL_AUTHORIZATION_TYPEHASH =
        keccak256("CancelAuthorization(address authorizer,bytes32 nonce)");

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           STORAGE                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Total token supply
    /// @dev Storage slot 0
    uint256 public totalSupply;
    /// @notice Contract owner address
    /// @dev Storage slot 1
    address public owner;
    /// @notice Balance of each account
    /// @dev Storage slot 2 - mapping(address => uint256)
    mapping(address => uint256) public balanceOf;
    /// @notice Allowance granted by owner to spender
    /// @dev Storage slot 3 - mapping(address => mapping(address => uint256))
    mapping(address => mapping(address => uint256)) public allowance;
    /// @notice Nonces for EIP-2612 permit
    /// @dev Storage slot 4 - mapping(address => uint256)
    mapping(address => uint256) public nonces;
    /// @notice Authorization state for EIP-3009
    /// @dev Storage slot 5 - mapping(address => mapping(bytes32 => bool))
    mapping(address => mapping(bytes32 => bool)) public authorizationState;

    /// @dev Restricts function access to contract owner only
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTRUCTOR                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor() payable {
        assembly {
            let deployer := caller()
            let initialSupply := 1000000000000000000000000000
            ///owner = deployer  (slot 1)
            sstore(1, deployer)
            sstore(0, initialSupply)
            ///balanceOf[deployer] = initialSupply
            ///slot = keccak256(abi.encode(deployer, 2))
            mstore(0x00, deployer)
            mstore(0x20, 2)
            let balanceSlot := keccak256(0x00, 0x40)
            sstore(balanceSlot, initialSupply)

            ///Emit Transfer(address(0), deployer, initialSupply)
            mstore(0x00, initialSupply)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                0,
                deployer
            )
        }

        /// Compute and store DOMAIN_SEPARATOR for EIP-712
        /// DOMAIN_SEPARATOR = keccak256(abi.encode(
        ///     keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        ///     keccak256(bytes(name)),
        ///     keccak256(bytes("1")),
        ///     block.chainid,
        ///     address(this)
        /// ))
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CORE ERC20                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function transfer(address to, uint256 amount) public virtual returns (bool success) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool success) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual returns (bool success) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    SAFE ALLOWANCE OPS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool success) {
        assembly {
            let owner_ := caller()
            ///Compute allowance slot: keccak256(spender, keccak256(owner, 3))
            mstore(0x00, owner_)
            mstore(0x20, 3)
            let innerSlot := keccak256(0x00, 0x40)
            mstore(0x00, spender)
            mstore(0x20, innerSlot)
            let allowanceSlot := keccak256(0x00, 0x40)
            let currentAllowance := sload(allowanceSlot)
            let newAllowance := add(currentAllowance, addedValue)
            ///Overflow check: if newAllowance < currentAllowance, overflow occurred
            if lt(newAllowance, currentAllowance) {
                mstore(0x00, 0xe5cfe957) ///TotalSupplyOverflow() pattern
                revert(0x1c, 0x04)
            }
            sstore(allowanceSlot, newAllowance)
            ///Emit Approval(owner, spender, newAllowance)
            mstore(0x00, newAllowance)
            log3(
                0x00,
                0x20,
                0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925,
                owner_,
                spender
            )
        }
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool success) {
        assembly {
            let owner_ := caller()
            ///Compute allowance slot: keccak256(spender, keccak256(owner, 3))
            mstore(0x00, owner_)
            mstore(0x20, 3)
            let innerSlot := keccak256(0x00, 0x40)
            mstore(0x00, spender)
            mstore(0x20, innerSlot)
            let allowanceSlot := keccak256(0x00, 0x40)
            let currentAllowance := sload(allowanceSlot)
            ///Revert if trying to decrease below zero
            if lt(currentAllowance, subtractedValue) {
                mstore(0x00, 0x9e5cc52e) ///AllowanceBelowZero()
                revert(0x1c, 0x04)
            }
            let newAllowance := sub(currentAllowance, subtractedValue)
            sstore(allowanceSlot, newAllowance)
            ///Emit Approval(owner, spender, newAllowance)
            mstore(0x00, newAllowance)
            log3(
                0x00,
                0x20,
                0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925,
                owner_,
                spender
            )
        }
        return true;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      EIP-2612 PERMIT                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function permit(
        address owner_,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        ///Check deadline
        if (block.timestamp > deadline) revert PermitExpired();

        ///Get and increment nonce
        uint256 nonce = nonces[owner_];
        nonces[owner_] = nonce + 1;

        ///Compute digest: keccak256(abi.encodePacked("\\x19\\x01", DOMAIN_SEPARATOR, structHash))
        ///structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline))
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner_, spender, value, nonce, deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\\x19\\x01", DOMAIN_SEPARATOR, structHash));

        ///Recover signer
        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0) || recovered != owner_) revert InvalidSignature();

        _approve(owner_, spender, value);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EIP-3009 AUTHORIZATION                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
        _requireValidAuthorization(from, nonce, validAfter, validBefore);

        bytes32 structHash = keccak256(
            abi.encode(TRANSFER_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce)
        );
        _validateSignature(from, structHash, v, r, s);

        _markAuthorizationAsUsed(from, nonce);
        _transfer(from, to, value);
    }

    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
        if (to != msg.sender) revert InvalidAddress();
        _requireValidAuthorization(from, nonce, validAfter, validBefore);

        bytes32 structHash = keccak256(
            abi.encode(RECEIVE_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce)
        );
        _validateSignature(from, structHash, v, r, s);

        _markAuthorizationAsUsed(from, nonce);
        _transfer(from, to, value);
    }

    function cancelAuthorization(
        address authorizer,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
        bytes32 structHash = keccak256(
            abi.encode(CANCEL_AUTHORIZATION_TYPEHASH, authorizer, nonce)
        );
        _validateSignature(authorizer, structHash, v, r, s);

        _markAuthorizationAsUsed(authorizer, nonce);
        emit AuthorizationCanceled(authorizer, nonce);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    INTERNAL HELPERS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _transfer(address from, address to, uint256 amount) internal virtual {
        assembly {
            ///Revert if from or to is zero address
            if iszero(from) {
                mstore(0x00, 0xc5723b51) ///InvalidAddress()
                revert(0x1c, 0x04)
            }
            if iszero(to) {
                mstore(0x00, 0xc5723b51) ///InvalidAddress()
                revert(0x1c, 0x04)
            }
            ///Load from balance: keccak256(abi.encode(from, 2))
            mstore(0x00, from)
            mstore(0x20, 2)
            let fromBalanceSlot := keccak256(0x00, 0x40)
            let fromBalance := sload(fromBalanceSlot)
            ///Revert if insufficient balance
            if lt(fromBalance, amount) {
                mstore(0x00, 0xf4d678b8) ///InsufficientBalance()
                revert(0x1c, 0x04)
            }
            ///Update from balance
            sstore(fromBalanceSlot, sub(fromBalance, amount))
            ///Load and update recipient balance: keccak256(abi.encode(to, 2))
            mstore(0x00, to)
            mstore(0x20, 2)
            let toBalanceSlot := keccak256(0x00, 0x40)
            sstore(toBalanceSlot, add(sload(toBalanceSlot), amount))
            ///Emit Transfer(from, to, amount)
            mstore(0x00, amount)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                from,
                to
            )
        }
    }

    function _approve(address owner_, address spender, uint256 amount) internal virtual {
        assembly {
            ///Compute allowance slot: keccak256(spender, keccak256(owner_, 3))
            mstore(0x00, owner_)
            mstore(0x20, 3)
            let innerSlot := keccak256(0x00, 0x40)
            mstore(0x00, spender)
            mstore(0x20, innerSlot)
            let allowanceSlot := keccak256(0x00, 0x40)
            sstore(allowanceSlot, amount)
            ///Emit Approval(owner_, spender, amount)
            mstore(0x00, amount)
            log3(
                0x00,
                0x20,
                0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925,
                owner_,
                spender
            )
        }
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal virtual {
        assembly {
            ///Compute allowance slot: keccak256(spender, keccak256(owner_, 3))
            mstore(0x00, owner_)
            mstore(0x20, 3)
            let innerSlot := keccak256(0x00, 0x40)
            mstore(0x00, spender)
            mstore(0x20, innerSlot)
            let allowanceSlot := keccak256(0x00, 0x40)
            let currentAllowance := sload(allowanceSlot)
            ///Skip if max uint256 (infinite approval)
            if iszero(
                eq(
                    currentAllowance,
                    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )
            ) {
                if lt(currentAllowance, amount) {
                    mstore(0x00, 0x13be252b) ///InsufficientAllowance()
                    revert(0x1c, 0x04)
                }
                sstore(allowanceSlot, sub(currentAllowance, amount))
            }
        }
    }

    function _requireValidAuthorization(
        address authorizer,
        bytes32 nonce,
        uint256 validAfter,
        uint256 validBefore
    ) internal view virtual {
        if (block.timestamp < validAfter) revert AuthorizationNotYetValid();
        if (block.timestamp > validBefore) revert AuthorizationExpired();
        if (authorizationState[authorizer][nonce]) revert AuthorizationAlreadyUsed();
    }

    function _validateSignature(
        address signer,
        bytes32 structHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view virtual {
        bytes32 digest = keccak256(abi.encodePacked("\\x19\\x01", DOMAIN_SEPARATOR, structHash));
        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0) || recovered != signer) revert InvalidSignature();
    }

    function _markAuthorizationAsUsed(address authorizer, bytes32 nonce) internal virtual {
        assembly {
            ///Compute authorizationState slot: keccak256(nonce, keccak256(authorizer, 5))
            mstore(0x00, authorizer)
            mstore(0x20, 5)
            let innerSlot := keccak256(0x00, 0x40)
            mstore(0x00, nonce)
            mstore(0x20, innerSlot)
            let stateSlot := keccak256(0x00, 0x40)
            sstore(stateSlot, 1)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MINT / BURN                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function mint(address to, uint256 amount) public onlyOwner {
        assembly {
            if iszero(to) {
                mstore(0x00, 0xc5723b51) ///InvalidAddress()
                revert(0x1c, 0x04)
            }
            let totalSupplyBefore := sload(0x00)
            let totalSupplyAfter := add(totalSupplyBefore, amount)
            if lt(totalSupplyAfter, totalSupplyBefore) {
                mstore(0x00, 0xe5cfe957) ///TotalSupplyOverflow()
                revert(0x1c, 0x04)
            }
            sstore(0x00, totalSupplyAfter)
            mstore(0x00, to)
            mstore(0x20, 2)
            let toBalanceSlot := keccak256(0x00, 0x40)
            sstore(toBalanceSlot, add(sload(toBalanceSlot), amount))
            mstore(0x00, amount)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                0x0000000000000000000000000000000000000000,
                to
            )
        }
    }

    function burn(uint256 amount) public {
        assembly {
            let sender := caller()
            mstore(0x00, sender)
            mstore(0x20, 2)
            let senderBalanceSlot := keccak256(0x00, 0x40)
            let senderBalance := sload(senderBalanceSlot)
            if lt(senderBalance, amount) {
                mstore(0x00, 0xf4d678b8) ///InsufficientBalance()
                revert(0x1c, 0x04)
            }
            sstore(senderBalanceSlot, sub(senderBalance, amount))
            let totalSupplyBefore := sload(0x00)
            sstore(0x00, sub(totalSupplyBefore, amount))
            mstore(0x00, amount)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                sender,
                0x0000000000000000000000000000000000000000
            )
        }
    }

    function burnFrom(address from, uint256 amount) public {
        _spendAllowance(from, msg.sender, amount);
        assembly {
            if iszero(from) {
                mstore(0x00, 0xc5723b51) ///InvalidAddress()
                revert(0x1c, 0x04)
            }
            mstore(0x00, from)
            mstore(0x20, 2)
            let fromBalanceSlot := keccak256(0x00, 0x40)
            let fromBalance := sload(fromBalanceSlot)
            if lt(fromBalance, amount) {
                mstore(0x00, 0xf4d678b8) ///InsufficientBalance()
                revert(0x1c, 0x04)
            }
            sstore(fromBalanceSlot, sub(fromBalance, amount))
            let totalSupplyBefore := sload(0x00)
            sstore(0x00, sub(totalSupplyBefore, amount))
            mstore(0x00, amount)
            log3(
                0x00,
                0x20,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                from,
                0x0000000000000000000000000000000000000000
            )
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         OWNERSHIP                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function transferOwnership(address newOwner) public onlyOwner {
        assembly {
            if iszero(newOwner) {
                mstore(0x00, 0xc5723b51) ///InvalidAddress()
                revert(0x1c, 0x04)
            }
            let previousOwner := sload(1)
            sstore(1, newOwner)
            log3(
                0x00,
                0x00,
                0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0,
                previousOwner,
                newOwner
            )
        }
    }

    function renounceOwnership() public onlyOwner {
        assembly {
            let previousOwner := sload(1)
            sstore(1, 0)
            log3(
                0x00,
                0x00,
                0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0,
                previousOwner,
                0x0000000000000000000000000000000000000000
            )
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                            EVENTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);
}
'''

print(f"Contract length: {len(contract_code)} characters")
print("Contract generated successfully!")