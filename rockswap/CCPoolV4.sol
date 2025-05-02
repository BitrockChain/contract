// SPDX-License-Identifier: MIT
// File: contracts/contracts/interfaces/IWmbReceiver.sol


pragma solidity ^0.8.0;

/**
 * @title IWmbReceiver
 * @dev Interface for contracts that can receive messages from the Wanchain Message Bridge (WMB).
 */
interface IWmbReceiver {
    /**
     * @dev Handles a message received from the WMB network
     * @param data The data contained within the message
     * @param messageId The unique identifier of the message
     * @param fromChainId The ID of the chain that sent the message
     * @param from The address of the contract that sent the message
     * 
     * This interface follows the EIP-5164 standard.
     */
    function wmbReceive(
        bytes calldata data,
        bytes32 messageId,
        uint256 fromChainId,
        address from
    ) external;
}

// File: contracts/contracts/interfaces/IEIP5164.sol


pragma solidity ^0.8.0;

// EIP-5164 defines a cross-chain execution interface for EVM-based blockchains. 
// Implementations of this specification will allow contracts on one chain to call contracts on another by sending a cross-chain message.
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-5164.md

struct Message {
    address to;
    bytes data;
}

interface MessageDispatcher {
  event MessageDispatched(
    bytes32 indexed messageId,
    address indexed from,
    uint256 indexed toChainId,
    address to,
    bytes data
  );

  event MessageBatchDispatched(
    bytes32 indexed messageId,
    address indexed from,
    uint256 indexed toChainId,
    Message[] messages
  );
}

interface SingleMessageDispatcher is MessageDispatcher {
    /**
     * @notice Sends a message to a specified chain and address with the given data.
     * @dev This function is used to dispatch a message to a specified chain and address with the given data.
     * @param toChainId The chain ID of the destination chain.
     * @param to The address of the destination contract on the destination chain.
     * @param data The data to be sent to the destination contract.
     * @return messageId A unique identifier for the dispatched message.
     */ 
    function dispatchMessage(uint256 toChainId, address to, bytes calldata data) external payable returns (bytes32 messageId);
}

interface BatchedMessageDispatcher is MessageDispatcher {
    /**
     * @notice Sends a batch of messages to a specified chain.
     * @dev This function is used to dispatch a batch of messages to a specified chain and returns a unique identifier for the dispatched batch.
     * @param toChainId The chain ID of the destination chain.
     * @param messages An array of Message struct objects containing the destination addresses and data to be sent to each destination contract.
     * @return messageId A unique identifier for the dispatched batch.
     */ 
    function dispatchMessageBatch(uint256 toChainId, Message[] calldata messages) external payable returns (bytes32 messageId);
}

/**
 * MessageExecutor
 *
 * MessageExecutors MUST append the ABI-packed (messageId, fromChainId, from) to the calldata for each message being executed.
 *
 * to: The address of the contract to call.
 * data: The data to cross-chain.
 * messageId: The unique identifier of the message being executed.
 * fromChainId: The ID of the chain the message originated from.
 * from: The address of the sender of the message.
 * to.call(abi.encodePacked(data, messageId, fromChainId, from));
 */
interface MessageExecutor {
    error MessageIdAlreadyExecuted(
        bytes32 messageId
    );

    error MessageFailure(
        bytes32 messageId,
        bytes errorData
    );

    error MessageBatchFailure(
        bytes32 messageId,
        uint256 messageIndex,
        bytes errorData
    );

    event MessageIdExecuted(
        uint256 indexed fromChainId,
        bytes32 indexed messageId
    );
}

interface IEIP5164 is SingleMessageDispatcher, BatchedMessageDispatcher, MessageExecutor {}

// File: contracts/contracts/interfaces/IWmbGateway.sol


pragma solidity ^0.8.0;


/**
 * @title IWmbGateway
 * @dev Interface for the Wanchain Message Bridge Gateway contract
 * @dev This interface is used to send and receive messages between chains
 * @dev This interface is based on EIP-5164
 * @dev It extends the EIP-5164 interface, adding a custom gasLimit feature.
 */
interface IWmbGateway is IEIP5164 {
    /**
     * @dev Estimates the fee required to send a message to a target chain
     * @param targetChainId ID of the target chain
     * @param gasLimit Total Gas limit for the message call
     * @return fee The estimated fee for the message call
     */
    function estimateFee(
        uint256 targetChainId,
        uint256 gasLimit
    ) external view returns (uint256 fee);

    /**
     * @dev Receives a message sent from another chain and verifies the signature of the sender.
     * @param messageId Unique identifier of the message to prevent replay attacks
     * @param sourceChainId ID of the source chain
     * @param sourceContract Address of the source contract
     * @param targetContract Address of the target contract
     * @param messageData Data sent in the message
     * @param gasLimit Gas limit for the message call
     * @param smgID ID of the Wanchain Storeman Group that signs the message
     * @param r R component of the SMG MPC signature
     * @param s S component of the SMG MPC signature
     * 
     * This function receives a message sent from another chain and verifies the signature of the sender using the provided SMG ID and signature components (r and s). 
     * If the signature is verified successfully, the message is executed on the target contract. 
     * The nonce value is used to prevent replay attacks. 
     * The gas limit is used to limit the amount of gas that can be used for the message execution.
     */
    function receiveMessage(
        bytes32 messageId,
        uint256 sourceChainId,
        address sourceContract,
        address targetContract,
        bytes calldata messageData,
        uint256 gasLimit,
        bytes32 smgID, 
        bytes calldata r, 
        bytes32 s
    ) external;

    /**
     * @dev Receives a message sent from another chain and verifies the signature of the sender.
     * @param messageId Unique identifier of the message to prevent replay attacks
     * @param sourceChainId ID of the source chain
     * @param sourceContract Address of the source contract
     * @param messages Data sent in the message
     * @param gasLimit Gas limit for the message call
     * @param smgID ID of the Wanchain Storeman Group that signs the message
     * @param r R component of the SMG MPC signature
     * @param s S component of the SMG MPC signature
     * 
     * This function receives a message sent from another chain and verifies the signature of the sender using the provided SMG ID and signature components (r and s). 
     * If the signature is verified successfully, the message is executed on the target contract. 
     * The nonce value is used to prevent replay attacks. 
     * The gas limit is used to limit the amount of gas that can be used for the message execution.
     */
    function receiveBatchMessage(
        bytes32 messageId,
        uint256 sourceChainId,
        address sourceContract,
        Message[] calldata messages,
        uint256 gasLimit,
        bytes32 smgID,
        bytes calldata r, 
        bytes32 s
    ) external;

    error SignatureVerifyFailed(
        bytes32 smgID,
        bytes32 sigHash,
        bytes r,
        bytes32 s
    );

    error StoremanGroupNotReady(
        bytes32 smgID,
        uint256 status,
        uint256 timestamp,
        uint256 startTime,
        uint256 endTime
    );
}

// File: @openzeppelin/contracts/proxy/utils/Initializable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.20;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/utils/introspection/ERC165.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;


/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// File: @openzeppelin/contracts/access/IAccessControl.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/IAccessControl.sol)

pragma solidity ^0.8.20;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/AccessControl.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

pragma solidity ^0.8.20;




/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}

// File: contracts/contracts/app/WmbApp.sol


pragma solidity ^0.8.0;





/**
 * @title WmbApp
 * @dev Abstract contract to be inherited by applications to use Wanchain Message Bridge for send and receive messages between different chains.
 * All interfaces with WmbGateway have been encapsulated, so users do not need to have any interaction with the WmbGateway contract.
 */
abstract contract WmbApp is AccessControl, Initializable, IWmbReceiver {
    // The address of the WMB Gateway contract
    address public wmbGateway;

    // A mapping of remote chains and addresses that are trusted to send messages to this contract
    // fromChainId => fromAddress => trusted
    mapping (uint => mapping(address => bool)) public trustedRemotes;

    /**
     * @dev Initializes the contract with the given admin, WMB Gateway address, and block mode flag
     * @param admin Address of the contract admin
     * @param _wmbGateway Address of the WMB Gateway contract
     */
    function initialize(address admin, address _wmbGateway) virtual public initializer {
        // Initialize the AccessControl module with the given admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        wmbGateway = _wmbGateway;
    }

    /**
     * @dev Function to set the trusted remote addresses
     * @param fromChainIds IDs of the chains the messages are from
     * @param froms Addresses of the contracts the messages are from
     * @param trusted Trusted flag
     * @notice This function can only be called by the admin
     */
    function setTrustedRemotes(uint[] calldata fromChainIds, address[] calldata froms, bool[] calldata trusted) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "WmbApp: must have admin role to set trusted remotes");
        require(fromChainIds.length == froms.length && froms.length == trusted.length, "WmbApp: invalid input");
        for (uint i = 0; i < fromChainIds.length; i++) {
            trustedRemotes[fromChainIds[i]][froms[i]] = trusted[i];
        }
    }

    /**
     * @dev Function to estimate fee in native coin for sending a message to the WMB Gateway
     * @param toChain ID of the chain the message is to
     * @param gasLimit Gas limit for the message
     * @return fee Fee in native coin
     */
    function estimateFee(uint256 toChain, uint256 gasLimit) virtual public view returns (uint256) {
        return IWmbGateway(wmbGateway).estimateFee(toChain, gasLimit);
    }

    /**
     * @dev Function to receive a WMB message from the WMB Gateway
     * @param data Message data
     * @param messageId Message ID
     * @param fromChainId ID of the chain the message is from
     * @param from Address of the contract the message is from
     */
    function wmbReceive(
        bytes calldata data,
        bytes32 messageId,
        uint256 fromChainId,
        address from
    ) virtual external {
        // Only the WMB gateway can call this function
        require(msg.sender == wmbGateway, "WmbApp: Only WMB gateway can call this function");
        require(trustedRemotes[fromChainId][from], "WmbApp: Remote is not trusted");
        _wmbReceive(data, messageId, fromChainId, from);
    }

    /**
     * @dev Function to be implemented by the application to handle received WMB messages
     * @param data Message data
     * @param messageId Message ID
     * @param fromChainId ID of the chain the message is from
     * @param from Address of the contract the message is from
     */
    function _wmbReceive(
        bytes calldata data,
        bytes32 messageId,
        uint256 fromChainId,
        address from
    ) virtual internal;

    /**
     * @dev Function to send a WMB message to the WMB Gateway from this App
     * @param toChainId ID of the chain the message is to
     * @param to Address of the contract the message is to
     * @param data Message data
     * @return messageId Message ID
     */
    function _dispatchMessage(
        uint toChainId,
        address to,
        bytes memory data,
        uint fee
    ) virtual internal returns (bytes32) {
        return IWmbGateway(wmbGateway).dispatchMessage{value: fee}(toChainId, to, data);
    }

    /**
     * @dev Function to send batch WMB messages to the WMB Gateway from this App
     * @param toChainId ID of the chain the message is to
     * @param messages Messages data
     * @return messageId Message ID
     */
    function _dispatchMessageBatch(uint256 toChainId, Message[] memory messages, uint fee) virtual internal returns (bytes32) {
        return IWmbGateway(wmbGateway).dispatchMessageBatch{value: fee}(toChainId, messages);
    }
}

// File: @openzeppelin/contracts/security/Pausable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// File: @openzeppelin/contracts/utils/math/SafeMath.sol


// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// File: contracts/contracts/CCPoolV4.sol


pragma solidity ^0.8.18;





// Cross Chain Token Pool for bitrock
contract CCPoolV4 is WmbApp, ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    uint8 public destDecimals;

    // Fee
    uint256 public constant FEE = 50; // 0.5%
    bool public feeEnabled = true;

    address public marketingAddress;

    // chain id => remote pool address
    mapping(uint => address) public remotePools;

    event CrossArrive(uint256 indexed fromChainId, address indexed from, address indexed to, uint256 amount, string crossType);
    event CrossRequest(uint256 indexed toChainId, address indexed from, address indexed to, uint256 amount);
    event CrossRevert(uint256 indexed fromChainId, address indexed from, address indexed to, uint256 amount);

    error RevertFailed (
        address from,
        address to,
        uint256 amount,
        uint256 fromChainId
    );

    constructor(
        address admin, 
        address wmbGateway_, 
        address marketingAddress_,
        uint8 destDecimals_
    ) WmbApp() {
        require(marketingAddress_ != address(0), "Marketing wallet is zero");
        initialize(admin, wmbGateway_);
        marketingAddress = marketingAddress_;
        destDecimals = destDecimals_;
    }

    function configRemotePool(uint256 chainId, address remotePool) public onlyRole(DEFAULT_ADMIN_ROLE) {
        remotePools[chainId] = remotePool;
    }

    function crossTo(uint256 toChainId, uint256 gasLimit) public payable nonReentrant whenNotPaused {
        require(remotePools[toChainId] != address(0), "remote pool not configured");
        require(msg.value > 0, "amount is zero");
        uint256 amount = msg.value;
        // Estimate cross-chain transfer fee
        uint crossFee = estimateFee(toChainId, gasLimit);
        require(amount >= crossFee, "Insufficient amount for fee and transfer");
        uint256 transferAmount = amount - crossFee;
        if (transferAmount > (10 ** destDecimals)) {
            transferAmount = transferAmount / (10 ** destDecimals);
        }
        _dispatchMessage(toChainId, remotePools[toChainId], abi.encode(msg.sender, msg.sender, transferAmount, "crossTo"), crossFee);
        emit CrossRequest(toChainId, msg.sender, msg.sender, transferAmount);
    }

    // Transfer in enough native coin for fee. 
    receive() external payable {}

    function _wmbReceive(
        bytes calldata data,
        bytes32 /*messageId*/,
        uint256 fromChainId,
        address fromSC
    ) internal override {
        (address fromAccount, address to, uint256 amount, string memory crossType) = abi.decode(data, (address, address, uint256, string));
        if (address(this).balance >= amount) {
            if (feeEnabled && (keccak256(bytes(crossType)) != keccak256("crossRevert"))) {
                uint256 fee_ = _calculateFee(amount);
                amount = amount.sub(fee_);
                payable(marketingAddress).transfer(fee_);
            }
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success){
                if (keccak256(bytes(crossType)) == keccak256("crossTo")) {
                    uint256 amountToSend = amount / (10 ** destDecimals);
                    uint crossFee = estimateFee(fromChainId, 400_000);
                    _dispatchMessage(fromChainId, fromSC, abi.encode(to, fromAccount, amountToSend, "crossRevert"), crossFee);
                    emit CrossRevert(fromChainId, fromAccount, to, amountToSend);
                } else {
                    revert RevertFailed(fromAccount, to, amount, fromChainId);
                }
            } else {
                emit CrossArrive(fromChainId, fromAccount, to, amount, crossType);
            }
        } else {
            if (keccak256(bytes(crossType)) == keccak256("crossTo")) {
                uint256 amountToSend = amount / (10 ** destDecimals);
                uint crossFee = estimateFee(fromChainId, 400_000);
                _dispatchMessage(fromChainId, fromSC, abi.encode(to, fromAccount, amountToSend, "crossRevert"), crossFee);
                emit CrossRevert(fromChainId, fromAccount, to, amountToSend);
            } else {
                revert RevertFailed(fromAccount, to, amount, fromChainId);
            }
        }
    }

    function setFeeEnabled(
        bool _enabled
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        feeEnabled = _enabled;
    }

    function setMarketingWallet(
        address payable wallet
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(wallet != address(0), "Marketing wallet is zero");
        marketingAddress = wallet;
    }

    function _calculateFee(uint256 _amount)
        private
        pure
        returns (uint256)
    {
        return _amount.mul(FEE).div(10**4);
    }

    function withdraw(
        uint256 amount
    ) public nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(this).balance >= amount, "Amount exceed balance");
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Failed to withdraw amount");
    }
}
