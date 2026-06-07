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

private struct AnimatedNetworkSpeedText: View, Animatable {
    var bytesPerSecond: Double

    var animatableData: Double {
        get { bytesPerSecond }
        set { bytesPerSecond = newValue }
    }

    var body: some View {
        Text(SystemMonitor.formatNetworkSpeed(bytesPerSecond))
            .monospacedDigit()
            .contentTransition(.numericText())
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
                AnimatedNetworkSpeedText(bytesPerSecond: monitor.netBytesPerSecond)
                    .animation(MetricCountAnimation.style, value: monitor.netBytesPerSecond)
            }
        }
    }
}
