//
//  AnimatedMetricValueView.swift
//  TraceBar
//

import SwiftUI

private enum MetricCountAnimation {
    static let duration: TimeInterval = 0.2
    static var style: Animation { .linear(duration: duration) }
}

private enum NetworkSpeedLayout {
    static let metricFont = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let arrowWidth: CGFloat = 10
    static let valueWidth: CGFloat = 36
    static let mbpsUnitWidth: CGFloat = 28
    static let speedUnitWidth: CGFloat = 28
    static let sectionGap: CGFloat = 8

    static let rowWidth: CGFloat =
        arrowWidth + valueWidth + mbpsUnitWidth + sectionGap + valueWidth + speedUnitWidth
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

private struct AnimatedNetworkMetricValue: View, Animatable {
    var bytesPerSecond: Double
    let value: (Double) -> String

    var animatableData: Double {
        get { bytesPerSecond }
        set { bytesPerSecond = newValue }
    }

    var body: some View {
        Text(value(bytesPerSecond))
            .font(NetworkSpeedLayout.metricFont)
            .monospacedDigit()
            .contentTransition(.numericText())
            .frame(width: NetworkSpeedLayout.valueWidth, alignment: .trailing)
            .lineLimit(1)
    }
}

private struct NetworkMetricUnit: View {
    let text: String
    let color: Color
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(NetworkSpeedLayout.metricFont)
            .foregroundStyle(color)
            .frame(width: width, alignment: .trailing)
            .lineLimit(1)
    }
}

private struct FixedNetworkSpeedUnit: View {
    let bytesPerSecond: Double
    let color: Color

    var body: some View {
        ZStack(alignment: .trailing) {
            unitLabel("MB/s", active: bytesPerSecond >= 1_048_576)
            unitLabel("KB/s", active: bytesPerSecond >= 1024 && bytesPerSecond < 1_048_576)
            unitLabel("B/s", active: bytesPerSecond < 1024)
        }
        .frame(width: NetworkSpeedLayout.speedUnitWidth, alignment: .trailing)
    }

    private func unitLabel(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(NetworkSpeedLayout.metricFont)
            .foregroundStyle(color)
            .opacity(active ? 1 : 0)
            .accessibilityHidden(!active)
    }
}

private struct AnimatedNetworkDirectionRow: View {
    let arrow: String
    let bytesPerSecond: Double
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            Text(arrow)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: NetworkSpeedLayout.arrowWidth, alignment: .center)

            AnimatedNetworkMetricValue(
                bytesPerSecond: bytesPerSecond,
                value: SystemMonitor.networkSpeedMbpsValue
            )
            .foregroundStyle(color.opacity(0.65))
            .animation(MetricCountAnimation.style, value: bytesPerSecond)

            NetworkMetricUnit(
                text: "Mbps",
                color: color.opacity(0.65),
                width: NetworkSpeedLayout.mbpsUnitWidth
            )

            Color.clear
                .frame(width: NetworkSpeedLayout.sectionGap)

            AnimatedNetworkMetricValue(
                bytesPerSecond: bytesPerSecond,
                value: { SystemMonitor.networkSpeedComponents($0).value }
            )
            .foregroundStyle(color.opacity(0.65))
            .animation(MetricCountAnimation.style, value: bytesPerSecond)

            FixedNetworkSpeedUnit(bytesPerSecond: bytesPerSecond, color: color.opacity(0.65))
        }
        .frame(width: NetworkSpeedLayout.rowWidth, alignment: .trailing)
    }
}

private struct AnimatedNetworkSpeedText: View {
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            AnimatedNetworkDirectionRow(
                arrow: "↓",
                bytesPerSecond: downloadBytesPerSecond,
                color: GraphMetric.downloadColor
            )
            AnimatedNetworkDirectionRow(
                arrow: "↑",
                bytesPerSecond: uploadBytesPerSecond,
                color: GraphMetric.uploadColor
            )
        }
        .frame(width: NetworkSpeedLayout.rowWidth, alignment: .trailing)
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
