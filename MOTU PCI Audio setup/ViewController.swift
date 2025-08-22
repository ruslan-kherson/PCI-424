//
//  ViewController.swift
//  MOTU PCI Audio setuo
//
//  Created by Computer on 15.08.2025.

import Cocoa
import AudioToolbox

// Определяем структуру для удобного хранения информации о частоте
struct FrequencyOption {
    let name: String     // Отображаемое название частоты
    let value: Float64   // Фактическое значение частоты
}

class ViewController: NSViewController {
    
    // Путь к вашему plist-файлу. Изменить имя пользователя. и номер слота, если у вас другой.
    let filePath = "/Users/computer/Library/Preferences/com.motu.PCIAudio/PCI-424.bus4.slot0.plist"
    
    
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
    
    @IBOutlet weak var activeOutputChannelsCountLabel: NSTextField!
    
    
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
    
    @IBOutlet weak var activeInputChannelsCountLabel: NSTextField!
    
    
    
    @IBOutlet weak var ClockSource: NSComboBox!
    
    @IBOutlet weak var defaultOutput: NSComboBox!
    
    @IBOutlet weak var defaultInput: NSComboBox!
    
    @IBOutlet weak var sampleRateComboBox: NSComboBox!
    
    @IBOutlet weak var enableVolumeConrols: NSButton!
            
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadOutputChannelStates()
        loadInputChannelStates()
        loadCurrentClockSource()
        loadCurrentDefaultOutput()
        loadCurrentDefaultInput()
        loadCurrentSampleRate()
        LoadEnableVolumeControls()
        updateActiveOutputChannelsCountLabel()
        updateActiveInputChannelsCountLabel()// Здесь обновляем метку
        self.sampleRateComboBox.target = self
        self.sampleRateComboBox.action = #selector(sampleRateChanged(_:))
    }
    
// Обработка OutputChannels -----------------------------------------------------
    
    private func countActiveOutputChannels() -> Int {
        guard let data = FileManager.default.contents(atPath: filePath),
              let rootDict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any],
              let outputChannels = rootDict["OutputChannels"] as? [NSNumber]
        else {
            return 0
        }
        
        // Фильтруем только первые 24 элемента массива
        return Array(outputChannels.prefix(24)).filter { $0.boolValue }.count
    }

    private func updateActiveOutputChannelsCountLabel() {
        activeOutputChannelsCountLabel.stringValue = String(countActiveOutputChannels())
    }
    
    // Связываем каждую кнопку с соответствующим набором индексов Output
    lazy var buttonsAndIndexes: [(button: NSButton, indexes: (Int, Int))] = [
        (outputChannel1Button, (0, 1)),
        (outputChannel2Button, (2, 3)),
        (outputChannel3Button, (4, 5)),
        (outputChannel4Button, (6, 7)),
        (outputChannel5Button, (8, 9)),
        (outputChannel6Button, (10, 11)),
        (outputChannel7Button, (12, 13)),
        (outputChannel8Button, (14, 15)),
        (outputChannel9Button, (16, 17)),
        (outputChannel10Button, (18, 19)),
        (outputChannel11Button, (20, 21)),
        (outputChannel12Button, (22, 23))
    ]
    
    // Функция для считывания текущего состояния каналов Output
    private func loadOutputChannelStates() {
        do {
            guard let data = FileManager.default.contents(atPath: filePath),
                  let rootDict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any],
                  let outputChannels = rootDict["OutputChannels"] as? [NSNumber]
            else {
                print("Ошибка при чтении файла или структуре.")
                return
            }
            
            // Установим состояние кнопок в зависимости от значений из массива
            for buttonPair in buttonsAndIndexes {
                let index1 = buttonPair.indexes.0
                let index2 = buttonPair.indexes.1
                
                if outputChannels.indices.contains(index1), outputChannels.indices.contains(index2) {
                    let value = outputChannels[index1].boolValue
                    buttonPair.button.state = value ? .on : .off
                }
            }
        } catch {
            print("Ошибка при обработке файла:", error.localizedDescription)
        }
    }
    
    // Нажатие кнопки меняет состояние каналов Output. tag 1-12
    @IBAction func toggleOutputChannels(_ sender: NSButton) {
        guard let pairInfo = buttonsAndIndexes.first(where: { $0.button === sender }) else {
            return
        }
        
        doToggle(forIndexes: pairInfo.indexes)
        updateActiveOutputChannelsCountLabel() // здесь обновление метки
    }
    
    // Изменение состояния каналов Output в plist
    private func doToggle(forIndexes indexes: (Int, Int)) {
        do {
            guard let data = FileManager.default.contents(atPath: filePath),
                  let rootDict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any],
                  var channelsArray = rootDict["OutputChannels"] as? [NSNumber]
            else {
                print("Ошибка при чтении файла.")
                return
            }
            
            let idx1 = indexes.0
            let idx2 = indexes.1
            
            if channelsArray.count > idx2 {
                let currentValue = channelsArray[idx1].intValue
                let newValue = currentValue == 0 ? 1 : 0
                
                channelsArray[idx1] = NSNumber(value: newValue)
                channelsArray[idx2] = NSNumber(value: newValue)
                
                var updatedRootDict = rootDict
                updatedRootDict["OutputChannels"] = channelsArray
                
                let newData = try PropertyListSerialization.data(
                    fromPropertyList: updatedRootDict,
                    format: .xml,
                    options: 0
                )
                try newData.write(to: URL(fileURLWithPath: filePath))
                
                print("Каналы успешно обновлены!")
            }
        } catch {
            print("Ошибка при изменении файлов:", error.localizedDescription)
        }
    }
    
// Обработка InputChannels ---------------------------------------------------------------------------------------------------------
    
    // функция подсчёта активных каналов
    private func countActiveInputChannels() -> Int {
        guard let data = FileManager.default.contents(atPath: filePath),
              let rootDict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any],
              let inputChannels = rootDict["InputChannels"] as? [NSNumber]
        else {
            return 0
        }
        
        // Используем prefix(12), чтобы выбрать только первые 12 элементов
        return Array(inputChannels.prefix(12)).filter { $0.boolValue }.count
    }

    private func updateActiveInputChannelsCountLabel() {
        let activeChannelsCount = countActiveInputChannels()
        activeInputChannelsCountLabel.stringValue = String(activeChannelsCount * 2)
    }
    
    // Связываем каждую кнопку с соответствующим набором индексов Input
    lazy var inputButtonsAndIndexes: [(button: NSButton, index: Int)] = [
            (inputChannel1Button, 0),
            (inputChannel2Button, 1),
            (inputChannel3Button, 2),
            (inputChannel4Button, 3),
            (inputChannel5Button, 4),
            (inputChannel6Button, 5),
            (inputChannel7Button, 6),
            (inputChannel8Button, 7),
            (inputChannel9Button, 8),
            (inputChannel10Button, 9),
            (inputChannel11Button, 10),
            (inputChannel12Button, 11)
            ]
    
    private func loadInputChannelStates() {
        do {
            guard let data = FileManager.default.contents(atPath: filePath),
                  let rootDict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any],
                  let inputChannels = rootDict["InputChannels"] as? [NSNumber]
            else {
                print("Ошибка при чтении файла или структуре.")
                return
            }
            
            // Правильно устанавливаем состояние кнопок входов
            for buttonPair in inputButtonsAndIndexes {
                let index = buttonPair.index
                
                if inputChannels.indices.contains(index) {
                    let value = inputChannels[index].boolValue
                    buttonPair.button.state = value ? .on : .off
                }
            }
        } catch {
            print("Ошибка при обработке файла:", error.localizedDescription)
        }
    }
        
        // Обработчик нажатия кнопки Input. без tag
        @IBAction func toggleInputChannels(_ sender: NSButton) {
            guard let pairInfo = inputButtonsAndIndexes.first(where: { $0.button === sender }) else {
                return
            }
            
            doToggleInput(forIndex: pairInfo.index)
            updateActiveInputChannelsCountLabel() // здесь обновление метки
        }
        
        // Метод переключения одного конкретного Input-канала
    private func doToggleInput(forIndex index: Int) {
        do {
            guard let data = FileManager.default.contents(atPath: filePath),
                  let rootDict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any],
                  var channelsArray = rootDict["InputChannels"] as? [NSNumber]
            else {
                print("Ошибка при чтении файла.")
                return
            }
            
            if channelsArray.count > index {
                // Получаем текущее значение и конвертируем его в Bool
                let currentValue = channelsArray[index].boolValue
                let newValue = !currentValue
                
                // Сохраняем новое значение обратно в виде NSNumber
                channelsArray[index] = NSNumber(value: newValue)
                
                var updatedRootDict = rootDict
                updatedRootDict["InputChannels"] = channelsArray
                
                let newData = try PropertyListSerialization.data(
                    fromPropertyList: updatedRootDict,
                    format: .xml,
                    options: 0
                )
                try newData.write(to: URL(fileURLWithPath: filePath))
                
                print("Входные каналы успешно обновлены!")
            }
        } catch {
            print("Ошибка при изменении файлов:", error.localizedDescription)
        }
    }
    
// обработка Clock Source ----------------------------------------------------------------------
    
    private func loadCurrentClockSource() {
        if let dict = NSDictionary(contentsOf: URL(fileURLWithPath: filePath)) as? [String: Any],
           let currentValue = dict["ClockSource"] as? Int {
            selectClockSource(indexForValue: currentValue)
        }
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
        if let mutableDict = NSMutableDictionary(contentsOf: URL(fileURLWithPath: filePath)) {
            // Обновляем значение
            mutableDict.setValue(value, forKey: "ClockSource")
            
            // Перезапись файла plist
            mutableDict.write(toFile: filePath, atomically: true)
        } else {
            print("Ошибка при сохранении нового значения в plist.")
        }
    }
    
 // Озаботка Default Output -----------------------------------------------------------------------------
    
    // Загружаем текущее значение из plist
    private func loadCurrentDefaultOutput() {
        guard let data = FileManager.default.contents(atPath: filePath),
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
        if let data = FileManager.default.contents(atPath: filePath) {
            do {
                return try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any]
            } catch {
                print("Ошибка при чтении файла plist:", error.localizedDescription)
            }
        }
        return nil
    }

    // Записываем новый словарь обратно в plist
    private func writeToPlist(_ dictionary: NSDictionary) {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
            
            // Преобразование строки в URL
            let url = URL(fileURLWithPath: filePath)
            
            // Записываем данные обратно в файл
            try data.write(to: url)
        } catch {
            print("Ошибка при записи файла plist:", error.localizedDescription)
        }
    }
    
// Обработка Input Default -------------------------------------------------------------------------------------
    
    // Загружаем текущее значение из plist
    private func loadCurrentDefaultInput() {
        guard let data = FileManager.default.contents(atPath: filePath),
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
        if let data = FileManager.default.contents(atPath: filePath) {
            do {
                return try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any]
            } catch {
                print("Ошибка при чтении файла plist:", error.localizedDescription)
            }
        }
        return nil
    }

    // Записываем новый словарь обратно в plist
    private func writeToInputDefaultPlist(_ dictionary: NSDictionary) {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
            
            // Преобразование строки в URL
            let url = URL(fileURLWithPath: filePath)
            
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

        // Загружаем текущую частоту из .plist файла
        private func loadCurrentSampleRate() {
            if let dict = NSDictionary(contentsOf: URL(fileURLWithPath: filePath)) as? [String: Any],
               let currentValue = dict["SampleRate"] as? Int {
                selectSampleRate(indexForValue: currentValue)
            }
        }

        // Устанавливаем правильный пункт в комбобокс
        private func selectSampleRate(indexForValue: Int) {
            switch indexForValue {
            case 44100: sampleRateComboBox.selectItem(at: 0)
            case 48000: sampleRateComboBox.selectItem(at: 1)
            case 88200: sampleRateComboBox.selectItem(at: 2)
            case 96000: sampleRateComboBox.selectItem(at: 3)
            default: break
            }
        }

        // Реакция на смену выбранной частоты
        @objc func sampleRateChanged(_ sender: NSComboBox) {
            let index = sender.indexOfSelectedItem
            guard index >= 0 && index < frequencies.count else { return }

            let selectedFrequency = frequencies[index]
            updateSampleRate(newValue: selectedFrequency.value)
        }

        // Изменяет частоту в системе и обновляет .plist файл
        private func updateSampleRate(newValue: Float64) {
            // Записываем новую частоту в .plist файл
            saveNewSampleRateToPlist(value: Int(newValue))

            // Меняем частоту непосредственно в аудиосистеме
            changeSystemSampleRate(newValue)
        }

        // Записываем новое значение частоты в .plist файл
        private func saveNewSampleRateToPlist(value: Int) {
            if let mutableDict = NSMutableDictionary(contentsOf: URL(fileURLWithPath: filePath)) {
                mutableDict.setValue(value, forKey: "SampleRate")
                mutableDict.write(toFile: filePath, atomically: true)
            } else {
                print("Ошибка при сохранении нового значения в plist.")
            }
        }

        // Функция для установки новой частоты через Core Audio
        private func changeSystemSampleRate(_ newSampleRate: Float64) {
            guard let targetDeviceID = findDeviceByName("PCI-424") else {
                print("Устройство с указанным названием не найдено.")
                return
            }

            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyNominalSampleRate,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMaster
            )

            var mutableNewSampleRate = newSampleRate
            let result = AudioObjectSetPropertyData(targetDeviceID, &propertyAddress, 0, nil, UInt32(MemoryLayout<Float64>.size), &mutableNewSampleRate)

            if result != noErr {
                print("Ошибка при установке частоты: $result)")
            } else {
                print("Успешно установили частоту: $newSampleRate) Гц")
            }
        }

        // Поиск устройства по его названию
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
                    print("Ошибка чтения устройств")
                    return nil
                }

                let numDevices = Int(sizeOfArray) / MemoryLayout<AudioDeviceID>.stride
                for i in 0..<numDevices {
                    let deviceID = dataPtr.load(fromByteOffset: i * MemoryLayout<AudioDeviceID>.stride, as: AudioDeviceID.self)

                    // Получаем имя устройства
                    let deviceNameString = getDeviceName(deviceID)
                    if deviceNameString.contains(deviceName) {
                        return deviceID
                    }
                }
            }

            return nil
        }

        // Получаем имя устройства по его ID
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

                AudioObjectGetPropertyData(deviceID, &propAddr, 0, nil, &size, buffer)
                deviceName = buffer.pointee
            }

            return deviceName.map(String.init(describing:)) ?? ""
        }
    
// Обработка Stream Controls Enable Key ------------------------------------------------------------------------------------------
    
    /// Метод для загрузки текущего состояния из plist и установки его в чекбокс
        private func LoadEnableVolumeControls() {
            guard let data = FileManager.default.contents(atPath: filePath),
                  let rootDict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String : Any],
                  let currentValue = rootDict["StreamControlsEnableKey"] as? Int else { return }
            
            enableVolumeConrols.state = currentValue == 1 ? .on : .off
        }
        
        @IBAction func volumeControlStateChanged(_ sender: NSButton) {
            guard let data = FileManager.default.contents(atPath: filePath),
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


   




