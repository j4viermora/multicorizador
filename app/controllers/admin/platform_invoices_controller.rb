class Admin::PlatformInvoicesController < ApplicationController
  before_action :authenticate_super_admin!
  before_action :set_invoice, only: [:show, :edit, :update, :destroy]

  def index
    @invoices = PlatformInvoice.includes(:provider).order(created_at: :desc)
  end

  def show
  end

  def new
    @invoice = PlatformInvoice.new
  end

  def create
    @invoice = PlatformInvoice.new(invoice_params)
    if @invoice.save
      redirect_to admin_platform_invoices_path, notice: "Factura creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @invoice.update(invoice_params)
      redirect_to admin_platform_invoices_path, notice: "Factura actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @invoice.destroy
    redirect_to admin_platform_invoices_path, notice: "Factura eliminada."
  end

  private

  def set_invoice
    @invoice = PlatformInvoice.find(params[:id])
  end

  def invoice_params
    params.require(:platform_invoice).permit(:provider_id, :period_start, :period_end, :status, :paid_at)
  end
end
