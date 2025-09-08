class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable, :trackable

  belongs_to :site, optional: true
  has_many :feedback_item
  delegate :documents, to: :site, allow_nil: true

  scope :by_email, ->(email) {
    return all if email.blank?
    where("email LIKE ?", "%#{email}%")
  }

  def send_new_account_instructions?
    return false unless is_invited?

    token = set_reset_password_token
    ApplicationMailer.new_account_instructions(self, token).deliver_now
    true
  end
end
