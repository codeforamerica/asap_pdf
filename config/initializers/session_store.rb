Rails.application.config.session_store :active_record_store, key: "_your_app_session", secure: Rails.env.production?
