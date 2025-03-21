import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/app_themes.dart';
import '../screens/settings_screen.dart';
import '../models/player.dart';
import 'dart:async';
import '../widgets/period_end_dialog.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  String _sessionName = "Loading..."; // Default session name
  int _matchTime = 0;
  bool _isPaused = false;
  Timer? _matchTimer;
  bool _isTableExpanded = true;
  final FocusNode _addPlayerFocusNode = FocusNode();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Register as an observer to handle app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize with defaults first
    _sessionName = "Loading...";
    _isPaused = false;
    _matchTime = 0;
    
    // Use Future.microtask instead of post-frame callback for safer initialization
    Future.microtask(() {
      if (mounted) {
        _loadInitialState();
      }
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - refresh state
      if (mounted && _isInitialized) {
        _safeSetState(() {});
      }
    } else if (state == AppLifecycleState.paused) {
      // App went to background - save state
      if (mounted && _isInitialized) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.saveSession();
      }
    }
  }
  
  void _loadInitialState() {
    if (!mounted) return;
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      
      _safeSetState(() {
        _matchTime = appState.session.matchTime * 2;
        _isPaused = appState.session.isPaused;
        
        // Use session name from the session object or currentSessionPassword
        _sessionName = appState.session.sessionName.isNotEmpty 
            ? appState.session.sessionName 
            : (appState.currentSessionPassword ?? "New Session");
            
        _isInitialized = true;
      });
      
      // Start timer only after state is updated
      Future.microtask(() {
        if (mounted) {
          _startMatchTimer();
        }
      });
    } catch (e) {
      print('Error loading initial state: $e');
    }
  }

  @override
  void dispose() {
    // Unregister observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel timer before disposing
    if (_matchTimer != null) {
      _matchTimer!.cancel();
      _matchTimer = null;
    }
    _addPlayerFocusNode.dispose();
    super.dispose();
  }

  void _startMatchTimer() {
    // Cancel any existing timer first
    if (_matchTimer != null) {
      _matchTimer!.cancel();
      _matchTimer = null;
    }
    
    _matchTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final appState = Provider.of<AppState>(context, listen: false);
      bool hasActivePlayer = false;
      
      // Check if any player is active
      for (var playerName in appState.session.players.keys) {
        if (appState.session.players[playerName]!.active) {
          hasActivePlayer = true;
          break;
        }
      }
      
      if (!_isPaused && hasActivePlayer && mounted) {
        setState(() {
          if (mounted) _matchTime++;
          // Only update the session match time every second (every other timer tick)
          if (_matchTime % 2 == 0) {
            final seconds = _matchTime ~/ 2;
            appState.session.matchTime = seconds;
            appState.session.matchRunning = true;
            
            // Check for period transitions
            _checkPeriodEnd();
          }
        });
      }
    });
  }

  bool _hasActivePlayer() {
    final appState = Provider.of<AppState>(context, listen: false);
    for (var playerName in appState.session.players.keys) {
      if (appState.session.players[playerName]!.active) {
        return true;
      }
    }
    return false;
  }

  void _toggleTimer(int index) async {
    // Don't allow toggling if paused
    if (_isPaused) return;
    
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.currentSessionId == null) return;

    // Get the player name from the index, using a safety check
    if (index < 0 || index >= appState.players.length) return;
    final playerName = appState.players[index]['name'];
    
    // Toggle this specific player
    await appState.togglePlayer(playerName);
  }

  // Add an alternative toggle method by player name
  void _togglePlayerByName(String playerName) async {
    // Don't allow toggling if paused
    if (_isPaused) return;
    
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.currentSessionId == null) return;

    // Toggle this specific player
    await appState.togglePlayer(playerName);
  }

  // Add this method to safely update state
  void _safeSetState(Function updateState) {
    if (mounted) {
      setState(() {
        updateState();
      });
    }
  }

  // Modify _pauseAll to use safe state updates
  void _pauseAll() {
    final appState = Provider.of<AppState>(context, listen: false);

    if (!mounted) return;
    
    _safeSetState(() {
      _isPaused = !_isPaused;
      appState.session.isPaused = _isPaused;
      
      if (_isPaused) {
        // Store the list of active players before pausing
        appState.session.activeBeforePause = [];
        for (var playerName in appState.session.players.keys) {
          if (appState.session.players[playerName]!.active) {
            appState.session.activeBeforePause.add(playerName);
            // Deactivate all players when pausing
            appState.togglePlayer(playerName);
          }
        }
      } else {
        // Reactivate players that were active before pause
        for (var playerName in appState.session.activeBeforePause) {
          if (appState.session.players.containsKey(playerName)) {
            appState.togglePlayer(playerName);
          }
        }
        appState.session.activeBeforePause = [];
      }
      
      appState.saveSession();
    });
  }

  void _resetAll() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.resetSession();
    _safeSetState(() {
      _isPaused = false;
      _matchTime = 0; // Reset to 0:00
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showAddPlayerDialog() {
    final TextEditingController textController = TextEditingController();
    final appState = Provider.of<AppState>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        key: UniqueKey(),
        title: Text('Add Player'),
        content: TextField(
          controller: textController,
          focusNode: _addPlayerFocusNode,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Player Name'),
          onSubmitted: (value) async {
            if (value.isNotEmpty) {
              try {
                // Add player and wait for the operation to complete
                await appState.addPlayer(value);
                
                // Close dialog and update state
                if (context.mounted) {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _safeSetState(() {});
                  });
                  
                  // Reopen dialog for quick adding of multiple players
                  Future.delayed(Duration(milliseconds: 100), () {
                    if (mounted) _showAddPlayerDialog();
                  });
                }
              } catch (e) {
                print('Error adding player: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not add player: $e'))
                  );
                }
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (textController.text.isNotEmpty) {
                try {
                  // Add player and wait for the operation to complete
                  await appState.addPlayer(textController.text);
                  
                  // Close dialog and update state
                  if (context.mounted) {
                    Navigator.pop(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _safeSetState(() {});
                    });
                  }
                } catch (e) {
                  print('Error adding player: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not add player: $e'))
                    );
                  }
                }
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    ).then((_) => null);
  }

  // Toggle expansion state of the player table
  void _toggleTableExpansion() {
    setState(() {
      _isTableExpanded = !_isTableExpanded;
    });
  }

  // Add this helper method to calculate player time
  int _calculatePlayerTime(Player? player) {
    if (player == null) return 0;
    
    int playerTime = player.totalTime;
    // Ensure totalTime is in seconds, not milliseconds
    if (playerTime > 1000000) playerTime = playerTime ~/ 1000; // Temporary fix
    if (player.active && !_isPaused) {
      // Add current active time - fix the timestamp calculation
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final timeElapsed = now - player.startTime;
      playerTime += timeElapsed > 0 && timeElapsed < 86400 ? timeElapsed : 0; // Sanity check to prevent huge numbers
    }
    return playerTime;
  }

  // Modify _checkPeriodEnd to use safe state updates
  void _checkPeriodEnd() {
    if (!mounted) return;

    final appState = Provider.of<AppState>(context, listen: false);
    
    if (!appState.session.enableMatchDuration) return;
    
    // Calculate period duration
    final periodDuration = appState.session.matchDuration / appState.session.matchSegments;
    
    // Calculate when the current period should end
    final currentPeriodEndTime = periodDuration * appState.session.currentPeriod;
    
    // Check if we've reached the end of a period
    if (appState.session.matchTime >= currentPeriodEndTime && 
        appState.session.currentPeriod <= appState.session.matchSegments &&
        !_isPaused &&
        !appState.session.hasWhistlePlayed) {
      
      // Mark the period as ended to prevent multiple dialogs
      appState.session.hasWhistlePlayed = true;
      
      // Pause the game and save active players
      _pauseAll();
      
      // Show period end dialog after a short delay to ensure UI updates first
      if (mounted) {
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => PeriodEndDialog(
                // Pass any required parameters but avoid using keys
                onNextPeriod: () {
                  // Handle period transition in the callback
                  if (mounted) {
                    _safeSetState(() {
                      appState.session.currentPeriod++;
                      appState.session.hasWhistlePlayed = false;
                      _isPaused = false;
                      appState.session.isPaused = false;
                      
                      // Reactivate players that were active before pause
                      for (var playerName in appState.session.activeBeforePause) {
                        if (appState.session.players.containsKey(playerName)) {
                          appState.togglePlayer(playerName);
                        }
                      }
                      // Clear the list after reactivating
                      appState.session.activeBeforePause = [];
                    });
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            );
          }
        });
      }
    }
  }

  void _showPlayerContextMenu(BuildContext context, String playerName, int index) {
    final appState = Provider.of<AppState>(context, listen: false);
    final isDark = appState.isDarkTheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
        title: Text(
          'Player Actions: $playerName',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue),
              title: Text(
                'Edit Player',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(context); // Close dialog
                _showEditPlayerDialog(playerName);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text(
                'Remove Player',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(context); // Close dialog
                _showRemovePlayerConfirmation(playerName);
              },
            ),
            ListTile(
              leading: Icon(Icons.timer_off, color: Colors.orange),
              title: Text(
                'Reset Time',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(context); // Close dialog
                _resetPlayerTime(playerName);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showEditPlayerDialog(String playerName) {
    final textController = TextEditingController(text: playerName);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Player'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Player Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty && newName != playerName) {
                final appState = Provider.of<AppState>(context, listen: false);
                appState.renamePlayer(playerName, newName);
                Navigator.pop(context);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _showRemovePlayerConfirmation(String playerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Player'),
        content: Text('Are you sure you want to remove $playerName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final appState = Provider.of<AppState>(context, listen: false);
              appState.removePlayer(playerName);
              Navigator.pop(context);
            },
            child: Text('Remove'),
          ),
        ],
      ),
    );
  }
  
  void _resetPlayerTime(String playerName) {
    final appState = Provider.of<AppState>(context, listen: false);
    
    // Deactivate player if active
    if (appState.session.players[playerName]?.active ?? false) {
      appState.togglePlayer(playerName);
    }
    
    // Reset player time
    appState.resetPlayerTime(playerName);
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reset time for $playerName')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkTheme;
    
    // Ensure local pause state stays in sync with session state
    if (_isPaused != appState.session.isPaused) {
      // Don't call setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeSetState(() {
          _isPaused = appState.session.isPaused;
        });
      });
    }
    
    // If app state isn't ready yet, show a loading screen
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: isDark ? AppThemes.darkBackground : AppThemes.lightBackground,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Wrap the build code in try-catch to make it more resilient
    try {
      return Scaffold(
        backgroundColor: isDark ? AppThemes.darkBackground : AppThemes.lightBackground,
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Session header
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _sessionName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlue,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Match Time with positioned add button
                    Stack(
                      children: [
                        // Match Time container
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // Stack to separate timer centering and period positioning
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Center the match timer independently
                                  Center(
                                    child: Text(
                                      _formatTime(_matchTime ~/ 2),
                                      style: TextStyle(
                                        fontSize: 48, // Increased font size
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'RobotoMono', // Use a blocky font
                                        color: _hasActivePlayer() && !_isPaused ? Colors.green : Colors.red, // Green when running, red when stopped
                                        letterSpacing: 2.0, // Increased spacing for scoreboard look
                                      ),
                                    ),
                                  ),
                                  // Position the period indicator to the right of the timer
                                  Positioned(
                                    left: MediaQuery.of(context).size.width / 2 + 50, // Increased offset for better positioning
                                    top: 4,
                                    child: Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          appState.session.matchSegments == 2 
                                            ? 'H${appState.session.currentPeriod}' 
                                            : 'Q${appState.session.currentPeriod}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14, // Increased font size
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Match duration progress bar
                              if (appState.session.enableMatchDuration)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    height: 8,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: isDark ? Colors.black38 : Colors.grey.shade300,
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: ((_matchTime ~/ 2) / appState.session.matchDuration).clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          gradient: LinearGradient(
                                            colors: [Colors.orange.shade600, Colors.deepOrange],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Small add button in the bottom right
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showAddPlayerDialog,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: (isDark ? AppThemes.darkSecondaryBlue : AppThemes.lightSecondaryBlue).withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Container for both player buttons and table
                    Expanded(
                      child: Column(
                        children: [
                          // Player buttons pane
                          Expanded(
                            flex: 2, // Give buttons more space than table by default
                            child: Container(
                              margin: EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isDark ? AppThemes.darkCardBackground.withOpacity(0.3) : AppThemes.lightCardBackground.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white24 : Colors.black12,
                                  width: 1,
                                ),
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.all(8),
                                itemCount: appState.players.length,
                                itemBuilder: (context, index) {
                                  // Players are already sorted alphabetically in AppState
                                  final player = appState.players[index];
                                  final playerName = player['name'];
                                  final playerId = player['id'];
                                  final playerObj = appState.session.players[playerName];
                                  final isActive = playerObj?.active ?? false;
                                  final playerTime = _calculatePlayerTime(playerObj);
                                  
                                  // Create a stable key
                                  final stableKey = ValueKey('player-${playerId ?? playerName}');
                                  
                                  return Padding(
                                    key: stableKey,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? (isDark ? AppThemes.darkGreen : AppThemes.lightGreen)
                                            : (isDark ? AppThemes.darkRed : AppThemes.lightRed),
                                        border: playerTime >= appState.session.targetPlayDuration
                                            ? Border.all(
                                                color: Colors.yellow.shade600.withOpacity(0.6), // More subtle yellow color
                                                width: 1.5, // Thinner border
                                              )
                                            : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: InkWell(
                                        onTap: () => _togglePlayerByName(playerName),
                                        onLongPress: () => _showPlayerContextMenu(context, playerName, index),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    playerName,
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black38,
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Text(
                                                      _formatTime(playerTime),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            // Target duration progress bar
                                            if (appState.session.enableTargetDuration)
                                              Padding(
                                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                                child: Container(
                                                  height: 6,
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(3),
                                                    color: Colors.black38,
                                                  ),
                                                  child: FractionallySizedBox(
                                                    alignment: Alignment.centerLeft,
                                                    widthFactor: (playerTime / appState.session.targetPlayDuration).clamp(0.0, 1.0),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(3),
                                                        gradient: LinearGradient(
                                                          colors: playerTime >= appState.session.targetPlayDuration
                                                            ? [Colors.yellow.shade600, Colors.amber]
                                                            : [Colors.lightBlue.shade300, Colors.blue],
                                                          begin: Alignment.centerLeft,
                                                          end: Alignment.centerRight,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          
                          // Table header with toggle button
                          GestureDetector(
                            onTap: _toggleTableExpansion,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.black, // Match the dark header from the image
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                  bottomLeft: _isTableExpanded ? Radius.zero : Radius.circular(8),
                                  bottomRight: _isTableExpanded ? Radius.zero : Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Player header - left aligned
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Player',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  // Time header - right aligned
                                  Expanded(
                                    flex: 1,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Time',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                        // Chevron icon
                                        Icon(
                                          _isTableExpanded 
                                            ? Icons.keyboard_arrow_down
                                            : Icons.keyboard_arrow_up,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Player table pane (collapsible)
                          AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            height: _isTableExpanded ? 150 : 0,
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: _isTableExpanded 
                              ? SingleChildScrollView(
                                  child: Builder(
                                    builder: (context) {
                                      // Get all players with their times
                                      List<Map<String, dynamic>> sortedPlayers = [];
                                      
                                      // Handle empty player list case
                                      if (appState.players.isEmpty) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              'No players yet',
                                              style: TextStyle(
                                                color: isDark ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      // Create the sorted players list
                                      sortedPlayers = appState.players.map((player) {
                                        final playerName = player['name'];
                                        final playerObj = appState.session.players[playerName];
                                        final isActive = playerObj?.active ?? false;
                                        final playerTime = _calculatePlayerTime(playerObj);
                                        final index = appState.players.indexOf(player);
                                        
                                        return {
                                          'player': player,
                                          'name': playerName as String,
                                          'time': playerTime,
                                          'active': isActive,
                                          'index': index,
                                        };
                                      }).toList();
                                      
                                      // Sort by time descending
                                      sortedPlayers.sort((a, b) => (b['time'] as int).compareTo(a['time'] as int));
                                      
                                      // Use ListView instead of Table for more reliable rendering
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(), // Disable scrolling as we're in a SingleChildScrollView
                                        itemCount: sortedPlayers.length,
                                        itemBuilder: (context, i) {
                                          final item = sortedPlayers[i];
                                          final playerName = item['name'] as String;
                                          final playerTime = item['time'] as int;
                                          final isActive = item['active'] as bool;
                                          final player = item['player'] as Map<String, dynamic>;
                                          final playerId = player['id'];
                                          
                                          // Create a stable key
                                          final stableKey = ValueKey('table-${playerId ?? playerName}');
                                          
                                          // Use simplified widget structure
                                          return Container(
                                            key: stableKey,
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? (isDark ? AppThemes.darkGreen.withOpacity(0.7) : AppThemes.lightGreen.withOpacity(0.7))
                                                  : (isDark ? AppThemes.darkRed.withOpacity(0.7) : AppThemes.lightRed.withOpacity(0.7)),
                                              border: playerTime >= appState.session.targetPlayDuration
                                                  ? Border.all(
                                                      color: Colors.yellow.shade600.withOpacity(0.6), // More subtle yellow color
                                                      width: 1.5, // Thinner border
                                                    )
                                                  : null,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: Text(
                                                        playerName,
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 1,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8.0),
                                                      child: Text(
                                                        _formatTime(playerTime),
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  ),
                                )
                              : SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    
                    // Action buttons in 2x2 grid
                    SizedBox(height: 8),
                    Row(
                      children: [
                        // Pause button
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ElevatedButton(
                              onPressed: _pauseAll,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppThemes.darkPauseButton : AppThemes.lightPauseButton,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(_isPaused ? 'Resume' : 'Pause'),
                            ),
                          ),
                        ),
                        // Settings button
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: ElevatedButton(
                              onPressed: () {
                                // Show settings screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppThemes.darkSettingsButton : AppThemes.lightSettingsButton,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Settings'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        // Reset button with confirmation
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ElevatedButton(
                              onPressed: () {
                                // Show confirmation dialog
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Reset Match'),
                                      content: Text('Are you sure you want to reset all timers?'),
                                      actions: [
                                        TextButton(
                                          child: Text('Cancel'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: Text('Reset'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _resetAll();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppThemes.darkResetButton : AppThemes.lightResetButton,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Reset'),
                            ),
                          ),
                        ),
                        // Exit button with confirmation
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: ElevatedButton(
                              onPressed: () {
                                // Show confirmation dialog
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Exit Match'),
                                      content: Text('Are you sure you want to exit this match?'),
                                      actions: [
                                        TextButton(
                                          child: Text('Cancel'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: Text('Exit'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            Navigator.of(context).pushReplacementNamed('/');
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppThemes.darkExitButton : AppThemes.lightExitButton,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Exit'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Version info at bottom
                    Text(
                      'SoccerTimeApp v1.0.46| Documentation',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Pause overlay
            if (_isPaused)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Match Paused',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _pauseAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            'Resume',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } catch (e) {
      // Return a simple error widget if build fails
      print('Error in MainScreen build: $e');
      return Scaffold(
        body: Center(
          child: Text('Error loading match screen. Please restart the app.'),
        ),
      );
    }
  }
}