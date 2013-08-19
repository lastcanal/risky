require 'spec_helper'

Risky.riak = proc { Riak::Client.new(:host => '127.0.0.1', :protocol => 'pbc') }
class Album < Risky
  include Risky::SecondaryIndexes

  bucket :risky_albums

  index2i :artist_id, :map => true
  index2i :label_key, :map => '_key', :allow_nil => true
  index2i :genre, :type => :bin, :allow_nil => true
  index2i :tags, :type => :bin, :multi => true, :allow_nil => true

  value :name
  value :year

  allow_mult
end

class Artist < Risky
  bucket :risky_artists

  value :name
end

class Label < Risky
  bucket :risky_labels

  value :name
end

class City < Risky
  include Risky::SecondaryIndexes
  bucket :risky_cities

  index2i :country_id, :type => :invalid, :allow_nil => true

  value :name
  value :details
end


describe SecondaryIndexes do
  let(:artist) { Artist.create(1, :name => 'Motorhead') }
  let(:label) { Label.create(1, :name => 'Bronze Records') }


  before :each do
    Album.delete_all
    Artist.delete_all
    Label.delete_all
  end

  it "sets indexes on initialize" do
    album = Album.new(1, {:name => 'Bomber', :year => 1979}, {:artist_id => 2})
    album.indexes2i.should == {"artist_id" => 2 }
  end

  it "defines getter and setter methods" do
    album = Album.new(1)
    album.artist_id = 1
    album.artist_id.should == 1
  end

  it "defines association getter and setter methods" do
    album = Album.new(1)
    album.artist = artist
    album.artist.should == artist
  end

  it "defines association getter and setter methods when using suffix" do
    album = Album.new(1)
    album.label = label
    album.label.should == label
  end

  it "resets association if associated object is not saved" do
    artist = Artist.new(1)
    album = Album.new(1)
    album.artist = artist
    album.artist.should be_nil
  end

  it "assigns attributs after association assignment" do
    album = Album.new(1)
    album.artist = artist
    album.artist_id.should == artist.id
  end

  it "assigns association after attribute assignment" do
    album = Album.new(1)
    album.artist_id = artist.id
    album.artist.should == artist
  end

  it "saves a model with indexes" do
    album = Album.new(1, {:name => 'Ace of Spades' }, { :artist_id => 1 }).save
    album.artist_id.should == 1
  end

  it "creates a model with indexes" do
    album = Album.create(1, {:name => 'Ace of Spades' }, { :artist_id => 1 })
    album.artist_id.should == 1
  end

  it "persists association after save" do
    sleep 3 # we need to sleep here until delete from before block finishes

    album = Album.new(1)
    album.name = 'Ace of Spades'
    album.artist_id = artist.id
    album.save

    album.artist.should == artist
    album.artist_id.should == artist.id

    album.reload

    album.artist.should == artist
    album.artist_id.should == artist.id

    album = Album.find(album.id)

    album.artist.should == artist
    album.artist_id.should == artist.id
  end

  it "finds first by int secondary index" do
    album = Album.create(1, {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id})

    albums = Album.find_by_index(:artist_id, artist.id)
    albums.should == album
  end

  it "finds all by int secondary index" do
    album1 = Album.create(1, {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id})
    album2 = Album.create(1, {:name => 'Ace Of Spaces', :year => 1980},
      {:artist_id => artist.id, :label_key => label.id})

    albums = Album.find_all_by_index(:artist_id, artist.id)
    albums.should include(album1)
    albums.should include(album2)
  end

  it "finds all by binary secondary index" do
    album = Album.create(1, {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id, :genre => 'heavy'})

    Album.find_all_by_index(:genre, 'heavy').should == [album]
  end

  it "finds all by multi binary secondary index" do
    album = Album.create(1, {:name => 'Bomber', :year => 1979},
      {:artist_id => artist.id, :label_key => label.id,
       :tags => ['rock', 'heavy']})

    Album.find_all_by_index(:tags, 'heavy').should == [album]
    Album.find_all_by_index(:tags, 'rock').should == [album]
  end

  it "raises an exception when index is nil" do
    album = Album.new(1)
    expect { album.save }.to raise_error(ArgumentError)
  end

  it "raises an exception when type is invalid" do
    city = City.new(1)
    expect { city.save }.to raise_error(TypeError)
  end

  it "can inspect a model" do
    album = Album.new(1, { :name => 'Bomber' }, { :artist_id => 2 })

    album.inspect.should match(/Album 1/)
    album.inspect.should match(/"name"=>"Bomber"/)
    album.inspect.should match(/"artist_id"=>2/)
  end
end