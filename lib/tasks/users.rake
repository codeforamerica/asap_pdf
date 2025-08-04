namespace :users do
  desc "Create admin user with specified password (usage: rake users:create_admin[password])"
  task :create_admin, [:password] => :environment do |t, args|
    User.find_or_create_by!(email: "admin@codeforamerica.org") do |user|
      user.password = args.password
      user.is_site_admin = true
      user.is_user_admin = true
      puts "Created test user: admin@codeforamerica.org / #{args.password}"
    end
  end
end
