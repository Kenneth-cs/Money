import SwiftUI
import CoreData
import PhotosUI
import UIKit

// MARK: - 添加支出视图
struct AddExpenseView: View {
    
    // MARK: - 环境对象
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 预填充数据
    let prefilledData: URLStateManager.PrefilledExpenseData?
    
    // MARK: - 状态变量
    @State private var amount = ""
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var note = ""
    @State private var selectedDate = Date()
    @State private var categories: [Category] = []
    @State private var accounts: [Account] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // MARK: - OCR和图片相关状态
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var selectedImage: UIImage?
    @State private var isProcessingOCR = false
    @State private var ocrResults: [OCRResult] = []
    @State private var showingOCRResults = false
    @State private var parsedInfo: ParsedExpenseInfo?
    
    // MARK: - 图片选择器
    @State private var photosPickerItem: PhotosPickerItem?
    
    // MARK: - 计算属性
    private var isValidInput: Bool {
        !amount.isEmpty && 
        Double(amount) != nil && 
        Double(amount)! > 0 && 
        selectedCategory != nil && 
        selectedAccount != nil
    }
    
    // MARK: - 初始化方法
    init(prefilledData: URLStateManager.PrefilledExpenseData? = nil) {
        self.prefilledData = prefilledData
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // OCR功能区域
                    ocrSection
                    
                    // 金额输入
                    amountSection
                    
                    // 分类选择
                    categorySection
                    
                    // 账户选择
                    accountSection
                    
                    // 日期选择
                    dateSection
                    
                    // 备注输入
                    noteSection
                }
                .padding()
            }
            .navigationTitle("添加支出")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveExpense()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidInput)
                }
            }
            .onAppear {
                loadData()
                applyPrefilledData()
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    selectedImage = image
                    processImageWithOCR(image)
                }
            }
            .photosPicker(isPresented: $showingPhotosPicker, selection: $photosPickerItem, matching: .images)
            .onChange(of: photosPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        processImageWithOCR(image)
                    }
                }
            }
            .sheet(isPresented: $showingOCRResults) {
                OCRResultsView(
                    results: ocrResults,
                    parsedInfo: parsedInfo
                ) { info in
                    applyParsedInfo(info)
                }
            }
            .actionSheet(isPresented: $showingImagePicker) {
                ActionSheet(
                    title: Text("选择图片"),
                    message: Text("选择图片来源"),
                    buttons: [
                        .default(Text("拍照")) {
                            showingCamera = true
                        },
                        .default(Text("从相册选择")) {
                            showingPhotosPicker = true
                        },
                        .cancel(Text("取消"))
                    ]
                )
            }
        }
    }
    
    // MARK: - OCR功能区域
    private var ocrSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("智能识别")
                .font(.headline)
                .fontWeight(.semibold)
            
            Button(action: {
                showingImagePicker = true
            }) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("拍照识别")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("拍摄支付截图或小票自动识别")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isProcessingOCR {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .disabled(isProcessingOCR)
            
            // 显示已选择的图片
            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已选择图片")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if isProcessingOCR {
                            Text("正在识别中...")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else if !ocrResults.isEmpty {
                            Text("识别完成，点击查看结果")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    if !ocrResults.isEmpty {
                        Button("查看结果") {
                            showingOCRResults = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - 金额输入区域
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("金额")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("¥")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                TextField("0.00", text: $amount)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 分类选择区域
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("分类")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 15) {
                ForEach(categories, id: \.self) { category in
                    CategorySelectionItem(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 账户选择区域
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("账户")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(accounts, id: \.self) { account in
                    AccountSelectionItem(
                        account: account,
                        isSelected: selectedAccount == account
                    ) {
                        selectedAccount = account
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 日期选择区域
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("日期")
                .font(.headline)
                .fontWeight(.semibold)
            
            DatePicker("选择日期", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }
    
    // MARK: - 备注输入区域
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("备注")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("添加备注...", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }
    
    // MARK: - 加载数据
    private func loadData() {
        categories = dataManager.fetchCategories()
        accounts = dataManager.fetchAccounts()
        
        // 默认选择第一个分类和账户
        if selectedCategory == nil {
            selectedCategory = categories.first
        }
        if selectedAccount == nil {
            selectedAccount = accounts.first
        }
    }
    
    // 处理图片OCR识别
    private func processImageWithOCR(_ image: UIImage) {
        isProcessingOCR = true
        
        // 预处理图片
        let processedImage = OCRService.shared.preprocessImage(image) ?? image
        
        // 进行OCR识别
        OCRService.shared.recognizeText(from: processedImage) { result in
            DispatchQueue.main.async {
                isProcessingOCR = false
                
                switch result {
                case .success(let results):
                    ocrResults = results
                    
                    // 解析识别结果
                    let fullText = results.map { $0.recognizedText }.joined(separator: "\n")
                    parsedInfo = TextParsingService.shared.parseExpenseInfo(from: fullText)
                    
                    // 自动显示结果
                    if !results.isEmpty {
                        showingOCRResults = true
                    }
                    
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    // 应用解析的信息
    private func applyParsedInfo(_ info: ParsedExpenseInfo) {
        // 应用金额
        if let amount = info.amount {
            self.amount = String(format: "%.2f", amount)
        }
        
        // 应用分类
        if let categoryName = info.categoryName {
            selectedCategory = categories.first { $0.name == categoryName }
        }
        
        // 应用账户
        if let paymentMethod = info.paymentMethod {
            selectedAccount = accounts.first { $0.name == paymentMethod }
        }
        
        // 应用备注
        if let note = info.note {
            self.note = note
        }
        
        // 应用时间
        if let date = info.transactionTime {
            selectedDate = date
        }
        
        showingOCRResults = false
    }
    
    // 保存支出记录
    private func saveExpense() {
        guard let amountValue = Double(amount),
              let category = selectedCategory,
              let account = selectedAccount else {
            errorMessage = "请填写完整信息"
            showingError = true
            return
        }
        
        // 添加支出记录
        let expense = dataManager.addExpense(
            amount: amountValue,
            category: category,
            account: account,
            note: note.isEmpty ? nil : note,
            date: selectedDate
        )
        
        // 记录创建成功，关闭页面
        dismiss()
    }
    
    // MARK: - 应用预填充数据
    private func applyPrefilledData() {
        guard let prefilledData = prefilledData else { return }
        
        // 填充金额
        amount = prefilledData.amount
        
        // 填充分类
        if let categoryName = prefilledData.category {
            selectedCategory = categories.first { $0.name == categoryName }
        }
        
        // 填充账户
        if let accountName = prefilledData.account {
            selectedAccount = accounts.first { $0.name == accountName }
        }
        
        // 填充备注
        note = prefilledData.note
        
        print("✅ 预填充数据已应用 - 金额: \(amount), 分类: \(selectedCategory?.name ?? "无"), 账户: \(selectedAccount?.name ?? "无"), 备注: \(note)")
    }
}

// MARK: - 相机视图
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - OCR结果显示视图
struct OCRResultsView: View {
    let results: [OCRResult]
    let parsedInfo: ParsedExpenseInfo?
    let onApply: (ParsedExpenseInfo) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 解析结果摘要
                    if let info = parsedInfo {
                        parsedInfoSection(info)
                    }
                    
                    // 原始OCR结果
                    originalResultsSection
                }
                .padding()
            }
            .navigationTitle("识别结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        if let info = parsedInfo {
                            onApply(info)
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(parsedInfo == nil)
                }
            }
        }
    }
    
    // 解析信息摘要
    private func parsedInfoSection(_ info: ParsedExpenseInfo) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("智能解析结果")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(String(format: "置信度: %.0f%%", info.confidence * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            
            VStack(spacing: 12) {
                if let amount = info.amount {
                    InfoRow(label: "金额", value: String(format: "¥%.2f", amount), icon: "yensign.circle.fill", color: .green)
                }
                
                if let merchant = info.merchantName {
                    InfoRow(label: "商家", value: merchant, icon: "storefront.fill", color: .blue)
                }
                
                if let category = info.categoryName {
                    InfoRow(label: "分类", value: category, icon: "tag.fill", color: .orange)
                }
                
                if let payment = info.paymentMethod {
                    InfoRow(label: "支付方式", value: payment, icon: "creditcard.fill", color: .purple)
                }
                
                if let date = info.transactionTime {
                    InfoRow(
                        label: "时间",
                        value: {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .short
                            return formatter.string(from: date)
                        }(),
                        icon: "clock.fill",
                        color: .cyan
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // 原始OCR结果
    private var originalResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("原始识别文本")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.recognizedText)
                                .font(.subheadline)
                            
                            Text(String(format: "置信度: %.0f%%", result.confidence * 100))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - 信息行视图
struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
}

// MARK: - 分类选择项
struct CategorySelectionItem: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: category.icon ?? "questionmark.circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : colorFromString(category.color ?? "gray"))
                    .frame(width: 50, height: 50)
                    .background(
                        isSelected ?
                        colorFromString(category.color ?? "gray") :
                        colorFromString(category.color ?? "gray").opacity(0.1)
                    )
                    .clipShape(Circle())
                
                Text(category.name ?? "未知")
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? colorFromString(category.color ?? "gray") : .primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "brown": return .brown
        case "gray": return .gray
        default: return .secondary
        }
    }
}

// MARK: - 账户选择项
struct AccountSelectionItem: View {
    let account: Account
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: account.accountType.icon)
                    .foregroundColor(isSelected ? .white : colorFromString(account.accountType.color))
                    .font(.title3)
                
                Text(account.name ?? "未知")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ?
                colorFromString(account.accountType.color) :
                Color(.secondarySystemGroupedBackground)
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? colorFromString(account.accountType.color) : Color.clear,
                        lineWidth: isSelected ? 0 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "brown": return .brown
        case "gray": return .gray
        default: return .secondary
        }
    }
}

// MARK: - 预览
#Preview {
    AddExpenseView()
        .environment(\.managedObjectContext, DataManager.shared.viewContext)
        .environmentObject(DataManager.shared)
} 