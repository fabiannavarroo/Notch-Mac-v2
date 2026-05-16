//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.boringShelf) private var showShelf
    @Default(.showTimerModule) private var showTimer
    @Default(.enableAirPodsWidget) private var showAirPods
    @Default(.airPodsDebugAlwaysShow) private var airPodsDebugAlwaysShow
    @ObservedObject private var airPods = AirPodsManager.shared
    @Namespace var animation
    var body: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                        withAnimation(.smooth) {
                            coordinator.currentView = tab.view
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
            }
        }
        .clipShape(Capsule())
    }

    private var visibleTabs: [TabModel] {
        var base = [TabModel(label: "Home", icon: "house.fill", view: .home)]
        if showShelf {
            base.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
        }
        if showTimer {
            base.append(TabModel(label: "Pomodoro", icon: "timer", view: .focus))
        }
        if showAirPods && (airPods.state != nil || airPodsDebugAlwaysShow) {
            base.append(TabModel(label: "AirPods", icon: "airpods", view: .airpods))
        }
        return base
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
