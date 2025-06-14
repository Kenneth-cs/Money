//
//  MoneyApp.swift
//  Money
//
//  Created by zhangshaocong6 on 2025/6/14.
//

import SwiftUI

@main
struct MoneyApp: App {
    
    // MARK: - 数据管理器
    let dataManager = DataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataManager.viewContext)
                .environmentObject(dataManager)
        }
    }
}
