import Foundation
import Supabase

private var _chatChannels: [String: RealtimeChannelV2] = [:]

extension SupabaseManager {

    func fetchMessages(applicationId: UUID) async throws -> [DBChatMessage] {
        return try await client
            .from("chat_messages")
            .select()
            .eq("application_id", value: applicationId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    @discardableResult
    func sendMessage(applicationId: UUID, senderId: UUID, content: String, messageType: ChatMessageType, documentType: DocumentRequestType?) async throws -> DBChatMessage {
        var insertData: [String: AnyJSON] = [
            "application_id": .string(applicationId.uuidString),
            "sender_id": .string(senderId.uuidString),
            "content": .string(content),
            "message_type": .string(messageType.rawValue)
        ]
        if let documentType {
            insertData["document_type"] = .string(documentType.rawValue)
        } else {
            insertData["document_type"] = .null
        }

        let saved: DBChatMessage = try await client
            .from("chat_messages")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value
        return saved
    }

    func subscribeToMessages(applicationId: UUID, subscriberId: String = "default", onNewMessage: @escaping (DBChatMessage) -> Void) async {
        let channelKey = "\(applicationId.uuidString)_\(subscriberId)"
        await unsubscribeFromMessages(applicationId: applicationId, subscriberId: subscriberId)

        let channel = client.channel("chat_\(channelKey)")

        let stream = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "chat_messages"
        )

        do {
            try await channel.subscribeWithError()
            _chatChannels[channelKey] = channel

            Task {
                for await insertion in stream {
                    do {
                        let message = try insertion.decodeRecord(as: DBChatMessage.self, decoder: AnyJSON.decoder)

                        if message.applicationId == applicationId {
                            onNewMessage(message)
                        }
                    } catch {
                        print("Error decoding realtime message: \(error)")
                    }
                }
            }
        } catch {
            print("Error subscribing to chat messages: \(error)")
        }
    }

    func unsubscribeFromMessages(applicationId: UUID, subscriberId: String = "default") async {
        let channelKey = "\(applicationId.uuidString)_\(subscriberId)"
        if let channel = _chatChannels[channelKey] {
            await client.removeChannel(channel)
            _chatChannels.removeValue(forKey: channelKey)
        }
    }
}