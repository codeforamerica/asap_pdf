class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  #has_many :sessions, dependent: :destroy
  belongs_to :site, optional: true
  delegate :documents, to: :site, allow_nil: true

  #normalizes :email_address, with: ->(e) { e.strip.downcase }

  #validates :email_address, presence: true, uniqueness: {case_sensitive: false}, format: {with: URI::MailTo::EMAIL_REGEXP}
end
