require "net/http"

class AndroidRelease
  REPOSITORY = "mycomputernetwork/noted"
  RELEASES_URL = URI("https://api.github.com/repos/#{REPOSITORY}/releases?per_page=10")
  LATEST_DOWNLOAD_URL = "https://github.com/#{REPOSITORY}/releases/latest/download/noted.apk"

  attr_reader :tag_name, :published_at, :download_url

  def self.latest
    Rails.cache.fetch("android_release/latest/v1", expires_in: 30.minutes) { fetch_latest }
  rescue StandardError
    nil
  end

  def self.fetch_latest
    response = Net::HTTP.start(RELEASES_URL.host, RELEASES_URL.port, use_ssl: true, open_timeout: 1, read_timeout: 1) do |http|
      request = Net::HTTP::Get.new(RELEASES_URL)
      request["Accept"] = "application/vnd.github+json"
      request["User-Agent"] = "noted"
      http.request(request)
    end
    return unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).find { |release| candidate?(release) }&.then { |release| from_release(release) }
  end

  def self.candidate?(release)
    release["draft"] == false && release["prerelease"] == false && apk_asset(release).present?
  end

  def self.from_release(release)
    new(
      tag_name: release.fetch("tag_name"),
      published_at: Time.zone.parse(release.fetch("published_at")),
      download_url: apk_asset(release).fetch("browser_download_url")
    )
  end

  def self.apk_asset(release)
    release.fetch("assets", []).find { |asset| asset["name"] == "noted.apk" }
  end

  def initialize(tag_name:, published_at:, download_url:)
    @tag_name = tag_name
    @published_at = published_at
    @download_url = download_url
  end

  def version = tag_name.delete_prefix("android-v")

  def published_on = published_at.to_date.to_fs(:long)
end
