class ProducerInvoice < ApplicationRecord
  acts_as_tenant :company

  belongs_to :producer, class_name: "User"
  has_many :producer_invoice_policies, dependent: :destroy
  has_many :policies, through: :producer_invoice_policies

  monetize :total_commission_cents

  enum :status, { draft: "draft", pending: "pending", paid: "paid" }

  def generate_from_policies!(policy_ids)
    policies = Policy.where(id: policy_ids, producer_commission_status: "pending")

    transaction do
      self.policies = policies
      self.total_commission = policies.sum(:producer_commission_cents)
      save!
      policies.update_all(producer_commission_status: "invoiced")
    end
  end

  def mark_as_paid!
    transaction do
      update!(status: "paid", paid_at: Time.current)
      policies.update_all(producer_commission_status: "paid", producer_commission_paid_at: Time.current)
    end
  end
end
