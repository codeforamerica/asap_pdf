Sidekiq.configure_server do |config|
  config.redis = {url: ENV.fetch("REDIS_URL", "redis://redis:6379/0")}
end

Rails.application.config.active_job.queue_adapter = :sidekiq
