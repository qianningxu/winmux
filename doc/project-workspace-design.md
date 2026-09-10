# Project and workspace appearance

The approved prototype lives in `../temp/winmux`. The native implementation uses the same Geist token roles, without glass.

| Name | Meaning | Appearance |
| --- | --- | --- |
| Widget bar | Status widgets in the native menu area | Dark secondary background; safe around the camera notch |
| Project frame | Outermost container beneath the widget bar | gray-300, gray-500 outline, rounded corners |
| Project tabs bar | One bordered row containing the Project menu and winmux, interview Q, etc. | Active workspace tab uses gray-100 and semibold text; inactive neighbours use separators when crowded |
| Workspace frame | Surface belonging to one stacked window | gray-500 rounded tab surface, separated from its native window |
| Workspace tab bar | Row switching apply, Inspiration, etc. | White selected pill; inactive neighbours use separators when crowded |
| Stacked window | Windows sharing one workspace tab bar | Existing grouping behavior |
| Workspace window | Native app window and title bar | Native controls, borders, and corner geometry retained |

Tab widths retain the existing native calculation and 200-point upper limit. Content is left aligned. The Project menu and workspace tabs share one first-row border. The Project tabs bar has four points of outer space above and at both ends; its 36-point surface contains 32-point tabs with two points of inner padding. Workspace tab bars use the same two-point inner padding and four-point outer spacing. Workspace windows use six-point structural gaps.

The names describe UI surfaces. Internal workspace/project identifiers, configuration keys, CLI commands, and stored user state keep their existing meanings for compatibility. Native window corners remain owned by their applications; the HTML mockup's simulated 20-point corners do not forcibly reshape third-party windows.

## Native frame corrections

WinMux-controlled tabs and frames use a 16-point continuous radius. The workspace tab bar uses an 18-point outer radius because it sits two points beyond the tabs, keeping the nested curves concentric. The Project menu is part of the shared first-row outline.

Each stacked window has a gray-500 rounded workspace tab surface with four points of outer space on every side. Native window borders remain visible.

Project and workspace tab titles use 14-point text. Widget text remains 12 points.
