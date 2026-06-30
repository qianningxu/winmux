struct WindowStackSplitPreview {
    let rect: Rect
    let geometry: WindowTabDropPreviewGeometry
}

func shouldUseStickyWindowDragIntent(previewStyle: WindowTabDropPreviewStyle) -> Bool {
    switch previewStyle {
        case .stackSplit:
            return true
        case .tabInsert, .swap, .detach, .workspaceMove, .sidebarWorkspaceMove:
            return false
    }
}
