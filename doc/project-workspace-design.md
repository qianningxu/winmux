# Project and workspace appearance

The approved prototype lives in `../temp/winmux`. The native implementation uses the same Geist token roles, without glass.

| Name | Meaning | Appearance |
| --- | --- | --- |
| Widget bar | Status widgets in the native menu area | Dark secondary background; safe around the camera notch |
| Project frame | Outermost container beneath the widget bar | gray-600, gray-500 outline, rounded corners |
| Project tabs bar | Row switching winmux, interview Q, etc. | Selected tab uses gray-300 and joins the workspace frame |
| Workspace frame | Inner surface containing workspace tab bars and windows | Solid gray-300, no dividers |
| Workspace tab bar | Row switching apply, Inspiration, etc. | Separate white selections with 8-point corners |
| Stacked window | Windows sharing one workspace tab bar | Existing grouping behavior |
| Workspace window | Native app window and title bar | Native controls, borders, and corner geometry retained |

Tab widths retain the existing native calculation and 200-point upper limit; the prototype’s 100–160-point clamp is intentionally not applied. Content is left aligned. Spacing is four points; individual group shells do not add another horizontal or bottom inset to the tiling gap. Project tabs occupy a 36-point row, and workspace tabs a 40-point row with 32-point selections and four points above/below.

The names describe UI surfaces. Internal workspace/project identifiers, configuration keys, CLI commands, and stored user state keep their existing meanings for compatibility. Native window corners remain owned by their applications; the HTML mockup's simulated 20-point corners do not forcibly reshape third-party windows.

## Native frame corrections

Project frame bottom corners follow the estimated native corner radius of the window touching each bottom edge, plus its actual inset. They are not a fixed mockup radius. The content area reserves four points below the project tabs even for a single window without workspace tabs.

A stacked window has its own visible outer frame around the workspace tab bar and native window. Its native window has four-point side/bottom insets; the workspace tab bar supplies four-point top/bottom spacing. Stack frame bottom corners follow the native corner plus the stack inset. The project frame accounts for both nested insets when a stack touches a project corner.

Project and workspace tab titles use 14-point text. Widget text remains 12 points.
