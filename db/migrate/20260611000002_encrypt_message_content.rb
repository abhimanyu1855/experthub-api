# Enables Active Record Encryption on messages.content.
# The column type stays `text` — AR encryption stores a JSON envelope in it.
# Existing plaintext rows are migrated at runtime by `db:encryption:rotate`.
# Run after deploy: bin/rails db:encryption:rotate MESSAGE_ENCRYPT_REASON="initial encryption"
class EncryptMessageContent < ActiveRecord::Migration[8.1]
  def up
    # No schema change needed — AR encryption is transparent at the column level.
    # This migration is a marker so we know when encryption was enabled.
    say "Message content encryption enabled via Active Record Encryption."
    say "Run: bin/rails runner 'Message.find_each { |m| m.encrypt }' to encrypt existing rows."
  end

  def down
    say "To disable encryption, remove 'encrypts :content' from Message model and decrypt existing rows."
  end
end
