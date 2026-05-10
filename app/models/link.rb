class Link < ApplicationRecord
  acts_as_tenant :company

  belongs_to :quote

  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  enum :status, { active: "active", expired: "expired", revoked: "revoked" }

  def generate_token
    self.token = SecureRandom.urlsafe_base64(24)
  end

  def expired?
    return true if status == "expired"
    return true if expires_at.present? && expires_at < Time.current
    false
  end

  def record_access!
    increment!(:access_count)
    touch(:last_accessed_at)
  end

  def revoke!
    update!(status: "revoked")
  end
end
