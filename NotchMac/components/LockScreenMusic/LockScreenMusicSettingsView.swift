import Defaults
import SwiftUI

struct LockScreenMusicSettingsView: View {
    @Default(.lockScreenMusicEnabled) private var enabled
    @Default(.lockScreenMusicShowLyrics) private var showLyrics

    var body: some View {
        VStack(spacing: 16) {
            card(title: "Modo musica en pantalla bloqueada") {
                row(
                    title: "Activar modo musica en pantalla bloqueada",
                    subtitle: "Cuando bloqueas el Mac y hay una cancion sonando, se muestra un widget de musica encima del wallpaper y el fondo cambia a uno del sistema cuyo color combine con la cancion. Al desbloquear se restaura todo."
                ) {
                    Toggle("", isOn: $enabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(.green)
                }

                row(
                    title: "Mostrar letras",
                    subtitle: "Si la cancion actual tiene letras sincronizadas, aparece una columna karaoke a la derecha del widget. Si no las tiene, el widget se mantiene centrado.",
                    enabled: enabled
                ) {
                    Toggle("", isOn: $showLyrics)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(.green)
                        .disabled(!enabled)
                }
            }

            card(title: "Limitaciones") {
                VStack(alignment: .leading, spacing: 8) {
                    note("macOS no permite personalizar oficialmente la pantalla de bloqueo. Esta funcion usa el overlay de NotchMac y modifica temporalmente tu wallpaper para combinarlo con la cancion.")
                    note("El cambio de wallpaper puede tardar 1-2 segundos en reflejarse en la pantalla de bloqueo, depende del sistema.")
                    note("Las letras requieren que la cancion tenga letra sincronizada. Si solo hay letra estatica, la columna no aparece.")
                    note("No se muestra nada cuando la pantalla esta apagada o no hay musica sonando.")
                }
            }
        }
    }

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            VStack(spacing: 0) { content() }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.085, green: 0.088, blue: 0.096).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.075), lineWidth: 0.7)
                )
        )
    }

    @ViewBuilder
    private func row<Control: View>(
        title: String,
        subtitle: String,
        enabled: Bool = true,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(enabled ? 0.92 : 0.38))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(enabled ? 0.46 : 0.26))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 20)
            control()
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func note(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
