require 'test_helper'
require 'db/postgres'

class PostgreSQLQuotingTest < Test::Unit::TestCase

  Column = ActiveRecord::ConnectionAdapters::Column

  def test_type_cast_true
    if ar_version('4.2')
      # TODO port test
    else
      c = Column.new(nil, 1, 'boolean')
      assert_equal 't', connection.type_cast(true, nil)
      assert_equal 't', connection.type_cast(true, c)
    end
  end if ar_version('3.1')

  def test_type_cast_false
    if ar_version('4.2')
      # TODO port test
    else
      c = Column.new(nil, 1, 'boolean')
      assert_equal 'f', connection.type_cast(false, nil)
      assert_equal 'f', connection.type_cast(false, c)
    end
  end if ar_version('3.1')

  def test_type_cast_cidr
    if ar_version('4.2')
      # TODO port test
    else
      ip = IPAddr.new('255.0.0.0/8')
      c = Column.new(nil, ip, 'cidr')
      assert_equal ip, connection.type_cast(ip, c)
    end
  end if ar_version('4.0')

  def test_type_cast_inet
    if ar_version('4.2')
      # TODO port test
    else
      ip = IPAddr.new('255.1.0.0/8')
      c = Column.new(nil, ip, 'inet')
      assert_equal ip, connection.type_cast(ip, c)
    end
  end if ar_version('4.0')

  def test_quote_float_nan
    nan = 0.0/0
    if ar_version('4.2')
      # TODO port test
    else
      c = Column.new(nil, 1, 'float')
      assert_equal "'NaN'", connection.quote(nan, c)
    end
  end

  def test_quote_float_infinity
    infinity = 1.0/0
    if ar_version('4.2')
      # TODO port test
    else
      c = Column.new(nil, 1, 'float')
      assert_equal "'Infinity'", connection.quote(infinity, c)
    end
  end

  def test_quote_cast_numeric
    fixnum = 666
    if ar_version('4.2')
      # TODO port test
    else
      c = Column.new(nil, nil, 'varchar')
      assert_equal "'666'", connection.quote(fixnum, c)
      c = Column.new(nil, nil, 'text')
      assert_equal "'666'", connection.quote(fixnum, c)
    end
  end

  def test_quote_time_usec
    assert_equal "'1970-01-01 00:00:00.000000'", connection.quote(Time.at(0))
    if ar_version('4.0')
      assert_equal "'1970-01-01 00:00:00.000000'", connection.quote(Time.at(0).to_datetime)
    else
      #assert_equal "'1970-01-01 00:00:00'", connection.quote(Time.at(0).to_datetime)
    end
  end if ar_version('3.0')

  OID = ActiveRecord::ConnectionAdapters::PostgreSQL::OID rescue nil

  def test_quote_range
    range = "1,2]'; SELECT * FROM users; --".."a"
    if ar_version('4.2')
      # TODO port test
    else
      c = Column.new(nil, nil, 'int8range')
      assert_equal "'[1,2]''; SELECT * FROM users; --,a]'::int8range", connection.quote(range, c)
      #c = PostgreSQLColumn.new(nil, nil, OID::Range.new(:integer), 'int8range')
      #assert_equal "'[1,2]''; SELECT * FROM users; --,a]'::int8range", @conn.quote(range, c)
    end
  end if OID

end