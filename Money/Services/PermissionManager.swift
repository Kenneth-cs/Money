import Foundation
import Photos
import UIKit

// MARK: - 权限管理器
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @Published var isPhotoLibraryAccessLimited = false
    
    private init() {
        updatePhotoLibraryStatus()
    }
    
    // MARK: - 照片库权限状态
    func updatePhotoLibraryStatus() {
        if #available(iOS 14, *) {
            photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        } else {
            photoLibraryStatus = PHPhotoLibrary.authorizationStatus()
        }
        
        isPhotoLibraryAccessLimited = (photoLibraryStatus == .limited)
        
        print("📸 照片权限状态: \(photoLibraryStatusDescription)")
    }
    
    // MARK: - 请求照片库权限 (强制显示完全访问选项)
    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        print("📸 请求照片库权限...")
        
        if #available(iOS 14, *) {
            // 关键修复：明确请求完全访问权限
            // 这会确保在首次请求时显示"完全访问"和"私密访问"两个选项
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    self?.photoLibraryStatus = status
                    self?.isPhotoLibraryAccessLimited = (status == .limited)
                    
                    let granted = (status == .authorized || status == .limited)
                    print("📸 照片权限请求结果: \(self?.photoLibraryStatusDescription ?? "未知") - \(granted ? "已授权" : "被拒绝")")
                    
                    // 如果用户选择了私密访问，提醒可以在设置中切换到完全访问
                    if status == .limited {
                        print("⚠️ 用户选择了私密访问，可以在设置中切换到完全访问")
                        print("💡 路径：设置 > Privacy & Security > Photos > Money > 完全访问")
                    }
                    
                    completion(granted)
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.photoLibraryStatus = status
                    
                    let granted = (status == .authorized)
                    print("📸 照片权限请求结果: \(self?.photoLibraryStatusDescription ?? "未知") - \(granted ? "已授权" : "被拒绝")")
                    completion(granted)
                }
            }
        }
    }
    
    // MARK: - 强制重新请求权限 (用于重置权限状态)
    @available(iOS 14, *)
    func forceRequestFullAccess(completion: @escaping (Bool) -> Void) {
        print("📸 强制请求完全访问权限...")
        
        // 如果当前是私密访问，显示权限管理界面
        if photoLibraryStatus == .limited {
            print("📸 当前为私密访问，显示权限选择界面...")
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: topViewController()) { _ in
                // 权限选择完成后，检查新的权限状态
                DispatchQueue.main.async {
                    self.updatePhotoLibraryStatus()
                    let granted = (self.photoLibraryStatus == .authorized || self.photoLibraryStatus == .limited)
                    completion(granted)
                }
            }
        } else {
            // 如果还没有权限，正常请求
            requestPhotoLibraryPermission(completion: completion)
        }
    }
    
    // MARK: - 检查是否需要完全访问权限
    var needsFullAccess: Bool {
        return photoLibraryStatus == .limited
    }
    
    // MARK: - 权限状态描述
    var photoLibraryStatusDescription: String {
        switch photoLibraryStatus {
        case .notDetermined:
            return "未确定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorized:
            return "完全访问"
        case .limited:
            return "私密访问"
        @unknown default:
            return "未知状态"
        }
    }
    
    // MARK: - 权限建议
    var permissionRecommendation: String {
        switch photoLibraryStatus {
        case .notDetermined:
            return "请允许访问照片以使用OCR识别功能"
        case .restricted, .denied:
            return "请在设置中开启照片访问权限"
        case .limited:
            return "建议设置为\"完全访问\"以获得更好的OCR体验"
        case .authorized:
            return "照片权限已正确配置"
        @unknown default:
            return "请检查照片权限设置"
        }
    }
    
    // MARK: - 获取设置路径说明
    var settingsPath: String {
        return "设置 → 隐私与安全性 → 照片 → Money → 完全访问"
    }
    
    // MARK: - 打开设置页面
    func openAppSettings() {
        print("📸 打开应用设置页面...")
        print("💡 设置路径: \(settingsPath)")
        
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            print("❌ 无法打开设置页面")
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl) { success in
                print("📸 设置页面打开\(success ? "成功" : "失败")")
            }
        }
    }
    
    // MARK: - 显示权限管理界面
    @available(iOS 14, *)
    func presentLimitedLibraryPicker() {
        print("📸 显示照片选择界面...")
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: topViewController())
    }
    
    // MARK: - 获取顶层视图控制器
    private func topViewController() -> UIViewController {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIViewController()
        }
        
        var topController = window.rootViewController
        while let presentedController = topController?.presentedViewController {
            topController = presentedController
        }
        
        return topController ?? UIViewController()
    }
    
    // MARK: - 权限状态检查
    func checkAllPermissions() {
        print("\n📸 检查所有权限状态...")
        print("============================================================")
        
        updatePhotoLibraryStatus()
        
        print("📷 照片库权限: \(photoLibraryStatusDescription)")
        print("💡 建议: \(permissionRecommendation)")
        
        if needsFullAccess {
            print("⚠️  当前为私密访问，可能影响OCR功能")
            print("💡 建议设置为完全访问以获得最佳体验")
            print("🔧 设置路径: \(settingsPath)")
        }
        
        print("============================================================\n")
    }
    
    // MARK: - 重置权限状态 (用于调试)
    func resetPermissionState() {
        print("🔄 重置权限状态...")
        updatePhotoLibraryStatus()
    }
} 