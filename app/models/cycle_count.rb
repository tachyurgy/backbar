class CycleCount < ApplicationRecord
  belongs_to :sku
  belongs_to :location
  validates :counted, numericality: { greater_than_or_equal_to: 0 }
  validates :counted_by, presence: true
  scope :pending, -> { where(status: "pending") }
end
