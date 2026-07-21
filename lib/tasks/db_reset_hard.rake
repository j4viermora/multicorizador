namespace :db do
  desc "Drop every table in all configured databases (with FK checks off) and reload the schema"
  task reset_hard: :environment do
    # Recovers a database left half-built by a schema load that failed partway
    # through. MariaDB DDL is not transactional, so an aborted `db:schema:load`
    # leaves tables behind but never writes `schema_migrations`. On the next
    # boot `db:prepare` sees no `schema_migrations`, decides the database is
    # empty and replays the schema — whose `force: :cascade` DROPs then fail
    # against the leftover foreign keys. That deadlocks every subsequent boot.
    #
    # Dropping with FOREIGN_KEY_CHECKS=0 sidesteps the ordering problem.
    #
    # DESTRUCTIVE: drops every table. Requires DISABLE_DATABASE_ENVIRONMENT_CHECK=1
    # outside development/test.
    ActiveRecord::Base.connection # ensure the framework is booted

    unless Rails.env.local? || ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"] == "1"
      abort "Refusing to run against #{Rails.env}. Re-run with DISABLE_DATABASE_ENVIRONMENT_CHECK=1 if you really mean it."
    end

    configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env)

    configs.each do |db_config|
      puts "==> #{db_config.name} (#{db_config.database})"

      ActiveRecord::Base.establish_connection(db_config)
      connection = ActiveRecord::Base.connection

      begin
        tables = connection.tables
      rescue ActiveRecord::NoDatabaseError
        puts "    database missing, creating it"
        ActiveRecord::Tasks::DatabaseTasks.create(db_config)
        next
      end

      if tables.empty?
        puts "    already empty"
        next
      end

      connection.execute("SET FOREIGN_KEY_CHECKS = 0")
      begin
        tables.each do |table|
          connection.execute("DROP TABLE IF EXISTS `#{table}`")
        end
      ensure
        connection.execute("SET FOREIGN_KEY_CHECKS = 1")
      end
      puts "    dropped #{tables.size} tables"
    end

    ActiveRecord::Base.establish_connection(Rails.env.to_sym)

    puts "==> reloading schema"
    Rake::Task["db:prepare"].invoke
    puts "Done."
  end
end
