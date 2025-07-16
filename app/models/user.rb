class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable, :trackable

  belongs_to :site, optional: true
  delegate :documents, to: :site, allow_nil: true
end
