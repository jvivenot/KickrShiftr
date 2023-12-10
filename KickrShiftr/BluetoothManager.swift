//
//  BluetoothManager.swift
//  KickrShiftr
//
//  Created by Julien Vivenot on 06/12/2023.
//

import CoreBluetooth

protocol BluetoothManagerProtocol {
    func setWheelCircumference(_ meters: Double)
    func setWheelCircumference_callback(perform: @escaping (_ error: Error?) -> ())
    func isConnected() -> Bool
    func foundCharacteristic() -> Bool
    func deviceName() -> String
}

class BluetoothManager : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, BluetoothManagerProtocol {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var config_characteristic: CBCharacteristic?
    private var connected: Bool = false
    private var callback: ((_ error: Error?) -> ())?
    
    let services = [
        //CBUUID(string: "1826"), // fitness machine
        CBUUID(string: "1818"),  // cycling power
    ]
    
    let configUUID = CBUUID(string: "A026E005-0A7D-4AB3-97FA-F1500F9FEB8B") // what I found reverse-engineering the wheel circumference setting
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    deinit {
        if let peripheral, connected {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var error: String?
        switch central.state {
        case .poweredOn:
            runScan()
        case .poweredOff:
            error = "Please turn on Bluetooth"
        case .unauthorized:
            error = "Please allow Bluetooth access in Settings for this app"
        default:
            break
        }
        if let error {
            // FIXME notify user of issue with bluetooth
            print("Error when initializing Bluetooth: \(error)")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        print("Found peripheral \(peripheral.name ?? "<name unknown>") \(peripheral.identifier) \(RSSI)")
        for v in advertisementData {
            print("    \(v.key) => \(v.value)")
        }
        if let name = peripheral.name, self.peripheral == nil {
            if name.contains("KICKR") {
                self.peripheral = peripheral // need to hold a ref or it will be destroyed when out of scope
                centralManager.connect(peripheral, options:nil)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.connected = true
        peripheral.delegate = self // FIXME should probably have a separate class
        peripheral.discoverServices(services)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // FIXME handle error
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        print("Discovered services (\(peripheral.name ?? peripheral.identifier.uuidString)): ")
        for s in services {
            print ("    Service: \(s.description) uuid:\(s.uuid)")
        }
        for service in services {
            //peripheral.discoverCharacteristics(nil, for: service)
            peripheral.discoverCharacteristics([configUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        print("Characteristics for service \(service.uuid) on  (\(peripheral.name ?? peripheral.identifier.uuidString)):")
        for c in characteristics {
            print("    characteristic: \(c.description) uuid:\(c.uuid)")
            config_characteristic = c
        }
    }
    
    func setWheelCircumference(_ meters: Double)
    {
        guard let peripheral, let config_characteristic else {
            return
        }
        guard meters < 6.5535 else {
            return
        }
        let value = UInt16(meters * 10000) // tenth of millimeter, same as bluetooth spec, max 6.5535m
        let data : [UInt8] = [
            0x48, // wheel circumference field, found by reverse engineering
            UInt8(value & 0xff), // per packet logging, it seems value is little endian
            UInt8(value >> 8)
        ]
        let ts = Int64(Date().timeIntervalSince1970 * 1000)
        print("\(ts): Setting circumference to \(meters)m: \(data)")
        peripheral.writeValue(Data(data), for: config_characteristic, type: .withResponse)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let ts = Int64(Date().timeIntervalSince1970 * 1000)
        if let error {
            print("\(ts): Issue while writing: \(error)")
        } else {
            print("\(ts): succeeded")
        }
        callback?(error)
    }
    
    func runScan() {
        centralManager.scanForPeripherals(withServices: services, options: nil)
    }
    
    func isConnected() -> Bool {
        return connected
    }
    
    func foundCharacteristic() -> Bool {
        return config_characteristic != nil
    }
    
    func setWheelCircumference_callback(perform: @escaping (_ error: Error?) -> ()) {
        callback = perform
    }
    
    func deviceName() -> String {
        return peripheral?.name ?? "<unknown>"
    }
}

class MockBluetoothManager : BluetoothManagerProtocol {
    
    private var found_info = false
    private var callback: ((_ error: Error?) -> ())?
    
    init() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { timer in
            self.found_info = true
        }
    }
    
    enum MockError : Error {
        case ValueError
    }
    
    func setWheelCircumference(_ meters: Double) {
        print("Mock: Setting wheel circumference to \(meters)")
        var error : Error? = nil
        if meters > 6.5536 {
            error = MockError.ValueError
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
            self.callback?(error)
        }
    }
    
    func isConnected() -> Bool {
        return true
    }
    
    func foundCharacteristic() -> Bool {
        return found_info
    }
    
    func setWheelCircumference_callback(perform: @escaping (_ error: Error?) -> ()) {
        callback = perform
    }
    
    func deviceName() -> String {
        return "MOCK KICKR CORE 42"
    }
}
