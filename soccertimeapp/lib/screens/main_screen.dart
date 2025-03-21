import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/app_themes.dart';
import '../screens/settings_screen.dart';
import '../models/player.dart';
import 'dart:async';
import '../widgets/period_end_dialog.dart';
import '../services/audio_service.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  String _sessionName = "Loading..."; // Default session name
  int _matchTime = 0;
  bool _isPaused = false;
  Timer? _matchTimer;
  bool _isTableExpanded = true;
  final FocusNode _addPlayerFocusNode = FocusNode();
  bool _isInitialized = false;
  final AudioService _audioService = AudioService();
  
  // Animation controller for pulsing add button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Register as an observer to handle app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize animation controller for pulsing
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
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
        final appState = Provider.of<AppState>(context, listen: false);
        
        // Properly restore the match time from saved state
        _safeSetState(() {
          // Make sure the local match time is in sync with the saved session match time
          _matchTime = appState.session.matchTime * 2;
          
          // Make sure pause state is in sync
          _isPaused = appState.session.isPaused;
          
          print('App resumed: Setting match time to ${_matchTime ~/ 2} seconds (${_formatTime(_matchTime ~/ 2)})');
        });
        
        // Add a slight delay to ensure player times are loaded correctly
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            // Reconcile match time with player times to fix any discrepancies
            _reconcileMatchAndPlayerTimes();
            
            // Restart the timer to ensure everything is synchronized
            _startMatchTimer();
          }
        });
      }
    } else if (state == AppLifecycleState.paused) {
      // App went to background - save state
      if (mounted && _isInitialized) {
        final appState = Provider.of<AppState>(context, listen: false);
        
        // Make sure the session match time is updated before saving
        if (!_isPaused) {
          appState.session.matchTime = _matchTime ~/ 2;
          print('App paused: Saving match time as ${appState.session.matchTime} seconds (${_formatTime(appState.session.matchTime)})');
        }
        
        appState.saveSession();
      }
    }
  }
  
  void _loadInitialState() {
    if (!mounted) return;
    
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      
      print('_loadInitialState: Current session ID: ${appState.currentSessionId}');
      print('_loadInitialState: Session object name: "${appState.session.sessionName}"');
      print('_loadInitialState: Current session password: "${appState.currentSessionPassword}"');
      
      _safeSetState(() {
        _matchTime = appState.session.matchTime * 2;
        _isPaused = appState.session.isPaused;
        
        // Determine the session name to display in the UI
        String nameToDisplay = '';
        
        // First priority: Use currentSessionPassword if available (this comes from the database)
        if (appState.currentSessionPassword != null && appState.currentSessionPassword!.isNotEmpty) {
          nameToDisplay = appState.currentSessionPassword!;
          print('_loadInitialState: Using currentSessionPassword for display: "$nameToDisplay"');
        } 
        // Second priority: Use session object name
        else if (appState.session.sessionName.isNotEmpty) {
          nameToDisplay = appState.session.sessionName;
          print('_loadInitialState: Using session.sessionName for display: "$nameToDisplay"');
        }
        // Last resort: Use a default with the session ID
        else if (appState.currentSessionId != null) {
          // Check in sessions list for a better name
          final sessionInfo = appState.sessions.firstWhere(
            (s) => s['id'] == appState.currentSessionId,
            orElse: () => {'name': 'Session ${appState.currentSessionId}'}
          );
          nameToDisplay = sessionInfo['name'] ?? 'Session ${appState.currentSessionId}';
          print('_loadInitialState: Using sessions list or fallback: "$nameToDisplay"');
        } else {
          nameToDisplay = 'New Session';
          print('_loadInitialState: Using default name: "$nameToDisplay"');
        }
        
        // Set the session name for display
        _sessionName = nameToDisplay;
        print('_loadInitialState: Final name for display: "$_sessionName"');
        
        _isInitialized = true;
        
        // Start pulsing animation if there are no players
        if (appState.players.isEmpty) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
        }
      });
      
      // Start timer only after state is updated
      Future.microtask(() {
        if (mounted) {
          _startMatchTimer();
        }
      });
    } catch (e) {
      print('Error loading initial state: $e');
      // Show an error message and allow user to return to session list
      if (mounted) {
        _safeSetState(() {
          _isInitialized = true; // Set to true so we show error not loading
        });
        
        // Show a snackbar with the error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading session data: ${e.toString()}'),
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Return',
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                ),
              ),
            );
          }
        });
      }
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
    
    // Dispose the animation controller
    _pulseController.dispose();
    
    // Dispose the audio service
    _audioService.dispose();
    
    super.dispose();
  }

  void _startMatchTimer() {
    // Cancel any existing timer first
    if (_matchTimer != null) {
      _matchTimer!.cancel();
      _matchTimer = null;
    }
    
    final appState = Provider.of<AppState>(context, listen: false);
    
    // When starting the timer, ensure all active players have a valid start time
    if (!_isPaused) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Ensure active players have correct start times after app resume
      for (var playerName in appState.session.players.keys) {
        final player = appState.session.players[playerName];
        if (player != null && player.active) {
          // If the start time is very old or invalid, reset it
          if (player.startTime <= 0 || (now - player.startTime) > 36000) { // 10 hours max
            print('Resetting invalid start time for active player: $playerName');
            player.startTime = now;
          }
        }
      }
    }
    
    _matchTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
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

  void _showAddPlayerDialog(BuildContext context) {
    final textController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        key: UniqueKey(),
        title: Text(
          'Add Player',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppThemes.darkText : AppThemes.lightText,
            letterSpacing: 1.0,
          ),
        ),
        content: TextField(
          controller: textController,
          focusNode: _addPlayerFocusNode,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: 'Player Name'),
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              try {
                // Add player and wait for the operation to complete
                final appState = Provider.of<AppState>(context, listen: false);
                await appState.addPlayer(value.trim());
                
                // Close dialog and update state
                if (context.mounted) {
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _safeSetState(() {});
                  });
                  
                  // Reopen dialog for quick adding of multiple players
                  Future.delayed(Duration(milliseconds: 100), () {
                    if (mounted) _showAddPlayerDialog(context);
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
              if (textController.text.trim().isNotEmpty) {
                try {
                  // Add player and wait for the operation to complete
                  final appState = Provider.of<AppState>(context, listen: false);
                  await appState.addPlayer(textController.text.trim());
                  
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
      
      // Play whistle sound
      _playWhistle(isMatchEnd: appState.session.currentPeriod >= appState.session.matchSegments);
      
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
  
  // Helper method to play whistle sounds
  void _playWhistle({bool isMatchEnd = false}) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      // Only play sound if it's enabled in settings
      if (appState.session.enableSound) {
        // Play first whistle sound
        await _audioService.playWhistle();
        
        // Play second whistle sound if it's match end
        if (isMatchEnd) {
          // Wait a short moment before playing the second whistle
          await Future.delayed(Duration(milliseconds: 800));
          await _audioService.playWhistle();
        }
      } else {
        // Log that sound was requested but disabled
        print('Whistle sound was requested but sound is disabled in settings');
      }
    } catch (e) {
      print('Error playing whistle sound: $e');
    }
  }

  void _showPlayerActionsDialog(String playerName) {
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
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
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
                _showEditPlayerDialog(context, '', playerName);
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
  
  void _showEditPlayerDialog(BuildContext context, String playerId, String playerName) {
    final textController = TextEditingController(text: playerName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Player',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppThemes.darkText : AppThemes.lightText,
            letterSpacing: 1.0,
          ),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
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
              } else if (newName.isEmpty) {
                // Show error for empty name
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Player name cannot be empty'))
                );
              } else if (newName == playerName) {
                // No change, just close the dialog
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
    final appState = Provider.of<AppState>(context, listen: false);
    final isDark = appState.isDarkTheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Player',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppThemes.darkText : AppThemes.lightText,
            letterSpacing: 0.5,
          ),
        ),
        content: Text('Are you sure you want to remove $playerName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
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

  // Add a method to reconcile match time with player times
  void _reconcileMatchAndPlayerTimes() {
    final appState = Provider.of<AppState>(context, listen: false);
    
    // Only proceed if the session is initialized and not paused
    if (!_isInitialized || _isPaused) return;
    
    // Get the sum of all player times
    int totalPlayerSeconds = 0;
    int maxPlayerSeconds = 0;
    int activePlayerCount = 0;
    
    for (var playerName in appState.session.players.keys) {
      final player = appState.session.players[playerName];
      if (player != null) {
        final playerTime = _calculatePlayerTime(player);
        totalPlayerSeconds += playerTime;
        
        // Track the maximum player time as a reference
        if (playerTime > maxPlayerSeconds) {
          maxPlayerSeconds = playerTime;
        }
        
        // Count active players
        if (player.active) {
          activePlayerCount++;
        }
      }
    }
    
    // Calculate average player time
    final avgPlayerSeconds = appState.session.players.isNotEmpty 
        ? totalPlayerSeconds / appState.session.players.length
        : 0;
    
    // Get current match time in seconds
    final currentMatchSeconds = _matchTime ~/ 2;
    
    // If there's a significant discrepancy between match time and max player time
    // and we have at least one player, adjust the match time
    if (appState.session.players.isNotEmpty && 
        (maxPlayerSeconds > currentMatchSeconds + 60 || maxPlayerSeconds < currentMatchSeconds - 60)) {
      
      print('Significant time discrepancy detected:');
      print('  Current match time: ${_formatTime(currentMatchSeconds)}');
      print('  Max player time: ${_formatTime(maxPlayerSeconds)}');
      print('  Average player time: ${_formatTime(avgPlayerSeconds.toInt())}');
      
      // Adjust match time to be at least as high as the maximum player time
      _safeSetState(() {
        _matchTime = maxPlayerSeconds * 2;
        appState.session.matchTime = maxPlayerSeconds;
        print('  → Adjusted match time to: ${_formatTime(maxPlayerSeconds)}');
      });
      
      // Save the session with the updated time
      appState.saveSession();
    }
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
    
    // Update animation state based on player count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hasPlayers = appState.players.isNotEmpty;
      if (hasPlayers && _pulseController.isAnimating) {
        _pulseController.stop();
      } else if (!hasPlayers && !_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    });
    
    // Ensure session name is always displayed - fix blank session name
    if (_sessionName.isEmpty && appState.currentSessionPassword != null) {
      // Don't call setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _safeSetState(() {
          _sessionName = appState.currentSessionPassword ?? "Unnamed Session";
          print('Fixed blank session name to: "$_sessionName"');
        });
      });
    }
    
    // If app state isn't ready yet, show a loading screen
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: isDark ? AppThemes.darkBackground : AppThemes.lightBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading session data...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // If there was an error loading the session, show a simple error screen
    if (appState.currentSessionId == null) {
      return Scaffold(
        backgroundColor: isDark ? AppThemes.darkBackground : AppThemes.lightBackground,
        appBar: AppBar(
          title: Text('Session Error'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'There was an error loading the session',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'The session may be in read-only mode or the data might be corrupted',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: Text('Return to Sessions'),
                ),
              ],
            ),
          ),
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
                    // Match Time with positioned add button and session name
                    Stack(
                      children: [
                        // Match Time container
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          padding: EdgeInsets.fromLTRB(10, 4, 10, 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppThemes.darkCardBackground : AppThemes.lightCardBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // Session name at the top of this container
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _sessionName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.lightBlue,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (appState.isReadOnlyMode)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 3.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lock_outline,
                                            size: 9,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(width: 1),
                                          Text(
                                            'Read-Only',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              
                              // Stack to separate timer centering and period positioning
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Center the match timer independently
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 0, bottom: 0),
                                      child: Text(
                                        _formatTime(_matchTime ~/ 2),
                                        style: TextStyle(
                                          fontSize: 46, // Slightly smaller font size
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'RobotoMono',
                                          color: _hasActivePlayer() && !_isPaused ? Colors.green : Colors.red,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Position the period indicator to the right of the timer
                                  Positioned(
                                    left: MediaQuery.of(context).size.width / 2 + 62,
                                    top: 4,
                                    child: Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          appState.session.matchSegments == 2 
                                            ? 'H${appState.session.currentPeriod}' 
                                            : 'Q${appState.session.currentPeriod}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
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
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Container(
                                    height: 6,
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
                              child: appState.players.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 48,
                                          color: isDark ? Colors.white54 : Colors.black38,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No Players Added',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white54 : Colors.black38,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Tap the + button to add players',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontStyle: FontStyle.italic,
                                            color: isDark ? Colors.white38 : Colors.black26,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    itemCount: appState.players.length,
                                    itemBuilder: (context, index) {
                                      // Players are already sorted alphabetically in AppState
                                      final player = appState.players[index];
                                      final playerName = player['name'];
                                      final playerId = player['id'];
                                      final playerObj = appState.session.players[playerName];
                                      final isActive = playerObj?.active ?? false;
                                      final playerTime = _calculatePlayerTime(playerObj);
                                      
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 6),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                isActive ? Colors.green : (isDark ? Colors.red.shade700 : Colors.red.shade600),
                                                isActive ? Colors.green.shade800 : (isDark ? Colors.red.shade900 : Colors.red.shade800),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: playerTime >= appState.session.targetPlayDuration
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.amber.withOpacity(0.3),
                                                    blurRadius: 10,
                                                    spreadRadius: 1,
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ]
                                              : [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                            border: playerTime >= appState.session.targetPlayDuration
                                              ? Border.all(
                                                  color: Colors.amber.shade200.withOpacity(0.5),
                                                  width: 1.0,
                                                )
                                              : null,
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(12),
                                              onTap: appState.isReadOnlyMode ? null : () {
                                                appState.togglePlayer(playerName);
                                              },
                                              onLongPress: appState.isReadOnlyMode ? null : () {
                                                _showPlayerActionsDialog(playerName);
                                              },
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          playerName,
                                                          style: TextStyle(
                                                            fontSize: 20,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white,
                                                            letterSpacing: 1.5,
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
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.white,
                                                              letterSpacing: 1.2,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  
                                                  // Target duration progress bar
                                                  if (appState.session.enableTargetDuration)
                                                    Padding(
                                                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                                                      child: Container(
                                                        height: 4,
                                                        width: double.infinity,
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(2),
                                                          color: Colors.black38,
                                                        ),
                                                        child: FractionallySizedBox(
                                                          alignment: Alignment.centerLeft,
                                                          widthFactor: (playerTime / appState.session.targetPlayDuration).clamp(0.0, 1.0),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(2),
                                                              gradient: LinearGradient(
                                                                colors: playerTime >= appState.session.targetPlayDuration
                                                                  ? [Colors.amber.shade300, Colors.amber.shade600]
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
                                        letterSpacing: 0.5,
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
                                            letterSpacing: 0.5,
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
                                                      color: Colors.amber.shade200.withOpacity(0.5),
                                                      width: 1.0,
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
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 2.0,
                                ),
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
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 2.0,
                                ),
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
                                      title: Text(
                                        'Reset Match',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppThemes.darkText : AppThemes.lightText,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
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
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 2.0,
                                ),
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
                                      title: Text(
                                        'Exit Match',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppThemes.darkText : AppThemes.lightText,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
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
                                            // Clear current session by resetting AppState
                                            Provider.of<AppState>(context, listen: false).clearCurrentSession();
                                                
                                            // Pop the alert dialog
                                            Navigator.of(context).pop();
                                            
                                            // Use pushReplacementNamed to navigate back to the session prompt screen
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
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 2.0,
                                ),
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
                              letterSpacing: 2.0,
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
        
        floatingActionButton: Stack(
          alignment: Alignment.topRight,
          children: [
            // Hint text for empty player list
            if (appState.players.isEmpty)
              Positioned(
                top: 45,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Add Players',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
            // The FAB with pulse animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                // Only pulse if there are no players
                final shouldPulse = appState.players.isEmpty;
                final scale = shouldPulse ? _pulseAnimation.value : 1.0;
                
                return Transform.scale(
                  scale: scale,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showAddPlayerDialog(context),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 37, // 15% bigger than 32
                        height: 37, // 15% bigger than 32
                        decoration: BoxDecoration(
                          color: shouldPulse 
                              ? Colors.amber.withOpacity(0.9) // Highlight color when no players
                              : Color(0xFF555555).withOpacity(0.8), // Darker gray when players exist
                          shape: BoxShape.circle,
                          boxShadow: shouldPulse ? [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ] : null,
                        ),
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 23, // 15% bigger than 20
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
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