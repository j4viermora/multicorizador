class Producer::TravelersController < ApplicationController
  before_action :authenticate_active_producer!
  before_action :set_traveler, only: [:show, :edit, :update, :destroy]

  def index
    @travelers = current_user.travelers.order(:last_name)
  end

  def show
  end

  def new
    @traveler = current_user.travelers.build
  end

  def create
    @traveler = current_user.travelers.build(traveler_params)
    if @traveler.save
      redirect_to producer_travelers_path, notice: "Cliente creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @traveler.update(traveler_params)
      redirect_to producer_travelers_path, notice: "Cliente actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @traveler.destroy
    redirect_to producer_travelers_path, notice: "Cliente eliminado."
  end

  private

  def set_traveler
    @traveler = current_user.travelers.find(params[:id])
  end

  def traveler_params
    params.require(:traveler).permit(:first_name, :last_name, :email, :phone, :document, :birth_date)
  end
end
