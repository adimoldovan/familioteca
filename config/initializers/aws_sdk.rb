require "aws-sdk-s3"

Rails.application.config.to_prepare do
  next if Rails.env.test? || Rails.env.e2e?

  endpoint = ENV["FAMILIOTECA_BUCKET_ENDPOINT"]
  region   = ENV["FAMILIOTECA_BUCKET_REGION"] || "auto"
  access   = ENV["FAMILIOTECA_BUCKET_KEY_ID"]
  secret   = ENV["FAMILIOTECA_BUCKET_SECRET"]

  next if [ endpoint, access, secret ].any?(&:blank?)

  Aws.config.update(
    region: region,
    credentials: Aws::Credentials.new(access, secret),
    endpoint: endpoint,
    force_path_style: true
  )
end
