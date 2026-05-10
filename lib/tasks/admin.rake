# frozen_string_literal: true

namespace :admin do
  desc "Create a super admin user: bin/rails admin:create EMAIL=admin@example.com PASSWORD=secret"
  task create: :environment do
    email = ENV.fetch("EMAIL") { abort "ERROR: EMAIL is required. Usage: bin/rails admin:create EMAIL=admin@example.com PASSWORD=secret" }
    password = ENV.fetch("PASSWORD") { abort "ERROR: PASSWORD is required. Usage: bin/rails admin:create EMAIL=admin@example.com PASSWORD=secret" }

    user = ActsAsTenant.without_tenant do
      company = Company.find_or_create_by!(name: "Asisto Admin") { |c| c.currency = "ARS" }

      User.create!(
        email: email,
        password: password,
        password_confirmation: password,
        role: :super_admin,
        status: :active,
        first_name: "Super",
        last_name: "Admin",
        company: company
      )
    end

    puts "Super admin creado: #{user.email}"
  end
end
