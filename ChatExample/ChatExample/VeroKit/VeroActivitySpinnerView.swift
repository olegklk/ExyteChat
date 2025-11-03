//
//  VeroActivitySpinnerView.swift
//  YourSwiftUIProject
//
//  Created by AI Assistant
//

import SwiftUI

/// SwiftUI view, которая повторяет функциональность и внешний вид `VeroActivitySpinnerView` из UIKit.
/// Использует `UIViewRepresentable` для интеграции `UIView` с вращающимся `UIImageView`.
struct VeroActivitySpinnerView: UIViewRepresentable {
//переделай этот класс полность в идеалогии swift и swiftUI уйдя от наследния UIKit AI!
    // MARK: - Properties
    
    /// Привязка, управляющая состоянием анимации (запущена/остановлена).
    @Binding var isAnimating: Bool
    
    /// Имя изображения для спиннера.
    private let imageName: String

    // MARK: - Initialization
    
    /// Инициализирует спиннер с кастомным изображением.
    /// - Parameters:
    ///   - isAnimating: Привязка к состоянию анимации.
    ///   - imageName: Имя изображения в Asset Catalogs или Bundle.
    init(isAnimating: Binding<Bool>, imageName: String) {
        self._isAnimating = isAnimating
        self.imageName = imageName
    }
    
    init(isAnimating: Binding<Bool>) {
        self._isAnimating = isAnimating
        self.imageName = "spinner"
    }

    // MARK: - UIViewRepresentable
    
    /// Создает `UIView` с центрированным `UIImageView` внутри.
    func makeUIView(context: Context) -> UIView {
        // Создаем основной контейнер
        let containerView = UIView()
        containerView.isUserInteractionEnabled = false
        
        // Создаем изображение для спиннера
        let spinnerImageView = UIImageView(image: UIImage(named: imageName))
        spinnerImageView.contentMode = .scaleAspectFit
        spinnerImageView.translatesAutoresizingMaskIntoConstraints = false
        spinnerImageView.isHidden = true // Изначально скрыт
        
        // Добавляем изображение в контейнер
        containerView.addSubview(spinnerImageView)
        
        // Центрируем изображение с помощью Auto Layout
        NSLayoutConstraint.activate([
            spinnerImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            spinnerImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        // Сохраняем ссылку на imageView в координаторе для дальнейшего использования
        context.coordinator.spinnerImageView = spinnerImageView
        
        return containerView
    }

    /// Обновляет состояние анимации в ответ на изменения в SwiftUI.
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let spinnerImageView = context.coordinator.spinnerImageView else { return }
        
        if isAnimating {
            // Если анимация еще не запущена, запускаем ее
            if spinnerImageView.layer.animation(forKey: "Spin") == nil {
                spinnerImageView.isHidden = false
                
                let rotation = CABasicAnimation(keyPath: "transform.rotation")
                rotation.fromValue = 0
                rotation.toValue = Float.pi * 2
                rotation.duration = 1.1
                rotation.repeatCount = .infinity
                spinnerImageView.layer.add(rotation, forKey: "Spin")
            }
        } else {
            // Останавливаем анимацию и скрываем изображение
            spinnerImageView.layer.removeAllAnimations()
            spinnerImageView.isHidden = true
        }
    }
    
    /// Создает координатор для хранения ссылок на subview.
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator
    
    /// Координатор для хранения ссылки на `UIImageView`.
    class Coordinator {
        var spinnerImageView: UIImageView?
    }
}


// MARK: - Preview Provider
#if DEBUG
struct VeroActivitySpinnerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Пример с системным символом для превью (не требует ассетов)
            VeroActivitySpinnerView(isAnimating: .constant(true), imageName: "spinner")
                .previewDisplayName("Animating (SF Symbol)")
            
            // Пример с остановленной анимацией
            VeroActivitySpinnerView(isAnimating: .constant(false), imageName: "spinner")
                .previewDisplayName("Stopped (SF Symbol)")
        }
        .padding()
        .frame(width: 80, height: 80) // Задаем размер для превью
        .previewLayout(.sizeThatFits)
    }
}
#endif

/*
// MARK: - Пример использования в другом SwiftUI View

struct ExampleUsageView: View {
    @State private var isLoading = false
    @State private var showSpinner = false // Управляет видимостью всего спиннера

    var body: some View {
        ZStack {
            // Основной контент
            VStack(spacing: 20) {
                Text("Какой-то контент")
                
                Button(showSpinner ? "Скрыть спиннер" : "Показать спиннер") {
                    showSpinner.toggle()
                    isLoading.toggle()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Спиннер отображается поверх контента, когда showSpinner == true
            // Это заменяет методы addToViewAndStart/removeFromSuperviewAndStop
            if showSpinner {
                Color.black.opacity(0.3).ignoresSafeArea() // Полупрозрачный фон
                
                VeroActivitySpinnerView(isAnimating: $isLoading, imageName: "comments_spinner")
                    .frame(width: 50, height: 50) // Задаем размер для спиннера
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
            }
        }
    }
}
*/
