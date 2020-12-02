require 'test_helper'
require 'db/mssql'

class MSSQLLimitOffsetTest < Test::Unit::TestCase

  class CreateLegacyShips < ActiveRecord::Migration

    def self.up
      create_table "legacy_ships", { :primary_key => :ShipKey } do |t|
        t.string "name", :limit => 50, :null => false
        t.integer "width", :default => 123
        t.integer "length", :default => 456
      end
    end

    def self.down
      drop_table "legacy_ships"
    end

  end

  class LegacyShip < ActiveRecord::Base
    self.primary_key = "ShipKey"
  end

  class CreateLongShips < ActiveRecord::Migration

    def self.up
      create_table "long_ships", :force => true do |t|
        t.string "name", :limit => 50, :null => false
        t.integer "width", :default => 123
        t.integer "length", :default => 456
      end
    end

    def self.down
      drop_table "long_ships"
    end

  end

  class LongShip < ActiveRecord::Base
    has_many :vikings
  end

  class CreateVikings < ActiveRecord::Migration

    def self.up
      create_table "vikings", :force => true do |t|
        t.integer "long_ship_id", :null => false
        t.string "name", :limit => 50, :default => "Sven"
        t.decimal "strength", :limit => 10, :default => 1.0
        t.timestamps
      end
    end

    def self.down
      drop_table "vikings"
    end

  end

  class Viking < ActiveRecord::Base
    belongs_to :long_ship
  end

  class CreateNoIdVikings < ActiveRecord::Migration
    def self.up
      create_table "no_id_vikings", :force => true do |t|
        t.string "name", :limit => 50, :default => "Sven"
      end
      remove_column "no_id_vikings", "id"
    end

    def self.down
      drop_table "no_id_vikings"
    end
  end

  class NoIdViking < ActiveRecord::Base
  end

  def setup
    CreateLegacyShips.up
    CreateLongShips.up
    CreateVikings.up
    CreateNoIdVikings.up
    ActiveRecord::Base.connection.execute "CREATE VIEW viewkings AS ( SELECT id, name, long_ship_id FROM vikings )"
  end

  def teardown
    ActiveRecord::Base.connection.execute "DROP VIEW viewkings"
    CreateLegacyShips.down
    CreateVikings.down
    CreateLongShips.down
    CreateNoIdVikings.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_limit_with_no_id_column_available
    NoIdViking.create!(:name => 'Erik')
    assert NoIdViking.first # nothing raised
  end

  def test_limit_with_alternate_named_primary_key
    %w(one two three four five six seven eight).each do |name|
      LegacyShip.create!(:name => name)
    end
    ships = LegacyShip.limit(3)
    assert_equal(3, ships.size)
  end if ar_version('3.0')

  def test_limit_and_offset
    %w(one two three four five six seven eight).each do |name|
      LongShip.create!(:name => name)
    end
    if ar_version('4.0')
      ship_names = LongShip.offset(2).limit(3).to_a.map(&:name)
    else
      ship_names = LongShip.find(:all, :offset => 2, :limit => 3).map(&:name)
    end
    assert_equal(%w(three four five), ship_names)
  end

  def test_limit_and_offset_with_order
    names = %w(one two three four five six seven eight).each do |name|
      LongShip.create!(:name => name)
    end
    if ar_version('4.0')
      ship_names = LongShip.order("name").offset(4).limit(2).to_a.map(&:name)
    else
      ship_names = LongShip.find(:all, :order => "name", :offset => 4, :limit => 2).map(&:name)
    end
    assert_equal(names.sort[4, 2], ship_names)

    if ar_version('4.0')
      ship_names = LongShip.order("id").offset(4).limit(2).to_a.map(&:name)
    else
      ship_names = LongShip.find(:all, :order => "id", :offset => 4, :limit => 2).map(&:name)
    end
    assert_equal(%w(five six), ship_names)
  end

  def test_limit_and_offset_with_include
    skei = LongShip.create!(:name => "Skei")
    skei.vikings.create!(:name => "Bob")
    skei.vikings.create!(:name => "Ben")
    skei.vikings.create!(:name => "Basil")
    if ar_version('4.0')
      ships = Viking.includes(:long_ship).offset(1).limit(2) #.all
    else
      ships = Viking.find(:all, :include => :long_ship, :offset => 1, :limit => 2)
    end
    assert_equal(2, ships.size)
  end

  def test_limit_and_offset_with_include_and_order
    boat1 = LongShip.create!(:name => "1-Skei")
    boat2 = LongShip.create!(:name => "2-Skei")

    boat1.vikings.create!(:name => "Adam")
    boat2.vikings.create!(:name => "Ben")
    boat1.vikings.create!(:name => "Carl")
    boat2.vikings.create!(:name => "Donald")

    if ar_version('4.0')
      vikings = Viking.includes(:long_ship).order('long_ships.name, vikings.name').references(:long_ship).offset(0).limit(3)
    else
      vikings = Viking.find(:all, :include => :long_ship, :order => "long_ships.name, vikings.name", :offset => 0, :limit => 3)
    end
    assert_equal ["Adam", "Carl", "Ben"], vikings.map(&:name)
  end

  def test_offset_without_limit
    %w( egy keto harom negy ot hat het nyolc ).each do |name|
      LongShip.create!(:name => name)
    end
    if ar_version('4.0')
      ships = LongShip.select(:name).offset(3).to_a
    elsif ar_version('3.0')
      ships = LongShip.select(:name).offset(3).all
    else
      ships = LongShip.find(:all, :select => 'name', :offset => 3)
    end
    assert_equal ['negy', 'ot', 'hat', 'het', 'nyolc'], ships.map(&:name)
  end

  def test_limit_with_group_by
    # TODO: simply out-of-order - group.limit not supported !
    %w( one two three four five six seven eight ).each do |name|
      LongShip.create!(:name => name)
    end
    ships = LongShip.select(:name).group(:name).limit(2).all
    assert_equal ['one', 'two'], ships.map(&:name)

    ships = LongShip.select(:name).group(:name).limit(2).offset(2)
    assert_equal ['three', 'four'], ships.map(&:name)
  end if ar_version('3.0')

  # NOTE: can not work due how MS-SQL "rulezzz"
  # Column 'long_ships.id' is invalid in the select list because it is not
  # contained in either an aggregate function or the GROUP BY clause.:
  #  SELECT t.* FROM ( SELECT ROW_NUMBER() OVER(ORDER BY MIN([long_ships].[id]))
  #   AS _row_num, [long_ships].* FROM [long_ships]
  #   GROUP BY [long_ships].[name] ) AS t WHERE t._row_num BETWEEN 1 AND 2
  #
#  def test_limit_with_group_by_all
#    %w( one two three four five six seven eight ).each do |name|
#      LongShip.create!(:name => name)
#    end
#    ships = LongShip.select('*').group(:name).limit(2).all
#    assert_equal ['one', 'two'], ships.map(&:name)
#
#    ships = LongShip.select(:name).group(:name).limit(2).offset(2)
#    assert_equal ['three', 'four'], ships.map(&:name)
#  end if ar_version('3.0')

  def test_limit_with_group_by_and_aggregate_in_order_clause
    %w( one two three four five six seven eight ).each_with_index do |name, i|
      LongShip.create!(:name => name, :width => (i+1)*10)
    end

    ships = LongShip.select(:name).group(:name).limit(2).order('width').all
    assert_equal ['one', 'two'], ships.map(&:name)

    ships = LongShip.select(:name).group(:name).limit(2).order('width DESC').all
    assert_equal ['eight', 'seven'], ships.map(&:name)

    ships = LongShip.select(:name).group(:name).limit(2).order('MAX(width)').all
    assert_equal ['one', 'two'], ships.map(&:name)

    ships = LongShip.select(:name).group(:name).limit(2).order('MAX(width) DESC').all
    assert_equal ['eight', 'seven'], ships.map(&:name)
  end if ar_version('3.0')

  def test_select_distinct_with_limit
    %w(c a b a b a c d c d).each do |name|
      LongShip.create!(:name => name)
    end
    if ar_version('3.0')
      result = LongShip.select("DISTINCT name").order("name").limit(2)
    else
      result = LongShip.find(:all, :select => "DISTINCT name", :order => "name", :limit => 2)
    end
    assert_equal %w(a b), result.map(&:name)
  end

  def test_select_distinct_view_with_joins_and_limit
    mega_ship = LongShip.create! :name => 'mega-canoe'
    giga_ship = LongShip.create! :name => 'giga-canoe'
    Viking.create! :name => '11', :long_ship_id => mega_ship.id
    Viking.create! :name => '21', :long_ship_id => giga_ship.id
    Viking.create! :name => '12', :long_ship_id => mega_ship.id
    Viking.create! :name => '22', :long_ship_id => giga_ship.id

    result = Viking.select('DISTINCT *').limit(10).
      joins(:long_ship).where(:long_ship_id => mega_ship.id).
      order('name')
    assert_equal [ '11', '12' ], result.map { |viking| viking.name }
  end if ar_version('3.0')

  class Viewking < ActiveRecord::Base
    belongs_to :long_ship
    self.primary_key = 'id'
  end

  def test_order_and_limit_view_with_include
    mega_ship = LongShip.create! :name => 'mega-canoe'
    giga_ship = LongShip.create! :name => 'giga-canoe'
    Viking.create! :name => 'Jozko', :long_ship_id => mega_ship.id
    Viking.create! :name => 'Ferko', :long_ship_id => giga_ship.id

    # NOTE: since connection.primary_key('viewkings') returns nil
    # this test will fail if it's not explicitly set self.primary_key = 'id'

    arel = Viewking.includes(:long_ship).order('long_ships.name').limit(2)
    assert_equal [ 'Ferko', 'Jozko' ], arel.map { |viking| viking.name }

    arel = Viewking.includes(:long_ship).limit(3)
    assert_equal 2, arel.to_a.size
  end if ar_version('3.0')

  test 'ordering_on_aggregate GH-532' do
    5.times { |i| LongShip.create! :name => "ship_#{i}", :length => 1000 + i }
    m1_ship = LongShip.create! :name => 'matching-1', :length => 500
    m2_ship = LongShip.create! :name => 'matching-2', :length => 600

    Viking.create! :name => 'V1', :long_ship_id => m1_ship.id
    Viking.create! :name => 'V2', :long_ship_id => m2_ship.id
    Viking.create! :name => 'X3', :long_ship_id => LongShip.first.id
    Viking.create! :name => 'X4', :long_ship_id => LongShip.first.id
    Viking.create! :name => 'X5', :long_ship_id => LongShip.limit(3).last.id
    Viking.create! :name => 'V6', :long_ship_id => m2_ship.id
    Viking.create! :name => 'V7', :long_ship_id => m2_ship.id
    Viking.create! :name => 'V8', :long_ship_id => m1_ship.id

    result = Viking
        .select('w.*, count(o.length) num_objects')
        .joins("w inner join long_ships o on o.id = w.long_ship_id" )
        .where('w.long_ship_id > 0 and w.long_ship_id IN (?)', [ m2_ship.id, m1_ship.id ])
        .group('w.long_ship_id, w.name, w.strength, w.id, w.updated_at, w.created_at')
        .order('count(o.length) DESC')
        .limit(4)
    assert_equal ['V1','V2','V6','V7'], result.map(&:name)
  end

end
