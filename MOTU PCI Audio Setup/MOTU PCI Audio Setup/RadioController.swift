//
//  RadioController.swift
//  MOTU PCI Audio setuo
//
//  Created by Computer on 15.08.2025.
//

import Cocoa

class RadioController: NSViewController {
    
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

    @IBOutlet weak var button1: NSButton!
    @IBOutlet weak var button2: NSButton!
    @IBOutlet weak var button3: NSButton!
    @IBOutlet weak var button4: NSButton!
    @IBOutlet weak var button5: NSButton!
    @IBOutlet weak var button6: NSButton!

//    let plistPath = "/Users/computer/Library/Preferences/com.motu.PCIAudio/PCI-424.bus4.slot0.plist"

    override func viewDidLoad() {
        super.viewDidLoad()
        _ = findDynamicFilePath()
        loadInitialSettings()
    }

    func loadInitialSettings() {
        guard let dynamicFilePath = findDynamicFilePath(),
              let dict = NSDictionary(contentsOfFile: dynamicFilePath) as? [String: Any],
              let inputLevels = dict["Interfaces"] as? [[String: Any]],
              let inputLevel = inputLevels[0]["DeviceSpecific"] as? [String: Any],
              let level = inputLevel["InputLevels"] as? Int else {
            print("Ошибка при загрузке начальных настроек из plist.")
            return
        }
        
        setSelectedButtons(for: level)
    }

    func setSelectedButtons(for level: Int) {
        switch level {
        case 0:
            button1.state = .on
            button3.state = .on
            button5.state = .on
        case 1:
            button2.state = .on
            button3.state = .on
            button5.state = .on
        case 2:
            button1.state = .on
            button4.state = .on
            button5.state = .on
        case 3:
            button2.state = .on
            button4.state = .on
            button5.state = .on
        case 4:
            button1.state = .on
            button3.state = .on
            button6.state = .on
        case 5:
            button2.state = .on
            button3.state = .on
            button6.state = .on
        case 6:
            button1.state = .on
            button4.state = .on
            button6.state = .on
        case 7:
            button2.state = .on
            button4.state = .on
            button6.state = .on
        case 8:
            break
        default:
            break
        }
    }

    // Обработчик изменения состояний кнопок. обязательно добавить tag 1-6
    @IBAction func buttonClicked(_ sender: NSButton) {
        switch sender.tag {
        case 1...2: // Первая группа (button1 и button2)
            updateGroup(buttons: [button1, button2], selectedIndex: sender.tag - 1)
        case 3...4: // Вторая группа (button3 и button4)
            updateGroup(buttons: [button3, button4], selectedIndex: sender.tag - 3)
        case 5...6: // Третья группа (button5 и button6)
            updateGroup(buttons: [button5, button6], selectedIndex: sender.tag - 5)
        default:
            break
        }
        
        var level: Int = -1
        if button1.state == .on && button3.state == .on && button5.state == .on {
            level = 0
        } else if button2.state == .on && button3.state == .on && button5.state == .on {
            level = 1
        } else if button1.state == .on && button4.state == .on && button5.state == .on {
            level = 2
        } else if button2.state == .on && button4.state == .on && button5.state == .on {
            level = 3
        } else if button1.state == .on && button3.state == .on && button6.state == .on {
            level = 4
        } else if button2.state == .on && button3.state == .on && button6.state == .on {
            level = 5
        } else if button1.state == .on && button4.state == .on && button6.state == .on {
            level = 6
        } else if button2.state == .on && button4.state == .on && button6.state == .on {
            level = 7
        }

        if level != -1 {
            updatePlist(with: level)
        }
    }

    // Функция обновления состояния группы кнопок
    private func updateGroup(buttons: [NSButton], selectedIndex: Int) {
        for i in buttons.indices {
            buttons[i].state = (i == selectedIndex) ? .on : .off
        }
    }

    func updatePlist(with level: Int) {
        guard let dynamicFilePath = findDynamicFilePath(),
              let dict = NSMutableDictionary(contentsOfFile: dynamicFilePath) else { return }

        if var inputLevels = dict["Interfaces"] as? [[String: Any]] {
            if var deviceSpecific = inputLevels[0]["DeviceSpecific"] as? [String: Any] {
                deviceSpecific["InputLevels"] = level
                inputLevels[0]["DeviceSpecific"] = deviceSpecific
                dict["Interfaces"] = inputLevels

                dict.write(toFile: dynamicFilePath, atomically: true)
            }
        }
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}


