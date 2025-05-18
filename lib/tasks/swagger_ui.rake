namespace :rswag do
  namespace :api do
    desc 'Generate Swagger API documentation'
    task :create_ui_link do
      puts 'Creating symlink for Swagger UI assets...'
      
      # Create link for Swagger UI assets
      source = Rails.root.join('swagger').to_s
      target = Rails.root.join('public/api-docs').to_s
      
      # Delete target if it exists
      FileUtils.rm_rf(target) if File.exist?(target)
      
      # Create symlink
      FileUtils.mkdir_p(source) unless File.exist?(source)
      FileUtils.symlink(source, target, force: true)
      
      puts 'Symlink created!'
    end
  end
end

# Run this task after swaggerize to ensure the UI has access to the generated docs
Rake::Task['rswag:specs:swaggerize'].enhance do
  Rake::Task['rswag:api:create_ui_link'].invoke
end
