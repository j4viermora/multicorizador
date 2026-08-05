# frozen_string_literal: true

def admin_create_credentials
  if ENV["EMAIL"].present? && ENV["PASSWORD"].present?
    return [ ENV["EMAIL"], ENV["PASSWORD"] ]
  end

  puts "Crear super admin"
  print "Email: "
  email = $stdin.gets.to_s.chomp

  password = admin_read_password("Contraseña: ")
  confirmation = admin_read_password("Confirmar contraseña: ")

  abort "ERROR: las contraseñas no coinciden" if password != confirmation
  abort "ERROR: la contraseña no puede estar vacía" if password.blank?
  abort "ERROR: el email no puede estar vacío" if email.blank?

  [ email, password ]
end

def admin_read_password(prompt)
  print prompt
  IO.console.noecho { |io| io.gets }.to_s.chomp
ensure
  puts
end

def admin_create_super_admin!(email:, password:)
  ActsAsTenant.without_tenant do
    # Mismo nombre que en db/seeds.rb: si difieren, correr el seed y la task
    # deja dos companies de admin distintas.
    company = Company.find_or_create_by!(name: "Ruka Admin") { |c| c.currency = "ARS" }

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
rescue ActiveRecord::RecordInvalid => e
  abort "ERROR: #{e.record.errors.full_messages.join(', ')}"
end

namespace :admin do
  desc "Create a super admin user (interactive, or EMAIL=... PASSWORD=...)"
  task create: :environment do
    email, password = admin_create_credentials
    user = admin_create_super_admin!(email: email, password: password)
    puts "Super admin creado: #{user.email}"
  end
end
