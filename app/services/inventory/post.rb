module Inventory
  # Write one movement. The whole contract is in the idempotency key: a POS that
  # retries a sale, a receiving scanner that fires twice on a bad wifi day, and a
  # replayed webhook all have to leave the ledger in the same place as one delivery.
  #
  # Uniqueness is enforced by the database, not by a read-then-write check, because
  # two workers can both read "not present" before either one writes.
  class Post
    class Insufficient < StandardError; end

    def self.call(sku:, location:, quantity:, kind:, key:, note: nil, occurred_at: nil,
                  allow_negative: false)
      raise ArgumentError, "quantity cannot be zero" if quantity.zero?
      raise ArgumentError, "unknown kind #{kind}" unless Movement::KINDS.include?(kind.to_s)

      Movement.transaction do
        existing = Movement.find_by(idempotency_key: key)
        return existing if existing

        unless allow_negative || quantity.positive?
          # Lock the (sku, location) pair by taking the row lock on the sku so two
          # concurrent sales cannot both see enough stock and both succeed.
          Sku.lock.find(sku.id)
          have = Movement.at(sku, location).sum(:quantity)
          if have + quantity < 0
            raise Insufficient,
                  "#{sku.code} at #{location.code}: have #{have}, cannot move #{quantity}"
          end
        end

        begin
          Movement.create!(sku: sku, location: location, quantity: quantity,
                           kind: kind.to_s, idempotency_key: key, note: note,
                           occurred_at: occurred_at || Time.current,
                           created_at: Time.current)
        rescue ActiveRecord::RecordNotUnique
          # Lost the race to a concurrent writer with the same key. Their row is the
          # one that counts, and it is identical to the one we were about to write.
          Movement.find_by!(idempotency_key: key)
        end
      end
    end
  end
end
