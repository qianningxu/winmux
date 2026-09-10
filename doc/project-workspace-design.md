# Project and workspace appearance

The approved prototype lives in `../temp/winmux`. The native implementation uses the same Geist token roles, without glass.

| Name | Meaning | Appearance |
| --- | --- | --- |
| Widget bar | Status widgets in the native menu area | Dark secondary background; safe around the camera notch |
| Project frame | Outermost container beneath the widget bar | gray-300, gray-500 outline, rounded corners |
| Project tabs bar | Row switching winmux, interview Q, etc. | Transparent tabs; active title is semibold; inactive neighbours use separators when crowded |
| Workspace frame | Surface belonging to one stacked window | gray-500 rounded tab surface, separated from its native window |
| Workspace tab bar | Row switching apply, Inspiration, etc. | White selected pill; inactive neighbours use separators when crowded |
| Stacked window | Windows sharing one workspace tab bar | Existing grouping behavior |
| Workspace window | Native app window and title bar | Native controls, borders, and corner geometry retained |

Tab widths retain the existing native calculation and 200-point upper limit. Content is left aligned. Project tabs occupy a 40-point row with 32-point content and four points above and below. Workspace tabs occupy a 40-point rounded surface with 36-point content and two points above and below. Workspace windows use six-point structural gaps.

The names describe UI surfaces. Internal workspace/project identifiers, configuration keys, CLI commands, and stored user state keep their existing meanings for compatibility. Native window corners remain owned by their applications; the HTML mockup's simulated 20-point corners do not forcibly reshape third-party windows.

## Native frame corrections

Project frame uses the same continuous radius on all four corners, chosen to accommodate the estimated native window radius plus its outer inset. The Project menu is an outlined pill. Project selections use typography rather than a filled plate.

Each stacked window has a gray-500 rounded workspace tab surface and a six-point gap before its native window. Native window borders remain visible.

Project and workspace tab titles use 14-point text. Widget text remains 12 points.
