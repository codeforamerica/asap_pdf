class Current < ActiveSupport::CurrentAttributes
  attribute :session
  # TODO  ask Mike about this.
  attribute :user
  delegate :user, to: :session, allow_nil: true
end
