import SwiftUI

/// A reusable loading indicator view that provides visual feedback for async operations.
///
/// `LoadingView` offers a flexible loading indicator with:
/// - Customizable progress tracking
/// - Status message display
/// - Clean animations and modern design
/// - Optional cancellation support
///
/// Use this view to provide visual feedback during long-running operations such as
/// authentication, data fetching, and export processes.
///
/// # Example Usage
/// ```swift
/// LoadingView(
///     isLoading: $isLoading,
///     progress: $progress,
///     statusMessage: $statusMessage,
///     allowCancellation: true,
///     onCancel: { cancelOperation() }
/// )
/// ```
public struct LoadingView: View {
    // MARK: - Properties
    
    /// Binding to control the loading state
    @Binding private var isLoading: Bool
    
    /// Binding to track operation progress (0.0 to 1.0)
    @Binding private var progress: Double
    
    /// Binding to display status message during the operation
    @Binding private var statusMessage: String
    
    /// Whether to show a determinate progress bar (true) or indeterminate spinner (false)
    private var isDeterminate: Bool
    
    /// Whether to allow the user to cancel the operation
    private var allowCancellation: Bool
    
    /// Action to perform when cancellation is requested
    private var onCancel: (() -> Void)?
    
    /// Controls the reveal animation of the loading view
    @State private var revealContent: Bool = false
    
    /// Controls the pulsing animation effect
    @State private var isPulsing: Bool = false
    
    // MARK: - Initializers
    
    /// Creates a loading view with all customization options
    /// - Parameters:
    ///   - isLoading: Binding to control the loading state
    ///   - progress: Binding to track operation progress (0.0 to 1.0)
    ///   - statusMessage: Binding to display status message
    ///   - isDeterminate: Whether to show progress bar (true) or indeterminate spinner (false)
    ///   - allowCancellation: Whether to allow the user to cancel the operation
    ///   - onCancel: Action to perform when cancellation is requested
    public init(
        isLoading: Binding<Bool>,
        progress: Binding<Double>,
        statusMessage: Binding<String>,
        isDeterminate: Bool = true,
        allowCancellation: Bool = false,
        onCancel: (() -> Void)? = nil
    ) {
        self._isLoading = isLoading
        self._progress = progress
        self._statusMessage = statusMessage
        self.isDeterminate = isDeterminate
        self.allowCancellation = allowCancellation
        self.onCancel = onCancel
    }
    
    /// Creates a simple indeterminate loading view
    /// - Parameters:
    ///   - isLoading: Binding to control the loading state
    ///   - statusMessage: Binding to display status message
    public init(
        isLoading: Binding<Bool>,
        statusMessage: Binding<String>
    ) {
        self._isLoading = isLoading
        self._progress = .constant(0.0)
        self._statusMessage = statusMessage
        self.isDeterminate = false
        self.allowCancellation = false
        self.onCancel = nil
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            if isLoading {
                // Semi-transparent background
                Color(.windowBackgroundColor)
                    .opacity(0.8)
                    .edgesIgnoringSafeArea(.all)
                
                // Loading panel
                VStack(spacing: 20) {
                    // Title
                    Text("Processing")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Progress indicator
                    Group {
                        if isDeterminate {
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(width: 250)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                        }
                    }
                    .padding(.vertical, 5)
                    
                    // Progress percentage (if determinate)
                    if isDeterminate {
                        Text("\(Int(progress * 100))%")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                            .animation(.none, value: progress)
                    }
                    
                    // Status message
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(isPulsing ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), 
                                   value: isPulsing)
                    
                    // Cancel button (if enabled)
                    if allowCancellation {
                        Button("Cancel") {
                            onCancel?()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 5)
                    }
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .scaleEffect(revealContent ? 1.0 : 0.8)
                .opacity(revealContent ? 1.0 : 0)
                .animation(.spring(response: 0.3), value: revealContent)
                .onChange(of: isLoading) { newValue in
                    if newValue {
                        // Start animations when loading begins
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            revealContent = true
                            isPulsing = true
                        }
                    } else {
                        // Reset animations when loading ends
                        revealContent = false
                        isPulsing = false
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

// MARK: - Preview Provider

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.white
                .edgesIgnoringSafeArea(.all)
            
            // Background content
            VStack {
                Text("Application Content")
                    .font(.title)
            }
            
            // Determinate loading view
            LoadingView(
                isLoading: .constant(true),
                progress: .constant(0.65),
                statusMessage: .constant("Exporting notes 65 of 100..."),
                isDeterminate: true,
                allowCancellation: true,
                onCancel: {}
            )
            
            // To preview indeterminate loading, uncomment below:
            /*
            LoadingView(
                isLoading: .constant(true),
                statusMessage: .constant("Authenticating with Evernote...")
            )
            */
        }
        .frame(width: 600, height: 400)
        .previewDisplayName("Loading View Preview")
    }
}

