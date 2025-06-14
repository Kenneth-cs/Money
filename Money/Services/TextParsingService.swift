import Foundation
import CoreData

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
    
    // MARK: - 提取金额
    private func extractAmount(from text: String) -> Double? {
        // 金额正则表达式模式
        let patterns = [
            "¥(\\d+(?:\\.\\d{1,2})?)",                    // ¥123.45
            "(\\d+(?:\\.\\d{1,2})?)元",                   // 123.45元
            "金额[：:￥¥]?(\\d+(?:\\.\\d{1,2})?)",         // 金额：123.45
            "总额[：:￥¥]?(\\d+(?:\\.\\d{1,2})?)",         // 总额：123.45
            "支付[：:￥¥]?(\\d+(?:\\.\\d{1,2})?)",         // 支付：123.45
            "收费[：:￥¥]?(\\d+(?:\\.\\d{1,2})?)",         // 收费：123.45
            "实付[：:￥¥]?(\\d+(?:\\.\\d{1,2})?)",         // 实付：123.45
            "合计[：:￥¥]?(\\d+(?:\\.\\d{1,2})?)",         // 合计：123.45
            "(\\d+(?:\\.\\d{1,2})?)块",                   // 123.45块
        ]
        
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                
                // 提取数字部分
                let numberPattern = "\\d+(?:\\.\\d{1,2})?"
                if let numberRange = matchedText.range(of: numberPattern, options: .regularExpression) {
                    let numberString = String(matchedText[numberRange])
                    if let amount = Double(numberString), amount > 0 {
                        return amount
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 提取商家名称
    private func extractMerchant(from text: String) -> String? {
        // 商家名称提取模式
        let patterns = [
            "收款方[：:]?([\\u4e00-\\u9fff\\w\\s]{2,20})",      // 收款方：XXX
            "商户[：:]?([\\u4e00-\\u9fff\\w\\s]{2,20})",        // 商户：XXX
            "店铺[：:]?([\\u4e00-\\u9fff\\w\\s]{2,20})",        // 店铺：XXX
            "向([\\u4e00-\\u9fff\\w\\s]{2,20})付款",           // 向XXX付款
            "([\\u4e00-\\u9fff]{2,10})(?:超市|便利店|餐厅|药店|商场)", // XX超市
        ]
        
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                
                // 提取商家名称部分
                if let nameMatch = matchedText.range(of: "([\\u4e00-\\u9fff\\w\\s]{2,20})", options: .regularExpression) {
                    let merchantName = String(matchedText[nameMatch])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !merchantName.isEmpty && merchantName.count >= 2 {
                        return merchantName
                    }
                }
            }
        }
        
        // 如果没有找到明确的商家标识，尝试识别常见商家关键词
        let merchantKeywords = [
            "超市", "便利店", "餐厅", "饭店", "咖啡", "药店", "医院", "加油站",
            "商场", "专卖店", "理发", "美容", "健身", "电影院", "KTV", "酒店"
        ]
        
        for keyword in merchantKeywords {
            if text.contains(keyword) {
                // 尝试提取包含关键词的商家名称
                let keywordPattern = "([\\u4e00-\\u9fff\\w]{1,8}\(keyword))"
                if let match = text.range(of: keywordPattern, options: .regularExpression) {
                    return String(text[match])
                }
            }
        }
        
        return nil
    }
    
    // MARK: - 推断消费分类
    private func inferCategory(from text: String, merchant: String?) -> String? {
        // 基于关键词的分类映射
        let categoryKeywords: [String: [String]] = [
            "餐饮": ["餐厅", "饭店", "咖啡", "奶茶", "火锅", "烧烤", "快餐", "外卖", "美食", "小吃", "食堂"],
            "交通": ["出租车", "滴滴", "uber", "地铁", "公交", "加油站", "停车", "高速", "过路费", "机票", "火车票"],
            "购物": ["超市", "便利店", "商场", "专卖店", "淘宝", "京东", "拼多多", "购物", "百货"],
            "医疗": ["医院", "药店", "诊所", "体检", "牙科", "眼科", "中医", "西医"],
            "娱乐": ["电影院", "KTV", "游戏", "娱乐", "酒吧", "夜店", "网吧", "台球"],
            "教育": ["学校", "培训", "书店", "教育", "学费", "课程", "辅导"],
            "住房": ["房租", "物业", "水费", "电费", "燃气费", "宽带", "装修"],
            "服饰": ["服装", "鞋子", "帽子", "内衣", "运动装", "正装", "休闲装"],
            "数码": ["手机", "电脑", "数码", "电子", "苹果", "华为", "小米", "电器"]
        ]
        
        let fullText = "\(text) \(merchant ?? "")"
        
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if fullText.contains(keyword) {
                    return category
                }
            }
        }
        
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