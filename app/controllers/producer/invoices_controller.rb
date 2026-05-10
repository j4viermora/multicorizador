class Producer::InvoicesController < ApplicationController
  before_action :authenticate_active_producer!

  def index
    @invoices = ProducerInvoice.where(producer: current_user).order(created_at: :desc)
  end

  def show
    @invoice = ProducerInvoice.where(producer: current_user).find(params[:id])
  end

  def create
    policy_ids = params[:policy_ids] || []

    if policy_ids.empty?
      redirect_to producer_commissions_path, alert: "Selecciona al menos una póliza."
      return
    end

    @invoice = ProducerInvoice.new(
      producer: current_user,
      company: current_user.company,
      period_start: Date.today.beginning_of_month,
      period_end: Date.today.end_of_month
    )

    @invoice.generate_from_policies!(policy_ids)
    redirect_to producer_invoices_path, notice: "Factura generada exitosamente."
  rescue => e
    redirect_to producer_commissions_path, alert: "Error: #{e.message}"
  end
end
