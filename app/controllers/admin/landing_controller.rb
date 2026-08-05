class Admin::LandingController < ApplicationController
  before_action :authenticate_super_admin!

  def index
    @testimonials = Testimonial.ordered
    @footer_links = FooterLink.ordered
  end
end
