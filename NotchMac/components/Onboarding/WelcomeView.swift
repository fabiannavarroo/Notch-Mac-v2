//
//  WelcomeView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 2024. 09. 26..
//

import SwiftUI
import SwiftUIIntrospect

struct WelcomeView: View {
    var onGetStarted: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                OnboardingNotchPreview(isActive: appeared)
                    .padding(.top, 28)

                VStack(spacing: 8) {
                    Image("logo2")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("NotchMac")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Tu notch, configurado a tu manera.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                }

                VStack(spacing: 10) {
                    OnboardingFeatureRow(icon: "music.note", title: "Musica", detail: "Titulo, artista y controles sin abrir nada.")
                    OnboardingFeatureRow(icon: "calendar", title: "Calendario", detail: "Eventos visibles cuando quieras tenerlos arriba.")
                    OnboardingFeatureRow(icon: "timer", title: "Pomodoro", detail: "Focus rapido con tiempo configurable.")
                }
                .padding(.horizontal, 34)
                .padding(.top, 4)
            }

            Spacer(minLength: 18)

            Button {
                onGetStarted?()
            } label: {
                Text("Configurar NotchMac")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 34)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            Color.black.opacity(0.42)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }
}

private struct OnboardingNotchPreview: View {
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.black)
                .frame(width: 248, height: 104)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 18, y: 12)

            HStack(spacing: 18) {
                Image(systemName: "music.note")
                Image(systemName: "calendar")
                Image(systemName: "timer")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white.opacity(0.78))
            .padding(.top, 18)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.10))
                .frame(width: isActive ? 170 : 44, height: 30)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .padding(.leading, 12)
                        .opacity(isActive ? 1 : 0)
                }
                .offset(y: 58)
        }
        .scaleEffect(isActive ? 1 : 0.92)
        .opacity(isActive ? 1 : 0)
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.white.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    WelcomeView()
}
