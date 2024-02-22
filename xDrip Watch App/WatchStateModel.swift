//
//  WatchModel.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 11/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Combine
import Foundation
import SwiftUI
import WatchConnectivity

class WatchStateModel: NSObject, ObservableObject {
    
    var session: WCSession
    
    var bgReadingValues: [Double] = [123]
    var bgReadingDates: [Date] = [Date().addingTimeInterval(-200)]
    @Published var isMgDl: Bool = true
    @Published var slopeOrdinal: Int = 5
    @Published var deltaChangeInMgDl: Double = 3
    @Published var urgentLowLimitInMgDl: Double = 60
    @Published var lowLimitInMgDl: Double = 80
    @Published var highLimitInMgDl: Double = 170
    @Published var urgentHighLimitInMgDl: Double = 250
    @Published var updatedDate: Date = Date()
    @Published var activeSensorDescription: String = ""
    @Published var sensorAgeInMinutes: Double = 2880
    @Published var sensorMaxAgeInMinutes: Double = 14400
    
    @Published var updatedString: String = "Updated: 12:34"
    
    init(session: WCSession = .default) {
        self.session = session
        super.init()

        session.delegate = self
        session.activate()
    }
    
    func bgValueInMgDl() -> Double {
        return bgReadingValues[0]
    }
    
    func bgReadingDate() -> Date {
        return bgReadingDates[0]
    }
    
    func bgUnitString() -> String {
        return isMgDl ? Texts_Common.mgdl : Texts_Common.mmol
    }
    
    func bgValueStringInUserChosenUnit() -> String {
        return bgReadingValues[0].mgdlToMmolAndToString(mgdl: isMgDl)
    }
    
    /// Blood glucose color dependant on the user defined limit values
    /// - Returns: a Color object either red, yellow or green
    func getBgColor() -> Color {
        if bgValueInMgDl() >= urgentHighLimitInMgDl || bgValueInMgDl() <= urgentLowLimitInMgDl {
            return .red
        } else if bgValueInMgDl() >= highLimitInMgDl || bgValueInMgDl() <= lowLimitInMgDl {
            return .yellow
        } else {
            return .green
        }
    }
    
    
    ///  returns a string holding the trend arrow
    /// - Returns: trend arrow string (i.e.  "↑")
    func trendArrow() -> String {
        switch slopeOrdinal {
        case 7:
            return "\u{2193}\u{2193}" // ↓↓
        case 6:
            return "\u{2193}" // ↓
        case 5:
            return "\u{2198}" // ↘
        case 4:
            return "\u{2192}" // →
        case 3:
            return "\u{2197}" // ↗
        case 2:
            return "\u{2191}" // ↑
        case 1:
            return "\u{2191}\u{2191}" // ↑↑
        default:
            return ""
        }
    }
    
    /// convert the optional delta change int (in mg/dL) to a formatted change value in the user chosen unit making sure all zero values are shown as a positive change to follow Nightscout convention
    /// - Returns: a string holding the formatted delta change value (i.e. +0.4 or -6)
    func getDeltaChangeStringInUserChosenUnit() -> String {
            
            let valueAsString = deltaChangeInMgDl.mgdlToMmolAndToString(mgdl: isMgDl)
            
            var deltaSign: String = ""
            if (deltaChangeInMgDl > 0) { deltaSign = "+"; }
            
            // quickly check "value" and prevent "-0mg/dl" or "-0.0mmol/l" being displayed
            // show unitized zero deltas as +0 or +0.0 as per Nightscout format
            if (isMgDl) {
                if (deltaChangeInMgDl > -1) && (deltaChangeInMgDl < 1) {
                    return "+0"
                } else {
                    return deltaSign + valueAsString
                }
            } else {
                if (deltaChangeInMgDl > -0.1) && (deltaChangeInMgDl < 0.1) {
                    return "+0.0"
                } else {
                    return deltaSign + valueAsString
                }
            }
    }
    
    func activeSensorProgress() -> (progress: Float, progressColor: Color, textColor: Color) {
        
        let sensorTimeLeftInMinutes = sensorMaxAgeInMinutes - sensorAgeInMinutes
        
        let progress = Float(1 - (sensorTimeLeftInMinutes / sensorMaxAgeInMinutes))
        
        // irrespective of all the above, if the current sensor age is over the max age, then just set everything to the expired colour to make it clear
        if sensorTimeLeftInMinutes < 0 {
            
            return (1.0, ConstantsHomeView.sensorProgressExpiredSwiftUI, ConstantsHomeView.sensorProgressExpiredSwiftUI)
            
        } else if sensorTimeLeftInMinutes <= ConstantsHomeView.sensorProgressViewUrgentInMinutes {
            
            return (progress, ConstantsHomeView.sensorProgressViewProgressColorUrgentSwiftUI, ConstantsHomeView.sensorProgressViewProgressColorUrgentSwiftUI)
            
        } else if sensorTimeLeftInMinutes <= ConstantsHomeView.sensorProgressViewWarningInMinutes {
            
            return (progress, ConstantsHomeView.sensorProgressViewProgressColorWarningSwiftUI, ConstantsHomeView.sensorProgressViewProgressColorWarningSwiftUI)
            
        } else {
            
            return (progress, ConstantsHomeView.sensorProgressViewNormalColorSwiftUI, ConstantsHomeView.sensorProgressNormalTextColorSwiftUI)
        }
    }
    
    
    func requestWatchStateUpdate() {
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        
        print("Requesting watch state update to iOS companion app")
        session.sendMessage(["requestWatchStateUpdate": true], replyHandler: nil) { error in
            print("WatchStateModel error: " + error.localizedDescription)
        }
    }
    
    private func processState(_ watchState: WatchState) {
        bgReadingValues = watchState.bgReadingValues //?? [Double]()
        bgReadingDates = watchState.bgReadingDates //?? [Date]()
        isMgDl = watchState.isMgDl ?? true
        slopeOrdinal = watchState.slopeOrdinal ?? 5
        deltaChangeInMgDl = watchState.deltaChangeInMgDl ?? 2
        urgentLowLimitInMgDl = watchState.urgentLowLimitInMgDl ?? 60
        lowLimitInMgDl = watchState.lowLimitInMgDl ?? 80
        highLimitInMgDl = watchState.highLimitInMgDl ?? 180
        urgentHighLimitInMgDl = watchState.urgentHighLimitInMgDl ?? 240
        updatedDate = watchState.updatedDate ?? Date()
        activeSensorDescription = watchState.activeSensorDescription ?? ""
        sensorAgeInMinutes = watchState.sensorAgeInMinutes ?? 0
        sensorMaxAgeInMinutes = watchState.sensorMaxAgeInMinutes ?? 0
        
        updatedString = "BG: \(bgReadingDate().formatted(date: .omitted, time: .shortened)) / State: \(Date().formatted(date: .omitted, time: .shortened))"
    }
}

extension WatchStateModel: WCSessionDelegate {
#if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {}
#endif
    
    func session(_: WCSession, activationDidCompleteWith state: WCSessionActivationState, error _: Error?) {
        print("WCSession activated: \(state == .activated)")
        requestWatchStateUpdate()
    }

    func session(_: WCSession, didReceiveMessage _: [String: Any]) {}

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("WCSession Reachability: \(session.isReachable)")
    }

    func session(_: WCSession, didReceiveMessageData messageData: Data) {
        if let watchState = try? JSONDecoder().decode(WatchState.self, from: messageData) {
            DispatchQueue.main.async {
                print("Received watch state from iOS")
                self.processState(watchState)
            }
        }
    }
}
