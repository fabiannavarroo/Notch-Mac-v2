//
//  CapsLockIndicatorView.swift
//  NotchMac
//
//  Ported from upstream PR boring.notch#1246 (Lucas Walker, 2026-05-11).
//

import SwiftUI

struct CapsLockIndicatorView: View {
    @EnvironmentObject var vm: BoringViewModel
    let isOn: Bool

    private var tint: Color { isOn ? .green : .secondary }
    private var label: String { isOn ? "Caps Lock On" : "Caps Lock Off" }
    private var icon: String { isOn ? "capslock.fill" : "capslock" }

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
                Spacer(minLength: 0)
            }
            .frame(width: 88, alignment: .leading)
            .padding(.leading, 8)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - 20)

            HStack {
                Spacer(minLength: 0)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            .frame(width: 88, alignment: .trailing)
            .padding(.trailing, 10)
        }
        .frame(height: vm.closedNotchSize.height, alignment: .center)
    }
}

#Preview {
    CapsLockIndicatorView(isOn: true)
        .frame(width: 360)
        .background(Color.black)
        .environmentObject(BoringViewModel())
}
