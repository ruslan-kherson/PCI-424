//
//  ViewController.swift
//  MOTU PCI Audio setup
//
//  Created by Computer on 15.08.2025.

import Cocoa
import AudioToolbox
import Foundation

// Определяем структуру для удобного хранения информации о частоте
struct FrequencyOption {
    let name: String     // Отображаемое название частоты
    let value: Float64   // Фактическое значение частоты
}

class ViewController: NSViewController {
    
    
    
   func findDynamicFilePath() -> String? {
        let currentUser = NSUserName()
        print("Текущий пользователь: \(currentUser)")
        
        let homeDir = "/Users/\(currentUser)"
        let preferencesDir = homeDir + "/Library/Preferences/com.motu.PCIAudio"
        
        guard FileManager.default.fileExists(atPath: preferencesDir) else {
            print("Директория \(preferencesDir) не существует.")
            return nil
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: preferencesDir)
            let pattern = #"^PCI-424\.bus4\.slot\d+\.plist$"#
            let regex = try NSRegularExpression(pattern: pattern)
            
            for file in files {
                let range = NSRange(location: 0, length: file.utf16.count)
                if regex.firstMatch(in: file, options: [], range: range) != nil {
                    let fullPath = preferencesDir + "/" + file
                    print("Найден файл: \(fullPath)")
                    return fullPath
                }
            }
        } catch {
            print("Ошибка при чтении директории: \(error)")
        }
        
        print("Файл с паттерном PCI-424.bus4.slot{номер}.plist не найден.")
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
    
    
    
    @IBOutlet weak var ClockSource: NSComboBox!
    
    @IBOutlet weak var defaultOutput: NSComboBox!
    
    @IBOutlet weak var defaultInput: NSComboBox!
    
    @IBOutlet weak var sampleRateComboBox: NSComboBox!
    
    @IBOutlet weak var enableVolumeConrols: NSButton!
    
    
    @IBAction func InputChannelCheckbox(_ sender: NSButton) {
        replaceChannelStates()
    }
    
    @IBAction func OutputChannelCheckbox(_ sender: NSButton) {
        replaceChannelStates()
    }
            
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadCurrentClockSource()
        loadCurrentDefaultOutput()
        loadCurrentDefaultInput()
        LoadEnableVolumeControls()
        self.sampleRateComboBox.target = self
        self.sampleRateComboBox.action = #selector(comboBoxSelected(_:))
        setInitialFrequencyInComboBox()
        
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
    
    private func loadCurrentClockSource() {
        guard let dynamicFilePath = findDynamicFilePath(),
              let dict = NSDictionary(contentsOf: URL(fileURLWithPath: dynamicFilePath)) as? [String: Any],
              let currentValue = dict["ClockSource"] as? Int else { return }
        
        selectClockSource(indexForValue: currentValue)
    }
        // Выбор правильного пункта в комбобоксе
        private func selectClockSource(indexForValue: Int) {
            switch indexForValue {
            case 0: ClockSource.selectItem(at: 0)  // "Internal"
            case 1: ClockSource.selectItem(at: 1)  // "ADAT"
            case 2: ClockSource.selectItem(at: 2)  // "SMPTE|"
            case 3: ClockSource.selectItem(at: 3)  // "Word Clock In"
            default: break
            }
        }
        
        // Обработчик изменения выбора в комбобоксе
        @IBAction func clockSourceChanged(_ sender: NSComboBox) {
            let selectedItemIndex = sender.indexOfSelectedItem
            
            // Определение нового значения на основе выбора
            let newValue: Int
            switch selectedItemIndex {
            case 0: newValue = 0   // "Internal"
            case 1: newValue = 1   // "ADAT"
            case 2: newValue = 2   // "SMPTE|"
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
    
 // Озаботка Default Output -----------------------------------------------------------------------------
    
    // Загружаем текущее значение из plist
    private func loadCurrentDefaultOutput() {
        guard let filePath = findDynamicFilePath(),
              let data = FileManager.default.contents(atPath: filePath),
              let plistData = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let preferredOutputValue = plistData["PreferredOutput"] as? Int else { return }

        // Устанавливаем индекс соответствующего пункта комбобокса
        switch preferredOutputValue {
            case 1: defaultOutput.selectItem(at: 0)
            case 3: defaultOutput.selectItem(at: 1)
            case 5: defaultOutput.selectItem(at: 2)
            case 7: defaultOutput.selectItem(at: 3)
            case 9: defaultOutput.selectItem(at: 4)
            case 11: defaultOutput.selectItem(at: 5)
            case 13: defaultOutput.selectItem(at: 6)
            case 15: defaultOutput.selectItem(at: 7)
            case 17: defaultOutput.selectItem(at: 8)
            case 19: defaultOutput.selectItem(at: 9)
            case 21: defaultOutput.selectItem(at: 10)
            case 23: defaultOutput.selectItem(at: 11)
            default: break
        }
    }

    // Обработчик события выбора другого элемента в комбобоксе
    @IBAction func outputDefaultChanged(_ sender: NSComboBox) {
        updateOutputDefaultPlistWithSelectedIndex(sender.indexOfSelectedItem)
    }

    // Обновляем файл plist новым значением
    private func updateOutputDefaultPlistWithSelectedIndex(_ index: Int) {
        guard let existingPlist = readPlistFile() else { return }

        // Создаем mutable dictionary напрямую, без опциональности
        let mutableDict = NSMutableDictionary(dictionary: existingPlist)

        // Меняем значение в зависимости от индекса
        let newValue: Int
        switch index {
            case 0: newValue = 1
            case 1: newValue = 3
            case 2: newValue = 5
            case 3: newValue = 7
            case 4: newValue = 9
            case 5: newValue = 11
            case 6: newValue = 13
            case 7: newValue = 15
            case 8: newValue = 17
            case 9: newValue = 19
            case 10: newValue = 21
            case 11: newValue = 23
            // Добавьте остальные индексы до 23
            default: newValue = 1
        }

        mutableDict.setObject(newValue, forKey: "PreferredOutput" as NSString)

        writeToPlist(mutableDict as NSDictionary)
    }

    // Читаем содержимое plist-файла
    private func readPlistFile() -> [String : Any]? {
        guard let dynamicFilePath = findDynamicFilePath(),
              let data = FileManager.default.contents(atPath: dynamicFilePath) else {
                  print("Ошибка при доступе к файлу plist.")
                  return nil
        }
        
        do {
            return try PropertyListSerialization.propertyList(from: data,
                                                             options: [],
                                                             format: nil) as? [String : Any]
        } catch {
            print("Ошибка при разборе файла plist:", error.localizedDescription)
            return nil
        }
    }

    // Записываем новый словарь обратно в plist
    private func writeToPlist(_ dictionary: NSDictionary) {
        guard let dynamicFilePath = findDynamicFilePath() else {
            print("Ошибка: Не удалось найти путь к файлу plist.")
            return
        }
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
            
            // Создаем URL на основе динамического пути
            let url = URL(fileURLWithPath: dynamicFilePath)
            
            // Записываем данные обратно в файл
            try data.write(to: url)
        } catch {
            print("Ошибка при записи файла plist:", error.localizedDescription)
        }
    }
    
// Обработка Input Default -------------------------------------------------------------------------------------
    
    // Загружаем текущее значение из plist
    private func loadCurrentDefaultInput() {
        guard let filePath = findDynamicFilePath(),
              let data = FileManager.default.contents(atPath: filePath),
              let plistData = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let preferredInputValue = plistData["PreferredInput"] as? Int else { return }

        // Устанавливаем индекс соответствующего пункта комбобокса
        switch preferredInputValue {
            case 1: defaultInput.selectItem(at: 0)
            case 3: defaultInput.selectItem(at: 1)
            case 5: defaultInput.selectItem(at: 2)
            case 7: defaultInput.selectItem(at: 3)
            case 9: defaultInput.selectItem(at: 4)
            case 11: defaultInput.selectItem(at: 5)
            case 13: defaultInput.selectItem(at: 6)
            case 15: defaultInput.selectItem(at: 7)
            case 17: defaultInput.selectItem(at: 8)
            case 19: defaultInput.selectItem(at: 9)
            case 21: defaultInput.selectItem(at: 10)
            case 23: defaultInput.selectItem(at: 11)
            default: break
        }
    }

    // Обработчик события выбора другого элемента в комбобоксе
    @IBAction func inputDefaultChanged(_ sender: NSComboBox) {
        updateInputDefaultPlistWithSelectedIndex(sender.indexOfSelectedItem)
    }

    // Обновляем файл plist новым значением
    private func updateInputDefaultPlistWithSelectedIndex(_ index: Int) {
        guard let existingPlist = readPlistFile() else { return }

        // Создаем mutable dictionary напрямую, без опциональности
        let mutableDict = NSMutableDictionary(dictionary: existingPlist)

        // Меняем значение в зависимости от индекса
        let newValue: Int
        switch index {
            case 0: newValue = 1
            case 1: newValue = 3
            case 2: newValue = 5
            case 3: newValue = 7
            case 4: newValue = 9
            case 5: newValue = 11
            case 6: newValue = 13
            case 7: newValue = 15
            case 8: newValue = 17
            case 9: newValue = 19
            case 10: newValue = 21
            case 11: newValue = 23
            // Добавьте остальные индексы до 23
            default: newValue = 1
        }

        mutableDict.setObject(newValue, forKey: "PreferredInput" as NSString)

        writeToPlist(mutableDict as NSDictionary)
    }

    // Читаем содержимое plist-файла
    private func readInputDefaultPlistFile() -> [String : Any]? {
        guard let dynamicFilePath = findDynamicFilePath(),
              let data = FileManager.default.contents(atPath: dynamicFilePath) else {
            print("Ошибка при доступе к файлу plist.")
            return nil
        }
        
        do {
            return try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any]
        } catch {
            print("Ошибка при разборе файла plist:", error.localizedDescription)
            return nil
        }
    }

    // Записываем новый словарь обратно в plist
    private func writeToInputDefaultPlist(_ dictionary: NSDictionary) {
        guard let dynamicFilePath = findDynamicFilePath() else {
            print("Ошибка: Не удалось найти путь к файлу plist.")
            return
        }
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
            
            // Создаем URL на основе динамического пути
            let url = URL(fileURLWithPath: dynamicFilePath)
            
            // Записываем данные обратно в файл
            try data.write(to: url)
        } catch {
            print("Ошибка при записи файла plist:", error.localizedDescription)
        }
    }
    
// Обработка Sample Rate ----------------------------------------------------------------------------------------
    
    // Доступные варианты частот
        let frequencies: [FrequencyOption] = [
            FrequencyOption(name: "44100", value: 44_100),
            FrequencyOption(name: "48000", value: 48_000),
            FrequencyOption(name: "88200", value: 88_200),
            FrequencyOption(name: "96000", value: 96_000)
        ]

    @objc func comboBoxSelected(_ sender: Any?) {
            let index = sampleRateComboBox.indexOfSelectedItem
            guard index >= 0 && index < frequencies.count else { return }
            
            let selectedFrequency = frequencies[index].value
            changeSampleRate(selectedFrequency)
            
            // Сохраняем новое значение SampleRate в plist-файл
            saveToPlist(sampleRate: selectedFrequency)
        }
        
        private func changeSampleRate(_ newSampleRate: Float64) {
            // Ищем нужное устройство по его уникальному имени
            guard let targetDeviceID = findDeviceByName("PCI-424") else { return }
            
            // Создаем изменяемую копию адреса свойства
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyNominalSampleRate,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMaster
            )
            
            // Передача новой частоты по ссылке должна происходить через изменяемую копию
            var mutableNewSampleRate = newSampleRate
            
            // Установка новой частоты выборки
            _ = AudioObjectSetPropertyData(targetDeviceID, &propertyAddress, 0, nil, UInt32(MemoryLayout<Float64>.size), &mutableNewSampleRate)
        }
        
        /// Поиск устройства по его уникальному имени
        private func findDeviceByName(_ deviceName: String) -> AudioDeviceID? {
            var deviceCount = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMaster
            )
            
            var sizeOfArray: UInt32 = 0
            AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &deviceCount, 0, nil, &sizeOfArray)
            
            if let dataPtr = malloc(Int(sizeOfArray)) {
                defer { free(dataPtr) }
                
                let result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceCount, 0, nil, &sizeOfArray, dataPtr)
                if result != noErr {
                    return nil
                }
                
                let numDevices = Int(sizeOfArray) / MemoryLayout<AudioDeviceID>.stride
                for i in 0..<numDevices {
                    let deviceID = dataPtr.load(fromByteOffset: i * MemoryLayout<AudioDeviceID>.stride, as: AudioDeviceID.self)
                    
                    // Читаем имя текущего устройства
                    let deviceNameString = getDeviceName(deviceID)
                    if deviceNameString.contains(deviceName) {
                        return deviceID
                    }
                }
            }
            
            return nil
        }
        
        /// Возвращает имя устройства по его ID
        private func getDeviceName(_ deviceID: AudioDeviceID) -> String {
            var deviceName: CFString?
            var propAddr = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMaster
            )
            
            var size: UInt32 = 0
            AudioObjectGetPropertyDataSize(deviceID, &propAddr, 0, nil, &size)
            
            if size > 0 {
                let buffer = UnsafeMutablePointer<CFString>.allocate(capacity: 1)
                defer { buffer.deallocate() }
                
                _ = AudioObjectGetPropertyData(deviceID, &propAddr, 0, nil, &size, buffer)
                deviceName = buffer.pointee
            }
            
            return deviceName.map(String.init(describing:)) ?? ""
        }
        
        /// Установить начальную частоту в комбобокс
        private func setInitialFrequencyInComboBox() {
            // Получаем текущую частоту устройства
            guard let currentFrequency = readCurrentSystemFrequency(forDeviceNamed: "PCI-424") else { return }
            
            // Ищем подходящую частоту из доступных опций
            let matchingIndex = frequencies.firstIndex { option in
                abs(option.value - currentFrequency) < 1 // Допустимая погрешность 1 Гц
            }
            
            // Если найдена соответствующая частота, выбираем её в комбобоксе
            if let validIndex = matchingIndex {
                sampleRateComboBox.selectItem(at: Int(UInt32(validIndex)))
            }
        }
        
        /// Читает текущую частоту указанного устройства
        private func readCurrentSystemFrequency(forDeviceNamed deviceName: String) -> Float64? {
            // Получаем список всех устройств
            var devicesListForSearch = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                                 mElement: kAudioObjectPropertyElementMaster)
            
            var sizeForSearch: UInt32 = 0
            AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &devicesListForSearch, 0, nil, &sizeForSearch)
            
            // Рассчитываем количество устройств
            let count = Int(sizeForSearch) / MemoryLayout<AudioDeviceID>.size
            let listBuffer = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: count)
            defer { listBuffer.deallocate() }
            
            // Получаем сами устройства
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &devicesListForSearch, 0, nil, &sizeForSearch, listBuffer)
            
            // Ищем устройство с указанным именем
            for i in 0 ..< count {
                let deviceID = listBuffer[i]
                
                // Получаем имя устройства
                let deviceNameString = getDeviceName(deviceID)
                
                // Если нашли устройство с нашим именем
                if deviceNameString.contains(deviceName) {
                    // Получаем частоту устройства
                    var propertyAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyNominalSampleRate,
                        mScope: kAudioDevicePropertyScopeOutput,
                        mElement: kAudioObjectPropertyElementMaster
                    )
                    
                    var sizeFreq: UInt32 = UInt32(MemoryLayout<Float64>.size)
                    var frequencyValue: Float64 = 0
                    
                    let result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &sizeFreq, &frequencyValue)
                    
                    if result == noErr {
                        return frequencyValue
                    } else {
                        break
                    }
                }
            }
            
            return nil
        }
        
        // Функция сохраняет новую частоту в .plist файл
    private func saveToPlist(sampleRate: Float64) {
        guard let dynamicFilePath = findDynamicFilePath() else {
            print("Ошибка: Не удалось найти путь к файлу plist.")
            return
        }
        
        do {
            // Читаем существующее содержимое plist файла
            let existingDict = NSDictionary(contentsOfFile: dynamicFilePath) as? [String : Any] ?? [:]
            
            // Обновляем словарь новым значением 'SampleRate'
            var updatedDict = existingDict
            updatedDict["SampleRate"] = NSNumber(value: sampleRate)
            
            // Записываем обновленные данные обратно в файл
            try PropertyListSerialization.data(fromPropertyList: updatedDict, format: .xml, options: 0).write(to: URL(fileURLWithPath: dynamicFilePath))
        } catch {
            print("Ошибка записи в plist:", error.localizedDescription)
        }
    }
    
// Обработка Stream Controls Enable Key ------------------------------------------------------------------------------------------
    
    /// Метод для загрузки текущего состояния из plist и установки его в чекбокс
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
            
            // Изменяем значение StreamControlsEnableKey
            rootDict["StreamControlsEnableKey"] = sender.state.rawValue
            
            do {
                let updatedData = try PropertyListSerialization.data(fromPropertyList: rootDict, format: .xml, options: 0)
                
                // Запись обновленного plist обратно
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


   




