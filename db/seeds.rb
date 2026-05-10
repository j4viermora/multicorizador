# Seeds

# Company para super admin
admin_company = Company.find_or_create_by!(name: "Asisto Admin") do |c|
  c.currency = "ARS"
end

# Company de ejemplo para productores
demo_company = Company.find_or_create_by!(name: "Demo Corp") do |c|
  c.currency = "ARS"
end

# Super Admin
super_admin = User.find_or_create_by!(email: "admin@asisto.com") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = :super_admin
  user.status = :active
  user.first_name = "Super"
  user.last_name = "Admin"
  user.company = admin_company
end
puts "Super admin creado: #{super_admin.email} / password123"

# Productor de ejemplo
producer = User.find_or_create_by!(email: "producer@asisto.com") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = :producer
  user.status = :active
  user.first_name = "Juan"
  user.last_name = "Pérez"
  user.company = demo_company
end
puts "Productor creado: #{producer.email} / password123"

# Proveedor de ejemplo
example_provider = Provider.find_or_create_by!(slug: "example_seguros") do |p|
  p.name = "Example Seguros"
  p.config = {
    base_url: "https://api.example.com",
    checkout_url: "https://checkout.example.com",
    webhook_token: "demo_token_123"
  }
end

# Contrato default
CommissionContract.find_or_create_by!(provider: example_provider, producer: nil) do |c|
  c.provider_commission_rate = 0.40
  c.producer_share_rate = 0.50
  c.valid_from = Date.today.beginning_of_year
end

puts "Proveedor de ejemplo creado: #{example_provider.name}"
