//
//  ViewController.swift
//  MOTU PCI Audio setup
//
//  Created by Computer on 15.08.2025.

import Cocoa
import Foundation
import CoreAudio

class ViewController: NSViewController {
    
    
    func findDynamicFilePath() -> String? {
            let currentUser = NSUserName()
            let homeDir = "/Users/\(currentUser)"
            let preferencesDir = homeDir + "/Library/Preferences/com.motu.PCIAudio"
    
            guard FileManager.default.fileExists(atPath: preferencesDir) else {return nil}
    
            var dynamicFilePath: String? = nil
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: preferencesDir)
                let pattern = #"^PCI-424\.bus4\.slot\d+\.plist$"#
                let regex = try NSRegularExpression(pattern: pattern)
    
                for file in files {
                    let range = NSRange(location: 0, length: file.utf16.count)
                    if regex.firstMatch(in: file, options: [], range: range) != nil {
                        dynamicFilePath = preferencesDir + "/" + file
                        break
                    }
                }
            } catch {return nil}
    
            return dynamicFilePath
        }
    
    func getDeviceIDByName(deviceName: String = "PCI-424") -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementWildcard
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        if status != noErr { return nil }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
        if status != noErr { return nil }
        
        for deviceID in deviceIDs {
            var namePropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementWildcard
            )
            
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            let namePtr = UnsafeMutablePointer<CFString?>.allocate(capacity: 1)
            defer { namePtr.deallocate() }
            namePtr.pointee = nil
            status = AudioObjectGetPropertyData(deviceID, &namePropertyAddress, 0, nil, &nameSize, namePtr)
            if status == noErr, let name = namePtr.pointee as String?, name == deviceName {
                return deviceID
            }
        }
        return nil
    }
    
    
    @IBOutlet weak var outputChannel1Button: NSButton!
    @IBOutlet weak var outputChannel2Button: NSButton!
    @IBOutlet weak var outputChannel3Button: NSButton!
    @IBOutlet weak var outputChannel4Button: NSButton!
    @IBOutlet weak var outputChannel5Button: NSButton!
    @IBOutlet weak var outputChannel6Button: NSButton!
    @IBOutlet weak var outputChannel7Button: NSButton!
    @IBOutlet weak var outputChannel8Button: NSButton!
    @IBOutlet weak var outputChannel9Button: NSButton!
    @IBOutlet weak var outputChannel10Button: NSButton!
    @IBOutlet weak var outputChannel11Button: NSButton!
    @IBOutlet weak var outputChannel12Button: NSButton!
    
    
    @IBOutlet weak var inputChannel1Button: NSButton!
    @IBOutlet weak var inputChannel2Button: NSButton!
    @IBOutlet weak var inputChannel3Button: NSButton!
    @IBOutlet weak var inputChannel4Button: NSButton!
    @IBOutlet weak var inputChannel5Button: NSButton!
    @IBOutlet weak var inputChannel6Button: NSButton!
    @IBOutlet weak var inputChannel7Button: NSButton!
    @IBOutlet weak var inputChannel8Button: NSButton!
    @IBOutlet weak var inputChannel9Button: NSButton!
    @IBOutlet weak var inputChannel10Button: NSButton!
    @IBOutlet weak var inputChannel11Button: NSButton!
    @IBOutlet weak var inputChannel12Button: NSButton!
    
    @IBOutlet weak var activeInputsLabel: NSTextField!
    @IBOutlet weak var activeOutputsLabel: NSTextField!
    
    
    
    @IBAction func MotuChannelName(_ sender: NSButton) {
        
        let process = Process()
            process.launchPath = "/usr/bin/open"
            process.arguments = ["-b", "com.motu.ChannelNamerAwesome"]
            process.launch()
        
    }
    
    
    
    
    @IBOutlet weak var enableVolumeConrols: NSButton!
    
    
    @IBAction func InputChannelCheckbox(_ sender: NSButton) {
        replaceChannelStates()
    }
    
    @IBAction func OutputChannelCheckbox(_ sender: NSButton) {
        replaceChannelStates()
    }
            
    
    override func viewDidLoad() {
        super.viewDidLoad()
        getDefaultChannelsOutput()
        getDefaultChannelsInput()
        getSampleRate()
        getClockSource()
        LoadEnableVolumeControls()
        
        inputButtons = [
            inputChannel1Button, inputChannel2Button, inputChannel3Button,
            inputChannel4Button, inputChannel5Button, inputChannel6Button,
            inputChannel7Button, inputChannel8Button, inputChannel9Button,
            inputChannel10Button, inputChannel11Button, inputChannel12Button
        ]
        
        outputButtons = [
            outputChannel1Button, outputChannel2Button, outputChannel3Button,
            outputChannel4Button, outputChannel5Button, outputChannel6Button,
            outputChannel7Button, outputChannel8Button, outputChannel9Button,
            outputChannel10Button, outputChannel11Button, outputChannel12Button
        ]
        
        loadChannelStates()
    }
    
    
    
// Обработка Channels -------------------------------------------------------------------------------------------------
    
    private var inputButtons: [NSButton] = []
    private var outputButtons: [NSButton] = []
    
    private func loadChannelStates() {
        // Прямой поиск по классу com_motu_driver_PCIAudio_Engine
        let matching = IOServiceMatching("com_motu_driver_PCIAudio_Engine")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iterator) == KERN_SUCCESS else { return }
        
        var foundProps: [String: Any]? = nil
        var service = IOIteratorNext(iterator)
        while service != 0 {
            // Получаем имя сервиса как C-строку
            var nameBuffer = [CChar](repeating: 0, count: 128)  // Буфер для имени (стандартный размер для IOKit)
            if IORegistryEntryGetName(service, &nameBuffer) == KERN_SUCCESS {
                let name = String(cString: nameBuffer)
                // Проверяем, совпадает ли имя (хотя бы для надёжности)
                if name == "com_motu_driver_PCIAudio_Engine" {
                    // Читаем свойства
                    var properties: Unmanaged<CFMutableDictionary>?
                    if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                       let props = properties?.takeRetainedValue() as? [String: Any] {
                        foundProps = props
                    }
                    IOObjectRelease(service)
                    break  // Нашли — выходим из цикла
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        
        guard let props = foundProps else { return }
        
        if let inputChannels = props["InputChannels"] as? [[String: Any]] {
            for (index, channel) in inputChannels.enumerated() where index < inputButtons.count {
                if let flags = channel["Flags"] as? UInt32 {
                    inputButtons[index].state = (flags & 0x1) != 0 ? .on : .off
                }
            }
        }
        
        if let outputChannels = props["OutputChannels"] as? [[String: Any]] {
            let channelsPerButton = 2
            for i in 0..<outputButtons.count {
                let firstIndex = i * channelsPerButton
                let secondIndex = firstIndex + 1
                guard secondIndex < outputChannels.count else { continue }
                
                if let firstSource = outputChannels[firstIndex]["Source"] as? UInt32,
                   let secondSource = outputChannels[secondIndex]["Source"] as? UInt32 {
                    let enabled = ((firstSource & 0x1) != 0) || ((secondSource & 0x1) != 0)
                    outputButtons[i].state = enabled ? .on : .off
                }
            }
        }
        
        // Считаем количество активных Input-каналов
        let activeInputCount = inputButtons.reduce(into: 0) { result, button in
                if button.state == .on {
                    result += 2
                }
            }

            // Считаем количество активных Output-каналов, учитывая двойственность
            let activeOutputCount = outputButtons.reduce(into: 0) { result, button in
                if button.state == .on {
                    result += 2
                    
                }
            }

            // Отображаем количество активных каналов на лейбах
            DispatchQueue.main.async {
                self.activeInputsLabel.stringValue = "\(activeInputCount)"
                self.activeOutputsLabel.stringValue = "\(activeOutputCount)"
            }
    }
    
    func replaceChannelStates() {
        guard let plistPath = findDynamicFilePath(), !plistPath.isEmpty else {
            print("Не удалось определить путь к файлу настроек.")
            return
        }

        // Загружаем существующее содержимое файла
        guard let data = FileManager.default.contents(atPath: plistPath),
              let existingData = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let inputChannelsArray = existingData["InputChannels"] as? [Any], // Сохраняем оригинальный массив
              let outputChannelsArray = existingData["OutputChannels"] as? [Any] // Сохраняем оригинальный массив
        else {
            print("Не удалось загрузить существующие настройки из файла.")
            return
        }

        // Создаем копию оригинальных массивов
        var newInputChannels = inputChannelsArray
        var newOutputChannels = outputChannelsArray

        // Обновляем первые 12 элементов InputChannels
        for i in 0 ..< min(inputButtons.count, 12) {
            newInputChannels[i] = inputButtons[i].state == .on
        }

        // Обновляем первые 24 элемента OutputChannels
        for i in stride(from: 0, to: min(outputButtons.count * 2, 24), by: 2) {
            let stateNumber = outputButtons[i / 2].state == .on ? 1 : 0
            newOutputChannels[i] = stateNumber
            newOutputChannels[i+1] = stateNumber
        }

        // Обновляем структуру существующих данных
        var updatedData = existingData
        updatedData["InputChannels"] = newInputChannels
        updatedData["OutputChannels"] = newOutputChannels

        // Преобразование обратно в Data и запись в файл
        guard let newData = try? PropertyListSerialization.data(fromPropertyList: updatedData, format: .xml, options: 0) else {
            print("Ошибка преобразования данных перед сохранением.")
            return
        }

        do {
            try newData.write(to: URL(fileURLWithPath: plistPath))
            print("Настройки успешно сохранены!")
        } catch {
            print("Ошибка сохранения изменений в файл: $error.localizedDescription)")
        }
        
        // Пересчет количества активных каналов после сохранения
        let activeInputCount = inputButtons.filter { $0.state == .on }.map { _ in 2 }.reduce(0, +)
            let activeOutputCount = outputButtons.filter { $0.state == .on }.map { _ in 2 }.reduce(0, +)

            // Обновляем UI
            DispatchQueue.main.async {
                self.activeInputsLabel.stringValue = "\(activeInputCount)"
                self.activeOutputsLabel.stringValue = "\(activeOutputCount)"
            }
    }
    
// обработка Clock Source ----------------------------------------------------------------------
    
    
    
    private func getClockSource() {
        guard let dynamicFilePath = findDynamicFilePath(),
              let dict = NSDictionary(contentsOf: URL(fileURLWithPath: dynamicFilePath)) as? [String: Any],
              let currentValue = dict["ClockSource"] as? Int else { return }
        
        selectClockSource(indexForValue: currentValue)
    }
        private func selectClockSource(indexForValue: Int) {
            switch indexForValue {
            case 0: ClockSource.selectItem(at: 0)  // "Internal"
            case 1: ClockSource.selectItem(at: 1)  // "ADAT"
            case 2: ClockSource.selectItem(at: 2)  // "SMPTE"
            case 3: ClockSource.selectItem(at: 3)  // "Word Clock In"
            default: break
            }
        }
    
    @IBOutlet weak var ClockSource: NSComboBox!
        
        
    @IBAction func clockSourceChanged(_ sender: NSComboBox) {
            let selectedItemIndex = sender.indexOfSelectedItem
            
            // Определение нового значения на основе выбора
            let newValue: Int
            switch selectedItemIndex {
            case 0: newValue = 0   // "Internal"
            case 1: newValue = 1   // "ADAT"
            case 2: newValue = 2   // "SMPTE"
            case 3: newValue = 3   // "Word Clock In"
            default: return
            }
            
            // Сохранение нового значения в plist
            saveNewClockSource(value: newValue)
        }
        
        // Метод для записи нового значения в plist
    func saveNewClockSource(value: Int) {
        guard let dynamicFilePath = findDynamicFilePath(),
              let mutableDict = NSMutableDictionary(contentsOf: URL(fileURLWithPath: dynamicFilePath))
        else {
            print("Ошибка при открытии или поиске файла для записи.")
            return
        }
        
        // Обновление значения в словаре
        mutableDict.setValue(value, forKey: "ClockSource")
        
        // Записываем изменения обратно в файл
        if !mutableDict.write(toFile: dynamicFilePath, atomically: true) {
            print("Ошибка при перезаписи файла.")
        }
    }
    
 // Default Stereo Channels Output -----------------------------------------------------------------------------
    
    @IBOutlet weak var DefaultChannelsOutput: NSComboBox!
    
    @IBAction func DefaultChannelsOutput(_ sender: NSComboBox) {
        
        setDefaultChannelsOutput()
    }

    func getDefaultChannelsOutput() {
        
        guard let deviceID = getDeviceIDByName(deviceName: "PCI-424") else { return }
        
        var totalChannels: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        if sizeStatus != noErr {return}
        
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
        defer { bufferList.deallocate() }
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferList)
        if status == noErr {
            let numBuffers = bufferList.pointee.mNumberBuffers
            let buffersBase = UnsafeRawPointer(bufferList).advanced(by: MemoryLayout<AudioBufferList>.offset(of: \AudioBufferList.mBuffers)!).assumingMemoryBound(to: AudioBuffer.self)
            for i in 0..<numBuffers {
                let buffer = buffersBase[Int(i)]
                totalChannels += buffer.mNumberChannels
            }
        }
        
        // Цикл по парам
        var channelIndex = 1
        while channelIndex <= Int(totalChannels) {
            
            var leftName: String = "Channel \(channelIndex)"
            var leftQualifier = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyChannelNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: UInt32(channelIndex)
            )
            var leftPtr: Unmanaged<CFString>? = nil
            var propertySize: UInt32 = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let leftStatus = AudioObjectGetPropertyData(deviceID, &leftQualifier, 0, nil, &propertySize, &leftPtr)
            if leftStatus == noErr, let name = leftPtr?.takeRetainedValue() as String?, !name.isEmpty {
                leftName = name
            }
            
            let rightIndex = channelIndex + 1
            var pairName: String
            if rightIndex <= Int(totalChannels) {
                // Аналогично для правого
                var rightName: String = "Channel \(rightIndex)"
                var rightQualifier = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyChannelNumberNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: UInt32(rightIndex)
                )
                var rightPtr: Unmanaged<CFString>? = nil
                let rightStatus = AudioObjectGetPropertyData(deviceID, &rightQualifier, 0, nil, &propertySize, &rightPtr)
                if rightStatus == noErr, let name = rightPtr?.takeRetainedValue() as String?, !name.isEmpty {
                    rightName = name
                }
                
                pairName = "\(leftName) - \(rightName)"
                channelIndex += 2
                
                DefaultChannelsOutput.addItem(withObjectValue: pairName)
            }
            
            var preferredChannels: [UInt32] = [0, 0]
            propertyAddress.mSelector = kAudioDevicePropertyPreferredChannelsForStereo
            propertyAddress.mScope = kAudioDevicePropertyScopeOutput
            propertyAddress.mElement = kAudioObjectPropertyElementMain
            propertySize = UInt32(MemoryLayout<[UInt32]>.size)
            let prefStatus = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &preferredChannels)

            if prefStatus == noErr {
                let leftIndex = Int(preferredChannels[0])
                let rightIndex = Int(preferredChannels[1])
                if leftIndex > 0 && rightIndex == leftIndex + 1 && leftIndex % 2 == 1 {
                    let pairIndex = (leftIndex - 1) / 2
                    if pairIndex < DefaultChannelsOutput.numberOfItems {
                        DefaultChannelsOutput.selectItem(at: pairIndex)
                    }
                }
            }
        }
    }
        
     func saveOutputToPlist(preferredOutputValue: Int) {
         guard let filePath = findDynamicFilePath() else {return}
         guard let data = FileManager.default.contents(atPath: filePath) else {return}
         guard var plistDict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {return}
            plistDict["PreferredOutput"] = preferredOutputValue
            guard let plistData = try? PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0),
                  (FileManager.default.createFile(atPath: filePath, contents: plistData, attributes: nil)) else {return}
        }
    
    func setDefaultChannelsOutput() {
            guard let deviceID = getDeviceIDByName(deviceName: "PCI-424") else { return }
            
            let selectedIndex = DefaultChannelsOutput.indexOfSelectedItem
            if selectedIndex < 0 || selectedIndex >= 24 { return }
            
            let channel1 = UInt32(selectedIndex * 2 + 1)
            let channel2 = UInt32(selectedIndex * 2 + 2)
            var channels: [UInt32] = [channel1, channel2]
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyPreferredChannelsForStereo, //0x64636832, // 'dch2'
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementWildcard
            )
            
            let dataSize = UInt32(MemoryLayout<UInt32>.size * channels.count)
            let status = AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, dataSize, &channels)
            if status != noErr {
                print("Error setting default output channels: \(status)")
            }
                // --- Сохранение в plist ---
        
                let preferredOutputValues: [Int] = [
                    0x1,  // каналы 1,2
                    0x3,  // каналы 3,4
                    0x5,  // каналы 5,6
                    0x7,  // каналы 7,8
                    0x9,  // каналы 9,10
                    0x11,  // каналы 11,12
                    0x13,  // каналы 13,14
                    0x15,  // каналы 15,16
                    0x17, // каналы 17,18
                    0x19, // каналы 19,20
                    0x21, // каналы 21,22
                    0x23  // каналы 23,24
                ]
        
        guard selectedIndex < preferredOutputValues.count else {return}
        
                let preferredOutputValue = preferredOutputValues[selectedIndex]
        
        saveOutputToPlist(preferredOutputValue: preferredOutputValue)
            
        }

    
    
// Default Stereo Channels Input  -------------------------------------------------------------------------------------
    
    
    @IBOutlet weak var DefaultChannelsInput: NSComboBox!

    @IBAction func DefaultChannelsInput(_ sender: NSComboBox) {
        setDefaultChannelsInput()
    }

    func getDefaultChannelsInput() {
        
        guard let deviceID = getDeviceIDByName(deviceName: "PCI-424") else { return }
        
        var totalChannels: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        if sizeStatus != noErr {return}
        
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(dataSize))
        defer { bufferList.deallocate() }
        
        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferList)
        if status == noErr {
            let numBuffers = bufferList.pointee.mNumberBuffers
            let buffersBase = UnsafeRawPointer(bufferList).advanced(by: MemoryLayout<AudioBufferList>.offset(of: \AudioBufferList.mBuffers)!).assumingMemoryBound(to: AudioBuffer.self)
            for i in 0..<numBuffers {
                let buffer = buffersBase[Int(i)]
                totalChannels += buffer.mNumberChannels
            }
        }
        
        // Цикл по парам
        var channelIndex = 1
        while channelIndex <= Int(totalChannels) {
            
            var leftName: String = "Channel \(channelIndex)"
            var leftQualifier = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyChannelNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: UInt32(channelIndex)
            )
            var leftPtr: Unmanaged<CFString>? = nil
            var propertySize: UInt32 = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            let leftStatus = AudioObjectGetPropertyData(deviceID, &leftQualifier, 0, nil, &propertySize, &leftPtr)
            if leftStatus == noErr, let name = leftPtr?.takeRetainedValue() as String?, !name.isEmpty {
                leftName = name
            }
            
            let rightIndex = channelIndex + 1
            var pairName: String
            if rightIndex <= Int(totalChannels) {
                // Аналогично для правого
                var rightName: String = "Channel \(rightIndex)"
                var rightQualifier = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyChannelNumberNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: UInt32(rightIndex)
                )
                var rightPtr: Unmanaged<CFString>? = nil
                let rightStatus = AudioObjectGetPropertyData(deviceID, &rightQualifier, 0, nil, &propertySize, &rightPtr)
                if rightStatus == noErr, let name = rightPtr?.takeRetainedValue() as String?, !name.isEmpty {
                    rightName = name
                }
                
                pairName = "\(leftName) - \(rightName)"
                channelIndex += 2
                
                DefaultChannelsInput.addItem(withObjectValue: pairName)
            }
            
            var preferredChannels: [UInt32] = [0, 0]
            propertyAddress.mSelector = kAudioDevicePropertyPreferredChannelsForStereo
            propertyAddress.mScope = kAudioDevicePropertyScopeInput
            propertyAddress.mElement = kAudioObjectPropertyElementMain
            propertySize = UInt32(MemoryLayout<[UInt32]>.size)
            let prefStatus = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &preferredChannels)

            if prefStatus == noErr {
                let leftIndex = Int(preferredChannels[0])
                let rightIndex = Int(preferredChannels[1])
                if leftIndex > 0 && rightIndex == leftIndex + 1 && leftIndex % 2 == 1 {
                    let pairIndex = (leftIndex - 1) / 2
                    if pairIndex < DefaultChannelsInput.numberOfItems {
                        DefaultChannelsInput.selectItem(at: pairIndex)
                    }
                }
            }
        }
    }
        
     func saveInputToPlist(preferredInputValue: Int) {
         guard let filePath = findDynamicFilePath() else {return}
         guard let data = FileManager.default.contents(atPath: filePath) else {return}
         guard var plistDict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {return}
            plistDict["PreferredInput"] = preferredInputValue
            guard let plistData = try? PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0),
                  (FileManager.default.createFile(atPath: filePath, contents: plistData, attributes: nil)) else {return}
        }
    
    func setDefaultChannelsInput() {
            guard let deviceID = getDeviceIDByName(deviceName: "PCI-424") else { return }
            
            let selectedIndex = DefaultChannelsInput.indexOfSelectedItem
            if selectedIndex < 0 || selectedIndex >= 24 { return }
            
            let channel1 = UInt32(selectedIndex * 2 + 1)
            let channel2 = UInt32(selectedIndex * 2 + 2)
            var channels: [UInt32] = [channel1, channel2]
            
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: 0x64636832, // 'dch2'  kAudioDevicePropertyPreferredChannelsForStereo,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 0 //kAudioObjectPropertyElementWildcard
            )
            
            let dataSize = UInt32(MemoryLayout<UInt32>.size * channels.count)
            let status = AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, dataSize, &channels)
            if status != noErr {
                print("Error setting default output channels: \(status)")
            }
        
                // --- Сохранение в plist ---
        
                let preferredInputValues: [Int] = [
                    0x1,  // каналы 1,2
                    0x3,  // каналы 3,4
                    0x5,  // каналы 5,6
                    0x7,  // каналы 7,8
                    0x9,  // каналы 9,10
                    0x11,  // каналы 11,12
                    0x13,  // каналы 13,14
                    0x15,  // каналы 15,16
                    0x17, // каналы 17,18
                    0x19, // каналы 19,20
                    0x21, // каналы 21,22
                    0x23  // каналы 23,24
                ]
        
        guard selectedIndex < preferredInputValues.count else {return}
        
                let preferredInputValue = preferredInputValues[selectedIndex]
        
        saveInputToPlist(preferredInputValue: preferredInputValue)
            
        }

    
    
// Обработка Sample Rate ----------------------------------------------------------------------------------------
    
    
    @IBOutlet weak var readSampleRate: NSComboBox!
    
    @IBAction func writeSampleRate(_ sender: NSComboBox) {
        
        setSampleRate()
    }
    
    func getSampleRate() {
        guard let deviceID = getDeviceIDByName(deviceName: "PCI-424") else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyAvailableNominalSampleRates,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )

        var size: UInt32 = 0

        var result = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &size)

        let numSampleRates = Int(size) / MemoryLayout<AudioValueRange>.size
        var sampleRates = [AudioValueRange](repeating: AudioValueRange(mMinimum: 0, mMaximum: 0), count: numSampleRates)

        result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &size, &sampleRates)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.groupingSize = 3
        formatter.usesGroupingSeparator = true

        readSampleRate.removeAllItems()

        for rate in sampleRates {
            if let formattedRate = formatter.string(from: NSNumber(value: rate.mMinimum)) {
                readSampleRate.addItem(withObjectValue: formattedRate)
            }
        }

        var currentRate: Float64 = 0
        var currentRateSize: UInt32 = UInt32(MemoryLayout<Float64>.size)
        propertyAddress.mSelector = kAudioDevicePropertyNominalSampleRate
        result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &currentRateSize, &currentRate)
        guard result == noErr else { print("Error getting current sample rate: \(result)"); return }

        if let formattedCurrentRate = formatter.string(from: NSNumber(value: currentRate)) {
            readSampleRate.selectItem(withObjectValue: formattedCurrentRate)
        }
    }

    func setSampleRate() {
        guard let deviceID = getDeviceIDByName(deviceName: "PCI-424") else { return }
        guard let selectedRateString = readSampleRate.objectValueOfSelectedItem as? String else { return }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.groupingSize = 3
        formatter.usesGroupingSeparator = true

        guard let selectedRateNSNumber = formatter.number(from: selectedRateString),
              let selectedRate = Float64(exactly: selectedRateNSNumber.doubleValue) else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )

        var newRate: Float64 = selectedRate
        let size: UInt32 = UInt32(MemoryLayout<Float64>.size)

        let result = AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, size, &newRate)

        guard result == noErr else {
            print("Error setting sample rate: \(result)")
            return
        }
        
        saveSampleRateToPlist(sampleRate: newRate)
    }

    
    func saveSampleRateToPlist(sampleRate: Float64) {
        guard let dynamicFilePath = findDynamicFilePath() else {return}
    
            do {
                let existingDict = NSDictionary(contentsOfFile: dynamicFilePath) as? [String : Any] ?? [:]
                var updatedDict = existingDict
                updatedDict["SampleRate"] = NSNumber(value: sampleRate)
                try PropertyListSerialization.data(fromPropertyList: updatedDict, format: .xml, options: 0).write(to: URL(fileURLWithPath: dynamicFilePath))
            } catch {
                print("Ошибка записи в plist:", error.localizedDescription)
            }
        }

    
// Обработка Stream Controls Enable Key ------------------------------------------------------------------------------------------
    
        private func LoadEnableVolumeControls() {
            guard let filePath = findDynamicFilePath(),
                  let data = FileManager.default.contents(atPath: filePath),
                  let rootDict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any],
                  let currentValue = rootDict["StreamControlsEnableKey"] as? Int else { return }
            
            enableVolumeConrols.state = currentValue == 1 ? .on : .off
        }
        
        @IBAction func volumeControlStateChanged(_ sender: NSButton) {
            guard let filePath = findDynamicFilePath(),
                  let data = FileManager.default.contents(atPath: filePath),
                  var rootDict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any]
            else { return }
            
            rootDict["StreamControlsEnableKey"] = sender.state.rawValue
            
            do {
                let updatedData = try PropertyListSerialization.data(fromPropertyList: rootDict, format: .xml, options: 0)
                
                try updatedData.write(to: URL(fileURLWithPath: filePath))
            } catch {
                print("Ошибка обновления plist:", error.localizedDescription)
            }
        }

    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}


   




