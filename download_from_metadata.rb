require 'json'
require 'fileutils'
require 'open-uri'
require 'rubygems'
require 'pry'
require 'mp3info'

data = JSON.parse(File.read('output/data.json'))

def save(from_url, target_file)
  FileUtils.mkdir_p(File.dirname(target_file))
  File.open(target_file, 'w') do |save_file|
    open(from_url, 'rb') do |read_file|
      save_file.write(read_file.read)
    end
  end
end

data.each do |album|
  puts "Downloading album #{album['artist']} - #{album['title']} ..."

  album_folder = "output/downloaded/#{album['artist'] || album['title']}/#{album['title']}"

  cover_local_path = "#{album_folder}/cover.jpg"
  save(album['covers'].first['src'], cover_local_path)

  album['tracks'][0..0].each do |track|
    puts "Downloading track #{track['title']} ..."

    local_path = "#{album_folder}/#{track['title']}.mp3"
    save(track['href'], local_path)
    Mp3Info.open(local_path) do |mp3|
      if mp3.tag.title.nil? || mp3.tag.title == ''
        puts "Title tag missing!"
        mp3.tag.title = track['title']
      elsif mp3.tag.title != track['title']
        puts "Title is different from metadata! '#{mp3.tag.title}' != '#{track['title']}'"
      end
      if mp3.tag.artist.nil? || mp3.tag.artist == ''
        puts "Artist tag missing!"
        mp3.tag.artist = album['artist']
      elsif mp3.tag.artist != album['artist']
        puts "Artist is different from metadata! '#{mp3.tag.artist}' != '#{album['artist']}'"
      end
      if mp3.tag.album.nil? || mp3.tag.album == ''
        puts "Album tag missing!"
        mp3.tag.album = album['title']
      elsif mp3.tag.album != album['title']
        puts "Album is different from metadata! '#{mp3.tag.album}' != '#{album['title']}'"
      end

      mp3.tag2.add_picture(File.new(cover_local_path, 'rb').read)
    end

    puts ''
  end

  puts ''
end

