# iOS RuneLite Distributed Bridge (`ios_runelite_bridge`)

## 1. System Overview & Problem Statement
Apple iOS does not permit custom JIT or JVM bytecode runtimes inside standard sandbox apps, preventing native desktop Java applications like **RuneLite** from running directly on an iPhone or iPad. Furthermore, downloading or running modified client binaries on mobile devices creates severe account ban hazards and credential theft risks.

The **iOS RuneLite Distributed Bridge** solves this completely by establishing a **Zero-Frontend-Credential Distributed Architecture**:
1. **Headless Backend (Host / Container / Local Box)**: Runs the official RuneLite client in headless mode (`java.awt.headless=true`). All native RuneLite plugins (77+ reverse-engineered plugins including Agility markers, Ground Items, Prayer timers, Tile Indicators) execute natively on the JVM with full access to the RuneLite event bus (`@Subscribe`).
2. **Streaming & Input Bridge**: The daemon extracts vector overlay coordinates and interactive frames, scrubbing all sensitive data through the fail-closed `MobileSecurityGate`.
3. **iOS Frontend (Web Clip / Standalone PWA)**: A zero-install, single-file HTML5 Web Clip that can be opened in mobile Safari and added to the iOS Home Screen (`"Add to Home Screen"`). It provides hardware-accelerated Canvas rendering, mobile touch gestures (touch-to-click, long-press right click, virtual F-keys), and plugin management without any risk of credential exposure.

---

## 2. Zero-Credential Security Boundary
Per Ethan's strict requirement:
> *"like frontend/backend is distributed so no user data lands on frontend if thats safe"*

- **No Passwords on Frontend**: All Jagex authentication is executed server-side.
- **No Session Secrets on Frontend**: The iOS client receives only visual primitives (bounding boxes, colors, overlay text labels) and sends back coordinate touch actions (`x, y, action`).
- **Fail-Closed Sanitization**: Every wire packet passes through `MobileSecurityGate`, which strips any credential-like keys or high-entropy tokens.

---

## 3. Architecture Topology

```mermaid
flowchart TD
    subgraph Host["Headless Host / Linux Server"]
        RL["Headless RuneLite Daemon<br/>(Java / JVM)"]
        Plugins["RuneLite Plugins<br/>(Agility, Prayer, GroundItems)"]
        Bus["EventBus (@Subscribe)"]
        Gate["MobileSecurityGate<br/>(Zero-Credential Filter)"]

        RL --> Bus
        Bus --> Plugins
        Plugins --> Gate
    end

    subgraph iOS["iOS Mobile Device (iPhone / iPad)"]
        WebClip["iOS Web Clip / PWA<br/>(ios_runelite_webclip.html)"]
        TouchLayer["Touch & Virtual F-Key Layer"]
        CanvasLayer["Canvas2D / WebGL Overlay Renderer"]

        WebClip --> TouchLayer
        WebClip --> CanvasLayer
    end

    Gate -->|Encrypted Overlays / WebRTC / WS| CanvasLayer
    TouchLayer -->|Touch Coordinates (x, y)| RL
```

---

## 4. Reverse-Engineered Plugin Mapping
Extracted directly via `scripts/source_re_engine.py`:
- **Total Ingested Files**: 1,892 Java source files
- **Identified Plugins**: 77 plugins
- **Event Bus Hooks**: 727 `@Subscribe` methods
- **Key Event Triggers**: `GameStateChanged`, `GameTick`, `ChatMessage`, `VarbitChanged`, `ItemContainerChanged`, `NpcSpawned`, `MenuOptionClicked`
