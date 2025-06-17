import Foundation
import CoreData

// MARK: - String扩展
extension String {
    func ranges(of pattern: String, options: NSString.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchRange = self.startIndex..<self.endIndex
        
        while let range = self.range(of: pattern, options: options, range: searchRange) {
            ranges.append(range)
            searchRange = range.upperBound..<self.endIndex
        }
        
        return ranges
    }
}

// MARK: - 解析结果
struct ParsedExpenseInfo {
    let amount: Double?
    let merchantName: String?
    let categoryName: String?
    let transactionTime: Date?
    let paymentMethod: String?
    let note: String?
    
    // 置信度评分 (0.0 - 1.0)
    let confidence: Float
    
    init(amount: Double? = nil, 
         merchantName: String? = nil, 
         categoryName: String? = nil, 
         transactionTime: Date? = nil, 
         paymentMethod: String? = nil, 
         note: String? = nil, 
         confidence: Float = 0.0) {
        self.amount = amount
        self.merchantName = merchantName
        self.categoryName = categoryName
        self.transactionTime = transactionTime
        self.paymentMethod = paymentMethod
        self.note = note
        self.confidence = confidence
    }
}

// MARK: - 智能文本解析服务
class TextParsingService {
    
    // MARK: - 单例模式
    static let shared = TextParsingService()
    
    private init() {}
    
    // MARK: - 解析OCR识别的文本
    func parseExpenseInfo(from text: String) -> ParsedExpenseInfo {
        let cleanedText = cleanText(text)
        print("🔍 开始解析文本: \(cleanedText)")
        
        // 检查是否为纯时间格式文本
        if isTimeFormatOnly(cleanedText) {
            print("❌ 检测到纯时间格式文本，跳过解析")
            return ParsedExpenseInfo(confidence: 0.0)
        }
        
        let amount = extractAmount(from: cleanedText)
        let merchant = extractMerchant(from: cleanedText)
        let category = inferCategory(from: cleanedText, merchant: merchant)
        let time = extractTime(from: cleanedText)
        let paymentMethod = extractPaymentMethod(from: cleanedText)
        let note = generateNote(from: cleanedText, merchant: merchant)
        
        // 计算置信度
        let confidence = calculateConfidence(
            amount: amount,
            merchant: merchant,
            category: category,
            time: time,
            paymentMethod: paymentMethod
        )
        
        let result = ParsedExpenseInfo(
            amount: amount,
            merchantName: merchant,
            categoryName: category,
            transactionTime: time,
            paymentMethod: paymentMethod,
            note: note,
            confidence: confidence
        )
        
        print("✅ 解析结果: 金额=\(amount ?? 0), 商家=\(merchant ?? "未知"), 分类=\(category ?? "未知"), 置信度=\(confidence)")
        
        return result
    }
    
    // MARK: - 清理文本
    private func cleanText(_ text: String) -> String {
        // 移除多余的空白字符和换行符
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned
    }
    
    // MARK: - 检查是否为纯时间格式
    private func isTimeFormatOnly(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 常见时间格式
        let timePatterns = [
            "^\\d{1,2}:\\d{2}$",                    // HH:MM 格式 (如 17:04)
            "^\\d{1,2}:\\d{2}:\\d{2}$",             // HH:MM:SS 格式
            "^\\d{4}-\\d{2}-\\d{2}$",               // YYYY-MM-DD 格式
            "^\\d{2}/\\d{2}/\\d{4}$",               // MM/DD/YYYY 格式
            "^\\d{4}年\\d{1,2}月\\d{1,2}日$",        // 中文日期格式
            "^\\d{1,2}月\\d{1,2}日$",                // 中文月日格式
        ]
        
        for pattern in timePatterns {
            if trimmedText.range(of: pattern, options: .regularExpression) != nil {
                print("🕐 检测到时间格式: '\(trimmedText)' 匹配模式: \(pattern)")
                return true
            }
        }
        
        return false
    }
    
    // MARK: - 提取金额
    private func extractAmount(from text: String) -> Double? {
        print("🔍 开始提取金额，原始文本: '\(text)'")
        
        // 金额正则表达式模式 - 按优先级排序，支持负数
        let patterns = [
            // 滴滴出行等交通应用特殊格式
            "滴滴.*?-?(\\d+(?:\\.\\d{1,2})?)",                     // 滴滴出行 -12.40
            "出行.*?-?(\\d+(?:\\.\\d{1,2})?)",                     // 出行类应用
            
            // 支持负数的模式
            "-\\s*¥?(\\d+(?:\\.\\d{1,2})?)",                      // -¥32.40 或 -32.40
            "¥\\s*-?(\\d+(?:\\.\\d{1,2})?)",                     // ¥-32.40 或 ¥32.40
            "-?(\\d+(?:\\.\\d{1,2})?)元",                        // -32.40元 或 32.40元
            
            // 支付应用特定模式
            "交易成功.*?-?(\\d+(?:\\.\\d{1,2})?)",                // 交易成功 -32.40
            "支付成功.*?-?(\\d+(?:\\.\\d{1,2})?)",                // 支付成功 -32.40
            "消费.*?-?(\\d+(?:\\.\\d{1,2})?)",                   // 消费 -32.40
            
            // 原有模式保持
            "金额[：:￥¥]?\\s*-?(\\d+(?:\\.\\d{1,2})?)",          // 金额：32.40
            "总额[：:￥¥]?\\s*-?(\\d+(?:\\.\\d{1,2})?)",          // 总额：32.40
            "支付[：:￥¥]?\\s*-?(\\d+(?:\\.\\d{1,2})?)",          // 支付：32.40
            "收费[：:￥¥]?\\s*-?(\\d+(?:\\.\\d{1,2})?)",          // 收费：32.40
            "实付[：:￥¥]?\\s*-?(\\d+(?:\\.\\d{1,2})?)",          // 实付：32.40
            "合计[：:￥¥]?\\s*-?(\\d+(?:\\.\\d{1,2})?)",          // 合计：32.40
            "-?(\\d+(?:\\.\\d{1,2})?)块",                        // 32.40块
            "价格[：:￥¥]?\\s*-?(\\d+(?:\\.\\d{1,2})?)",          // 价格：32.40
            "费用[：:￥¥]?\\s*-?(\\d+(?:\\.\\d{1,2})?)",          // 费用：32.40
        ]
        
        // 尝试每个模式
        for (index, pattern) in patterns.enumerated() {
            print("🔍 尝试模式 \\(index + 1): \\(pattern)")
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                print("✅ 匹配到: '\\(matchedText)'")
                
                // 提取数字部分
                let numberPattern = "\\d+(?:\\.\\d{1,2})?"
                if let numberRange = matchedText.range(of: numberPattern, options: .regularExpression) {
                    let numberString = String(matchedText[numberRange])
                    if let amount = Double(numberString), amount > 0 {
                        print("💰 找到金额: \\(amount)")
                        return amount
                    }
                }
            }
        }
        
        print("🔍 未找到明确金额标识，尝试提取所有数字...")
        
        // 如果没有找到明确的金额标识，尝试提取所有可能的金额数字
        let numberPattern = "\\d+(?:\\.\\d{1,2})?"
        let matches = text.ranges(of: numberPattern, options: .regularExpression)
        
        var candidates: [Double] = []
        for match in matches {
            let numberString = String(text[match])
            if let number = Double(numberString) {
                print("🔍 发现数字: \\(number) (绝对值: \\(abs(number)))")
                
                // 检查是否像金额
                if isLikelyAmount(number, in: text, at: match) {
                    candidates.append(abs(number))
                    print("✅ 候选金额: \\(abs(number))")
                } else {
                    print("❌ 排除数字: \\(number) (不像金额)")
                }
            }
        }
        
        // 选择最合适的金额
        if let amount = selectBestAmount(from: candidates) {
            print("💰 最终选择金额: \\(amount)")
            return amount
        }
        
        print("❌ 未能提取到金额")
        return nil
    }
    
    // MARK: - 判断数字是否像金额
    private func isLikelyAmount(_ number: Double, in text: String, at range: Range<String.Index>) -> Bool {
        // 获取扩展范围来检查上下文
        let startIndex = text.index(range.lowerBound, offsetBy: -3, limitedBy: text.startIndex) ?? range.lowerBound
        let endIndex = text.index(range.upperBound, offsetBy: 3, limitedBy: text.endIndex) ?? range.upperBound
        let expandedRange = startIndex..<endIndex
        let expandedText = String(text[expandedRange])
        
        print("🔍 检查数字 \(number) 的上下文: '\(expandedText)'")
        
        // 时间格式排除 (如 15:04, 12:30, 17:04)
        let timePatterns = [
            "\\d{1,2}:\\d{2}",           // 基本时间格式 HH:MM
            "\\d{1,2}:\\d{2}:\\d{2}",    // 完整时间格式 HH:MM:SS
            "\\d{2}:\\d{2}",             // 两位数时间格式
        ]
        
        for timePattern in timePatterns {
            if expandedText.range(of: timePattern, options: .regularExpression) != nil {
                print("❌ 排除时间格式: '\(expandedText)' 匹配模式: \(timePattern)")
                return false
            }
        }
        
        // 检查原始文本是否完全是时间格式
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.range(of: "^\\d{1,2}:\\d{2}$", options: .regularExpression) != nil {
            print("❌ 整个文本是时间格式: '\(trimmedText)'")
            return false
        }
        
        // 日期格式排除 (如 2023, 1201, 2024)
        if number >= 1000 && number <= 9999 {
            print("❌ 排除年份格式: \(number)")
            return false
        }
        
        // 月日格式排除 (如 1201, 0304)
        if number >= 100 && number <= 1231 && floor(number) == number {
            let intNumber = Int(number)
            let month = intNumber / 100
            let day = intNumber % 100
            if month >= 1 && month <= 12 && day >= 1 && day <= 31 {
                print("❌ 排除月日格式: \(number)")
                return false
            }
        }
        
        // 过小的数字可能不是金额 (小于0.1)
        if number < 0.1 {
            print("❌ 数字过小: \(number)")
            return false
        }
        
        // 过大的数字可能不是金额 (大于100000)
        if number > 100000 {
            print("❌ 数字过大: \(number)")
            return false
        }
        
        print("✅ 数字 \(number) 通过金额检查")
        return true
    }
    
    // MARK: - 选择最佳金额
    private func selectBestAmount(from candidates: [Double]) -> Double? {
        guard !candidates.isEmpty else { return nil }
        
        // 如果只有一个候选，直接返回
        if candidates.count == 1 {
            return candidates.first
        }
        
        // 多个候选时，选择最合理的一个
        // 优先选择在合理范围内的金额 (0.1 - 10000)
        let reasonableCandidates = candidates.filter { $0 >= 0.1 && $0 <= 10000 }
        
        if reasonableCandidates.count == 1 {
            return reasonableCandidates.first
        }
        
        if !reasonableCandidates.isEmpty {
            // 选择最大的合理金额（通常是实际支付金额）
            return reasonableCandidates.max()
        }
        
        // 如果没有合理的候选，返回最小的正数
        return candidates.filter { $0 > 0 }.min()
    }
    
    // MARK: - 提取商家名称
    private func extractMerchant(from text: String) -> String? {
        print("🔍 开始提取商家名称，文本: '\(text)'")
        
        // 商家名称提取模式 - 按优先级排序
        let patterns = [
            // 交通出行应用特殊格式
            "(滴滴出行|滴滴|出行)",                                 // 滴滴出行
            "(特惠快车|快车|专车|出租车)",                           // 交通工具类型
            
            // 支付应用特定格式
            "([\\u4e00-\\u9fff\\w]{2,10})\\s*-?\\d+\\.\\d{2}",    // 美团 -32.40
            "([\\u4e00-\\u9fff\\w]{2,15})(?:\\s*\\(.*?\\))?\\s*-?\\d+\\.\\d{2}", // 小象超市（原美团买菜-葛庄店）-32.40
            
            // 传统格式
            "收款方[：:]?\\s*([\\u4e00-\\u9fff\\w\\s]{2,20})",      // 收款方：XXX
            "商户[：:]?\\s*([\\u4e00-\\u9fff\\w\\s]{2,20})",        // 商户：XXX
            "店铺[：:]?\\s*([\\u4e00-\\u9fff\\w\\s]{2,20})",        // 店铺：XXX
            "向\\s*([\\u4e00-\\u9fff\\w\\s]{2,20})\\s*付款",        // 向XXX付款
            "付款给\\s*([\\u4e00-\\u9fff\\w\\s]{2,20})",            // 付款给XXX
            
            // 基于关键词的商家识别
            "([\\u4e00-\\u9fff\\w]{2,10})(?:超市|便利店|餐厅|药店|商场|咖啡|奶茶)",
            "([\\u4e00-\\u9fff\\w]{1,8}(?:超市|便利店|餐厅|药店|商场|咖啡|奶茶))",
        ]
        
        // 尝试每个模式
        for (index, pattern) in patterns.enumerated() {
            print("🔍 尝试商家模式 \\(index + 1): \\(pattern)")
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                print("✅ 匹配到商家文本: '\\(matchedText)'")
                
                // 提取商家名称部分 - 使用更简单的方法
                let cleanedMerchant = matchedText
                    .replacingOccurrences(of: "\\d+\\.\\d{2}", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "-", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cleanedMerchant.isEmpty && cleanedMerchant.count >= 2 {
                    // 过滤掉明显不是商家名的词汇
                    let excludeWords = ["交易成功", "支付成功", "消费", "金额", "总额", "支付", "收费", "实付", "合计", "价格", "费用"]
                    if !excludeWords.contains(cleanedMerchant) {
                        print("🏪 找到商家: \\(cleanedMerchant)")
                        return cleanedMerchant
                    }
                }
            }
        }
        
        // 尝试识别常见商家关键词
        print("🔍 尝试识别常见商家关键词...")
        let merchantKeywords = [
            "滴滴": "滴滴出行",
            "美团": "美团",
            "饿了么": "饿了么", 
            "淘宝": "淘宝",
            "京东": "京东",
            "支付宝": "支付宝",
            "微信": "微信支付",
            "星巴克": "星巴克",
            "麦当劳": "麦当劳",
            "肯德基": "肯德基"
        ]
        
        for (keyword, fullName) in merchantKeywords {
            if text.contains(keyword) {
                print("🏪 通过关键词识别商家: \\(fullName)")
                return fullName
            }
        }
        
        print("❌ 未能提取到商家名称")
        return nil
    }
    
    // MARK: - 推断消费分类
    private func inferCategory(from text: String, merchant: String?) -> String? {
        print("🔍 开始推断分类，文本: '\(text)', 商家: '\(merchant ?? "无")'")
        
        // 基于关键词的分类映射
        let categoryKeywords: [String: [String]] = [
            "餐饮": [
                // 外卖平台
                "美团", "饿了么", "百度外卖", "外卖",
                // 餐厅类型
                "餐厅", "饭店", "咖啡", "奶茶", "火锅", "烧烤", "快餐", "美食", "小吃", "食堂",
                "麦当劳", "肯德基", "星巴克", "喜茶", "海底捞", "必胜客"
            ],
            "交通": [
                "滴滴", "uber", "出租车", "网约车", "地铁", "公交", "加油站", "停车", "高速", "过路费", 
                "机票", "火车票", "汽车票", "船票", "共享单车", "摩拜", "哈啰"
            ],
            "购物": [
                // 电商平台
                "淘宝", "京东", "拼多多", "天猫", "苏宁", "唯品会", "小红书",
                // 实体店
                "超市", "便利店", "商场", "专卖店", "百货", "购物", "沃尔玛", "家乐福", "7-11"
            ],
            "医疗": [
                "医院", "药店", "诊所", "体检", "牙科", "眼科", "中医", "西医", "挂号", "药费", "医疗"
            ],
            "娱乐": [
                "电影院", "KTV", "游戏", "娱乐", "酒吧", "夜店", "网吧", "台球", "密室逃脱", "剧本杀"
            ],
            "教育": [
                "学校", "培训", "书店", "教育", "学费", "课程", "辅导", "考试", "报名费"
            ],
            "住房": [
                "房租", "物业", "水费", "电费", "燃气费", "宽带", "装修", "家具", "电器维修"
            ],
            "服饰": [
                "服装", "鞋子", "帽子", "内衣", "运动装", "正装", "休闲装", "包包", "饰品"
            ],
            "数码": [
                "手机", "电脑", "数码", "电子", "苹果", "华为", "小米", "电器", "充电器", "耳机"
            ],
            "生活服务": [
                "理发", "美容", "美甲", "按摩", "洗车", "维修", "快递", "洗衣", "家政"
            ]
        ]
        
        let fullText = "\(text) \(merchant ?? "")"
        print("🔍 完整文本用于分类: '\(fullText)'")
        
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if fullText.contains(keyword) {
                    print("🏷️ 通过关键词 '\(keyword)' 推断分类: \(category)")
                    return category
                }
            }
        }
        
        // 基于商家名称的特殊规则
        if let merchant = merchant {
            // 超市类
            if merchant.contains("超市") || merchant.contains("便利店") || merchant.contains("商场") {
                print("🏷️ 通过商家名称推断分类: 购物")
                return "购物"
            }
            
            // 餐饮类
            if merchant.contains("餐") || merchant.contains("饭") || merchant.contains("食") {
                print("🏷️ 通过商家名称推断分类: 餐饮")
                return "餐饮"
            }
        }
        
        print("❌ 未能推断出分类")
        return nil
    }
    
    // MARK: - 提取交易时间
    private func extractTime(from text: String) -> Date? {
        let timePatterns = [
            "\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}:\\d{2}",  // 2023-12-01 14:30:25
            "\\d{4}/\\d{2}/\\d{2}\\s+\\d{2}:\\d{2}",        // 2023/12/01 14:30
            "\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}",               // 12-01 14:30
            "\\d{2}:\\d{2}",                                 // 14:30
        ]
        
        let formatter = DateFormatter()
        
        for pattern in timePatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let timeString = String(text[match])
                
                // 尝试不同的日期格式
                let formats = [
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy/MM/dd HH:mm",
                    "MM-dd HH:mm",
                    "HH:mm"
                ]
                
                for format in formats {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: timeString) {
                        // 如果只有时间，使用今天的日期
                        if format == "HH:mm" {
                            let calendar = Calendar.current
                            let today = Date()
                            let components = calendar.dateComponents([.hour, .minute], from: date)
                            return calendar.date(bySettingHour: components.hour ?? 0,
                                               minute: components.minute ?? 0,
                                               second: 0,
                                               of: today)
                        }
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 提取支付方式
    private func extractPaymentMethod(from text: String) -> String? {
        let paymentKeywords: [String: String] = [
            "支付宝": "支付宝",
            "微信": "微信",
            "银行卡": "银行卡",
            "信用卡": "信用卡",
            "现金": "现金",
            "余额": "支付宝",
            "花呗": "支付宝",
            "零钱": "微信"
        ]
        
        for (keyword, method) in paymentKeywords {
            if text.contains(keyword) {
                return method
            }
        }
        
        return nil
    }
    
    // MARK: - 生成备注
    private func generateNote(from text: String, merchant: String?) -> String? {
        // 如果有商家信息，优先使用商家作为备注
        if let merchant = merchant {
            return merchant
        }
        
        // 否则从文本中提取有意义的信息作为备注
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 2 && trimmed.count < 50 && !trimmed.contains("¥") && !trimmed.contains("元") {
                return trimmed
            }
        }
        
        return nil
    }
    
    // MARK: - 计算置信度
    private func calculateConfidence(amount: Double?, 
                                   merchant: String?, 
                                   category: String?, 
                                   time: Date?, 
                                   paymentMethod: String?) -> Float {
        var score: Float = 0.0
        
        // 金额权重最高
        if amount != nil {
            score += 0.5
        }
        
        // 商家信息
        if merchant != nil {
            score += 0.2
        }
        
        // 分类信息
        if category != nil {
            score += 0.15
        }
        
        // 时间信息
        if time != nil {
            score += 0.1
        }
        
        // 支付方式
        if paymentMethod != nil {
            score += 0.05
        }
        
        return score
    }
}

// MARK: - 扩展方法
extension TextParsingService {
    
    // MARK: - 批量解析多条文本
    func parseMultipleTexts(_ texts: [String]) -> [ParsedExpenseInfo] {
        return texts.map { parseExpenseInfo(from: $0) }
    }
    
    // MARK: - 验证解析结果
    func validateParsedInfo(_ info: ParsedExpenseInfo) -> Bool {
        // 至少需要有金额信息
        guard info.amount != nil else { return false }
        
        // 金额必须大于0
        guard let amount = info.amount, amount > 0 else { return false }
        
        // 置信度需要达到最低标准
        return info.confidence >= 0.3
    }
    
    // MARK: - 根据解析结果匹配数据库中的分类和账户
    func matchDatabaseEntities(_ info: ParsedExpenseInfo, 
                              categories: [Category], 
                              accounts: [Account]) -> (category: Category?, account: Account?) {
        
        // 匹配分类
        var matchedCategory: Category?
        if let categoryName = info.categoryName {
            matchedCategory = categories.first { $0.name == categoryName }
        }
        
        // 匹配账户
        var matchedAccount: Account?
        if let paymentMethod = info.paymentMethod {
            matchedAccount = accounts.first { $0.name == paymentMethod }
        }
        
        return (matchedCategory, matchedAccount)
    }
} 