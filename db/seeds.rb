# Seeds

# Company para super admin
admin_company = Company.find_or_create_by!(name: "Ruka Admin") do |c|
  c.currency = "ARS"
end

# Company de ejemplo para productores
demo_company = Company.find_or_create_by!(name: "Demo Corp") do |c|
  c.currency = "ARS"
end

# Company propia de Ruka, para venta directa (ruka.com/)
ruka_company = Company.find_or_create_by!(slug: Company::RUKA_DIRECT_SLUG) do |c|
  c.name = "Ruka"
  c.currency = "ARS"
end

# Super Admin
super_admin = User.find_or_create_by!(email: "admin@ruka.com") do |user|
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
producer = User.find_or_create_by!(email: "producer@ruka.com") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = :producer
  user.status = :active
  user.first_name = "Juan"
  user.last_name = "Pérez"
  user.company = demo_company
end
puts "Productor creado: #{producer.email} / password123"

# Vendedor in-house de Ruka (venta directa)
ruka_producer = User.find_or_create_by!(email: "ventas@ruka.com") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = :producer
  user.status = :active
  user.first_name = "Ruka"
  user.last_name = "Ventas"
  user.company = ruka_company
end
puts "Productor directo de Ruka creado: #{ruka_producer.email} / password123"

# Proveedor de ejemplo
example_provider = Provider.find_or_create_by!(slug: "example_seguros") do |p|
  p.name = "Example Seguros"
  p.config = {
    base_url: "https://api.example.com",
    checkout_url: "https://checkout.example.com",
    webhook_token: "demo_token_123"
  }
end

puts "Proveedor de ejemplo creado: #{example_provider.name}"

# Proveedores fake para testing de búsqueda
[
  { name: "Assist Card", slug: "assist_card_fake", config: { base_url: "https://fake.assistcard.com" } },
  { name: "Universal Assistance", slug: "universal_assistance_fake", config: { base_url: "https://fake.universal.com" } },
  { name: "Travel Ace", slug: "travel_ace_fake", config: { base_url: "https://fake.travelace.com" } }
].each do |attrs|
  prov = Provider.find_or_create_by!(slug: attrs[:slug]) do |p|
    p.name = attrs[:name]
    p.config = attrs[:config]
  end

  puts "Proveedor fake creado: #{prov.name}"
end

# Omint Assistance — proveedor real (CreateQuotationB2B). Credenciales en
# Provider#config por ahora (ver docs/09-omint-integration-plan.md); el
# client_secret se lee de ENV para no commitear el secret real al repo —
# seteá OMINT_CLIENT_SECRET en tu .env local con el valor del manual PDF.
# Arranca "inactive": activalo manualmente una vez validado contra el
# ambiente de test.
omint_provider = Provider.find_or_create_by!(slug: "omint") do |p|
  p.name = "Omint Assistance"
  p.status = "inactive"
  p.config = {
    base_url: "https://oaapp.eastus2.cloudapp.azure.com:8448", # test; prod: https://api.omintassistance.com.ar
    token_endpoint: "https://core.omintassistance.com.ar/connect/token",
    client_id: "c92cbe04-c81d-428d-8c3f-453b0d45cf9e",
    client_secret: ENV.fetch("OMINT_CLIENT_SECRET", "CHANGEME"),
    scope: "OACoreApi IntegrationWebApi",
    agreement_number: 3329,
    timeout: 30
  }
end

puts "Proveedor Omint creado: #{omint_provider.name} (status: #{omint_provider.status})"
