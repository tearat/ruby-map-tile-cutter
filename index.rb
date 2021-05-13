require './cutter_class'

# You have to change it manually
options = {
  filename: 'test.jpg',
  tile_size: 256,
  ext: 'png',
  bg_color: '#111',
  tiles_path: 'tiles'
}

cutter = Cutter.new(options)
cutter.make_templates
cutter.make_tiles
cutter.show_time
