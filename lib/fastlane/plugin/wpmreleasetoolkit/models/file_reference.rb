module Fastlane
  class Configuration
    class FileReference
      attr_accessor :file, :destination, :encrypt
  
      def initialize(params = {})
        self.file = params[:file] || ""
        self.destination = params[:destination] || ""
        self.encrypt = params[:encrypt] || false
      end
  
      def source_contents
        return File.read(secrets_repository_file_path) unless self.encrypt
        return nil unless File.file?(encrypted_file_path)
        encrypted = File.read(encrypted_file_path)
        Fastlane::Helper::EncryptionHelper.decrypt(encrypted, encryption_key)
      end
    
      def destination_contents
        return nil unless File.file?(destination_file_path)
        File.read(destination_file_path)
      end
    
      def needs_apply?
        destination = destination_contents
        destination.nil? || source_contents != destination
      end
    
      def update
        return unless self.encrypt
        # Create the destination directory if it doesn't exist
        FileUtils.mkdir_p(Pathname.new(encrypted_file_path).dirname)
        # Encrypt the file
        file_contents = File.read(secrets_repository_file_path)
        encrypted = Fastlane::Helper::EncryptionHelper.encrypt(file_contents, encryption_key)
        File.write(encrypted_file_path, encrypted)
      end
    
      def apply
        # Create the destination directory if it doesn't exist
        FileUtils.mkdir_p(Pathname.new(destination_file_path).dirname)
        # Copy/decrypt the file
        File.write(destination_file_path, source_contents)
      end
    
      def secrets_repository_file_path
        File.join(Fastlane::Helper::FilesystemHelper.secret_store_dir, self.file)
      end
    
      def encrypted_file_path
        Fastlane::Helper::FilesystemHelper.encrypted_file_path(self.file)
      end
  
      def destination_file_path
        File.join(Fastlane::Helper::FilesystemHelper.project_path, self.destination)
      end
    
      def encryption_key
        Fastlane::Helper::ConfigureHelper.encryption_key
      end
  
      def to_hash
        { file: self.file, destination: self.destination, encrypt: self.encrypt }
      end
    end
  end
end