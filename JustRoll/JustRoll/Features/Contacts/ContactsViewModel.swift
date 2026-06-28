import Foundation
import Observation

@Observable
@MainActor
final class ContactsViewModel {
    var contacts: [Contact] = []
    var isLoading = false
    var errorMessage: String?
    var showAddSheet = false

    private let service: any SupabaseServiceProtocol

    init(service: any SupabaseServiceProtocol = MockSupabaseService.shared) {
        self.service = service
    }

    func load() async {
        isLoading = true
        do {
            contacts = try await service.fetchContacts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addContact(username: String) async throws {
        let contact = try await service.addContact(username: username)
        contacts.append(contact)
    }
}
