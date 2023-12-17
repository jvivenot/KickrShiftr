//
//  ContentView.swift
//  KickrShiftr
//
//  Created by Julien Vivenot on 02/12/2023.
//

import SwiftUI

struct GearChangeButton: View {
    var icon: String
    var color: Color
    var on: () -> Void
    var enabled: Bool
    var hapticLevel:  UIImpactFeedbackGenerator.FeedbackStyle = .medium
    
    var body: some View {
        Button {
            on()
            UIImpactFeedbackGenerator(style: hapticLevel).impactOccurred()
        } label: {
            Image(systemName:icon)
                .resizable()
                .scaledToFit()
                .frame(width:110, height:110)
                .foregroundColor(Color(UIColor.placeholderText))
                .rotationEffect(.degrees(-90))
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
        .tint(color.opacity(1.3))
    }
}

struct ContentView: View {
    @State
    var enabled = false
    @State
    var wheeleditable = false
    
    var previewMode = false
    
    @State
    var prevWheelSize : Double = 0
    
    // 2.096 is the real wheel circumference for a 700x23C wheel
    @State
    var wheelSize : Double = 2.096 {
        didSet {
            if wheeleditable {
                wheeleditable = false
                bt?.setWheelCircumference(wheelSize)
                prevWheelSize = oldValue
            }
        }
    }
    
    // ratio between gears when shiting up/down
    // I checked a few ultegra sprockets. ratio between gears lies between 1.07 and 1.12
    @State
    var ratio : Double = 1.1
    
    @State
    var state : String = "Initializing..."
    
    init(previewMode : Bool) {
        self.previewMode = previewMode
    }
    
     // vertical = compact seems to be the simplest way to determine landscape orientation on iphone. e.g. on my iphone 8, width is always compact https://developer.apple.com/design/human-interface-guidelines/layout#Device-size-classes
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var body: some View {
        VStack {
            Label("KickrShiftr", systemImage: "gear")
                .imageScale(.large)
                .font(.largeTitle)
            Spacer()
            Text(state)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(2)
            Spacer()
            HStack {
                Spacer()
                Grid {
                    if verticalSizeClass == .regular
                    {
                        GridRow {
                            Color.clear
                                .gridCellUnsizedAxes([.horizontal, .vertical])
                            GearChangeButton(
                                icon: "chevron.forward.2",
                                color: .green,
                                on: { speedUp(2) },
                                enabled: (wheeleditable && enabled),
                                hapticLevel: .heavy
                            )
                        }
                        GridRow {
                            GearChangeButton(
                                icon: "chevron.backward",
                                color: .red,
                                on: { speedDown() },
                                enabled: (wheeleditable && enabled)
                            )
                            GearChangeButton(
                                icon: "chevron.forward",
                                color: .green,
                                on: { speedUp() },
                                enabled: (wheeleditable && enabled)
                            )
                        }
                        GridRow {
                            GearChangeButton(
                                icon: "chevron.backward.2",
                                color: .red,
                                on: { speedDown(2) },
                                enabled: (wheeleditable && enabled),
                                hapticLevel: .heavy
                            )
                            Color.clear
                                .gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    } else {
                        GridRow {
                            GearChangeButton(
                                icon: "chevron.backward.2",
                                color: .red,
                                on: { speedDown(2) },
                                enabled: (wheeleditable && enabled),
                                hapticLevel: .heavy
                            )
                            GearChangeButton(
                                icon: "chevron.backward",
                                color: .red,
                                on: { speedDown() },
                                enabled: (wheeleditable && enabled)
                            )
                            GearChangeButton(
                                icon: "chevron.forward",
                                color: .green,
                                on: { speedUp() },
                                enabled: (wheeleditable && enabled)
                            )
                            GearChangeButton(
                                icon: "chevron.forward.2",
                                color: .green,
                                on: { speedUp(2) },
                                enabled: (wheeleditable && enabled),
                                hapticLevel: .heavy
                            )
                        }
                    }
                }
                Spacer()
            }
            Spacer()
            HStack{
                Spacer()
                    .frame(width:30)
                Text("Wheel circumference")
                    .fontWeight(.bold)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                Text("\(wheelSize, specifier: "%.3f")")
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            Slider(
                value : $wheelSize,
                in: 0.5...6.5535,
                step: 0.1,
                label: {},
                minimumValueLabel: {
                    Text("0.5")
                },
                maximumValueLabel: {
                    Text("6.55")
                }, onEditingChanged: { editing in
                    if (!editing) {
                        self.wheelSize = self.wheelSize
                    }
                }
            ).disabled(!wheeleditable || !enabled)
            HStack{
                Spacer()
                .frame(width:30)
                Text("Gear step ratio")
                    .fontWeight(.bold)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                Text("\(ratio, specifier: "%.2f")")
                      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            Slider(
                value: $ratio,
                in: 1.0...2,
                step: 0.1
            ) {} minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                Text("2")
            }
        }
        .padding()
        .onAppear(perform: {
            start()
        })
    }
    
    @State
    var bt : BluetoothManagerProtocol?
    
    func start() {
        state = "Searching device..."
        bt = previewMode ? MockBluetoothManager() : BluetoothManager()
        wheeleditable = true
        bt?.setWheelCircumference_callback(perform: wheelChanged)
        guard let bt else { return }
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard bt.isConnected() else {
                print("Bluetooth not connected to device yet")
                return
            }
            guard bt.foundCharacteristic() else {
                print("Kickr service or characteristic not available yet")
                return
            }
            print("Connection to kickr functional !")
            state = "Connected to \(bt.deviceName())"
            // do not let the screen go dark while the app is used
            UIApplication.shared.isIdleTimerDisabled = true
            enabled = true
            timer.invalidate() // finally connected. get rid of task
        }
    }
    
    func wheelChanged(_ error: Error?) {
        if let error {
            wheelSize = prevWheelSize
            print("Error while changing circumference. Rolling back. error: \(error)")
        }
        wheeleditable = true
    }
    
    func speedUp(_ factor : Double = 1.0) {
        wheelSize *= pow(ratio,factor)
    }
    func speedDown(_ factor : Double = 1.0) {
        wheelSize /= pow(ratio,factor)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(previewMode: true)
    }
}
