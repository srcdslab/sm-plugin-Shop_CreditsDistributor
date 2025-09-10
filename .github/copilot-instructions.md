# Copilot Instructions for Shop_CreditsDistributor Plugin

## Repository Overview

This is a SourcePawn plugin for SourceMod that integrates with the Shop system to distribute credits to players based on gameplay events. The plugin rewards players with credits for playing time, winning rounds, killing enemies, and applies penalties for deaths in Counter-Strike-based games.

**Current State**: The plugin is functional but has some logic errors that should be addressed (see Common Issues section).

**Key Files:**
- `addons/sourcemod/scripting/Shop_CreditsDistributor.sp` - Main plugin source code
- `addons/sourcemod/translations/shop_creditsdistributor.phrases.txt` - Translation strings
- `sourceknight.yaml` - Build configuration for SourceKnight build system
- `.github/workflows/ci.yml` - Automated CI/CD pipeline

**Plugin Features:**
- **Time-based Credits**: Give credits to players at configurable intervals
- **Round Win Bonuses**: Different credit amounts for solo wins vs team wins
- **Kill/Death System**: Award credits for kills, penalize for deaths
- **Team Integration**: Only active for players on CT/T teams
- **Configurable**: All amounts and intervals configurable via ConVars

## Technical Environment

### Language & Platform
- **Language**: SourcePawn (SourceMod scripting language)
- **Platform**: SourceMod 1.11+ for Source engine games
- **Build Tool**: SourceKnight 0.2 (Python-based SourceMod build system)
- **Target Games**: Counter-Strike games (uses cstrike extension)

### Dependencies
- **SourceMod**: Core scripting platform (1.11.0-git6934+)
- **MultiColors**: Color formatting library for chat messages
- **Shop-Core**: Main shop system that this plugin extends
- **CStrike Extension**: For Counter-Strike specific functionality

## Build & Development Workflow

### Build System (SourceKnight)
The repository uses SourceKnight, a Python-based build system for SourceMod plugins:

```bash
# Install SourceKnight (if not in CI environment)
pip install sourceknight

# Build the plugin
sourceknight build

# Built plugins will be in .sourceknight/package/
```

**Note**: In CI/CD environments, SourceKnight is installed and run automatically via GitHub Actions.

### Local Development Setup
1. Clone repository
2. Install SourceKnight: `pip install sourceknight`
3. Run `sourceknight build` to compile
4. Built plugin (.smx) will be in `.sourceknight/package/`
5. Copy to local SourceMod server for testing

### CI/CD Pipeline
- **Triggers**: Push to main/master branches, tags, and pull requests
- **Process**: 
  1. Build plugin using SourceKnight
  2. Package with translations
  3. Create GitHub releases for tags
  4. Upload artifacts for testing

### Local Development
1. Clone repository
2. Ensure SourceKnight is installed
3. Run `sourceknight build` to compile
4. Test on local SourceMod server

## Code Style & Standards

### SourcePawn Conventions
```sourcepawn
#pragma semicolon 1
#pragma newdecls required

// Variable naming
Handle g_ConvarExample;        // Global handles with g_ prefix
int g_iPlayerCredits[MAXPLAYERS+1];  // Global arrays with g_ prefix
char sPlayerName[256];         // Local strings with s prefix
int iLocalVariable;            // Local ints with i prefix
float fInterval;               // Local floats with f prefix
bool bEnabled;                 // Local bools with b prefix

// Function naming
public void OnPluginStart()    // SourceMod callbacks in PascalCase
void CreateTimerForPlayer()    // Custom functions in PascalCase
```

### Memory Management
```sourcepawn
// Proper timer cleanup
if (h_timer[client] != INVALID_HANDLE)
{
    KillTimer(h_timer[client]);
    h_timer[client] = INVALID_HANDLE;
}

// Handle cleanup (legacy style in this codebase)
if (g_Handle != INVALID_HANDLE)
{
    CloseHandle(g_Handle);
    g_Handle = INVALID_HANDLE;
}
```

### Error Handling
- Always validate client indices with `IsValidClient()` checks
- Check handle validity before using timers/handles
- Use proper return values for functions
- Handle edge cases in game events

## Plugin Architecture

### Core Components
1. **Timer System**: Distributes credits at intervals to active players
2. **Event Handlers**: React to round end, player death, team changes
3. **ConVar System**: Configurable credit amounts and intervals
4. **Integration**: Hooks into Shop-Core for credit management

### Event Flow
```
Player joins team → Create timer → Give credits periodically
Round ends → Calculate winners → Distribute bonus credits  
Player dies → Attacker gets credits, victim loses credits
Player disconnects → Clean up timers
```

### Configuration
- Auto-generates config file: `cfg/shop/shop_creditsdistributor.cfg`
- All ConVars prefixed with `sm_shop_creditsdistributor_`
- Translation strings support multiple languages

## Integration Points

### Shop System Integration
```sourcepawn
// Give credits (returns actual amount given, -1 on failure)
int gain = Shop_GiveClientCredits(client, amount, CREDITS_BY_NATIVE);

// Take credits (returns actual amount taken, -1 on failure)
int taken = Shop_TakeClientCredits(client, amount, CREDITS_BY_NATIVE);
```

### MultiColors Integration
```sourcepawn
// Colored chat messages
CPrintToChat(client, "%t", "Translation_Key", param1, param2);
CPrintToChatAll("%t", "Translation_Key", param1);
```

## Common Issues & Solutions

### Timer Management
**Problem**: Memory leaks from improper timer cleanup
**Solution**: Always kill existing timers before creating new ones
```sourcepawn
public void OnClientDisconnect_Post(int client)
{
    if (h_timer[client] != INVALID_HANDLE)
    {
        KillTimer(h_timer[client]);
        h_timer[client] = INVALID_HANDLE;
    }
}
```

### Team Validation Logic Error (Current Codebase Issue)
**Problem**: Line 45 has faulty logic: `GetClientTeam(i) != CS_TEAM_T || GetClientTeam(i) != CS_TEAM_CT`
This condition will ALWAYS be true (a player cannot be both T and CT simultaneously).

**Current Broken Code:**
```sourcepawn
// This is WRONG - will always be true
if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != CS_TEAM_T || GetClientTeam(i) != CS_TEAM_CT)
    continue;
```

**Correct Solution:**
```sourcepawn
// Option 1: Check if NOT on valid teams (using AND)
if (!IsClientInGame(i) || IsFakeClient(i) || 
    (GetClientTeam(i) != CS_TEAM_T && GetClientTeam(i) != CS_TEAM_CT))
    continue;

// Option 2: Check if on valid teams (more readable)
if (!IsClientInGame(i) || IsFakeClient(i))
    continue;
    
int team = GetClientTeam(i);
if (team != CS_TEAM_T && team != CS_TEAM_CT)
    continue;
```

### Event Handling
**Problem**: Events firing for invalid clients
**Solution**: Always validate event data
```sourcepawn
public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!client || !IsClientInGame(client) || IsFakeClient(client))
        return;
    // Handle event
}
```

### ConVar Usage Optimization
**Problem**: Calling GetConVarInt/GetConVarFloat repeatedly in timers
**Solution**: Cache values or use ConVar callbacks
```sourcepawn
// Cache ConVar values
int g_iCreditsPerTick;
bool g_bCreditsForRoundWin;

public void OnConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_Cvar_CreditsPerTick)
        g_iCreditsPerTick = StringToInt(newValue);
}
```

## Testing Guidelines

### Manual Testing
1. Start local CS server with SourceMod
2. Install Shop-Core and dependencies
3. Load plugin and verify ConVars are created
4. Test credit distribution scenarios:
   - Join team and verify timer starts
   - Play for interval and check credit gain
   - Win rounds and verify bonus credits
   - Kill/death scenarios

### Validation Checklist
- [ ] Plugin compiles without warnings in SourceKnight
- [ ] ConVars are created and functional (`sm cvars shop_creditsdistributor`)
- [ ] Logic errors fixed (team validation, boolean operators)
- [ ] Timers start/stop correctly on team changes
- [ ] Credits are properly awarded/deducted via Shop system
- [ ] Translation strings display correctly with color codes
- [ ] No memory leaks (timers cleaned up on disconnect)
- [ ] Events handle edge cases and invalid clients
- [ ] Performance acceptable with high player counts

## Debugging & Troubleshooting

### Common Debug Commands
```sourcepawn
// Add debug prints
PrintToServer("Debug: Timer created for client %d", client);
LogMessage("Credits given: %d to client %d", amount, client);

// Check client validity
if (!IsValidClient(client))
{
    LogError("Invalid client %d in function", client);
    return;
}
```

### Log Analysis
- Check SourceMod error logs for crashes: `logs/errors_*.log`
- Monitor server console for plugin messages
- Use `sm plugins list` to verify plugin loading
- Use `sm cvars shop_creditsdistributor` to check ConVars
- Use `sm_shop_stats <player>` to verify credit transactions

### Development Issues & Solutions

**Issue**: "Plugin failed to compile"
- Check include file paths in sourceknight.yaml
- Verify SourceMod version compatibility
- Check for syntax errors (missing semicolons, brackets)

**Issue**: "Timer not starting for players"
- Verify team logic is correct (not the broken OR condition)
- Check if player is valid when timer is created
- Ensure interval ConVar is > 1.0

**Issue**: "Credits not being awarded"
- Verify Shop-Core plugin is loaded and functional
- Check if Shop_GiveClientCredits returns -1 (failure)
- Ensure player has shop account/credits enabled

**Issue**: "Memory leaks/server lag"
- Check timer cleanup in OnClientDisconnect_Post
- Verify all handles are properly closed
- Use `sm_profiler` to identify performance issues

## Performance Considerations

### Optimization Tips
- Cache ConVar values when used frequently
- Minimize operations in timer callbacks
- Use efficient loops for player iteration
- Avoid string operations in frequently called functions

### Resource Management
- Clean up timers on client disconnect
- Use appropriate timer intervals (avoid sub-second timers)
- Handle high player counts efficiently
- Monitor CPU usage with timer-heavy operations

## Release Process

1. **Version Updates**: Update version in plugin info struct
2. **Testing**: Validate on test server environment
3. **Commit**: Commit changes with descriptive messages
4. **Tag**: Create version tag for release (triggers CI/CD)
5. **Release**: GitHub Actions automatically creates release package

## Dependencies Management

The `sourceknight.yaml` file manages all dependencies:
- SourceMod core files
- MultiColors include files  
- Shop-Core include files

When adding new dependencies, update the yaml file with appropriate source and destination paths.