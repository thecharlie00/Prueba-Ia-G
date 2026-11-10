# Lobby & Room Management System — Technical Design Specification

**Game:** 3D Multiplayer Tabletop Simulator (mod-supported)
**Networking:** Photon Fusion 2 (Shared Mode + Host/Client hybrid, Server-Authoritative Physics)
**Platform:** Unity 2022.3 LTS / .NET 8
**Author:** Senior Multiplayer Architect
**Version:** 1.0.0

---

## Table of Contents

1. [Module 1: Data Architecture & Custom Room Properties (Matchmaking)](#module-1)
2. [Module 2: UI/UX State Machine](#module-2)
3. [Module 3: Seating, Roles & Slot Selection](#module-3)
4. [Module 4: Resilience & Error Handling](#module-4)
5. [Module 5: C# Class Architecture (Component / MVC)](#module-5)
6. [Module 6: Best Practices & Performance Optimization](#module-6)

---

<a id="module-1"></a>
## MODULE 1: DATA ARCHITECTURE & CUSTOM ROOM PROPERTIES (MATCHMAKING)

### 1.1 Session Properties Schema

Photon Cloud stores room metadata in `SessionProperties` (a `Dictionary<string, object>`). Only a **subset** of fields should be sent to the cloud — heavy payloads stay in the room's `NetworkedProperties` after the room is created. This keeps lobby listing lightweight and enables efficient server-side filtering.

#### Cloud-visible fields (in `SessionProperties`)

| Key | Type | Size (bytes) | Purpose |
|-----|------|:---:|---------|
| `name` | string | ~32 | Room display name (filtered by Lobby list) |
| `mod_id` | string | ~64 | Workshop/Mod GUID or hash for content validation |
| `mod_version` | int | 4 | Semantic version packed as int (Maj.Min.Patch) |
| `rules_checksum` | string | ~16 | SHA-1 hex of rules script hash for anti-cheat |
| `game_mode` | byte | 1 | Enum: 0=Normal, 1=Tournament, 2=Practice, 3=Custom |
| `dlc_required` | string[] | ~32 | Array of DLC GUIDs required |
| `state` | byte | 1 | Enum: 0=WaitingInLobby, 1=LoadingBoard, 2=InProgress, 3=Paused |
| `privacy` | byte | 1 | Enum: 0=Public, 1=FriendsOnly, 2=PrivateWithPassword |
| `max_players` | byte | 1 | Slot capacity (2–8) |
| `open_slots` | byte | 1 | Derived: `max_players - current_players` |
| `ping_region` | string | ~8 | Approximate region code (EU/NA/SA/AS/OC) |
| `host_id` | long | 8 | Photon actor number of the host (for friend filtering) |
| `version_min` | int | 4 | Minimum game version accepted (join-time validation) |
| `version_max` | int | 4 | Maximum game version accepted (join-time validation) |
| `custom_flags` | int | 4 | Bitmask for table-specific options (see §1.4) |

**Total per room: ~200 bytes.** This is well within Photon's `lobby.maxlobbysize` (default 3000 bytes).

#### In-room fields (NOT in `SessionProperties`, in `NetworkedProperties`)

| Key | Type | Purpose |
|-----|------|---------|
| `seats` | `NetworkDictionary<int, SeatInfo>` | Slot assignments (player → seat index) |
| `spectators` | `List<PlayerRef>` | Spectator list |
| `mod_data` | `byte[]` | Serialized mod state (board config, RNG seed, etc.) |
| `handshake_state` | `byte` | 0=Idle, 1=Negotiating, 2=Ready, 3=Failed |
| `session_seed` | `uint` | Deterministic RNG seed for board generation |

### 1.2 Version Packing Strategy

Pack semantic version into a single `int` for compact comparison:

```csharp
public static int PackVersion(int major, int minor, int patch)
    => (major & 0xFF) << 24 | (minor & 0xFF) << 16 | (patch & 0xFF) << 8;

public static (int major, int minor, int patch) UnpackVersion(int packed)
    => (packed >> 24 & 0xFF, packed >> 16 & 0xFF, packed >> 8 & 0xFF);
```

Server-side filtering via `Lobby.JoinLobby(TypedLobbyInfo)` can then use LINQ on `SessionProperties` without unpacking overhead.

### 1.3 Password Security

Photon does **not** encrypt room passwords. A naive `session.SetCustomRoomProperties("password", "1234")` exposes them in the lobby listing. Instead:

1. **Password never goes to cloud.** Store a salted hash in `SessionProperties`:
   ```csharp
   // On room creation:
   var salt = Random.GetRandomInteger(0, int.MaxValue);
   var hash = ComputeSaltedHash(password, salt);
   session.SetCustomRoomProperties("auth_salt", salt);
   session.SetCustomRoomProperties("auth_hash", hash);
   ```
   Use PBKDF2 or scrypt for the hash function.

2. **Client-side verification before handshake.** When a client attempts to join a `PrivateWithPassword` room, they first request the `auth_salt`, compute the hash locally, and send the hash in the `JoinRoom` request's custom authentication (`AuthenticationValues`). Photon's Cloud Code (or client-side check after join) validates the hash.

3. **Post-join verification.** After `OnJoinedRoom`, the host sends a `VerifyPassword` RPC. If verification fails, the host kicks the actor. This prevents clients from joining without the password even if Photon's join succeeds.

4. **Brute-force protection.** If a client fails 3 password attempts, the host sets a `lockout_until` timestamp in `NetworkedProperties` and ignores further join attempts for 60 seconds.

```csharp
public static uint ComputeSaltedHash(string password, uint salt)
{
    var bytes = Encoding.UTF8.GetBytes(password + salt.ToString());
    // Use PBKDF2 via System.Security.Cryptography
    using var pbkdf2 = new Rfc2898DeriveBytes(password, BitConverter.GetBytes(salt), 10000, HashAlgorithmName.SHA256);
    var hash = pbkdf2.GetBytes(4);
    return BitConverter.ToUInt32(hash, 0);
}
```

### 1.4 Custom Flags Bitmask

```csharp
[Flags]
public enum RoomCustomFlags : uint
{
    None             = 0,
    NoSpectators     = 1 << 0,
    AutoStart        = 1 << 1,  // Start game when all slots filled
    TournamentMode   = 1 << 2,  // Disable chat, enforce turn timer
    ModsOnly         = 1 << 3,  // Require mod to join
    FriendlyFire     = 1 << 4,  // Allow physics interaction between players
    CoopMode         = 1 << 5,  // Shared board state, no competition
    ScoreboardEnabled = 1 << 6,
    RematchEnabled   = 1 << 7,  // Allow quick rematch after game end
}
```

---

<a id="module-2"></a>
## MODULE 2: UI/UX STATE MACHINE

### 2.1 State Definitions

```csharp
public enum UIState
{
    MainMenu,
    LobbyBrowser,
    RoomCreation,
    PreGameRoom,
    LoadingTransition,
    InGame,
    PostGame,
    ErrorDialog
}
```

### 2.2 State Transition Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                  MainMenu                                      │
│  • Connect to Photon Cloud (PUNWebSocket)                                     │
│  • Authenticate user (Steam/Epic/Discord)                                     │
│  • Fetch user profile (avatar, friends list, mod library)                     │
│  • Show: [Create Room] [Find Game] [My Mods] [Settings] [Exit]                │
└───────────────┬───────────────────────────────────┬─────────────────────────┘
                │ Create                             │ Find Game
                ▼                                    ▼
┌─────────────────────────────┐         ┌──────────────────────────────────┐
│      RoomCreationModal      │         │      LobbyBrowser                 │
│ • Mod selection (dropdown)  │         │ • Virtualized list of rooms       │
│ • Game mode picker          │         │ • Search bar (name filter)        │
│ • Max players (2-8 slider)  │         │ • Filter chips:                   │
│ • Privacy selector          │         │   [Mod] [No Password] [State]    │
│ • Password field (if priv.) │         │   [Ping < X ms] [Friends Only]   │
│ • Custom flags toggles      │         │ • Sortable: Name / Ping / Players │
│ • [Create & Enter] [Cancel] │         │ • Real-time updates via           │
└───────────────┬─────────────┘         │   OnSessionListUpdated()          │
                │ Create & Enter         │ • [Refresh] [Create Room]          │
                ▼                        └──────────────┬─────────────────────┘
                                       ┌─────────────────┴───────────────────┐
                                       │ JoinRoom(room)                      │ Create Room
                                       ▼                                     ▼
                              ┌──────────────────────────────────────────────────┐
                              │              PreGameRoom (Sala de Espera)        │
                              │ • Shows room name, mod info, host avatar        │
                              │ • Seat assignment panel (visual table preview) │
                              │ • Player list with ping indicators              │
                              │ • Chat panel                                    │
                              │ • Host controls: [Start Game] [Kick] [Ban]     │
                              │   [Change Mod] [Set Password]                  │
                              │ • Wait for host signal to load board scene      │
                              └───────────────┬──────────────────────────────────┘
                                              │ Host triggers LoadingTransition
                                              ▼
                              ┌──────────────────────────────────────────────────┐
                              │              LoadingTransition                   │
                              │ • All clients load board scene synchronously    │
                              │   via NetworkSceneManagerDefault               │
                              │ • Show loading progress bar per client          │
                              │ • Host verifies all players have loaded asset   │
                              │ • On all-loaded → spawn avatars, assign seats   │
                              └───────────────┬──────────────────────────────────┘
                                              ▼
                              ┌──────────────────────────────────────────────────┐
                              │                    InGame                         │
                              │ • 3D tabletop board active                      │
                              │ • Physics-based object interaction               │
                              │ • Turn system / action management               │
                              └──────────────────────────────────────────────────┘
```

### 2.3 Key Transitions Detail

#### MainMenu → LobbyBrowser
1. Call `NetworkRunner.StartCloudNavigation()` to connect to Photon Cloud.
2. On `OnConnectedToMaster()`, call `LobbyManager.ListLobbies()`.
3. `LobbyManager` subscribes to `Lobby.OnLobbyUpdate` for real-time updates.
4. Apply filters via `Lobby.JoinLobby(new TypedLobbyInfo(...))` with `TypedLobbyInfo` constraints.

#### RoomCreationModal → PreGameRoom
1. Serialize `RoomCreationConfig` → `SessionProperties` (see Module 5).
2. Call `NetworkRunner.CreateRoom(roomName, options, TypedLobbyInfo, customRoomProperties)`.
3. On `OnCreatedRoom`, set state to `PreGameRoom`.
4. Host enters the room; room properties are now immutable until game start.

#### PreGameRoom → LoadingTransition
1. Host checks: all required slots filled (or host confirms with fewer players).
2. Host sets `state = LoadingBoard` in `SessionProperties` (visible to all).
3. Host triggers `NetworkSceneManagerDefault.LoadScene(boardSceneName, NetworkSceneLoadMode.AllLoad)`.
4. All clients receive `OnSceneLoaded` callback.
5. Each client loads the mod assets (Workshop dependency).
6. When all clients report `AssetsLoaded = true`, transition to `InGame`.

#### LoadingTransition → InGame
1. Host assigns seats based on `NetworkDictionary<int, SeatInfo>`.
2. Spawn player avatars at their seat positions.
3. Set `handshake_state = Ready`.
4. Begin game loop (turn system, physics sync, etc.).

---

<a id="module-3"></a>
## MODULE 3: SEATING, ROLES & SLOT SELECTION

### 3.1 Role Hierarchy

```csharp
public enum PlayerRole : byte
{
    Host = 0,       // Master Client — full control
    Player = 1,     // Assigned to a seat — can interact with their zone
    Spectator = 2   // No seat — camera only, no interaction
}
```

### 3.2 Seat Data Structure

```csharp
[Serializable]
public struct SeatInfo
{
    public int PlayerActor;      // Photon actor number (-1 = empty)
    public int SeatIndex;        // Physical seat position (0-7)
    public PlayerRole Role;      // Player or Spectator
    public byte ColorIndex;      // Player color (0=Red, 1=Blue, ...)
    public bool IsLocked;        // Locked by host (cannot be changed)
    public byte HandZoneMask;    // Bitmask of which board zones this seat controls
    public float PingMs;         // Last measured ping (for UI display)
    public bool Ready;           // Player confirmed they're ready
}
```

### 3.3 Seat Assignment Flow

```
                    ┌─────────────────────────┐
                    │  Player joins room      │
                    └──────────┬──────────────┘
                               ▼
                    ┌─────────────────────────┐
                    │  Host auto-assigns      │
                    │  next free seat OR      │
                    │  host picks manually   │
                    └──────────┬──────────────┘
                               ▼
                    ┌─────────────────────────┐
                    │  Host sends             │
                    │  AssignSeat RPC        │
                    │  (seat_index, actor)   │
                    └──────────┬──────────────┘
                               ▼
                    ┌─────────────────────────┐
                    │  SeatController.        │
                    │  OnSeatAssigned()       │
                    │  • Spawn avatar at      │
                    │    seat position        │
                    │  • Set input authority  │
                    │    for hand zones       │
                    │  • Update UI           │
                    └─────────────────────────┘
```

### 3.4 Conflict Resolution: Two Players, Same Seat

The host is the sole authority over seat assignments. Clients **cannot** self-assign seats — they can only request.

```csharp
// Client sends a request (not a command):
[Rpc(RpcAttributes.ExcludeOwner)]
private void RequestSeat(int seatIndex)
{
    if (IsHost) return; // Host doesn't need to request
    // Only process if seat is free:
    if (seats.ContainsKey(seatIndex) && seats[seatIndex].PlayerActor == -1)
    {
        AssignSeat(seatIndex, RpcTarget.Others); // Host-side logic
    }
}

// Host processes the request:
[Rpc]
private void AssignSeat(int seatIndex, NetworkPlayerRef player)
{
    if (seatIndex < 0 || seatIndex >= MAX_SEATS) return;
    if (seats[seatIndex].PlayerActor != -1) return; // Seat taken — reject
    if (IsRpcFrom(player)) // Sanity check
    {
        seats[seatIndex].PlayerActor = (int)player.ActorNumber;
        seats[seatIndex].Role = PlayerRole.Player;
        // Notify the player:
        RpcAssignSeatToPlayer(seatIndex);
        // Notify everyone else:
        RpcSeatUpdated(seatIndex);
    }
}
```

**Key principles:**
- Clients send `RequestSeat` (excluded from host) — it's a suggestion, not a command.
- Host validates and issues `AssignSeat` RPC to all clients.
- If a seat is taken, the host silently rejects the request and sends a `SeatTaken` notification to the requesting client.
- No transactional locking needed — the host's sequential processing guarantees no double-assignment.

### 3.5 Spectator Management

- Spectators join with `Role = Spectator` and no seat assignment.
- Their `SeatInfo.PlayerActor = -1` but they appear in the `spectators` list.
- Spectators cannot send `RequestSeat` — they can only request host approval via a `RequestSpectatorToPlayer` RPC, which the host manually approves/rejects.
- Host can downgrade a player to spectator at any time (e.g., on disconnect, the seat is freed and the player becomes a spectator if they rejoin).

---

<a id="module-4"></a>
## MODULE 4: RESILIENCE & ERROR HANDLING

### 4.1 Host Disconnection

Photon Fusion provides **Host Migration** out of the box. When the host disconnects:

1. Fusion automatically promotes the next-oldest actor to Master Client (`NetworkRunner.MasterClient` changes).
2. The new host receives `OnMasterClientChanged(bool)` callback.
3. **Critical:** The new host must:
   - Update `SessionProperties["host_id"]` with their own actor number.
   - Display a "New Host Selected" notification to all clients.
   - Verify they have the necessary permissions (they inherit the old host's `NetworkedProperties`).
4. If **no valid host** remains (all players disconnect), the room is destroyed. Clients receive `OnLeftRoom()` and transition to `MainMenu` with a "Room Closed" message.

```csharp
public override void OnMasterClientChanged(bool wasMaster, NetworkPlayerRef newMaster)
{
    if (!wasMaster && IsMasterClient)
    {
        // We are the new host.
        UpdateHostMetadata();
        ShowHostTransferNotification();
        // Verify we can continue the game:
        if (handshakeState == HandshakeState.LoadingBoard)
            RestartLoadingSequence();
        else if (handshakeState == HandshakeState.InProgress)
            ResumeGameAsHost();
    }
}
```

### 4.2 Player Disconnection in PreGameRoom

| Step | Action |
|------|--------|
| 1 | `OnPlayerLeft(NetworkPlayerRef)` fires |
| 2 | Free the seat: `seats[seat].PlayerActor = -1` |
| 3 | If the player was the Host, trigger Host Migration (§4.1) |
| 4 | Update `SessionProperties["open_slots"]` |
| 5 | Send `RpcSeatUpdated(seatIndex)` to all remaining clients |
| 6 | Update UI: remove player from list, show "Seat Available" |
| 7 | If `AutoStart` flag is set and now all required slots are empty, notify host |

### 4.3 Version / Mod Incompatibility

```csharp
public override void OnJoinRequestFailed(ConnectionRequestFailedReason reason)
{
    switch (reason)
    {
        case ConnectionRequestFailedReason.VersionMismatch:
            ShowErrorDialog("Game Version Mismatch",
                "Your game version is out of date. Please update to the latest version.");
            break;
        case ConnectionRequestFailedReason.AuthFailed:
            ShowErrorDialog("Authentication Failed",
                "The room password is incorrect or the room requires authentication.");
            break;
        case ConnectionRequestFailedReason.RoomFull:
            ShowErrorDialog("Room Full", "This room has reached its player limit.");
            break;
        case ConnectionRequestFailedReason.LobbyNotFound:
            ShowErrorDialog("Room Not Found", "The room you tried to join no longer exists.");
            break;
        default:
            ShowErrorDialog("Connection Failed",
                $"Could not join room. Reason: {reason}\nReturning to lobby.");
            TransitionToState(UIState.LobbyBrowser);
            break;
    }
}
```

**Mod version check:** Before joining, the client fetches the mod's `mod_version` from `SessionProperties` and compares with its locally installed version. If mismatched, show:
> "Mod version mismatch: Room requires v1.2.4, you have v1.1.0. Please update from the Workshop."

### 4.4 Connection Timeout & Packet Loss During Handshake

- **Handshake phase** (`handshake_state = Negotiating`): Implement a 10-second timer.
  - If not all clients report `Ready` within 10s, host sends `CancelLoading` and returns to `PreGameRoom`.
  - If a single client times out, they are kicked and can rejoin.
- **Loading timeout:** If a client hasn't loaded the board scene within 30s, the host shows a "Loading Failed" dialog and either waits or kicks the stuck client.
- **Ping monitoring:** During `PreGameRoom`, continuously monitor `NetworkRunner.CurrentRtt`. If a player's RTT exceeds 500ms for >10s, show a "High Latency" warning. If the host's RTT drops to 0 (disconnected), trigger Host Migration.

### 4.5 Disconnection During Game

- **Player disconnects during InGame:** Their seat is marked as "AFK" but not freed (to preserve game state). The host can either:
  - Pause the game and wait for reconnection.
  - Allow an AI/Bot to take over (if configured).
  - End the game and return to `PostGame`.
- **Host disconnects during InGame:** Host Migration takes over. The new host inherits all `NetworkedProperties`. If the game state was in a non-deterministic state (physics), the new host may need to force a state sync.

---

<a id="module-5"></a>
## MODULE 5: C# CLASS ARCHITECTURE (COMPONENT / MVC)

### 5.1 Class Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         UI Layer (MVC Controllers)                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ MainMenuView     │  │ LobbyBrowserView │  │ RoomCreationView │  │
│  │ + MainMenuCtrl   │  │ + LobbyBrowserCtrl│ │ + RoomCreationCtrl│ │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘  │
│           │                      │                     │             │
│           ▼                      ▼                     ▼             │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                     LobbyManager (Singleton)                   │  │
│  │  • Connection state                                            │  │
│  │  • Session list cache (ObservableCollection<RoomInfo>)         │  │
│  │  • Filter pipeline (ILobbyFilter[])                             │  │
│  │  • Password verification                                      │  │
│  └──────────────────────────┬───────────────────────────────────┘  │
└─────────────────────────────┼──────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Network Layer (Photon Fusion)                    │
│  ┌──────────────────────┐  ┌────────────────────────────────────┐  │
│  │ RoomManager          │  │ SeatController                      │  │
│  │ (NetworkBehaviour)   │  │ (NetworkBehaviour, on avatars)      │  │
│  │ • SessionProperties  │  │ • Input authority per hand zone    │  │
│  │ • NetworkedProperties │  │ • Physics interaction filtering    │  │
│  │ • Seat management    │  │ • Seat visual feedback             │  │
│  │ • Host controls      │  │                                     │  │
│  └──────────────────────┘  └────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Data Layer (Serializable Structs)                 │
│  ┌──────────────────────┐  ┌──────────────────┐                    │
│  │ RoomCreationConfig   │  │ SeatInfo          │                    │
│  │ (RoomCreationConfig) │  │ (SeatInfo)        │                    │
│  │ • name, mod, privacy │  │ • player, seat,   │                    │
│  │ • max_players, flags │  │ • role, ready     │                    │
│  └──────────────────────┘  └──────────────────┘                    │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 `RoomCreationConfig.cs`

```csharp
using System;
using Photon.Fusion;
using Photon.Fusion.Diagnostics;

[Serializable]
public class RoomCreationConfig
{
    // --- Display ---
    public string RoomName;
    public byte MaxPlayers;          // 2-8
    public byte Privacy;             // See RoomPrivacy enum
    public string Password;          // Only for PrivateWithPassword

    // --- Mod / Content ---
    public string ModId;             // Workshop GUID or content hash
    public int ModVersion;           // Packed semver
    public string RulesChecksum;     // SHA-1 of rules script
    public string[] RequiredDlcs;    // GUID array

    // --- Game Mode ---
    public byte GameMode;            // 0=Normal, 1=Tournament, 2=Practice
    public uint CustomFlags;         // Bitmask (see Module 1 §1.4)
    public uint SessionSeed;         // Deterministic RNG seed

    // --- Serialization ---
    public Dictionary<string, object> ToSessionProperties()
    {
        var props = new Dictionary<string, object>
        {
            ["name"]            = RoomName,
            ["mod_id"]          = ModId,
            ["mod_version"]     = ModVersion,
            ["rules_checksum"]  = RulesChecksum,
            ["game_mode"]       = GameMode,
            ["dlc_required"]    = RequiredDlcs,
            ["state"]           = (byte)RoomState.WaitingInLobby,
            ["privacy"]         = Privacy,
            ["max_players"]     = MaxPlayers,
            ["open_slots"]      = MaxPlayers,
            ["ping_region"]     = "EU",
            ["host_id"]         = 0, // Set after join
            ["custom_flags"]    = CustomFlags,
            ["session_seed"]    = SessionSeed,
        };

        if (Privacy == (byte)RoomPrivacy.PrivateWithPassword)
        {
            var salt = (uint)Random.Next(0, int.MaxValue);
            var hash = PasswordHasher.ComputeSaltedHash(Password, salt);
            props["auth_salt"] = salt;
            props["auth_hash"] = hash;
        }

        return props;
    }

    // --- Validation ---
    public bool Validate()
    {
        if (string.IsNullOrWhiteSpace(RoomName) || RoomName.Length > 30) return false;
        if (string.IsNullOrWhiteSpace(ModId)) return false;
        if (MaxPlayers < 2 || MaxPlayers > 8) return false;
        if (Privacy == (byte)RoomPrivacy.PrivateWithPassword &&
            (string.IsNullOrEmpty(Password) || Password.Length < 4)) return false;
        return true;
    }
}
```

### 5.3 `LobbyManager.cs`

```csharp
using System.Collections.ObjectModel;
using Photon.Fusion;
using Photon.Fusion.Diagnostics;
using UnityEngine;

public class LobbyManager : FusionBehaviour, INetworkRunnerCallbacks
{
    [Header("Configuration")]
    [SerializeField] private NetworkRunner networkRunner;
    [SerializeField] private int maxLobbyRooms = 50;

    // --- Connection State ---
    public bool IsConnectedToCloud { get; private set; }
    public bool IsAuthenticated { get; private set; }

    // --- Session List Cache (Object Pooled) ---
    private readonly List<RoomInfo> _roomList = new();
    public ReadOnlyCollection<RoomInfo> Rooms => _roomList.AsReadOnly();
    private ObservableCollection<RoomInfo> _observableRooms;

    // --- Filter Pipeline ---
    private readonly List<ILobbyFilter> _filters = new();
    public void AddFilter(ILobbyFilter filter) => _filters.Add(filter);
    public void RemoveFilter(ILobbyFilter filter) => _filters.Remove(filter);

    // --- Throttling ---
    private float _lastListRequestTime;
    private const float MinListRequestInterval = 2.0f; // 2s between refreshes

    // --- Singleton ---
    public static LobbyManager Instance { get; private set; }

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  INetworkRunnerCallbacks — Connection Lifecycle
    // ═══════════════════════════════════════════════════════════════════════

    public void OnConnectedToMaster()
    {
        IsConnectedToCloud = true;
        Debug.Log("[LobbyManager] Connected to Photon Cloud.");
    }

    public void OnAuthenticationSuccess()
    {
        IsAuthenticated = true;
        ListLobbies();
    }

    public void OnAuthenticationFailure(Photon.Realtime.ErrorCode error)
    {
        Debug.LogError($"[LobbyManager] Auth failed: {error}");
        UIController.Instance.ShowErrorDialog("Authentication Failed",
            "Could not authenticate with Photon Cloud. Please check your internet connection.");
    }

    public void OnCreatedRoom()
    {
        Debug.Log($"[LobbyManager] Room created: {networkRunner.LocalPlayer.SessionId}");
        // Notify RoomManager to switch to PreGameRoom state
        RoomManager.Instance?.OnRoomCreated();
    }

    public void OnJoinedRoom()
    {
        Debug.Log($"[LobbyManager] Joined room: {networkRunner.LocalPlayer.SessionId}");
        RoomManager.Instance?.OnRoomJoined();
    }

    public void OnJoinRequestFailed(ConnectionRequestFailedReason reason)
    {
        Debug.LogError($"[LobbyManager] Join failed: {reason}");
        HandleJoinFailure(reason);
    }

    public void OnLeftRoom()
    {
        Debug.Log("[LobbyManager] Left room.");
        RoomManager.Instance?.OnRoomLeft();
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Session Listing & Filtering
    // ═══════════════════════════════════════════════════════════════════════

    public void ListLobbies()
    {
        if (!IsConnectedToCloud) return;

        // Throttle: don't request more often than MinListRequestInterval
        if (Time.time - _lastListRequestTime < MinListRequestInterval) return;
        _lastListRequestTime = Time.time;

        // Apply filters to the TypedLobbyInfo:
        var constraints = new TypedLobbyInfo(
            new Hashtable(),
            new List<TypedLobbyInfo>(), // Custom room properties filter
            null,
            false);

        // Add server-side constraints:
        constraints.SetCustomRoomProperties(FilterToConstraints());

        networkRunner.StartCloudNavigation(constraints);
    }

    public void OnSessionListUpdated(List<Photon.Realtime.RoomInfo> rooms)
    {
        // Cache and filter on the client side:
        _roomList.Clear();
        for (int i = 0; i < rooms.Count && i < maxLobbyRooms; i++)
        {
            var room = rooms[i];
            var filtered = ApplyFilters(room);
            if (filtered)
                _roomList.Add(new RoomInfo(room));
        }

        _observableRooms?.OnChanged(); // Notify UI
    }

    private Dictionary<string, object> FilterToConstraints()
    {
        var constraints = new Dictionary<string, object>();
        foreach (var filter in _filters)
        {
            filter.ApplyConstraints(constraints);
        }
        return constraints;
    }

    private bool ApplyFilters(Photon.Realtime.RoomInfo room)
    {
        foreach (var filter in _filters)
        {
            if (!filter.Passes(room))
                return false;
        }
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Room Creation
    // ═══════════════════════════════════════════════════════════════════════

    public bool CreateRoom(RoomCreationConfig config)
    {
        if (!config.Validate())
        {
            Debug.LogError("[LobbyManager] Invalid room config.");
            return false;
        }

        var roomName = config.RoomName;
        var options = new Photon.Realtime.RoomOptions
        {
            MaxPlayers = config.MaxPlayers,
            IsVisible = config.Privacy != (byte)RoomPrivacy.PrivateWithPassword,
            IsOpen = true,
        };

        var props = config.ToSessionProperties();
        networkRunner.CreateRoom(roomName, options, null, props);
        return true;
    }

    public bool JoinRoom(string roomName)
    {
        // For private rooms, verify password first:
        var room = networkRunner.CurrentRoom;
        if (room != null && room.CustomRoomProperties.ContainsKey("auth_salt"))
        {
            var salt = (uint)room.CustomRoomProperties["auth_salt"];
            var expectedHash = (uint)room.CustomRoomProperties["auth_hash"];
            var clientHash = PasswordHasher.ComputeSaltedHash(
                UIController.Instance.GetPendingPassword(), salt);
            if (clientHash != expectedHash)
            {
                Debug.LogError("[LobbyManager] Password verification failed.");
                return false;
            }
        }

        networkRunner.JoinRoom(roomName);
        return true;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Error Handling
    // ═══════════════════════════════════════════════════════════════════════

    private void HandleJoinFailure(ConnectionRequestFailedReason reason)
    {
        string title, message;
        switch (reason)
        {
            case ConnectionRequestFailedReason.VersionMismatch:
                title = "Version Mismatch";
                message = "The room requires a different game version. Please update.";
                break;
            case ConnectionRequestFailedReason.AuthFailed:
                title = "Authentication Failed";
                message = "The room password is incorrect.";
                break;
            case ConnectionRequestFailedReason.RoomFull:
                title = "Room Full";
                message = "This room has no available slots.";
                break;
            case ConnectionRequestFailedReason.LobbyNotFound:
                title = "Room Not Found";
                message = "The room no longer exists.";
                break;
            default:
                title = "Connection Failed";
                message = $"Could not join room. Reason: {reason}";
                break;
        }
        UIController.Instance.ShowErrorDialog(title, message);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  ILobbyFilter Interface
    // ═══════════════════════════════════════════════════════════════════════

    public interface ILobbyFilter
    {
        void ApplyConstraints(Dictionary<string, object> constraints);
        bool Passes(Photon.Realtime.RoomInfo room);
    }
}
```

### 5.4 `RoomManager.cs` (NetworkBehaviour)

```csharp
using System.Collections.Generic;
using Photon.Fusion;
using Photon.Fusion.Diagnostics;
using UnityEngine;

public class RoomManager : NetworkBehaviour
{
    // ═══════════════════════════════════════════════════════════════════════
    //  Networked Properties (Shared with all clients)
    // ═══════════════════════════════════════════════════════════════════════

    [Networked] public NetworkDictionary<int, SeatInfo> seats { get; set; }
    [Networked] public List<NetworkPlayerRef> spectators { get; set; }
    [Networked] public byte handshakeState { get; set; } // 0=Idle, 1=Negotiating, 2=Ready, 3=Failed
    [Networked] public uint sessionSeed { get; set; }
    [Networked] public byte currentPlayers { get; set; }
    [Networked] public uint customFlags { get; set; }

    // ═══════════════════════════════════════════════════════════════════════
    //  Local State (Not synced)
    // ═══════════════════════════════════════════════════════════════════════

    public static RoomManager Instance { get; private set; }
    private static readonly int MaxSeats = 8;
    private float _handshakeTimer;
    private const float HandshakeTimeout = 10.0f;
    private const float LoadingTimeout = 30.0f;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Lifecycle
    // ═══════════════════════════════════════════════════════════════════════

    public override void OnNetworkSpawn()
    {
        if (IsHost)
        {
            InitializeSeats();
            UpdateHostMetadata();
        }

        if (IsMasterClient)
        {
            // We are the host — set up initial state
            seats ??= new NetworkDictionary<int, SeatInfo>();
        }
    }

    public override void OnNetworkDespawn()
    {
        if (Instance == this) Instance = null;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Seat Management
    // ═══════════════════════════════════════════════════════════════════════

    private void InitializeSeats()
    {
        for (int i = 0; i < MaxSeats; i++)
        {
            seats.AddOrSet(i, new SeatInfo
            {
                PlayerActor = -1,
                SeatIndex = i,
                Role = PlayerRole.Spectator,
                ColorIndex = (byte)(i % 8),
                IsLocked = false,
                HandZoneMask = (byte)(1 << i),
                PingMs = 0,
                Ready = false,
            });
        }
        currentPlayers = 1; // Host counts as 1
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  RPC: Seat Assignment
    // ═══════════════════════════════════════════════════════════════════════

    // Client requests a seat (host processes):
    [Rpc(RpcAttributes.ExcludeOwner)]
    private void RequestSeat(int seatIndex)
    {
        if (!IsHost) return;
        if (seatIndex < 0 || seatIndex >= MaxSeats) return;
        if (!seats.ContainsKey(seatIndex)) return;
        if (seats[seatIndex].PlayerActor != -1)
        {
            // Seat taken — notify requester:
            RpcSeatTaken(seatIndex, RpcTarget.Others);
            return;
        }
        AssignSeat(seatIndex);
    }

    // Host assigns a seat:
    [Rpc]
    private void AssignSeat(int seatIndex)
    {
        if (seatIndex < 0 || seatIndex >= MaxSeats) return;
        if (seats[seatIndex].PlayerActor != -1) return;

        var player = LocalPlayer;
        seats[seatIndex] = new SeatInfo
        {
            PlayerActor = (int)player.ActorNumber,
            SeatIndex = seatIndex,
            Role = PlayerRole.Player,
            ColorIndex = (byte)(seatIndex % 8),
            IsLocked = false,
            HandZoneMask = (byte)(1 << seatIndex),
            PingMs = 0,
            Ready = false,
        };
        currentPlayers++;
        RpcSeatUpdated(seatIndex);
    }

    // Notify the assigned player:
    [Rpc(RequireOwnership = false)]
    private void RpcAssignSeatToPlayer(int seatIndex, NetworkPlayerRef player)
    {
        // Called on the player's client — spawn avatar, set input authority
        var seat = seats[seatIndex];
        SeatController.Instance?.OnSeatAssigned(seatIndex, seat);
    }

    // Notify everyone else of a seat update:
    [Rpc]
    private void RpcSeatUpdated(int seatIndex)
    {
        // Update UI on all clients
        UIController.Instance?.UpdateSeatUI(seatIndex, seats[seatIndex]);
    }

    // Seat is taken — notify requester:
    [Rpc(RpcAttributes.ExcludeOwner)]
    private void RpcSeatTaken(int seatIndex)
    {
        UIController.Instance?.ShowSeatTakenNotification(seatIndex);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  RPC: Host Controls
    // ═══════════════════════════════════════════════════════════════════════

    [Rpc]
    public void KickPlayer(int seatIndex)
    {
        if (!IsHost) return;
        var actor = seats[seatIndex].PlayerActor;
        if (actor == -1) return;
        NetworkRunner.CloseConnection(actor);
        seats[seatIndex].PlayerActor = -1;
        currentPlayers--;
        RpcSeatUpdated(seatIndex);
    }

    [Rpc]
    public void StartGame()
    {
        if (!IsHost) return;
        if (handshakeState != HandshakeState.Ready) return;

        handshakeState = HandshakeState.LoadingBoard;
        // Update SessionProperties so lobby shows LoadingBoard state:
        Photon.Realtime.PhotonNetwork.CurrentRoom.SetCustomRoomProperties(
            "state", (byte)RoomState.LoadingBoard);

        // Trigger scene load:
        NetworkSceneManagerDefault.Instance.LoadScene(
            ModManager.Instance.CurrentMod.BoardSceneName,
            NetworkSceneLoadMode.AllLoad);
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Handshake State Machine
    // ═══════════════════════════════════════════════════════════════════════

    public override void OnNetworkUpdate()
    {
        if (!IsHost) return;

        switch (handshakeState)
        {
            case HandshakeState.Negotiating:
                _handshakeTimer += Time.deltaTime;
                if (_handshakeTimer > HandshakeTimeout)
                {
                    handshakeState = HandshakeState.Failed;
                    UIController.Instance?.ShowErrorDialog(
                        "Loading Timeout", "A player failed to load the board. Please try again.");
                    TransitionToPreGameRoom();
                }
                break;

            case HandshakeState.Ready:
                // All players loaded — start game
                StartGame();
                break;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Player Lifecycle
    // ═══════════════════════════════════════════════════════════════════════

    public override void OnPlayerLeft(NetworkPlayerRef player)
    {
        // Free the seat:
        for (int i = 0; i < MaxSeats; i++)
        {
            if (seats[i].PlayerActor == (int)player.ActorNumber)
            {
                seats[i].PlayerActor = -1;
                currentPlayers--;
                RpcSeatUpdated(i);
                break;
            }
        }

        // Remove from spectators:
        spectators.Remove(player);

        // Update session properties:
        Photon.Realtime.PhotonNetwork.CurrentRoom.SetCustomRoomProperties(
            "open_slots", (byte)(MaxSeats - currentPlayers));
    }

    public override void OnMasterClientChanged(bool wasMaster, NetworkPlayerRef newMaster)
    {
        if (!wasMaster && IsMasterClient)
        {
            // We are the new host:
            UpdateHostMetadata();
            ShowHostTransferNotification();
        }
    }

    private void UpdateHostMetadata()
    {
        Photon.Realtime.PhotonNetwork.CurrentRoom.SetCustomRoomProperties(
            "host_id", (long)LocalPlayer.ActorNumber);
    }

    private void ShowHostTransferNotification()
    {
        UIController.Instance?.ShowHostTransferNotification();
    }

    private void TransitionToPreGameRoom()
    {
        handshakeState = HandshakeState.Idle;
        // Return to PreGameRoom state
        UIController.Instance?.TransitionToState(UIState.PreGameRoom);
    }
}
```

### 5.5 `SeatController.cs`

```csharp
using System.Collections.Generic;
using Photon.Fusion;
using UnityEngine;
using UnityEngine.InputSystem;

public class SeatController : NetworkBehaviour
{
    [Header("Seat Configuration")]
    [SerializeField] private int seatIndex;
    [SerializeField] private Transform seatPosition;
    [SerializeField] private Transform[] handZones;
    [SerializeField] private PlayerAvatar avatarPrefab;

    [Header("Input Filtering")]
    [SerializeField] private float inputCooldown = 0.1f;
    private float _lastInputTime;

    private PlayerAvatar _avatar;
    private NetworkPlayerRef _assignedPlayer;
    private bool _isSeatActive;

    public static SeatController Instance { get; private set; }

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
    }

    private void OnDestroy()
    {
        if (Instance == this) Instance = null;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Seat Assignment
    // ═══════════════════════════════════════════════════════════════════════

    public void OnSeatAssigned(int index, SeatInfo info)
    {
        seatIndex = index;
        _assignedPlayer = NetworkRunner.LocalPlayer;
        _isSeatActive = true;

        // Spawn avatar at seat position:
        if (avatarPrefab != null && seatPosition != null)
        {
            _avatar = PhotonInstantiate.Instantiate(
                avatarPrefab, seatPosition.position, seatPosition.rotation,
                NetworkRunner.LocalPlayer);
            _avatar.Initialize(info.ColorIndex);
        }

        // Enable input for hand zones:
        EnableHandZoneInput(true);
    }

    public void OnSeatRemoved()
    {
        _isSeatActive = false;
        EnableHandZoneInput(false);
        // Destroy avatar:
        if (_avatar != null)
        {
            PhotonDestroy.Destroy(_avatar);
            _avatar = null;
        }
        _assignedPlayer = default;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Input Filtering (Server-Authoritative Physics)
    // ═══════════════════════════════════════════════════════════════════════

    private void EnableHandZoneInput(bool enabled)
    {
        foreach (var zone in handZones)
        {
            if (zone == null) continue;
            var filter = zone.GetComponent<InputFilter>();
            if (filter != null)
            {
                filter.enabled = enabled;
                filter.playerRef = _assignedPlayer;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Physics Interaction (Server-Authoritative)
    // ═══════════════════════════════════════════════════════════════════════

    // Only the assigned player can pick up objects in their hand zones:
    private void OnTriggerEnter(Collider other)
    {
        if (!_isSeatActive) return;
        if (!IsInputFromAssignedPlayer()) return;

        var pickup = other.GetComponent<NetworkPickup>();
        if (pickup != null && pickup.CanBePickedUpBy(_assignedPlayer))
        {
            pickup.PickUp(_assignedPlayer);
        }
    }

    private bool IsInputFromAssignedPlayer()
    {
        // Verify the input source is the assigned player:
        // In Fusion, input is sent via NetworkInputUser.
        return NetworkRunner.LocalPlayer == _assignedPlayer;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Spectator Mode
    // ═══════════════════════════════════════════════════════════════════════

    public void SetSpectatorMode(bool spectator)
    {
        if (spectator)
        {
            OnSeatRemoved();
            // Enable free camera:
            CameraController.Instance?.EnableSpectatorCamera(_assignedPlayer);
        }
        else
        {
            // Request seat back from host:
            RpcRequestSeat(seatIndex);
        }
    }

    [Rpc(RpcAttributes.ExcludeOwner)]
    private void RpcRequestSeat(int index)
    {
        if (IsHost)
        {
            AssignSeat(index); // Directly assign if host
        }
    }

    [Rpc]
    private void AssignSeat(int index)
    {
        OnSeatAssigned(index, new SeatInfo
        {
            PlayerActor = (int)NetworkRunner.LocalPlayer.ActorNumber,
            SeatIndex = index,
            Role = PlayerRole.Player,
            ColorIndex = (byte)(index % 8),
            IsLocked = false,
            HandZoneMask = (byte)(1 << index),
            PingMs = 0,
            Ready = false,
        });
    }
}
```

### 5.6 Supporting Enums & Structs

```csharp
// ─── Enums ──────────────────────────────────────────────────────────────

public enum RoomState : byte
{
    WaitingInLobby = 0,
    LoadingBoard   = 1,
    InProgress     = 2,
    Paused         = 3,
}

public enum RoomPrivacy : byte
{
    Public = 0,
    FriendsOnly = 1,
    PrivateWithPassword = 2,
}

public enum PlayerRole : byte
{
    Host = 0,
    Player = 1,
    Spectator = 2,
}

public enum HandshakeState : byte
{
    Idle = 0,
    Negotiating = 1,
    Ready = 2,
    Failed = 3,
}

// ─── RoomInfo (Lightweight wrapper) ─────────────────────────────────────

public class RoomInfo
{
    public string Name;
    public byte MaxPlayers;
    public byte CurrentPlayers;
    public byte OpenSlots;
    public byte State;
    public byte Privacy;
    public string ModId;
    public int ModVersion;
    public string ModName;
    public float PingMs;

    public RoomInfo(Photon.Realtime.RoomInfo photonRoom)
    {
        Name = photonRoom.Name;
        MaxPlayers = photonRoom.MaxPlayers;
        CurrentPlayers = photonRoom.PlayerCount;
        OpenSlots = (byte)(MaxPlayers - CurrentPlayers);
        State = (byte)photonRoom.CustomRoomProperties["state"];
        Privacy = (byte)photonRoom.CustomRoomProperties["privacy"];
        ModId = (string)photonRoom.CustomRoomProperties["mod_id"];
        ModVersion = (int)photonRoom.CustomRoomProperties["mod_version"];
        ModName = ModManager.Instance.GetModName(ModId);
        PingMs = networkRunner.CurrentRtt;
    }
}
```

---

<a id="module-6"></a>
## MODULE 6: BEST PRACTICES & PERFORMANCE OPTIMIZATION

### 6.1 Photon Cloud Throttling

Photon Cloud rate-limits certain operations. Exceeding limits results in temporary bans or dropped requests.

| Operation | Default Limit | Strategy |
|-----------|:---:|----------|
| `JoinLobby` | 30s / 10 requests | Throttle to 1 request per 2 seconds. Use `OnSessionListUpdated` for incremental updates instead of polling. |
| `SetCustomRoomProperties` | 60s / 10 requests | Only update when state actually changes. Batch multiple property updates into a single call. |
| `CreateRoom` | 60s / 20 requests | Disable "Create" button for 3s after creation. |
| `JoinRoom` | 60s / 30 requests | Disable "Join" button on click until `OnJoinedRoom` or `OnJoinRequestFailed` fires. |

**Implementation:**

```csharp
// In LobbyManager:
private const float MinCreateRoomInterval = 3.0f;
private const float MinJoinRoomInterval = 1.0f;
private const float MinListInterval = 2.0f;

private float _lastCreateTime, _lastJoinTime, _lastListTime;

public bool TryCreateRoom(RoomCreationConfig config)
{
    if (Time.time - _lastCreateTime < MinCreateRoomInterval) return false;
    _lastCreateTime = Time.time;
    // ... proceed
}

public bool TryJoinRoom(string roomName)
{
    if (Time.time - _lastJoinTime < MinJoinRoomInterval) return false;
    _lastJoinTime = Time.time;
    // ... proceed
}
```

### 6.2 Memory & GC Optimization

**Problem:** Creating `RoomInfo` objects for every lobby update causes GC pressure, especially with 50+ rooms and frequent refreshes.

**Solution: Object Pooling for RoomInfo**

```csharp
public class RoomInfoPool
{
    private readonly Stack<RoomInfo> _pool = new();

    public RoomInfo Acquire()
    {
        if (_pool.Count > 0)
        {
            var room = _pool.Pop();
            room.Reset();
            return room;
        }
        return new RoomInfo();
    }

    public void Release(RoomInfo room)
    {
        room.Reset();
        _pool.Push(room);
    }
}

// Usage in LobbyManager:
private readonly RoomInfoPool _roomPool = new();

private void OnSessionListUpdated(List<Photon.Realtime.RoomInfo> rooms)
{
    // Clear old entries (release to pool):
    foreach (var old in _roomList)
        _roomPool.Release(old);
    _roomList.Clear();

    // Acquire new entries:
    for (int i = 0; i < rooms.Count && i < maxLobbyRooms; i++)
    {
        var room = _roomPool.Acquire();
        room.Populate(rooms[i]); // Copy data without allocation
        if (PassesFilters(room))
            _roomList.Add(room);
    }
    _observableRooms?.OnChanged();
}
```

**Additional optimizations:**
- **String interning** for room names and mod IDs: use `String.Intern()` for frequently compared strings.
- **Avoid LINQ in hot paths:** Filter loops should be `for` loops, not `Where().Select()`.
- **Cache `PhotonNetwork.CurrentRoom.CustomRoomProperties`** in a local variable — accessing it repeatedly creates dictionary lookup overhead.
- **Use `ValueTuple`** for filter results instead of allocating small structs.

### 6.3 Network Profiling & Debugging

#### 6.3.1 Fusion Diagnostics Package

Enable the Fusion Diagnostics package (`com.photon.fusion.diagnostics`) to get real-time network monitoring:

```csharp
// In NetworkRunner configuration:
runner.ConfigureNetworkSettings(
    new NetworkConfig
    {
        // ...
    });

// In editor:
#if UNITY_EDITOR
    FusionDebugger.Show();
#endif
```

#### 6.3.2 Profiling Checklist

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Input rate | < 30 packets/s per player | Fusion Debugger → Input tab |
| Property sync rate | < 10 updates/s for room state | Fusion Debugger → Properties tab |
| RPC count | < 5/s during normal gameplay | Fusion Debugger → RPCs tab |
| Bandwidth per player | < 50 KB/s during lobby | Network Profiler window |
| Scene load time | < 15s for average mod | Time.realtimeSinceStartup around `LoadScene` |
| Host migration time | < 3s | Measure from `OnMasterClientChanged` to new host's `OnNetworkSpawn` |

#### 6.3.3 Debug Logging

```csharp
// Conditional logging based on build configuration:
#if DEBUG_NETWORK
    private const bool LogNetworkEvents = true;
#else
    private const bool LogNetworkEvents = false;
#endif

private void LogNetworkEvent(string message)
{
#if DEBUG_NETWORK
    Debug.Log($"[Network] {message}");
#endif
}

// Usage:
LogNetworkEvent($"Room created: {roomName}, players: {MaxPlayers}, mod: {ModId}");
LogNetworkEvent($"Player joined: {player.ActorNumber}, seat: {seatIndex}");
LogNetworkEvent($"Handshake state: {handshakeState}, timer: {_handshakeTimer:F1}s");
```

#### 6.3.4 Common Pitfalls

1. **Don't sync `SessionProperties` from client.** Only the host should update `PhotonNetwork.CurrentRoom.SetCustomRoomProperties`. Clients should treat these as read-only.
2. **Don't use `NetworkDictionary<int, SeatInfo>` for frequent updates.** Each property change generates a network sync. If seats change rarely (during setup), this is fine. For in-game state, use RPCs.
3. **Don't call `JoinLobby` from `OnSessionListUpdated`.** This creates an infinite loop. Use a separate refresh timer.
4. **Don't store passwords in `NetworkedProperties`.** Use `SessionProperties` with salted hash only, and verify post-join.
5. **Always check `IsHost` before host-only RPCs.** Use `[Rpc]` with `RequireOwnership = true` for host commands.

### 6.4 Scene Loading Optimization

For `LoadingTransitionState`, use `NetworkSceneManagerDefault` with `NetworkSceneLoadMode.AllLoad`:

```csharp
// Host triggers:
NetworkSceneManagerDefault.Instance.LoadScene(
    boardSceneName,
    NetworkSceneLoadMode.AllLoad,
    () => {
        // All clients loaded — proceed to InGame
        handshakeState = HandshakeState.Ready;
    },
    () => {
        // Load failed — return to PreGameRoom
        handshakeState = HandshakeState.Failed;
        ShowErrorDialog("Scene Load Failed", "Could not load the board scene. Please check your mod installation.");
    });
```

**Pre-loading:** Before the host creates the room, preload the mod's dependencies in the background:

```csharp
// In ModManager:
public void PreloadModAssets(string modId)
{
    // Use Addressables or Resources to preload:
    Addressables.LoadAssetsAsync<GameObject>(modId, null);
    // Store in a cache for instant scene load later.
}
```

This reduces `LoadingTransitionState` from ~15s to ~3s on first load, and ~1s on subsequent loads.

### 6.5 Connection Quality Monitoring

During `PreGameRoom`, continuously monitor connection quality:

```csharp
private void UpdateConnectionQuality()
{
    if (NetworkRunner.CurrentRtt > 500)
    {
        // Show high latency warning
        UIController.Instance?.ShowLatencyWarning(NetworkRunner.CurrentRtt);
    }
    else if (NetworkRunner.CurrentRtt > 200)
    {
        // Show mild latency indicator
        UIController.Instance?.ShowLatencyIndicator(NetworkRunner.CurrentRtt);
    }
    else
    {
        UIController.Instance?.HideLatencyWarning();
    }
}
```

Use `NetworkRunner.CurrentRtt` (round-trip time in milliseconds) for real-time latency display. Avoid using ping from `PhotonNetwork.GetPing()` as it can be inaccurate.

---

## Appendix: Module Dependency Graph

```
LobbyManager (Singleton, persistent)
  ├── NetworkRunner (Photon Fusion)
  ├── UIController (View Layer)
  └── RoomManager (NetworkBehaviour, in-room)
        ├── SeatController (per-avatar)
        ├── NetworkSceneManagerDefault
        └── ModManager (content loading)
```

**Dependency rules:**
- `LobbyManager` depends on `NetworkRunner` and `UIController`. It does **not** depend on `RoomManager`.
- `RoomManager` depends on `NetworkRunner`, `SeatController`, and `ModManager`.
- `SeatController` depends on `NetworkRunner` and `InputFilter` (on hand zones).
- No circular dependencies — `RoomManager` notifies `UIController` via callbacks, not direct references.

---

*End of Specification — v1.0.0*
