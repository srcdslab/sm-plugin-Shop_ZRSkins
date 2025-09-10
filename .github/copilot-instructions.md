# Shop_ZRSkins Plugin - Copilot Instructions

## Repository Overview
This repository contains a SourcePawn plugin for SourceMod that integrates zombie and human skins with the Shop Core system. The plugin allows players to purchase and use custom player skins for both zombie and human teams in Zombie Reloaded (ZR) mod for Counter-Strike: Source/GO servers.

**Primary Purpose**: Extend the Shop Core plugin with skin purchasing functionality for ZR servers
**Target Platform**: SourceMod 1.11+ on Source engine games (CS:S/CS:GO)
**Plugin Type**: Shop module/extension

## Technical Environment & Dependencies

### Core Dependencies
- **SourceMod**: 1.11.0+ (specified in sourceknight.yaml)
- **Shop Core**: Main shop system (from srcdslab/sm-plugin-Shop-Core)
- **Zombie Reloaded**: ZR mod plugin (from srcdslab/sm-plugin-zombiereloaded)
- **MultiColors**: Colored chat functionality (from srcdslab/sm-plugin-MultiColors)

### Build System
- **Primary Tool**: SourceKnight 0.2 (dependency management & building)
- **Configuration**: `sourceknight.yaml` defines dependencies and build targets
- **Output**: Compiled `.smx` files in `/addons/sourcemod/plugins/`
- **CI/CD**: GitHub Actions using `maxime1907/action-sourceknight@v1`

### Build Commands
```bash
# Using SourceKnight (preferred)
sourceknight build

# Manual compilation (if needed)
spcomp -i/path/to/includes Shop_ZRSkins.sp
```

## Project Structure

```
addons/sourcemod/
├── configs/
│   ├── skins_dlist.txt     # Download list for custom models
│   ├── skins_humans.txt    # Human skin definitions (KeyValues)
│   └── skins_zombies.txt   # Zombie skin definitions (KeyValues)
└── scripting/
    └── Shop_ZRSkins.sp     # Main plugin source code
```

### Key Files Explained
- **Shop_ZRSkins.sp**: Main plugin implementing Shop Core integration
- **skins_*.txt**: KeyValues configuration files defining available skins
- **skins_dlist.txt**: File paths for models to add to download table
- **sourceknight.yaml**: Dependency management and build configuration

## Code Architecture & Patterns

### Shop Integration Pattern
```sourcepawn
// Plugin registers categories with Shop Core
g_category_zombies = Shop_RegisterCategory("skins_zombies", "Zombies Skins", ...);
g_category_humans = Shop_RegisterCategory("skins_humans", "Humans Skins", ...);

// Items are populated from KeyValues config files
PopulateCategory(g_category_zombies, "configs/shop/skins_zombies.txt");
```

### Event-Driven Skin Application
```sourcepawn
// Hooks critical events for skin changes
HookEvent("player_spawn", Ev_PlayerSpawn);
public void ZR_OnClientInfected(int client, ...) {
    CreateTimer(0.5, Timer_ChangeSkin, UID(client));
}
```

### Memory Management Pattern
- Uses `delete` for cleanup without null checks (follows SourcePawn best practices)
- Timers for delayed skin application (0.5s delay for ZR compatibility)
- Entity cleanup with automatic fadeout for preview models

### Configuration Pattern
```sourcepawn
// KeyValues structure for skin definitions
"Skins" {
    "Skin Name" {
        "price"      "1000"
        "sell_price" "-1"
        "skin"       "models/path/to/model.mdl"
        "anim"       "animation_name"
        "duration"   "86400"
    }
}
```

## Development Guidelines Specific to This Plugin

### Code Style (Beyond Standard SourcePawn)
- Use MPS (MAXPLAYERS+1) and PMP (PLATFORM_MAX_PATH) defines
- Utility macros: `CID()`, `UID()`, `SZF()`, `LC()` for common operations
- Prefix global arrays with `g_` (e.g., `g_skin_zombie[MPS][PMP]`)
- Boolean tracking variables for state (e.g., `g_in_preview[MPS]`)

### Shop Core Integration Points
1. **Category Registration**: Use meaningful category names and descriptions
2. **Item Callbacks**: Implement `OnSkinSelected` for purchase handling
3. **Preview System**: Use `OnPreviewSkin` for temporary model display
4. **Custom Info Strings**: Store model paths and animation names with items

### ZR Integration Requirements
- Always check `ZR_IsClientZombie()` before applying skins
- Use timers for skin application (ZR needs processing time)
- Handle both infection and spawn events
- Respect ConVar controls for enabling/disabling features

### Performance Considerations
- Precache all models on `OnMapStart()`
- Use preview entity cleanup with automatic timers
- Minimal string operations in frequently called functions
- Cache skin paths in client arrays for quick access

## Configuration Management

### Adding New Skins
1. Add model path to appropriate config file (`skins_zombies.txt` or `skins_humans.txt`)
2. Add model files to `skins_dlist.txt` for client downloads
3. Ensure model files are present on server
4. Test with `/shop` command in-game

### ConVar Configuration
- `zr_shop_skins_zombie "1"`: Enable/disable zombie skins
- `zr_shop_skins_human "1"`: Enable/disable human skins
- Auto-generates config: `cfg/sourcemod/shop/zr_shop_skins.cfg`

## Testing & Validation

### Manual Testing Checklist
1. **Build Test**: Ensure plugin compiles without errors
2. **Shop Integration**: Verify categories appear in shop menu
3. **Skin Application**: Test skin changes on spawn/infection
4. **Preview System**: Test preview functionality (5-second duration)
5. **ConVar Controls**: Test enabling/disabling categories
6. **ZR Compatibility**: Test with zombie infections and spawns

### Common Issues & Debugging
- **Model Missing**: Check `skins_dlist.txt` and server file presence
- **Shop Not Loading**: Verify Shop Core dependency and load order
- **Skins Not Applying**: Check ZR events and timer delays
- **Preview Issues**: Verify model precaching and entity cleanup

## Build & CI/CD Process

### Local Development
```bash
# Install dependencies (handled by SourceKnight)
sourceknight install

# Build plugin
sourceknight build

# Output location
ls .sourceknight/package/addons/sourcemod/plugins/
```

### GitHub Actions Workflow
- **Trigger**: Push, PR, or manual dispatch
- **Build**: Uses SourceKnight action for compilation
- **Artifact**: Creates downloadable package
- **Release**: Auto-creates releases for tags and main branch

### Dependency Updates
- Dependencies defined in `sourceknight.yaml`
- SourceMod, MultiColors, Shop Core, and ZR automatically pulled
- Version pinning available for stability

## Common Modification Patterns

### Adding New Features
1. **New Skin Property**: Add to KeyValues structure and parsing logic
2. **Additional Categories**: Register new category in `Shop_Started()`
3. **Custom Callbacks**: Implement Shop Core callback functions
4. **ZR Event Handling**: Hook additional ZR events if needed

### Performance Optimization
- Cache frequently accessed data in global arrays
- Minimize database/file operations in hot paths
- Use efficient string operations and avoid unnecessary allocations
- Consider timer consolidation for multiple simultaneous operations

### Error Handling
- Always validate KeyValues file existence and structure
- Handle missing models gracefully (fallback to default)
- Log errors with descriptive messages using `LogError()`
- Validate client indices and game state before operations

## Plugin Integration Notes

### Shop Core API Usage
- Register categories with meaningful identifiers
- Use custom info strings for model data storage
- Implement proper callback functions for user interactions
- Handle item toggling and duration-based purchases

### Zombie Reloaded Integration
- Hook `ZR_OnClientInfected` for infection events
- Use `ZR_IsClientZombie()` for team detection
- Respect ZR's processing delays with timers
- Handle both mother zombie and regular infections

This plugin serves as a good example of multi-plugin integration in the SourceMod ecosystem, demonstrating proper event handling, configuration management, and user interface integration.