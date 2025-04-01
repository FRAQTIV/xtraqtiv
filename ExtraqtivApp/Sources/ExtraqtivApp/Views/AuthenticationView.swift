import SwiftUI
import ExtraqtivCore

/// `AuthenticationView` provides a user interface for authenticating with Evernote.
///
/// This view handles:
/// - Initiating the OAuth authentication flow
/// - Displaying current authentication status
/// - Handling authentication errors
/// - Providing feedback on authentication progress
/// - Supporting logout functionality
public struct AuthenticationView: View {
    // MARK: - Environment
    
    /// The authentication service from ExtraqtivCore
    @EnvironmentObject private var authService: EvernoteAuthServiceImpl
    
    /// The environment's color scheme (light/dark mode)
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - State
    
    /// Tracks if authentication is in progress
    @State private var isAuthenticating = false
    
    /// Stores any error message to display to the user
    @State private var errorMessage: String?
    
    /// Controls the display of the error alert
    @State private var showingErrorAlert = false
    
    // MARK: - UI
    
    public var body: some View {
        VStack(spacing: 20) {
            // Logo and title
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("Evernote Authentication")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 20)
            
            // Status display
            statusView
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: colorScheme == .dark ? .darkGray : .lightGray))
                        .opacity(0.2)
                )
            
            // Action buttons
            if authService.isAuthenticated {
                logoutButton
            } else {
                loginButton
            }
            
            // Authentication info
            Text("Authentication allows Extraqtiv to access your Evernote notes and notebooks for export. Your credentials are never stored locally.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
        .frame(width: 400, height: 350)
        .padding()
        .alert("Authentication Error", isPresented: $showingErrorAlert) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    /// Displays the current authentication status
    private var statusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                    .fontWeight(.semibold)
                
                Spacer()
                
                statusIndicator
            }
            
            if authService.isAuthenticated, let username = authService.username {
                HStack {
                    Text("Account:")
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(username)
                        .foregroundColor(.secondary)
                }
            }
            
            if authService.isAuthenticated, let expirationDate = authService.tokenExpirationDate {
                HStack {
                    Text("Expires:")
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(expirationDateFormatted(expirationDate))
                        .foregroundColor(isTokenExpiringSoon(expirationDate) ? .orange : .secondary)
                }
            }
        }
    }
    
    /// Visual indicator showing authentication status
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(authService.isAuthenticated ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            
            Text(authService.isAuthenticated ? "Authenticated" : "Not Authenticated")
                .foregroundColor(authService.isAuthenticated ? .green : .red)
        }
    }
    
    /// Button to initiate OAuth authentication flow
    private var loginButton: some View {
        Button {
            initiateAuthentication()
        } label: {
            if isAuthenticating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
                    .padding(.horizontal, 8)
            } else {
                Text("Sign in with Evernote")
                    .fontWeight(.semibold)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isAuthenticating)
    }
    
    /// Button to log out and clear authentication tokens
    private var logoutButton: some View {
        Button(role: .destructive) {
            logout()
        } label: {
            Text("Sign Out")
                .fontWeight(.semibold)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
    
    // MARK: - Helper Functions
    
    /// Initiates the OAuth authentication flow
    private func initiateAuthentication() {
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.authenticate()
                isAuthenticating = false
            } catch let error as EvernoteAuthError {
                await handleAuthError(error)
            } catch {
                await handleAuthError(.unknown(error.localizedDescription))
            }
        }
    }
    
    /// Logs out the current user and clears authentication tokens
    private func logout() {
        Task {
            do {
                try await authService.logout()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to sign out: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    /// Handles authentication errors and updates the UI accordingly
    @MainActor
    private func handleAuthError(_ error: EvernoteAuthError) {
        isAuthenticating = false
        
        switch error {
        case .userCancelled:
            // User cancellation is not an error to alert about
            break
        case .tokenRevoked:
            errorMessage = "Your authentication has expired. Please sign in again."
            showingErrorAlert = true
        case .networkError(let message):
            errorMessage = "Network error: \(message)"
            showingErrorAlert = true
        case .unauthorized(let message):
            errorMessage = "Authorization failed: \(message)"
            showingErrorAlert = true
        case .unknown(let message):
            errorMessage = "An error occurred: \(message)"
            showingErrorAlert = true
        }
    }
    
    /// Formats the token expiration date for display
    private func expirationDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Checks if the token is expiring within 7 days
    private func isTokenExpiringSoon(_ date: Date) -> Bool {
        let sevenDaysFromNow = Date().addingTimeInterval(7 * 24 * 60 * 60)
        return date < sevenDaysFromNow
    }
}

// MARK: - Preview

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Authenticated state
            AuthenticationView()
                .environmentObject(mockAuthenticatedService())
            
            // Unauthenticated state
            AuthenticationView()
                .environmentObject(mockUnauthenticatedService())
        }
    }
    
    /// Creates a mock authenticated service for previews
    static func mockAuthenticatedService() -> EvernoteAuthServiceImpl {
        let service = EvernoteAuthServiceImpl()
        service.mockForPreview(
            isAuthenticated: true,
            username: "example@email.com",
            expirationDate: Date().addingTimeInterval(30 * 24 * 60 * 60)
        )
        return service
    }
    
    /// Creates a mock unauthenticated service for previews
    static func mockUnauthenticatedService() -> EvernoteAuthServiceImpl {
        let service = EvernoteAuthServiceImpl()
        service.mockForPreview(isAuthenticated: false)
        return service
    }
}

// MARK: - Extensions for Preview

extension EvernoteAuthServiceImpl {
    /// Mock setup for SwiftUI previews
    fileprivate func mockForPreview(
        isAuthenticated: Bool,
        username: String? = nil,
        expirationDate: Date? = nil
    ) {
        // This would modify preview state only
        #if DEBUG
        self._isAuthenticated = isAuthenticated
        self._username = username
        self._tokenExpirationDate = expirationDate
        #endif
    }
}

