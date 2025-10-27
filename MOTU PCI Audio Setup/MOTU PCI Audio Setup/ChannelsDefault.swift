////
////  ChannelsDefault.swift
////  MOTU PCI Audio Setup
////
////  Created by Computer on 25.10.2025.
////
//
//import Cocoa
//import CoreAudio
//import Foundation
//
//class ChannelsDefault: NSViewController {
//    
//    @IBOutlet weak var DefaultChannelsOutput: NSComboBox!
//    
//    @IBAction func DefaultChannelsOutput(_ sender: NSComboBox) {
//        setDefaultChannelsOutput()
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        getDefaultChannelsOutput()
//    }
//    
//    func findDynamicFilePath() -> String? {
//        let currentUser = NSUserName()
//        let homeDir = "/Users/\(currentUser)"
//        let preferencesDir = homeDir + "/Library/Preferences/com.motu.PCIAudio"
//
//        guard FileManager.default.fileExists(atPath: preferencesDir) else {return nil}
//
//        var dynamicFilePath: String? = nil
//        do {
//            let files = try FileManager.default.contentsOfDirectory(atPath: preferencesDir)
//            let pattern = #"^PCI-424\.bus4\.slot\d+\.plist$"#
//            let regex = try NSRegularExpression(pattern: pattern)
//
//            for file in files {
//                let range = NSRange(location: 0, length: file.utf16.count)
//                if regex.firstMatch(in: file, options: [], range: range) != nil {
//                    dynamicFilePath = preferencesDir + "/" + file
//                    break
//                }
//            }
//        } catch {return nil}
//
//        return dynamicFilePath
//    }
//
//    func getDeviceIDByName(deviceName: String = "PCI-424") -> AudioDeviceID? {
//        var propertyAddress = AudioObjectPropertyAddress(
//            mSelector: kAudioHardwarePropertyDevices,
//            mScope: kAudioObjectPropertyScopeGlobal,
//            mElement: kAudioObjectPropertyElementWildcard
//        )
//        
//        var dataSize: UInt32 = 0
//        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
//        if status != noErr { return nil }
//        
//        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
//        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
//        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
//        if status != noErr { return nil }
//        
//        for deviceID in deviceIDs {
//            var namePropertyAddress = AudioObjectPropertyAddress(
//                mSelector: kAudioDevicePropertyDeviceNameCFString,
//                mScope: kAudioObjectPropertyScopeGlobal,
//                mElement: kAudioObjectPropertyElementWildcard
//            )
//            
//            var nameSize = UInt32(MemoryLayout<CFString>.size)
//            let namePtr = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
//            defer { namePtr.deallocate() }
//            namePtr.pointee = nil
//            status = AudioObjectGetPropertyData(deviceID, &namePropertyAddress, 0, nil, &nameSize, namePtr)
//            if status == noErr, let name = namePtr.pointee as String?, name == deviceName {
//                return deviceID
//            }
//        }
//        return nil
//    }
//
//    func getDefaultChannelsOutput() {
//        
//        guard let deviceID = getDeviceIDByName(deviceName: "PCI-424") else { return }
//        
//        var totalChannels: UInt32 = 0
//        var propertyAddress = AudioObjectPropertyAddress(
//            mSelector: kAudioDevicePropertyStreamConfiguration,
//            mScope: kAudioDevicePropertyScopeOutput,
//            mElement: kAudioObjectPropertyElementMain
//        )
//        
//        var dataSize: UInt32 = 0
//        let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
//        if sizeStatus != noErr {return}
//        
//        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
//        defer { bufferList.deallocate() }
//        
//        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferList)
//        if status == noErr {
//            let numBuffers = bufferList.pointee.mNumberBuffers
//            let buffersBase = UnsafeRawPointer(bufferList).advanced(by: MemoryLayout<AudioBufferList>.offset(of: \AudioBufferList.mBuffers)!).assumingMemoryBound(to: AudioBuffer.self)
//            for i in 0..<numBuffers {
//                let buffer = buffersBase[Int(i)]
//                totalChannels += buffer.mNumberChannels
//            }
//        }
//        
//        // Цикл по парам
//        var channelIndex = 1
//        while channelIndex <= Int(totalChannels) {
//            
//            var leftName: String = "Channel \(channelIndex)"
//            var leftQualifier = AudioObjectPropertyAddress(
//                mSelector: kAudioDevicePropertyChannelNameCFString,
//                mScope: kAudioObjectPropertyScopeGlobal,
//                mElement: UInt32(channelIndex)
//            )
//            var leftPtr: Unmanaged<CFString>? = nil
//            var propertySize: UInt32 = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
//            let leftStatus = AudioObjectGetPropertyData(deviceID, &leftQualifier, 0, nil, &propertySize, &leftPtr)
//            if leftStatus == noErr, let name = leftPtr?.takeRetainedValue() as String?, !name.isEmpty {
//                leftName = name
//            }
//            
//            let rightIndex = channelIndex + 1
//            var pairName: String
//            if rightIndex <= Int(totalChannels) {
//                // Аналогично для правого
//                var rightName: String = "Channel \(rightIndex)"
//                var rightQualifier = AudioObjectPropertyAddress(
//                    mSelector: kAudioDevicePropertyChannelNumberNameCFString,
//                    mScope: kAudioObjectPropertyScopeGlobal,
//                    mElement: UInt32(rightIndex)
//                )
//                var rightPtr: Unmanaged<CFString>? = nil
//                let rightStatus = AudioObjectGetPropertyData(deviceID, &rightQualifier, 0, nil, &propertySize, &rightPtr)
//                if rightStatus == noErr, let name = rightPtr?.takeRetainedValue() as String?, !name.isEmpty {
//                    rightName = name
//                }
//                
//                pairName = "\(leftName) - \(rightName)"
//                channelIndex += 2
//                
//                DefaultChannelsOutput.addItem(withObjectValue: pairName)
//            }
//            
//            var preferredChannels: [UInt32] = [0, 0]
//            propertyAddress.mSelector = kAudioDevicePropertyPreferredChannelsForStereo
//            propertyAddress.mScope = kAudioDevicePropertyScopeOutput
//            propertyAddress.mElement = kAudioObjectPropertyElementMain
//            propertySize = UInt32(MemoryLayout<[UInt32]>.size)
//            let prefStatus = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &preferredChannels)
//
//            if prefStatus == noErr {
//                let leftIndex = Int(preferredChannels[0])
//                let rightIndex = Int(preferredChannels[1])
//                if leftIndex > 0 && rightIndex == leftIndex + 1 && leftIndex % 2 == 1 {
//                    let pairIndex = (leftIndex - 1) / 2
//                    if pairIndex < DefaultChannelsOutput.numberOfItems {
//                        DefaultChannelsOutput.selectItem(at: pairIndex)
//                    }
//                }
//            }
//        }
//    }
//        
//     func saveOutputToPlist(preferredOutputValue: Int) {
//         guard let filePath = findDynamicFilePath() else {return}
//         guard let data = FileManager.default.contents(atPath: filePath) else {return}
//         guard var plistDict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {return}
//            plistDict["PreferredOutput"] = preferredOutputValue
//            guard let plistData = try? PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0),
//                  (FileManager.default.createFile(atPath: filePath, contents: plistData, attributes: nil)) else {return}
//        }
//    
//    func setDefaultChannelsOutput() {
//            guard let deviceID = getDeviceIDByName(deviceName: "PCI-424") else { return }
//            
//            let selectedIndex = DefaultChannelsOutput.indexOfSelectedItem
//            if selectedIndex < 0 || selectedIndex >= 24 { return }
//            
//            let channel1 = UInt32(selectedIndex * 2 + 1)
//            let channel2 = UInt32(selectedIndex * 2 + 2)
//            var channels: [UInt32] = [channel1, channel2]
//            
//            var propertyAddress = AudioObjectPropertyAddress(
//                mSelector: 0x64636832, // 'dch2'  kAudioDevicePropertyPreferredChannelsForStereo,
//                mScope: kAudioDevicePropertyScopeOutput,
//                mElement: 0 //kAudioObjectPropertyElementWildcard
//            )
//            
//            let dataSize = UInt32(MemoryLayout<UInt32>.size * channels.count)
//            let status = AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, dataSize, &channels)
//            if status != noErr {
//                print("Error setting default output channels: \(status)")
//            }
//        
//                // --- Сохранение в plist ---
//        
//                let preferredOutputValues: [Int] = [
//                    0x1,  // каналы 1,2
//                    0x3,  // каналы 3,4
//                    0x5,  // каналы 5,6
//                    0x7,  // каналы 7,8
//                    0x9,  // каналы 9,10
//                    0x11,  // каналы 11,12
//                    0x13,  // каналы 13,14
//                    0x15,  // каналы 15,16
//                    0x17, // каналы 17,18
//                    0x19, // каналы 19,20
//                    0x21, // каналы 21,22
//                    0x23  // каналы 23,24
//                ]
//        
//        guard selectedIndex < preferredOutputValues.count else {return}
//        
//                let preferredOutputValue = preferredOutputValues[selectedIndex]
//        
//        saveOutputToPlist(preferredOutputValue: preferredOutputValue)
//            
//        }
//}
