require 'json'
require 'fileutils'
require 'open-uri'
require 'rubygems'
require 'pry'
require 'mp3info'

data = JSON.parse(File.read('output/data.json'))

def save(from_url, target_file)
  if File.exists?(target_file)
    puts "File already exists, skipping!"
  else
    FileUtils.mkdir_p(File.dirname(target_file))
    begin
      open(from_url, 'rb') do |read_file|
        File.open(target_file, 'w') do |save_file|
          save_file.write(read_file.read)
        end
      end
      true
    rescue
      puts "Could not download file! (#{from_url})"
      false
    end
  end
end

current_album = 0
data.each do |album|
  current_album = current_album + 1
  puts "Downloading album #{album['artist']} - #{album['title']} [#{current_album}/#{data.size}] ..."

  album_folder = "output/downloaded/#{album['artist'] || album['title']}/#{album['title']}"

  cover_local_path = "#{album_folder}/cover.jpg"
  puts "Downloading cover..."
  cover_data = album['covers'].first
  if cover_data
    save(cover_data['src'], cover_local_path)
  end

  current_track = 0

  album['tracks'].each do |track|
    current_track = current_track + 1

    puts "Downloading track #{track['title']} [#{current_track}/#{album['tracks'].size}] ..."

    local_path = "#{album_folder}/#{track['title']}.mp3"

    if (save(track['href'], local_path))
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
        if mp3.tag.tracknum.nil? || mp3.tag.tracknum == ''
          puts "Track number tag missing!"
          mp3.tag.tracknum = current_track
        elsif mp3.tag.tracknum.to_s != current_track.to_s
          puts "Track number is different from metadata! '#{mp3.tag.tracknum}' != '#{current_track}'"
        end

        if cover_data
          mp3.tag2.add_picture(File.new(cover_local_path, 'rb').read)
        end
      end
    end

    puts ''
  end

  puts ''
end

