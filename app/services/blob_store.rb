# Uploaded knowledge files: S3 in AWS (S3_BUCKET set), local disk otherwise.
module BlobStore
  def self.put(key, data)
    if bucket
      client.put_object(bucket:, key:, body: data)
    else
      path = local_path(key)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, data)
    end
    key
  end

  def self.read(key)
    bucket ? client.get_object(bucket:, key:).body.read : File.binread(local_path(key))
  end

  def self.bucket = ENV["S3_BUCKET"].presence
  def self.local_path(key) = Rails.root.join("storage", "uploads", key).to_s
  def self.client = @client ||= Aws::S3::Client.new(region: ENV.fetch("AWS_REGION", "ap-southeast-2"))
end
