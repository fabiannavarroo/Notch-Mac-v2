//
//  AudioOutputPicker.swift
//  NotchMac
//
//  Pequeño selector de dispositivo de salida (auriculares / altavoz / AirPlay…)
//  basado en el `SystemVolumeService` de la primera versión de NotchMac.
//

import SwiftUI

struct AudioOutputPickerButton: View {
    @ObservedObject private var audio = AudioOutputManager.shared
    @State private var showPopover = false

    var body: some View {
        Button {
            audio.refreshDevices()
            audio.refresh()
            showPopover.toggle()
        } label: {
            Image(systemName: audio.currentOutputSymbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .help(audio.currentOutputDevice?.name ?? "Salida de audio")
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            AudioOutputPickerPopover()
                .environmentObject(audio)
        }
    }
}

private struct AudioOutputPickerPopover: View {
    @EnvironmentObject private var audio: AudioOutputManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Salida de audio")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            ForEach(audio.outputDevices, id: \.id) { (device: OutputDevice) in
                Button {
                    audio.setOutputDevice(device.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: device.symbolName)
                            .frame(width: 18)
                            .foregroundStyle(.primary)
                        Text(device.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if device.id == audio.currentDeviceID {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if audio.outputDevices.isEmpty {
                Text("No hay dispositivos disponibles")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(minWidth: 220)
    }
}
