//
//  TokiAlarmLiveActivity.swift
//  TokiAlarm
//
//  Created by hyunho lee on 11/20/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TokiAlarmAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TokiAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TokiAlarmAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TokiAlarmAttributes {
    fileprivate static var preview: TokiAlarmAttributes {
        TokiAlarmAttributes(name: "World")
    }
}

extension TokiAlarmAttributes.ContentState {
    fileprivate static var smiley: TokiAlarmAttributes.ContentState {
        TokiAlarmAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TokiAlarmAttributes.ContentState {
         TokiAlarmAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TokiAlarmAttributes.preview) {
   TokiAlarmLiveActivity()
} contentStates: {
    TokiAlarmAttributes.ContentState.smiley
    TokiAlarmAttributes.ContentState.starEyes
}
