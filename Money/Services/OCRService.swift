import Foundation
import Vision
import UIKit

// MARK: - OCR识别结果
struct OCRResult {
    let recognizedText: String
    let confidence: Float
    let boundingBox: CGRect?
    
    init(text: String, confidence: Float = 0.0, boundingBox: CGRect? = nil) {
        self.recognizedText = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

// MARK: - OCR识别服务
class OCRService {
    
    // MARK: - 单例模式
    static let shared = OCRService()
    
    private init() {}
    
    // MARK: - 识别图片中的文字
    func recognizeText(from image: UIImage, completion: @escaping (Result<[OCRResult], Error>) -> Void) {
        print("🔍 开始OCR识别...")
        print("📷 图片信息: 尺寸=\(image.size), 方向=\(image.imageOrientation.rawValue)")
        
        guard let cgImage = image.cgImage else {
            print("❌ 无法获取CGImage")
            completion(.failure(OCRError.invalidImage))
            return
        }
        
        print("📷 CGImage信息: 宽=\(cgImage.width), 高=\(cgImage.height)")
        
        // 创建文字识别请求
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                print("❌ OCR识别请求失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("❌ 没有找到文本识别结果")
                completion(.failure(OCRError.noTextFound))
                return
            }
            
            print("📝 识别到 \(observations.count) 个文本区域")
            let results = self.processTextObservations(observations)
            print("✅ OCR识别完成，共识别到 \(results.count) 个文本块")
            
            // 打印所有识别结果
            for (index, result) in results.enumerated() {
                print("📝 文本[\(index)]: '\(result.recognizedText)' (置信度: \(String(format: "%.2f", result.confidence)))")
            }
            
            completion(.success(results))
        }
        
        // 配置识别参数 - 使用最高精度
        print("🔧 OCR配置: 精确模式, 语言=[zh-CN, en], 语言校正=开启")
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-CN", "en"] // 支持中文和英文
        request.usesLanguageCorrection = true
        
        // 执行识别
        print("🚀 开始执行OCR识别...")
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("❌ OCR执行失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - 处理识别结果
    private func processTextObservations(_ observations: [VNRecognizedTextObservation]) -> [OCRResult] {
        var results: [OCRResult] = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            
            let result = OCRResult(
                text: topCandidate.string,
                confidence: topCandidate.confidence,
                boundingBox: observation.boundingBox
            )
            
            results.append(result)
        }
        
        return results.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - 从相机或相册获取的图片进行识别
    func recognizeTextFromImageData(_ imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let image = UIImage(data: imageData) else {
            completion(.failure(OCRError.invalidImage))
            return
        }
        
        recognizeText(from: image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ocrResults):
                    let fullText = ocrResults.map { $0.recognizedText }.joined(separator: "\n")
                    completion(.success(fullText))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - 预处理图片（提高识别准确率）
    func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: cgImage)
        
        // 增强对比度
        guard let contrastFilter = CIFilter(name: "CIColorControls") else { return image }
        contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.5, forKey: kCIInputContrastKey) // 增加对比度
        contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // 稍微增加亮度
        
        guard let contrastOutput = contrastFilter.outputImage else { return image }
        
        // 锐化
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else { return image }
        sharpenFilter.setValue(contrastOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.8, forKey: kCIInputSharpnessKey)
        
        guard let finalOutput = sharpenFilter.outputImage,
              let processedCGImage = context.createCGImage(finalOutput, from: finalOutput.extent) else {
            return image
        }
        
        return UIImage(cgImage: processedCGImage)
    }
}

// MARK: - OCR错误定义
enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无效的图片"
        case .noTextFound:
            return "未找到可识别的文字"
        case .processingFailed:
            return "图片处理失败"
        }
    }
}

// MARK: - 扩展方法
extension OCRService {
    
    // MARK: - 批量识别多张图片
    func recognizeTextFromImages(_ images: [UIImage], completion: @escaping (Result<[String], Error>) -> Void) {
        let group = DispatchGroup()
        var results: [String] = []
        var hasError: Error?
        
        for image in images {
            group.enter()
            recognizeText(from: image) { result in
                defer { group.leave() }
                
                switch result {
                case .success(let ocrResults):
                    let text = ocrResults.map { $0.recognizedText }.joined(separator: "\n")
                    results.append(text)
                case .failure(let error):
                    hasError = error
                }
            }
        }
        
        group.notify(queue: .main) {
            if let error = hasError {
                completion(.failure(error))
            } else {
                completion(.success(results))
            }
        }
    }
    
    // MARK: - 检查文字是否包含金额信息
    func containsAmount(_ text: String) -> Bool {
        let amountPatterns = [
            "\\d+\\.?\\d*元",
            "¥\\d+\\.?\\d*",
            "\\d+\\.?\\d*[元块]",
            "总金额.*\\d+",
            "金额.*\\d+",
            "支付.*\\d+"
        ]
        
        return amountPatterns.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    // MARK: - 检查文字是否包含商家信息
    func containsMerchant(_ text: String) -> Bool {
        let merchantKeywords = ["收款方", "商家", "店铺", "超市", "餐厅", "药店", "加油站", "便利店"]
        return merchantKeywords.contains { text.contains($0) }
    }
} 