//
//  AnimatedMetricValueView.swift
//  graphic-monitor
//

import SwiftUI

private enum MetricCountAnimation {
    static let duration: TimeInterval = 0.2
    static var style: Animation { .linear(duration: duration) }
}

private struct AnimatedPercentText: View, Animatable {
    var percent: Double

    var animatableData: Double {
        get { percent }
        set { percent = newValue }
    }

    var body: some View {
        Text(SystemMonitor.formatPercent(percent / 100))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

private struct AnimatedNetworkDirectionSpeed: View, Animatable {
    var bytesPerSecond: Double
    let color: Color

    var animatableData: Double {
        get { bytesPerSecond }
        set { bytesPerSecond = newValue }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(SystemMonitor.formatNetworkSpeedMbps(bytesPerSecond))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(color.opacity(0.65))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(SystemMonitor.formatNetworkSpeed(bytesPerSecond))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}

private struct AnimatedNetworkSpeedText: View {
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("↓")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(GraphMetric.downloadColor)
                AnimatedNetworkDirectionSpeed(
                    bytesPerSecond: downloadBytesPerSecond,
                    color: GraphMetric.downloadColor
                )
                .animation(MetricCountAnimation.style, value: downloadBytesPerSecond)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("↑")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(GraphMetric.uploadColor)
                AnimatedNetworkDirectionSpeed(
                    bytesPerSecond: uploadBytesPerSecond,
                    color: GraphMetric.uploadColor
                )
                .animation(MetricCountAnimation.style, value: uploadBytesPerSecond)
            }
        }
    }
}

struct AnimatedMetricValueView: View {
    let metric: GraphMetric
    let monitor: SystemMonitor

    var body: some View {
        Group {
            switch metric {
            case .cpu:
                AnimatedPercentText(percent: monitor.cpuUsage * 100)
                    .animation(MetricCountAnimation.style, value: monitor.cpuUsage)
            case .gpu:
                AnimatedPercentText(percent: monitor.gpuUsage * 100)
                    .animation(MetricCountAnimation.style, value: monitor.gpuUsage)
            case .ram:
                AnimatedPercentText(percent: monitor.ramUsage * 100)
                    .animation(MetricCountAnimation.style, value: monitor.ramUsage)
            case .network:
                AnimatedNetworkSpeedText(
                    downloadBytesPerSecond: monitor.netDownloadBytesPerSecond,
                    uploadBytesPerSecond: monitor.netUploadBytesPerSecond
                )
            }
        }
    }
}
