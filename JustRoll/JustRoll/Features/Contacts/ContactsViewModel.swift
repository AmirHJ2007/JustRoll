// MARK: - Contacts feature disabled (re-enable when adding friend graph in a future version)
#if false

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

    func removeContact(_ contact: Contact) async {
        do {
            try await service.removeContact(contactId: contact.id)
            contacts.removeAll { $0.id == contact.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptContact(_ contact: Contact) async {
        do {
            try await service.acceptContact(contactId: contact.id)
            if let idx = contacts.firstIndex(where: { $0.id == contact.id }) {
                contacts[idx].isConnected = true
                contacts[idx].isPending   = false
                contacts[idx].isIncoming  = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectContact(_ contact: Contact) async {
        await removeContact(contact)
    }
}

#endif
