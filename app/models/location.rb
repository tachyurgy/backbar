class Location < ApplicationRecord
  has_many :movements, dependent: :restrict_with_exception
  validates :code, :name, presence: true
  validates :code, uniqueness: true
end
