class Youtube < PluginBase

  #TODO: TEST THIS: https://www.youtube.com/watch?v=Qapou-3-fM8&list=PL_Z529zmzNGcOVBJA0MgjjQoKiBcmMQWh

  # this will be called by the main app to check whether this plugin is responsible for the url passed
  def self.matches_provider?(url)
    url.include?("youtube.com") || url.include?("youtu.be")
  end

  def self.get_urls_and_filenames(url, options = {})
    initialize_components(options)

    urls   = @url_resolver.get_all_urls(url, options[:filter])
    videos = get_videos(urls)

    return_value = videos.map do |video|
      format = @format_picker.pick_format(video)
      make_url_filname_hash(video, format)
    end

    return_value.empty? ? download_error("No videos could be downloaded.") : return_value
  end

  def self.initialize_components(options)
    @cipher_io      = CipherIO.new
    coordinator     = DecipherCoordinator.new(Decipherer.new(@cipher_io), CipherGuesser.new)
    @video_resolver = VideoResolver.new(coordinator)
    @url_resolver   = UrlResolver.new
    @format_picker  = FormatPicker.new(options)
  end

  def self.notify(message)
    puts "[YOUTUBE] #{message}"
  end

  def self.download_error(message)
    raise CouldNotDownloadVideoError, message
  end

  def self.get_videos(urls)
    videos = urls.map do |url|
      @video_resolver.get_video(url)
    end
    videos.reject(&:nil?)
  end

  def self.make_url_filname_hash(video, format)
    url = video.get_download_url(format.itag)
    name = PluginBase.make_filename_safe(video.title) + ".#{format.extension}"
    {url: url, name: name, on_downloaded: make_downloaded_callback(video)}
  end

  def self.make_downloaded_callback(video)
    return nil unless video.signature_guess?

    lambda do |success|
      @cipher_io.add_cipher(video.cipher_version, video.cipher_operations) if success
    end
  end
end
