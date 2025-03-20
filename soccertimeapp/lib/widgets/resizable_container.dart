import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ResizableContainer extends StatefulWidget {
  final Widget child;
  final double initialHeight;
  final double minHeight;
  final double maxHeight;
  final bool handleOnTop;

  const ResizableContainer({
    Key? key,
    required this.child,
    this.initialHeight = 300.0,
    this.minHeight = 50.0,
    this.maxHeight = 600.0,
    this.handleOnTop = false,
  }) : super(key: key);

  @override
  _ResizableContainerState createState() => _ResizableContainerState();
}

class _ResizableContainerState extends State<ResizableContainer> {
  late double _height;
  double _lastSetHeight = 300.0; // Remember the height before collapsing
  final ScrollController _scrollController = ScrollController(); // Add the missing ScrollController

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;
    _lastSetHeight = widget.initialHeight;
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Dispose the controller when done
    super.dispose();
  }

  void _toggleCollapse() {
    setState(() {
      if (_height > widget.minHeight) {
        // If not collapsed, save current height and collapse
        _lastSetHeight = _height;
        _height = widget.minHeight;
      } else {
        // If collapsed, restore to previous height
        _height = _lastSetHeight;
      }
    });
  }

  Widget _buildResizeHandle() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _height += widget.handleOnTop ? -details.delta.dy : details.delta.dy;
                
                if (_height < widget.minHeight) {
                  _height = widget.minHeight;
                } else if (_height > widget.maxHeight) {
                  _height = widget.maxHeight;
                }
                
                if (_height > widget.minHeight + 20) {
                  _lastSetHeight = _height;
                }
              });
            },
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(widget.handleOnTop ? 10 : 0),
                  topRight: Radius.circular(widget.handleOnTop ? 10 : 0),
                  bottomLeft: Radius.circular(widget.handleOnTop ? 0 : 10),
                  bottomRight: Radius.circular(widget.handleOnTop ? 0 : 10),
                ),
              ),
              child: Center(
                child: Tooltip(
                  message: "Drag to resize",
                  child: Container(
                    width: 50,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Add a small button to quickly collapse/expand
        GestureDetector(
          onTap: _toggleCollapse,
          child: Container(
            width: 30,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(widget.handleOnTop ? 0 : 10),
                topRight: Radius.circular(widget.handleOnTop ? 0 : 10),
                bottomLeft: Radius.circular(widget.handleOnTop ? 10 : 0),
                bottomRight: Radius.circular(widget.handleOnTop ? 10 : 0),
              ),
            ),
            child: Icon(
              // Fix arrow direction: when collapsed (at min height), show down arrow to indicate it can expand
              // when expanded, show up arrow to indicate it can collapse
              _height <= widget.minHeight ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.handleOnTop) _buildResizeHandle(),
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          height: _height,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: widget.child,
          ),
        ),
        if (!widget.handleOnTop) _buildResizeHandle(),
      ],
    );
  }
} 