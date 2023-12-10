//
//  ContentView.swift
//  KickrShiftr
//
//  Created by Julien Vivenot on 02/12/2023.
//

import SwiftUI

struct ContentView: View {
    @State
    var enabled = false
    @State
    var wheeleditable = false
    
    var previewMode = false
    
    @State
    var prevWheelSize : Double = 0
    @State
    var wheelSize : Double = 2.056 {
        didSet {
            if wheeleditable {
                wheeleditable = false
                bt?.setWheelCircumference(wheelSize)
                prevWheelSize = oldValue
            }
        }
    }
    
    @State
    var ratio : Double = 1.1 // 16 gears mean 4.6 total ratio
    
    @State
    var state : String = "Initializing..."
    
    init(previewMode : Bool) {
        self.previewMode = previewMode
    }
    
    struct DebugField: Identifiable {
        var id = UUID()
        var field: String
        var value: String
    }
    @State
    var debug_info : [DebugField] = []
    
    var buttonForeColor: Color {
        get {
            if enabled {
                return Color(UIColor.placeholderText)
            }
            else {
                return Color(UIColor.placeholderText.withAlphaComponent(0.3))
            }
        }
    }

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
                VStack {
                    Button {
                        speedDown()
                    } label: {
                        Image(systemName:"chevron.down")
                            .resizable()
                            .scaledToFit()
                            .frame(width:120, height:120)
                            .foregroundColor(Color(UIColor.placeholderText))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!wheeleditable || !enabled)
                    .tint(.red.opacity(1.3))
                    Image(systemName: "tortoise")
                        .font(.largeTitle)
                        .frame(height:45)
                }
                Spacer()
                VStack {
                    Button {
                        speedUp()
                    } label: {
                        Image(systemName:"chevron.up")
                            .resizable()
                            .scaledToFit()
                            .frame(width:120, height:120)
                            .foregroundColor(Color(UIColor.placeholderText))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!wheeleditable || !enabled)
                    .tint(.green.opacity(1.3))
                    Image(systemName: "hare")
                        .font(.largeTitle)
                        .frame(height:45)
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
                in: 1.0...2.5,
                step: 0.1
            ) {} minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                Text("2.5")
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
        //guard !previewMode else { return }
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
            state = "Connected to \n\(bt.deviceName())"
            UIApplication.shared.isIdleTimerDisabled = true
            enabled = true
            timer.invalidate()
        }
    }
    
    func wheelChanged(_ error: Error?) {
        if let error {
            wheelSize = prevWheelSize
            print("Error while changing circumference. Rolling back. error: \(error)")
        }
        wheeleditable = true
    }
    
    func speedUp() {
        wheelSize *= ratio
    }
    func speedDown() {
        wheelSize /= ratio
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(previewMode: true)
    }
}
