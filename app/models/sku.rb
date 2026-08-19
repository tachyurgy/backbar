class Sku < ApplicationRecord
  has_many :movements, dependent: :restrict_with_exception
  validates :code, :name, presence: true
  validates :code, uniqueness: true

  def on_hand(location = nil)
    scope = movements
    scope = scope.where(location: location) if location
    scope.sum(:quantity)
  end
end
