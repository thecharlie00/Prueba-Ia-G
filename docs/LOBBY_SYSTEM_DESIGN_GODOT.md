# Lobby & Room Management System — Technical Design Specification

**Game:** 3D Multiplayer Tabletop Simulator (mod-supported)
**Engine:** Godot 4.7 (.NET / C# 12)
**Networking:** Photon Fusion 2 (Host/Client topology, Server-Authoritative)
**Author:** Senior Multiplayer Architect
**Version:** 2.0.0

---

## Table of Contents

1. [Module 1: Data Architecture & Custom Room Properties (Matchmaking)](#module-1)
2. [Module 2: Scene & Autoload Architecture in Godot 4.7](#module-2)
3. [Module 3: Fusion NetworkBehaviour & Seating System](#module-3)
4. [Module 4: Godot Signals & Reactive UI/UX](#module-4)
5. [Module 5: C# Code Specification for Godot 4.7](#module-5)
6. [Module 6: Resilience, Edge Cases & Performance Optimization](#module-6)

---

<a id="module-1"></a>
## MODULE 1: DATA ARCHITECTURE & CUSTOM ROOM PROPERTIES (MATCHMAKING)

### 1.1 SessionProperties Schema

Photon Cloud stores room metadata in `SessionProperties` (a `Dictionary<string, object>` accessible via `PhotonNetwork.CurrentRoom.CustomRoomProperties`). Only a lightweight subset should be sent to the cloud — heavy payloads stay in the room's `NetworkedProperties` after the room is created. This keeps lobby listing lightweight and enables efficient server-side filtering.

#### Cloud-visible fields (in `SessionProperties`)

| Key | Type | Size (bytes) | Purpose |
|-----|------|:---:|---------|
| `name` | string | ~32 | Room display name (filtered by Lobby list) |
| `mod_id` | string | ~64 | Mod/Workshop GUID or hash for content validation |
| `mod_version` | int | 4 | Semantic version packed as int (Maj.Min.Patch) |
| `rules_checksum` | string | ~16 | SHA-1 hex of rules script hash |
| `game_mode` | byte | 1 | Enum: 0=Normal, 1=Tournament, 2=Practice, 3=Custom |
| `dlc_required` | string[] | ~32 | Array of DLC GUIDs required |
| `state` | byte | 1 | Enum: 0=WaitingInLobby, 1=LoadingBoard, 2=InProgress, 3=Paused |
| `privacy` | byte | 1 | Enum: 0=Public, 1=FriendsOnly, 2=PrivateWithPassword |
| `max_players` | byte | 1 | Slot capacity (2–8) |
| `open_slots` | byte | 1 | Derived: `max_players - current_players` |
| `ping_region` | string | ~8 | Approximate region code (EU/NA/SA/AS/OC) |
| `host_id` | long | 8 | Photon actor number of the host |
| `custom_flags` | int | 4 | Bitmask for table-specific options |

**Total per room: ~200 bytes.** Well within Photon's `lobby.maxlobbysize` (default 3000 bytes).

#### In-room fields (NOT in `SessionProperties`, in `NetworkedProperties`)

| Key | Type | Purpose |
|-----|------|---------|
| `seats` | `NetworkDictionary<PlayerRef, SeatData>` | Slot assignments |
| `spectators` | `List<PlayerRef>` | Spectator list |
| `mod_data` | `byte[]` | Serialized mod state (board config, RNG seed) |
| `handshake_state` | `NetworkByte` | 0=Idle, 1=Negotiating, 2=Ready, 3=Failed |
| `session_seed` | `NetworkUInt` | Deterministic RNG seed for board generation |
| `ready_count` | `NetworkByte` | Number of players who confirmed readiness |

### 1.2 Version Packing Strategy

Pack semantic version into a single `int` for compact comparison:

```csharp
public static int PackVersion(int major, int minor, int patch)
    => (major & 0xFF) << 24 | (minor & 0xFF) << 16 | (patch & 0xFF) << 8;

public static (int major, int minor, int patch) UnpackVersion(int packed)
    => (packed >> 24 & 0xFF, packed >> 16 & 0xFF, packed >> 8 & 0xFF);
```

Server-side filtering via `Lobby.JoinLobby(TypedLobbyInfo)` can use LINQ on `SessionProperties` without unpacking overhead.

### 1.3 Password Security

Photon does **not** encrypt room passwords. A naive `session.SetCustomRoomProperties("password", "1234")` exposes them in the lobby listing. Instead:

1. **Password never goes to cloud.** Store a salted hash in `SessionProperties`:
   ```csharp
   // On room creation:
   var salt = Random.Shared.Next(0, int.MaxValue);
   var hash = ComputeSaltedHash(password, salt);
   session.SetCustomRoomProperties("auth_salt", salt);
   session.SetCustomRoomProperties("auth_hash", hash);
   ```
   Use PBKDF2 or scrypt for the hash function.

2. **Client-side verification before handshake.** When a client attempts to join a `PrivateWithPassword` room, they first fetch the `auth_salt`, compute the hash locally, and send the hash in the `JoinRoom` request's custom authentication (`AuthenticationValues`). Photon's Cloud Code (or client-side check after join) validates the hash.

3. **Post-join verification.** After `OnJoinedRoom`, the host sends a `VerifyPassword` RPC. If verification fails, the host kicks the actor. This prevents clients from joining without the password even if Photon's join succeeds.

4. **Brute-force protection.** If a client fails 3 password attempts, the host sets a `lockout_until` timestamp in `NetworkedProperties` and ignores further join attempts for 60 seconds.

```csharp
public static uint ComputeSaltedHash(string password, uint salt)
{
    var bytes = Encoding.UTF8.GetBytes(password + salt.ToString());
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
    None               = 0,
    NoSpectators       = 1 << 0,
    AutoStart          = 1 << 1,  // Start game when all slots filled
    TournamentMode     = 1 << 2,  // Disable chat, enforce turn timer
    ModsOnly           = 1 << 3,  // Require mod to join
    FriendlyFire       = 1 << 4,  // Allow physics interaction between players
    CoopMode           = 1 << 5,  // Shared board state, no competition
    ScoreboardEnabled  = 1 << 6,
    RematchEnabled     = 1 << 7,  // Allow quick rematch after game end
}
```

---

<a id="module-2"></a>
## MODULE 2: SCENE & AUTOLOAD ARCHITECTURE IN GODOT 4.7

### 2.1 Autoload Hierarchy

Godot's Autoload system provides persistent nodes across scene changes. The networking layer uses three autoloads:

```
[Root]
├── NetworkManager (Autoload, Singleton)
│   ├── NetworkRunner (Fusion NetworkRunner)
│   ├── LocalPlayer (FusionLocalPlayer)
│   └── ConnectionState (ConnectionStateNode)
├── LobbyManager (Autoload, Singleton)
│   ├── SessionCache (ObservableCollection<RoomInfo>)
│   ├── FilterPipeline (ILobbyFilter[])
│   └── SignalBus (Godot Signal Dispatcher)
└── UIController (Autoload, Singleton)
    ├── CurrentUIState (UIState enum)
    └── TransitionQueue (Queue<UIState>)
```

### 2.2 Scene Hierarchy

```
res://scenes/
├── BotMenu.tscn              # Main menu (entry point)
│   └── Control
│       ├── MainMenuView
│       └── MainMenuController
├── Lobby.tscn               # Lobby browser + room creation
│   └── Control
│       ├── LobbyBrowserView
│       │   ├── VBoxContainer
│       │   │   ├── SearchBar (LineEdit + FilterButton)
│       │   │   ├── FilterChips (HBoxContainer)
│       │   │   └── RoomList (ScrollContainer > VBoxContainer > VirtualList)
│       └── LobbyBrowserController
├── RoomWaiting.tscn         # Pre-game waiting room (3D + 2D hybrid)
│   └── Control
│       ├── WaitingView
│       │   ├── SeatPreview3D (Node3D with seat markers)
│       │   ├── PlayerListPanel (VBoxContainer)
│       │   ├── ChatPanel (TextEdit)
│       │   └── HostControlsPanel (Kick/Ban/Start buttons)
│       └── WaitingController
└── Island.tscn              # Game board (loaded during LoadingTransition)
    └── Node3D
        ├── Table (Node3D with collision)
        ├── Objects (Node3D for dynamic pieces)
        ├── CameraRig (Node3D)
        └── UI (Control overlay)
```

### 2.3 NetworkManager Autoload

The `NetworkManager` is a persistent `Node` added as an Autoload in `project.godot`:

```
[autoload]
NetworkManager="*res://scripts/net/NetworkManager.cs"
LobbyManager="*res://scripts/net/LobbyManager.cs"
UIController="*res://scripts/ui/UIController.cs"
```

Key responsibilities:
- **Lifecycle management:** `NetworkRunner` is created once and persists across all scenes.
- **Scene transitions:** Uses `GetTree().ChangeSceneToFile()` for UI scenes and `NetworkSceneManagerDefault` for game scenes.
- **Connection state:** Tracks `ConnectionState` (Disconnected → Connecting → Connected → InRoom → InGame).
- **Signal emission:** Emits Godot signals that UI nodes subscribe to.

### 2.4 Scene Loading Pipeline

#### UI Scene Transitions (MainMenu → Lobby → RoomWaiting)

```csharp
// In NetworkManager.cs:
public void ChangeUIScene(string scenePath)
{
    // Don't change scene while in a networked game scene
    if (NetworkRunner.IsInNetworkedScene)
        return;

    var scene = ResourceLoader.Load(scenePath);
    GetTree().ChangeSceneToPacked(scene);
}
```

#### Game Scene Loading (RoomWaiting → Island)

For the game board scene, use `NetworkSceneManagerDefault` to synchronize loading across all clients:

```csharp
// Host triggers loading:
NetworkSceneManagerDefault.LoadScene(
    "res://scenes/Island.tscn",
    NetworkSceneLoadMode.AllLoad,
    () => {
        // All clients loaded — proceed to InGame
        handshakeState = HandshakeState.Ready;
    },
    () => {
        // Load failed — return to RoomWaiting
        handshakeState = HandshakeState.Failed;
    });
```

#### Async Resource Loading (Mods)

Before the host creates the room, preload mod dependencies in the background using Godot's threaded resource loading:

```csharp
// In ModManager.cs:
public async Task<bool> PreloadModAssets(string modId)
{
    var requests = new List<ResourceLoader.LoadThreadedRequest>();
    var assetPaths = GetModAssetPaths(modId);

    for (var path in assetPaths)
    {
        var request = ResourceLoader.LoadThreadedRequest(path);
        requests.Add(request);
    }

    // Wait for all requests to complete
    foreach (var request in requests)
    {
        while (request.Status != ResourceLoader.LoadThreadedStatus.Loaded)
        {
            await Task.Delay(50);
            if (request.Status == ResourceLoader.LoadThreadedStatus.Failed)
                return false;
        }
    }
    return true;
}
```

This reduces `LoadingTransition` from ~15s to ~3s on first load.

### 2.5 Memory Management

- **Don't destroy NetworkRunner between scenes.** The runner persists as an Autoload.
- **Use `SceneTree.ChangeSceneToPacked()`** instead of `ChangeSceneToFile()` for packed resources (faster, no file I/O).
- **Queue scene changes** if multiple transitions are requested rapidly — only the last one executes.
- **Clean up UI node references** in `OnExitTree()` to prevent dangling references after scene change.

---

<a id="module-3"></a>
## MODULE 3: FUSION NETWORKBEHAVIOUR & SEATING SYSTEM

### 3.1 Networked Data Structures

```csharp
// SeatData — stored in NetworkDictionary<PlayerRef, SeatData>
public partial class SeatData : INetworkStruct
{
    public int SeatIndex;           // 0..7
    public NetworkColor PlayerColor; // Player color (red, blue, green, etc.)
    public NetworkBool IsReady;      // Player confirmed readiness
    public PlayerRole Role;          // Host, Player, Spectator
    public float PingMs;             // Last measured ping (for UI)
}

// RoomState — top-level synced state
public partial class RoomState : INetworkStruct
{
    public NetworkDictionary<PlayerRef, SeatData> Seats;
    public List<PlayerRef> Spectators;
    public NetworkByte HandshakeState;  // 0=Idle, 1=Negotiating, 2=Ready, 3=Failed
    public NetworkUInt SessionSeed;
    public NetworkByte ReadyCount;
}
```

### 3.2 Seat Assignment Flow

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
                    │  (seat_index, player)   │
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

### 3.3 Conflict Resolution: Two Players, Same Seat

The host is the sole authority over seat assignments. Clients **cannot** self-assign seats — they can only request.

```csharp
// Client sends a request (not a command):
[Rpc(RpcAttributes.ExcludeOwner)]
private void RequestSeat(int seatIndex)
{
    if (IsHost) return; // Host doesn't need to request
    // Only process if seat is free:
    if (seats.TryGetValue(seatIndex, out var seat) && seat.PlayerActor == -1)
    {
        AssignSeat(seatIndex, RpcTarget.Others);
    }
}

// Host processes the request:
[Rpc]
private void AssignSeat(int seatIndex, NetworkPlayerRef player)
{
    if (seatIndex < 0 || seatIndex >= MAX_SEATS) return;
    if (!seats.TryGetValue(seatIndex, out var seat)) return;
    if (seat.PlayerActor != -1) return; // Seat taken — reject

    seats[seatIndex] = new SeatData
    {
        PlayerActor = (int)player.ActorNumber,
        SeatIndex = seatIndex,
        Role = PlayerRole.Player,
        IsReady = false,
    };
    // Notify the player:
    RpcAssignSeatToPlayer(seatIndex, player);
    // Notify everyone else:
    RpcSeatUpdated(seatIndex);
}
```

**Key principles:**
- Clients send `RequestSeat` (excluded from host) — it's a suggestion, not a command.
- Host validates and issues `AssignSeat` RPC to all clients.
- If a seat is taken, the host silently rejects the request and sends a `SeatTaken` notification.
- No transactional locking needed — the host's sequential processing guarantees no double-assignment.

### 3.4 Spectator Management

- Spectators join with `Role = Spectator` and no seat assignment.
- Their `SeatData.PlayerActor = -1` but they appear in the `spectators` list.
- Spectators cannot send `RequestSeat` — they can only request host approval via a `RequestSpectatorToPlayer` RPC.
- Host can downgrade a player to spectator at any time.

### 3.5 SeatController — 3D Zone Permissions

```csharp
// SeatController.cs — attached to each seat marker in the 3D scene
public partial class SeatController : GridContainer3D
{
    [Export] public int SeatIndex;
    [Export] public Area3D[] HandZones;      // Player's private interaction zones
    [Export] public Node3D SeatPosition;    // Where to spawn the avatar

    private NetworkPlayerRef _assignedPlayer;
    private bool _isActive;

    public override void _Ready()
    {
        // Initially inactive — no one can interact
        foreach (var zone in HandZones)
        {
            zone.Monitoring = false;
            zone.Monitorable = false;
        }
    }

    public void OnSeatAssigned(NetworkPlayerRef player)
    {
        _assignedPlayer = player;
        _isActive = true;

        // Spawn avatar at seat position
        var avatar = InstantiateAvatar(SeatPosition.GlobalTransform.origin);
        avatar.Initialize(player, SeatIndex);

        // Enable input for hand zones
        foreach (var zone in HandZones)
        {
            zone.Monitoring = true;
            zone.Monitorable = true;
            zone.GetComponent<InputFilter>().playerRef = player;
        }
    }

    public void OnSeatRemoved()
    {
        _isActive = false;
        foreach (var zone in HandZones)
        {
            zone.Monitoring = false;
            zone.Monitorable = false;
        }
        // Destroy avatar
        if (_avatar != null)
            Destroy(_avatar);
        _assignedPlayer = default;
    }
}
```

---

<a id="module-4"></a>
## MODULE 4: GODOT SIGNALS & REACTIVE UI/UX

### 4.1 Signal Bus Architecture

Godot's signal system provides a clean pub/sub mechanism between the networking layer and UI. The `LobbyManager` and `RoomManager` emit signals; UI controllers subscribe.

```csharp
// In LobbyManager.cs (Autoload):
[Signal]
public delegate void SessionListUpdatedEventHandler(List<RoomInfo> rooms);

[Signal]
public delegate void SessionCreatedEventHandler(string roomName);

[Signal]
public delegate void SessionJoinedEventHandler(string roomName);

[Signal]
public delegate void SessionJoinFailedEventHandler(ConnectionRequestFailedReason reason);

[Signal]
public delegate void ConnectionStateChangedEventHandler(ConnectionState newState);
```

### 4.2 Signal Flow Diagram

```
Photon Cloud Events
       │
       ▼
┌────────────────────┐
│  NetworkManager     │
│  (INetworkRunner    │
│   Callbacks)        │
│                     │
│  Emits:             │
│  • OnConnectedTo    │
│    Master           │
│  • OnCreatedRoom    │
│  • OnJoinedRoom     │
│  • OnJoinFailed     │
│  • OnLeftRoom       │
│  • OnPlayerLeft     │
│  • OnMasterChanged  │
└────────┬────────────┘
         │ Signals
         ▼
┌────────────────────┐
│  LobbyManager       │
│  (Autoload)         │
│                     │
│  Transforms:        │
│  • SessionList      │
│    Updated          │
│  • PlayerJoined     │
│    Room            │
│  • PlayerLeftRoom   │
│  • SeatChanged      │
│  • ReadyUpdated     │
└────────┬────────────┘
         │ Signals
         ▼
┌────────────────────┐
│  UIController       │
│  (Autoload)         │
│                     │
│  Routes to:         │
│  • LobbyBrowserView │
│  • WaitingView      │
│  • MainMenuView     │
└────────────────────┘
```

### 4.3 RoomList Virtualization (Object Pooling)

To avoid GC spikes when updating the lobby list, use a **virtual list** pattern: only render visible items, recycling nodes as the user scrolls.

```csharp
// In LobbyBrowserView.cs:
public partial class LobbyBrowserView : VBoxContainer
{
    private readonly List<RoomListItem> _itemPool = new();
    private readonly ScrollContainer _scrollContainer;
    private readonly VBoxContainer _itemContainer;

    private const int ItemHeight = 64;
    private const int VisibleItems = 8;
    private const int BufferItems = 2;

    private int _totalItems;
    private int _scrollPosition;

    public LobbyBrowserView()
    {
        _scrollContainer = new ScrollContainer { CustomMinimumSize = new Vector2(300, 400) };
        _itemContainer = new VBoxContainer();
        _scrollContainer.AddChild(_itemContainer);
        AddChild(_scrollContainer);

        // Pool initial items
        for (int i = 0; i < VisibleItems + BufferItems * 2; i++)
        {
            var item = new RoomListItem();
            item.Visible = false;
            _itemContainer.AddChild(item);
            _itemPool.Add(item);
        }
    }

    private void OnSessionListUpdated(List<RoomInfo> rooms)
    {
        _totalItems = rooms.Count;
        UpdateVisibleItems();
    }

    private void UpdateVisibleItems()
    {
        var startIndex = Mathf.Max(0, _scrollPosition / ItemHeight - BufferItems);
        var endIndex = Mathf.Min(_totalItems, (_scrollPosition + VisibleItems * ItemHeight) / ItemHeight + BufferItems);

        for (int i = 0; i < _itemPool.Count; i++)
        {
            var item = _itemPool[i];
            int itemIndex = startIndex + i;
            if (itemIndex >= startIndex && itemIndex < endIndex && itemIndex < _totalItems)
            {
                item.Visible = true;
                item.UpdateData(_sessions[itemIndex]);
                item.Position = new Vector2(0, itemIndex * ItemHeight);
            }
            else
            {
                item.Visible = false;
            }
        }
    }

    private void _OnScrollContainerScrollPositionChanged(Vector2 _)
    {
        _scrollPosition = (int)_scrollContainer.ScrollVertical;
        UpdateVisibleItems();
    }
}
```

### 4.4 Reactive UI Updates

Each UI view subscribes to signals in `_Ready()` and unsubscribes in `_ExitTree()`:

```csharp
// In LobbyBrowserController.cs:
public override void _Ready()
{
    // Subscribe to signals
    LobbyManager.Instance.SessionListUpdated += OnSessionListUpdated;
    LobbyManager.Instance.SessionJoinFailed += OnJoinFailed;

    // Initial load
    LobbyManager.Instance.ListLobbies();
}

public override void _ExitTree()
{
    // Unsubscribe to prevent dangling references
    LobbyManager.Instance.SessionListUpdated -= OnSessionListUpdated;
    LobbyManager.Instance.SessionJoinFailed -= OnJoinFailed;
}

private void OnSessionListUpdated(List<RoomInfo> rooms)
{
    // Update the virtual list
    _view.UpdateRooms(rooms);
}

private void OnJoinFailed(ConnectionRequestFailedReason reason)
{
    _view.ShowErrorDialog(GetReasonMessage(reason));
}
```

---

<a id="module-5"></a>
## MODULE 5: C# CODE SPECIFICATION FOR GODOT 4.7

### 5.1 `RoomCreationConfig.cs`

```csharp
using System;
using System.Collections.Generic;
using System.Text;
using Godot;

namespace Tabletop.Networking
{
    [Serializable]
    public partial class RoomCreationConfig : RefCounted
    {
        // --- Display ---
        public string RoomName = "";
        public byte MaxPlayers = 4;        // 2-8
        public byte Privacy = 0;          // 0=Public, 1=FriendsOnly, 2=PrivateWithPassword
        public string Password = "";      // Only for PrivateWithPassword

        // --- Mod / Content ---
        public string ModId = "";         // Workshop GUID or content hash
        public int ModVersion = 0;        // Packed semver
        public string RulesChecksum = ""; // SHA-1 of rules script
        public string[] RequiredDlcs = Array.Empty<string>();

        // --- Game Mode ---
        public byte GameMode = 0;         // 0=Normal, 1=Tournament, 2=Practice
        public uint CustomFlags = 0;      // Bitmask
        public uint SessionSeed = 0;      // Deterministic RNG seed

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
                ["host_id"]         = 0L, // Set after join
                ["custom_flags"]    = CustomFlags,
            };

            if (Privacy == (byte)RoomPrivacy.PrivateWithPassword)
            {
                var salt = (uint)Random.Shared.Next(0, int.MaxValue);
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
}
```

### 5.2 `NetworkManager.cs` (Autoload / `INetworkRunnerCallbacks`)

```csharp
using System;
using System.Collections.Generic;
using Godot;
using Photon.Fusion;
using Photon.Fusion.Diagnostics;

namespace Tabletop.Networking
{
    public partial class NetworkManager : Node, INetworkRunnerCallbacks
    {
        [Signal]
        public delegate void ConnectionStateChangedEventHandler(ConnectionState newState);

        [Signal]
        public delegate void PlayerJoinedEventHandler(NetworkPlayerRef player);

        [Signal]
        public delegate void PlayerLeftEventHandler(NetworkPlayerRef player);

        [Signal]
        public delegate void MasterClientChangedEventHandler(bool wasMaster, NetworkPlayerRef newMaster);

        [Signal]
        public delegate void SceneLoadedEventHandler(string sceneName);

        // --- Singleton ---
        public static NetworkManager Instance { get; private set; }

        // --- Runner ---
        private NetworkRunner _runner;
        public NetworkRunner Runner => _runner;

        // --- Local Player ---
        public NetworkPlayerRef LocalPlayer => _runner?.LocalPlayer;

        // --- Connection State ---
        public enum ConnectionState : byte
        {
            Disconnected = 0,
            Connecting = 1,
            Connected = 2,
            InRoom = 3,
            InGame = 4,
            Disconnecting = 5,
        }

        private ConnectionState _connectionState;
        public ConnectionState State => _connectionState;

        private void _SetState(ConnectionState state)
        {
            if (_connectionState == state) return;
            _connectionState = state;
            EmitSignal(nameof(ConnectionStateChanged), state);
        }

        // --- Config ---
        private const string AppId = "YOUR_PHOTON_APP_ID";

        // --- Initialization ---
        public override void _Ready()
        {
            if (Instance != null && Instance != this)
            {
                QueueFree();
                return;
            }
            Instance = this;
            DontDestroyOnLoad(GetTree().Root);

            InitializeRunner();
        }

        private void InitializeRunner()
        {
            _runner = new NetworkRunner
            {
                AppId = AppId,
                UsePun = false,
                UseFusion = true,
                NetworkConfig = new NetworkConfig
                {
                    // Network topology: 1 host, up to 7 clients
                    NetworkTopology = NetworkTopologyType.Fixed,
                    DefaultScene = "res://scenes/Island.tscn",
                    // Enable Fusion Diagnostics for debugging
                    EnableDiagnostics = true,
                },
            };
            _runner.AddCallbacks(this);
            _runner.AddPlayer(new PlayerInfo
            {
                UserId = GetLocalUserId(),
                AuthCookie = GetAuthCookie(),
            });
        }

        // ═══════════════════════════════════════════════════════════════════════
        //  INetworkRunnerCallbacks — Connection Lifecycle
        // ═══════════════════════════════════════════════════════════════════════

        public void OnConnectedToCloud()
        {
            _SetState(ConnectionState.Connected);
            GD.Print("[NetworkManager] Connected to Photon Cloud.");
        }

        public void OnConnectedToMaster()
        {
            _SetState(ConnectionState.Connected);
        }

        public void OnCreatedRoom()
        {
            _SetState(ConnectionState.InRoom);
            GD.Print($"[NetworkManager] Room created: {_runner.LocalPlayer.SessionId}");
            EmitSignal(nameof(ConnectionStateChanged), ConnectionState.InRoom);
        }

        public void OnJoinedRoom()
        {
            _SetState(ConnectionState.InRoom);
            GD.Print($"[NetworkManager] Joined room: {_runner.LocalPlayer.SessionId}");
        }

        public void OnJoinRequestFailed(ConnectionRequestFailedReason reason)
        {
            GD.PrintError($"[NetworkManager] Join failed: {reason}");
            LobbyManager.Instance?.HandleJoinFailure(reason);
        }

        public void OnLeftRoom()
        {
            _SetState(ConnectionState.Connected);
            GD.Print("[NetworkManager] Left room.");
        }

        public void OnPlayerLeft(NetworkPlayerRef player)
        {
            GD.Print($"[NetworkManager] Player left: {player.ActorNumber}");
            EmitSignal(nameof(PlayerLeft), player);
        }

        public void OnMasterClientChanged(bool wasMaster, NetworkPlayerRef newMaster)
        {
            GD.Print($"[NetworkManager] Master changed: {wasMaster} → {newMaster.ActorNumber}");
            EmitSignal(nameof(MasterClientChanged), wasMaster, newMaster);
        }

        // ═══════════════════════════════════════════════════════════════════════
        //  Public API — Connection
        // ═══════════════════════════════════════════════════════════════════════

        public void ConnectToCloud()
        {
            if (_runner.State != NetworkRunnerState.Suspended) return;
            _runner.StartCloudNavigation();
            _SetState(ConnectionState.Connecting);
        }

        public void Disconnect()
        {
            if (_runner.State != NetworkRunnerState.Connected &&
                _runner.State != NetworkRunnerState.InRoom) return;
            _runner.LeaveRoom();
            _SetState(ConnectionState.Disconnecting);
        }

        // ═══════════════════════════════════════════════════════════════════════
        //  Public API — Room Creation & Joining
        // ═══════════════════════════════════════════════════════════════════════

        public bool CreateRoom(RoomCreationConfig config)
        {
            if (!config.Validate()) return false;

            var roomName = config.RoomName;
            var options = new Photon.Realtime.RoomOptions
            {
                MaxPlayers = config.MaxPlayers,
                IsVisible = config.Privacy != (byte)RoomPrivacy.PrivateWithPassword,
                IsOpen = true,
            };

            var props = config.ToSessionProperties();
            _runner.CreateRoom(roomName, options, null, props);
            return true;
        }

        public bool JoinRoom(string roomName)
        {
            // For private rooms, verify password first
            if (LobbyManager.Instance.IsRoomPrivate(roomName))
            {
                var salt = LobbyManager.Instance.GetRoomAuthSalt(roomName);
                var expectedHash = LobbyManager.Instance.GetRoomAuthHash(roomName);
                var clientHash = PasswordHasher.ComputeSaltedHash(
                    LobbyManager.Instance.GetPendingPassword(), salt);
                if (clientHash != expectedHash)
                {
                    GD.PrintError("[NetworkManager] Password verification failed.");
                    return false;
                }
            }

            _runner.JoinRoom(roomName);
            return true;
        }

        // ═══════════════════════════════════════════════════════════════════════
        //  Scene Management
        // ═══════════════════════════════════════════════════════════════════════

        public void ChangeUIScene(string scenePath)
        {
            // Don't change scene while in a networked game scene
            if (_runner.IsInNetworkedScene) return;

            var scene = ResourceLoader.Load(scenePath);
            GetTree().ChangeSceneToPacked(scene);
        }

        public void LoadGameSceneSync(string scenePath, Action<bool> onComplete)
        {
            NetworkSceneManagerDefault.LoadScene(
                scenePath,
                NetworkSceneLoadMode.AllLoad,
                () => onComplete(true),
                () => onComplete(false));
        }

        // ═══════════════════════════════════════════════════════════════════════
        //  Helpers
        // ═══════════════════════════════════════════════════════════════════════

        private string GetLocalUserId()
        {
            // Get from save file or generate
            var config = ConfigFile.Load("user://auth.cfg");
            return config.GetValue("auth", "user_id", "").ToString();
        }

        private string GetAuthCookie()
        {
            var config = ConfigFile.Load("user://auth.cfg");
            return config.GetValue("auth", "cookie", "").ToString();
        }

        public override void _ExitTree()
        {
            if (Instance == this) Instance = null;
        }
    }
}
```

### 5.3 `RoomManager.cs` (`NetworkBehaviour`)

```csharp
using System;
using System.Collections.Generic;
using Godot;
using Photon.Fusion;
using Photon.Fusion.Diagnostics;

namespace Tabletop.Networking
{
    public partial class RoomManager : NetworkBehaviour
    {
        [Signal]
        public delegate void SeatChangedEventHandler(int seatIndex, SeatData seat);

        [Signal]
        public delegate void PlayerReadyChangedEventHandler(int playerActor, bool isReady);

        [Signal]
        public delegate void HostChangedEventHandler(NetworkPlayerRef newHost);

        // ═══════════════════════════════════════════════════════════════════════
        //  Networked Properties (Shared with all clients)
        // ═══════════════════════════════════════════════════════════════════════

        [Networked] public NetworkDictionary<PlayerRef, SeatData> Seats { get; set; }
        [Networked] public List<PlayerRef> Spectators { get; set; }
        [Networked] public NetworkByte HandshakeState { get; set; }
        [Networked] public NetworkUInt SessionSeed { get; set; }
        [Networked] public NetworkByte ReadyCount { get; set; }
        [Networked] public NetworkByte CurrentPlayers { get; set; }
        [Networked] public NetworkUInt CustomFlags { get; set; }

        // ═══════════════════════════════════════════════════════════════════════
        //  Local State (Not synced)
        // ═══════════════════════════════════════════════════════════════════════

        public static RoomManager Instance { get; private set; }
        private const int MaxSeats = 8;
        private float _handshakeTimer;
        private const float HandshakeTimeout = 10.0f;
        private const float LoadingTimeout = 30.0f;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(this);
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
                Seats.AddOrSet(i, new SeatData
                {
                    SeatIndex = i,
                    Role = PlayerRole.Spectator,
                    PlayerColor = (NetworkColor)(i % 8),
                    IsReady = false,
                    PingMs = 0,
                });
            }
            CurrentPlayers = 1; // Host counts as 1
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
            if (!Seats.TryGetValue(seatIndex, out var seat)) return;
            if (seat.PlayerActor != -1)
            {
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
            if (!Seats.TryGetValue(seatIndex, out var seat)) return;
            if (seat.PlayerActor != -1) return;

            var player = LocalPlayer;
            Seats[seatIndex] = new SeatData
            {
                SeatIndex = seatIndex,
                Role = PlayerRole.Player,
                PlayerColor = (NetworkColor)(seatIndex % 8),
                IsReady = false,
                PingMs = 0,
            };
            CurrentPlayers++;
            RpcSeatUpdated(seatIndex);
        }

        // Notify the assigned player:
        [Rpc(RequireOwnership = false)]
        private void RpcAssignSeatToPlayer(int seatIndex, NetworkPlayerRef player)
        {
            SeatController.Instance?.OnSeatAssigned(seatIndex, player);
        }

        // Notify everyone else of a seat update:
        [Rpc]
        private void RpcSeatUpdated(int seatIndex)
        {
            if (Seats.TryGetValue(seatIndex, out var seat))
                EmitSignal(nameof(SeatChanged), seatIndex, seat);
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
            if (!Seats.TryGetValue(seatIndex, out var seat)) return;
            var actor = seat.PlayerActor;
            if (actor == -1) return;
            NetworkRunner.CloseConnection(actor);
            Seats[seatIndex] = new SeatData
            {
                SeatIndex = seatIndex,
                Role = PlayerRole.Spectator,
                PlayerActor = -1,
            };
            CurrentPlayers--;
            RpcSeatUpdated(seatIndex);
        }

        [Rpc]
        public void StartGame()
        {
            if (!IsHost) return;
            if (HandshakeState != HandshakeState.Ready) return;

            HandshakeState = HandshakeState.LoadingBoard;
            // Update SessionProperties so lobby shows LoadingBoard state
            Photon.Realtime.PhotonNetwork.CurrentRoom.SetCustomRoomProperties(
                "state", (byte)RoomState.LoadingBoard);

            // Trigger scene load
            NetworkManager.Instance.LoadGameSceneSync(
                "res://scenes/Island.tscn",
                (success) => {
                    if (success)
                        HandshakeState = HandshakeState.Ready;
                    else
                        HandshakeState = HandshakeState.Failed;
                });
        }

        // ═══════════════════════════════════════════════════════════════════════
        //  Ready System
        // ═══════════════════════════════════════════════════════════════════════

        [Rpc]
        public void SetReady(bool ready)
        {
            if (!IsHost) return;

            var player = LocalPlayer;
            var seatIndex = FindSeatForPlayer(player);
            if (seatIndex < 0) return;

            Seats[seatIndex].IsReady = ready;
            ReadyCount = (byte)CountReadyPlayers();

            EmitSignal(nameof(PlayerReadyChanged), (int)player.ActorNumber, ready);

            // Auto-start if flag is set and all required players are ready
            if ((CustomFlags & (uint)RoomCustomFlags.AutoStart) != 0)
            {
                if (ReadyCount >= RequiredPlayers())
                    StartGame();
            }
        }

        // ═══════════════════════════════════════════════════════════════════════
        //  Handshake State Machine
        // ═══════════════════════════════════════════════════════════════════════

        public override void OnNetworkUpdate()
        {
            if (!IsHost) return;

            switch (HandshakeState)
            {
                case HandshakeState.Negotiating:
                    _handshakeTimer += (float)Engine.GetProcessedFrameTime();
                    if (_handshakeTimer > HandshakeTimeout)
                    {
                        HandshakeState = HandshakeState.Failed;
                        UIController.Instance?.ShowErrorDialog(
                            "Loading Timeout", "A player failed to load the board. Please try again.");
                    }
                    break;

                case HandshakeState.Ready:
                    StartGame();
                    break;
            }
        }

        // ═══════════════════════════════════════════════════════════════════════
        //  Player Lifecycle
        // ═══════════════════════════════════════════════════════════════════════

        public override void OnPlayerLeft(NetworkPlayerRef player)
        {
            // Free the seat
            for (int i = 0; i < MaxSeats; i++)
            {
                if (Seats.TryGetValue(i, out var seat) &&
                    seat.PlayerActor == (int)player.ActorNumber)
                {
                    Seats[i] = new SeatData
                    {
                        SeatIndex = i,
                        Role = PlayerRole.Spectator,
                        PlayerActor = -1,
                        IsReady = false,
                    };
                    CurrentPlayers--;
                    RpcSeatUpdated(i);
                    break;
                }
            }

            // Remove from spectators
            Spectators.Remove(player);

            // Update session properties
            Photon.Realtime.PhotonNetwork.CurrentRoom.SetCustomRoomProperties(
                "open_slots", (byte)(MaxSeats - CurrentPlayers));
        }

        public override void OnMasterClientChanged(bool wasMaster, NetworkPlayerRef newMaster)
        {
            if (!wasMaster && IsMasterClient)
            {
                UpdateHostMetadata();
                EmitSignal(nameof(HostChanged), newMaster);
                UIController.Instance?.ShowHostTransferNotification();
            }
        }

        // ═══════════════════════════════════════════════════════════════════════
        //  Helpers
        // ═══════════════════════════════════════════════════════════════════════

        private void UpdateHostMetadata()
        {
            Photon.Realtime.PhotonNetwork.CurrentRoom.SetCustomRoomProperties(
                "host_id", (long)LocalPlayer.ActorNumber);
        }

        private int FindSeatForPlayer(NetworkPlayerRef player)
        {
            for (int i = 0; i < MaxSeats; i++)
            {
                if (Seats.TryGetValue(i, out var seat) &&
                    seat.PlayerActor == (int)player.ActorNumber)
                    return i;
            }
            return -1;
        }

        private int CountReadyPlayers()
        {
            int count = 0;
            for (int i = 0; i < MaxSeats; i++)
            {
                if (Seats.TryGetValue(i, out var seat) &&
                    seat.Role == PlayerRole.Player && seat.IsReady)
                    count++;
            }
            return count;
        }

        private int RequiredPlayers()
        {
            var max = (int)Photon.Realtime.PhotonNetwork.CurrentRoom.MaxPlayers;
            return Mathf.Max(2, max);
        }
    }
}
```

### 5.4 `SeatController.cs` (`Node3D`)

```csharp
using System;
using Godot;
using Photon.Fusion;

namespace Tabletop.Networking
{
    public partial class SeatController : Node3D
    {
        [Export] public int SeatIndex;
        [Export] public Area3D[] HandZones;
        [Export] public Node3D SeatPosition;
        [Export] public PlayerAvatar AvatarScene;

        private NetworkPlayerRef _assignedPlayer;
        private bool _isActive;
        private PlayerAvatar _avatar;

        public static SeatController Instance { get; private set; }

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(this);
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

        public void OnSeatAssigned(int index, NetworkPlayerRef player)
        {
            SeatIndex = index;
            _assignedPlayer = player;
            _isActive = true;

            // Spawn avatar at seat position
            if (AvatarScene != null && SeatPosition != null)
            {
                _avatar = AvatarScene.Instantiate() as PlayerAvatar;
                _avatar.GlobalPosition = SeatPosition.GlobalPosition;
                _avatar.GlobalRotation = SeatPosition.GlobalRotation;
                AddChild(_avatar);
                _avatar.Initialize(player, SeatIndex);
            }

            // Enable input for hand zones
            foreach (var zone in HandZones)
            {
                zone.Monitoring = true;
                zone.Monitorable = true;
                var filter = zone.GetComponent<InputFilter>();
                if (filter != null)
                    filter.PlayerRef = player;
            }
        }

        public void OnSeatRemoved()
        {
            _isActive = false;
            foreach (var zone in HandZones)
            {
                zone.Monitoring = false;
                zone.Monitorable = false;
            }
            if (_avatar != null)
            {
                _avatar.QueueFree();
                _avatar = null;
            }
            _assignedPlayer = default;
        }

        // ═══════════════════════════════════════════════════════════════════════
        //  Physics Interaction Filtering
        // ═══════════════════════════════════════════════════════════════════════

        private void OnTriggerEnter(Area3D other)
        {
            if (!_isActive) return;

            // Only the assigned player can pick up objects in their zones
            if (NetworkManager.Instance?.LocalPlayer != _assignedPlayer) return;

            var pickup = other.GetComponent<NetworkPickup>();
            if (pickup != null && pickup.CanBePickedUpBy(_assignedPlayer))
            {
                pickup.PickUp(_assignedPlayer);
            }
        }
    }
}
```

### 5.5 Supporting Enums & Structs

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

// ─── SeatData ───────────────────────────────────────────────────────────

public partial class SeatData : INetworkStruct
{
    public int PlayerActor = -1;      // -1 = empty
    public int SeatIndex;
    public NetworkColor PlayerColor;
    public NetworkBool IsReady;
    public PlayerRole Role;
    public float PingMs;
}

// ─── RoomInfo (Lightweight wrapper) ─────────────────────────────────────

public partial class RoomInfo : RefCounted
{
    public string Name = "";
    public byte MaxPlayers;
    public byte CurrentPlayers;
    public byte OpenSlots;
    public byte State;
    public byte Privacy;
    public string ModId = "";
    public int ModVersion;
    public string ModName = "";
    public float PingMs;

    public void Populate(Photon.Realtime.RoomInfo photonRoom)
    {
        Name = photonRoom.Name;
        MaxPlayers = photonRoom.MaxPlayers;
        CurrentPlayers = photonRoom.PlayerCount;
        OpenSlots = (byte)(MaxPlayers - CurrentPlayers);
        State = (byte)photonRoom.CustomRoomProperties["state"];
        Privacy = (byte)photonRoom.CustomRoomProperties["privacy"];
        ModId = (string)photonRoom.CustomRoomProperties["mod_id"];
        ModVersion = (int)photonRoom.CustomRoomProperties["mod_version"];
        ModName = ModManager.Instance?.GetModName(ModId) ?? ModId;
        PingMs = NetworkManager.Instance?.Runner.CurrentRtt ?? 0;
    }
}
```

---

<a id="module-6"></a>
## MODULE 6: RESILIENCE, EDGE CASES & PERFORMANCE OPTIMIZATION

### 6.1 Host Migration

Photon Fusion provides **Host Migration** out of the box. When the host disconnects:

1. Fusion automatically promotes the next-oldest actor to Master Client (`NetworkRunner.MasterClient` changes).
2. The new host receives `OnMasterClientChanged(bool wasMaster, NetworkPlayerRef newMaster)` callback.
3. **Critical:** The new host must:
   - Update `SessionProperties["host_id"]` with their own actor number.
   - Display a "New Host Selected" notification to all clients.
   - Verify they can continue the game:
     - If `handshakeState == LoadingBoard`, restart the loading sequence.
     - If `handshakeState == InProgress`, resume game as host.

```csharp
public override void OnMasterClientChanged(bool wasMaster, NetworkPlayerRef newMaster)
{
    if (!wasMaster && IsMasterClient)
    {
        // We are the new host
        UpdateHostMetadata();
        EmitSignal(nameof(HostChanged), newMaster);

        if (HandshakeState == HandshakeState.LoadingBoard)
            RestartLoadingSequence();
        else if (HandshakeState == HandshakeState.Ready)
            ResumeGameAsHost();
    }
}
```

### 6.2 Player Disconnection in PreGameRoom

| Step | Action |
|------|--------|
| 1 | `OnPlayerLeft(NetworkPlayerRef)` fires |
| 2 | Free the seat: `Seats[seatIndex].PlayerActor = -1` |
| 3 | If the player was the Host, trigger Host Migration (§6.1) |
| 4 | Update `SessionProperties["open_slots"]` |
| 5 | Send `RpcSeatUpdated(seatIndex)` to all remaining clients |
| 6 | Update UI: remove player from list, show "Seat Available" |
| 7 | If `AutoStart` flag is set and now all required slots are empty, notify host |

### 6.3 Version / Mod Incompatibility

```csharp
public void OnJoinRequestFailed(ConnectionRequestFailedReason reason)
{
    var (title, message) = GetReasonMessage(reason);
    UIController.Instance?.ShowErrorDialog(title, message);
}

private static (string title, string message) GetReasonMessage(ConnectionRequestFailedReason reason)
{
    return reason switch
    {
        ConnectionRequestFailedReason.VersionMismatch =>
            ("Version Mismatch", "The room requires a different game version. Please update."),
        ConnectionRequestFailedReason.AuthFailed =>
            ("Authentication Failed", "The room password is incorrect or the room requires authentication."),
        ConnectionRequestFailedReason.RoomFull =>
            ("Room Full", "This room has no available slots."),
        ConnectionRequestFailedReason.LobbyNotFound =>
            ("Room Not Found", "The room no longer exists."),
        _ => ("Connection Failed", $"Could not join room. Reason: {reason}")
    };
}
```

**Mod version check:** Before joining, the client fetches the mod's `mod_version` from `SessionProperties` and compares with its locally installed version. If mismatched, show:
> "Mod version mismatch: Room requires v1.2.4, you have v1.1.0. Please update from the Workshop."

### 6.4 Connection Timeout & Packet Loss During Handshake

- **Handshake phase** (`handshakeState = Negotiating`): Implement a 10-second timer.
  - If not all clients report `Ready` within 10s, host sends `CancelLoading` and returns to `PreGameRoom`.
  - If a single client times out, they are kicked and can rejoin.
- **Loading timeout:** If a client hasn't loaded the board scene within 30s, the host shows a "Loading Failed" dialog and either waits or kicks the stuck client.
- **Ping monitoring:** During `PreGameRoom`, continuously monitor `NetworkRunner.CurrentRtt`. If a player's RTT exceeds 500ms for >10s, show a "High Latency" warning.

### 6.5 GC Optimization

**Problem:** Creating `RoomInfo` objects for every lobby update causes GC pressure, especially with 50+ rooms and frequent refreshes.

**Solution: Object Pooling for RoomInfo**

```csharp
public partial class RoomInfoPool : RefCounted
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

private void OnSessionListUpdated(List<RoomInfo> rooms)
{
    // Clear old entries (release to pool)
    foreach (var old in _roomList)
        _roomPool.Release(old);
    _roomList.Clear();

    // Acquire new entries
    for (int i = 0; i < rooms.Count && i < maxLobbyRooms; i++)
    {
        var room = _roomPool.Acquire();
        room.Populate(rooms[i]);
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
- **Signal batching:** If multiple seat updates arrive in the same frame, batch them into a single signal emission to avoid multiple UI updates.

### 6.6 Photon Cloud Throttling

Photon Cloud rate-limits certain operations. Exceeding limits results in temporary bans or dropped requests.

| Operation | Default Limit | Strategy |
|-----------|:---:|----------|
| `JoinLobby` | 30s / 10 requests | Throttle to 1 request per 2 seconds. Use `OnSessionListUpdated` for incremental updates instead of polling. |
| `SetCustomRoomProperties` | 60s / 10 requests | Only update when state actually changes. Batch multiple property updates into a single call. |
| `CreateRoom` | 60s / 20 requests | Disable "Create" button for 3s after creation. |
| `JoinRoom` | 60s / 30 requests | Disable "Join" button on click until `OnJoinedRoom` or `OnJoinRequestFailed` fires. |

```csharp
// In LobbyManager.cs:
private const float MinCreateRoomInterval = 3.0f;
private const float MinJoinRoomInterval = 1.0f;
private const float MinListInterval = 2.0f;

private float _lastCreateTime, _lastJoinTime, _lastListTime;

public bool TryCreateRoom(RoomCreationConfig config)
{
    if ((float)Engine.GetProcessedFrameTime() - _lastCreateTime < MinCreateRoomInterval) return false;
    _lastCreateTime = (float)Engine.GetProcessedFrameTime();
    // ... proceed
}

public bool TryJoinRoom(string roomName)
{
    if ((float)Engine.GetProcessedFrameTime() - _lastJoinTime < MinJoinRoomInterval) return false;
    _lastJoinTime = (float)Engine.GetProcessedFrameTime();
    // ... proceed
}
```

### 6.7 Network Profiling & Debugging

#### Profiling Checklist

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Input rate | < 30 packets/s per player | Fusion Debugger → Input tab |
| Property sync rate | < 10 updates/s for room state | Fusion Debugger → Properties tab |
| RPC count | < 5/s during normal gameplay | Fusion Debugger → RPCs tab |
| Bandwidth per player | < 50 KB/s during lobby | Network Profiler window |
| Scene load time | < 15s for average mod | Time.GetSystemTimeMs() around `LoadScene` |
| Host migration time | < 3s | Measure from `OnMasterClientChanged` to new host's `OnNetworkSpawn` |

#### Debug Logging

```csharp
#if DEBUG_NETWORK
    private const bool LogNetworkEvents = true;
#else
    private const bool LogNetworkEvents = false;
#endif

private void LogNetworkEvent(string message)
{
#if DEBUG_NETWORK
    GD.Print($"[Network] {message}");
#endif
}

// Usage:
LogNetworkEvent($"Room created: {roomName}, players: {MaxPlayers}, mod: {ModId}");
LogNetworkEvent($"Player joined: {player.ActorNumber}, seat: {seatIndex}");
LogNetworkEvent($"Handshake state: {handshakeState}, timer: {_handshakeTimer:F1}s");
```

#### Common Pitfalls

1. **Don't sync `SessionProperties` from client.** Only the host should update `PhotonNetwork.CurrentRoom.SetCustomRoomProperties`. Clients should treat these as read-only.
2. **Don't use `NetworkDictionary<PlayerRef, SeatData>` for frequent updates.** Each property change generates a network sync. If seats change rarely (during setup), this is fine. For in-game state, use RPCs.
3. **Don't call `JoinLobby` from `OnSessionListUpdated`.** This creates an infinite loop. Use a separate refresh timer.
4. **Don't store passwords in `NetworkedProperties`.** Use `SessionProperties` with salted hash only, and verify post-join.
5. **Always check `IsHost` before host-only RPCs.** Use `[Rpc]` with `RequireOwnership = true` for host commands.
6. **Don't create Godot nodes in network callbacks.** Network callbacks run on the main thread, but creating nodes during `OnSessionListUpdated` can cause frame drops. Use `Call Queued` or `Queue Call` for UI updates.

### 6.8 Connection Quality Monitoring

During `PreGameRoom`, continuously monitor connection quality:

```csharp
public override void OnNetworkUpdate()
{
    if (!IsHost) return;

    // Monitor connection quality
    foreach (var player in NetworkRunner.Players)
    {
        var rtt = NetworkRunner.GetRtt(player);
        if (rtt > 500)
        {
            UIController.Instance?.ShowLatencyWarning(player, rtt);
        }
        else if (rtt > 200)
        {
            UIController.Instance?.ShowLatencyIndicator(player, rtt);
        }
    }

    // Monitor handshake timer
    if (HandshakeState == HandshakeState.Negotiating)
    {
        _handshakeTimer += (float)Engine.GetProcessedFrameTime();
        if (_handshakeTimer > HandshakeTimeout)
        {
            HandshakeState = HandshakeState.Failed;
            UIController.Instance?.ShowErrorDialog(
                "Loading Timeout", "A player failed to load the board. Please try again.");
        }
    }
}
```

---

## Appendix: Module Dependency Graph

```
NetworkManager (Autoload, persistent)
  ├── NetworkRunner (Photon Fusion)
  ├── LobbyManager (Autoload)
  │     ├── SessionCache (ObservableCollection<RoomInfo>)
  │     ├── FilterPipeline (ILobbyFilter[])
  │     └── SignalBus
  └── UIController (Autoload)
        ├── CurrentUIState (UIState enum)
        └── TransitionQueue

RoomManager (NetworkBehaviour, in-room)
  ├── SeatController (per-seat Node3D)
  ├── NetworkSceneManagerDefault
  └── ModManager (content loading)

SeatController (Node3D)
  ├── InputFilter (on Area3D zones)
  └── PlayerAvatar (spawned per seat)
```

**Dependency rules:**
- `NetworkManager` depends on `NetworkRunner` and emits signals. It does **not** depend on `LobbyManager` or `RoomManager`.
- `LobbyManager` depends on `NetworkManager` (for runner access) and emits signals.
- `RoomManager` depends on `NetworkRunner`, `SeatController`, and `ModManager`.
- `SeatController` depends on `NetworkManager` and `InputFilter`.
- No circular dependencies — all communication via signals.

---

*End of Specification — v2.0.0*
