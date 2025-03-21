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

class _MainScreenState extends State<MainScreen> {
  String _sessionName = "Bruno"; // Default session name
  int _matchTime = 0;
  bool _isPaused = false;
  Timer? _matchTimer;
  bool _isTableExpanded = true;
  final FocusNode _addPlayerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    
    // Load match time from session and convert to tracking value (2x for 500ms timer)
    _matchTime = appState.session.matchTime * 2;
    _isPaused = appState.session.isPaused;
    
    // Use session name from the session object or currentSessionPassword
    _sessionName = appState.session.sessionName.isNotEmpty 
        ? appState.session.sessionName 
        : (appState.currentSessionPassword ?? "New Session");
    
    _startMatchTimer();
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _addPlayerFocusNode.dispose();
    super.dispose();
  }

  void _startMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      
      final appState = Provider.of<AppState>(context, listen: false);
      bool hasActivePlayer = false;
      
      // Check if any player is active
      for (var playerName in appState.session.players.keys) {
        if (appState.session.players[playerName]!.active) {
          hasActivePlayer = true;
          break;
        }
      }
      
      if (!_isPaused && hasActivePlayer) {
        setState(() {
          _matchTime++;
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

  void _pauseAll() {
    final appState = Provider.of<AppState>(context, listen: false);
    
    setState(() {
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
    setState(() {
      _isPaused = false;
      _matchTime = 0; // Reset to 0:00
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showAddPlayerDialog() {
    final TextEditingController textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Player'),
        content: TextField(
          controller: textController,
          focusNode: _addPlayerFocusNode,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Player Name'),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Provider.of<AppState>(context, listen: false).addPlayer(value);
              Navigator.pop(context);
              // Reopen dialog for quick adding of multiple players
              Future.delayed(Duration(milliseconds: 100), () {
                if (mounted) _showAddPlayerDialog();
              });
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                Provider.of<AppState>(context, listen: false).addPlayer(textController.text);
                Navigator.pop(context);
                // Reopen dialog for quick adding of multiple players
                Future.delayed(Duration(milliseconds: 100), () {
                  if (mounted) _showAddPlayerDialog();
                });
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      // Focus on the input field when dialog opens
      Future.delayed(Duration(milliseconds: 50), () {
        if (_addPlayerFocusNode.canRequestFocus) {
          _addPlayerFocusNode.requestFocus();
        }
      });
    });
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
    if (player.active && !_isPaused) {
      // Add current active time
      final timeElapsed = (DateTime.now().millisecondsSinceEpoch - player.startTime) ~/ 1000;
      playerTime += timeElapsed;
    }
    return playerTime;
  }

  // Add this method to check for period transitions
  void _checkPeriodEnd() {
    final appState = Provider.of<AppState>(context, listen: false);
    
    if (!appState.session.enableMatchDuration) return;
    
    // Calculate period duration
    final periodDuration = appState.session.matchDuration / appState.session.matchSegments;
    
    // Calculate when the current period should end
    final currentPeriodEndTime = periodDuration * appState.session.currentPeriod;
    
    // Check if we've reached the end of a period
    if (appState.session.matchTime >= currentPeriodEndTime && 
        appState.session.currentPeriod <= appState.session.matchSegments &&
        !_isPaused) {
      
      // Save active players to session
      appState.storeActivePlayersForPeriodChange();
      
      // Update UI state to reflect pause
      setState(() {
        _isPaused = true;
      });
      
      // Show period end dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PeriodEndDialog(),
      ).then((_) {
        // If dialog is dismissed without starting next period, restore the pause state
        if (appState.session.isPaused) {
          setState(() {
            _isPaused = appState.session.isPaused;
          });
        }
      });
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
      _isPaused = appState.session.isPaused;
    }
    
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formatTime(_matchTime ~/ 2),
                                  style: TextStyle(
                                    fontSize: 42, // Larger font size
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier', // Monospace font for scoreboard look
                                    color: _hasActivePlayer() && !_isPaused ? Colors.green : Colors.red, // Green when running, red when stopped
                                    letterSpacing: 2.0, // Increased spacing for scoreboard look
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.only(left: 8),
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
                                      fontSize: 12,
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
                                final playerObj = appState.session.players[playerName];
                                final isActive = playerObj?.active ?? false;
                                final playerTime = _calculatePlayerTime(playerObj);
                                
                                // Determine background color based on active status
                                Color backgroundColor = isActive
                                    ? isDark ? AppThemes.darkGreen : AppThemes.lightGreen
                                    : isDark ? AppThemes.darkRed : AppThemes.lightRed;
                                
                                return Container(
                                  key: ValueKey(playerName),
                                  margin: EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onLongPress: () {
                                        _showPlayerContextMenu(context, playerName, index);
                                      },
                                      // Prevent default context menu in web browsers
                                      onSecondaryTapDown: (details) {
                                        _showPlayerContextMenu(context, playerName, index);
                                        // This prevents the default browser context menu
                                      },
                                      child: InkWell(
                                        onTap: () => _togglePlayerByName(playerName),
                                        // Disable this as we're handling it with onSecondaryTapDown
                                        onSecondaryTap: null,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    player['name'],
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
                                    final sortedPlayers = appState.players.map((player) {
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
                                    
                                    // Sort by time descending, then alphabetically for ties
                                    sortedPlayers.sort((a, b) {
                                      // First sort by time descending
                                      final int aTime = a['time'] as int;
                                      final int bTime = b['time'] as int;
                                      
                                      // Only consider times different if they differ by more than 1 second
                                      // This prevents reordering when times are very close
                                      if ((bTime - aTime).abs() > 1) {
                                        return bTime.compareTo(aTime);
                                      }
                                      
                                      // If times are very close, maintain the original order (by index)
                                      // This creates stability in the sort
                                      return (a['index'] as int).compareTo(b['index'] as int);
                                    });
                                    
                                    return Table(
                                      columnWidths: {
                                        0: FlexColumnWidth(2),
                                        1: FlexColumnWidth(1),
                                      },
                                      children: sortedPlayers.map((item) {
                                        final playerName = item['name'] as String;
                                        final playerTime = item['time'] as int;
                                        final isActive = item['active'] as bool;
                                        final index = item['index'] as int;
                                        
                                        return TableRow(
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? (isDark ? Colors.green.withOpacity(0.3) : Colors.green.withOpacity(0.1))
                                                : (index % 2 == 0 ? null : (isDark ? Colors.black12 : Colors.grey[100])),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                playerName,
                                                style: TextStyle(
                                                  color: isDark ? AppThemes.darkText : AppThemes.lightText,
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(
                                                _formatTime(playerTime),
                                                style: TextStyle(
                                                  color: isDark ? AppThemes.darkText : AppThemes.lightText,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
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
  }
}