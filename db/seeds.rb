admin_email = ENV.fetch("FAMILIOTECA_ADMIN_EMAIL", "admin@familioteca.local")
admin_password = ENV.fetch("FAMILIOTECA_ADMIN_PASSWORD", "changeme123")
admin_name = ENV.fetch("FAMILIOTECA_ADMIN_NAME", "Administrator")

if Rails.env.production? && !ENV.key?("FAMILIOTECA_ADMIN_PASSWORD")
  abort "Set FAMILIOTECA_ADMIN_PASSWORD before seeding in production."
end

Member.find_or_create_by!(email: admin_email) do |m|
  m.password = admin_password
  m.name = admin_name
  m.admin = true
end
