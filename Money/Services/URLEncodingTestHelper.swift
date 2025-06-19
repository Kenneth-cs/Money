import Foundation
import UIKit

// MARK: - URL编码测试辅助类
class URLEncodingTestHelper {
    static let shared = URLEncodingTestHelper()
    
    private init() {}
    
    // MARK: - 测试用例数据
    private let testCases = [
        // 中文字符测试
        "滴滴出行 -12.40",
        "美团外卖 ¥32.50",
        "小象超市（原美团买菜-葛庄店）-45.80",
        
        // 特殊字符测试
        "支付宝 -¥15.60",
        "微信支付 ¥-25.30",
        "交易成功 -128.90",
        
        // 混合字符测试
        "McDonald's 汉堡王 $12.50",
        "7-Eleven便利店 ¥8.80",
        "星巴克(Starbucks) ¥45.00",
        
        // 时间相关测试（验证是否会被误识别）
        "17:45 滴滴出行 -12.40",
        "2024-06-16 17:45 支付成功 ¥32.40",
        "17:454", // 你遇到的问题案例
        
        // 特殊符号测试
        "测试@#$%^&*()_+-=[]{}|;':\",./<>?",
        "¥€$£¢₹₽₩₪₫₱₡₨₦₵₴₸₼₲₳₶₷₺₻₽₾₿"
    ]
    
    // MARK: - 执行完整的编码测试
    func runFullEncodingTest() {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 开始URL编码测试")
        print(String(repeating: "=", count: 60))
        
        for (index, testCase) in testCases.enumerated() {
            print("\n📝 测试案例 \(index + 1): '\(testCase)'")
            testURLEncoding(originalText: testCase)
        }
        
        print("\n" + String(repeating: "=", count: 60))
        print("✅ URL编码测试完成")
        print(String(repeating: "=", count: 60))
    }
    
    // MARK: - 测试单个文本的URL编码
    private func testURLEncoding(originalText: String) {
        // 1. 原始文本信息
        print("   📄 原始文本: '\(originalText)'")
        print("   📏 原始长度: \(originalText.count) 字符")
        print("   🔤 UTF-8字节数: \(originalText.utf8.count) 字节")
        
        // 2. URL编码
        guard let encodedText = originalText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("   ❌ URL编码失败")
            return
        }
        print("   🔗 URL编码后: '\(encodedText)'")
        
        // 3. 构造完整URL
        let fullURL = "money://add-expense?text=\(encodedText)"
        print("   🌐 完整URL: \(fullURL)")
        
        // 4. URL解析测试
        guard let url = URL(string: fullURL) else {
            print("   ❌ URL解析失败")
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let textParam = queryItems.first(where: { $0.name == "text" }),
              let decodedText = textParam.value else {
            print("   ❌ URL组件解析失败")
            return
        }
        
        // 5. 解码结果对比
        print("   📤 解码结果: '\(decodedText)'")
        print("   📏 解码长度: \(decodedText.count) 字符")
        
        // 6. 完整性检查
        let isIdentical = originalText == decodedText
        print("   \(isIdentical ? "✅" : "❌") 编码完整性: \(isIdentical ? "完整" : "损坏")")
        
        if !isIdentical {
            print("   🔍 差异分析:")
            print("     - 原始: \(originalText.debugDescription)")
            print("     - 解码: \(decodedText.debugDescription)")
            
            // 字符级别对比
            let originalChars = Array(originalText)
            let decodedChars = Array(decodedText)
            
            if originalChars.count != decodedChars.count {
                print("     - 长度差异: 原始\(originalChars.count) vs 解码\(decodedChars.count)")
            }
            
            for i in 0..<min(originalChars.count, decodedChars.count) {
                if originalChars[i] != decodedChars[i] {
                    print("     - 位置\(i): '\(originalChars[i])' vs '\(decodedChars[i])'")
                }
            }
        }
    }
    
    // MARK: - 测试快捷指令模拟场景
    func testShortcutScenario() {
        print("\n" + String(repeating: "=", count: 60))
        print("📱 快捷指令模拟测试")
        print(String(repeating: "=", count: 60))
        
        // 模拟快捷指令可能遇到的编码问题
        let problematicCases = [
            "17:454", // 你遇到的实际问题
            "滴滴出行", // 纯中文
            "-12.40", // 负数
            "滴滴出行 -12.40", // 完整信息
            "¥32.40", // 货币符号
            "美团外卖（配送费）¥3.50" // 复杂格式
        ]
        
        for testCase in problematicCases {
            print("\n🧪 测试: '\(testCase)'")
            
            // 模拟不同的编码方式
            testDifferentEncodingMethods(text: testCase)
        }
    }
    
    // MARK: - 测试不同编码方法
    private func testDifferentEncodingMethods(text: String) {
        let encodingMethods: [(String, CharacterSet)] = [
            ("urlQueryAllowed", .urlQueryAllowed),
            ("urlPathAllowed", .urlPathAllowed),
            ("urlFragmentAllowed", .urlFragmentAllowed),
            ("urlHostAllowed", .urlHostAllowed)
        ]
        
        for (methodName, characterSet) in encodingMethods {
            if let encoded = text.addingPercentEncoding(withAllowedCharacters: characterSet) {
                print("   \(methodName): '\(encoded)'")
                
                // 测试解码
                if let decoded = encoded.removingPercentEncoding {
                    let isCorrect = decoded == text
                    print("     解码: '\(decoded)' (\(isCorrect ? "✅" : "❌"))")
                }
            }
        }
    }
    
    // MARK: - 生成测试URL供手动测试
    func generateTestURLs() {
        print("\n" + String(repeating: "=", count: 60))
        print("🔗 生成测试URL（可复制到Safari测试）")
        print(String(repeating: "=", count: 60))
        
        let testTexts = [
            "滴滴出行 -12.40",
            "17:454",
            "美团外卖 ¥32.50",
            "测试中文编码"
        ]
        
        for text in testTexts {
            if let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                let url = "money://add-expense?text=\(encoded)"
                print("\n📝 原文: \(text)")
                print("🔗 URL: \(url)")
                print("📋 可复制测试")
            }
        }
    }
} 