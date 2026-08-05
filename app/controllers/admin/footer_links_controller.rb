class Admin::FooterLinksController < ApplicationController
  before_action :authenticate_super_admin!
  before_action :set_footer_link, only: [ :edit, :update, :destroy, :toggle_published ]

  def index
    @footer_links = FooterLink.ordered
  end

  def new
    @footer_link = FooterLink.new(published: true)
  end

  def create
    @footer_link = FooterLink.new(footer_link_params)
    if @footer_link.save
      redirect_to admin_footer_links_path, notice: "Enlace creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @footer_link.update(footer_link_params)
      redirect_to admin_footer_links_path, notice: "Enlace actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @footer_link.destroy
    redirect_to admin_footer_links_path, notice: "Enlace eliminado."
  end

  def toggle_published
    @footer_link.update!(published: !@footer_link.published?)

    redirect_to admin_footer_links_path,
      notice: "El enlace quedó #{@footer_link.published? ? 'visible' : 'oculto'}."
  end

  private

  def set_footer_link
    @footer_link = FooterLink.find(params[:id])
  end

  def footer_link_params
    params.require(:footer_link).permit(:label, :url, :position, :published)
  end
end
