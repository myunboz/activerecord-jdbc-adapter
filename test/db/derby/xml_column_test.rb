require File.expand_path('test_helper', File.dirname(__FILE__))
require 'simple'

class DerbyXmlColumnTest < Test::Unit::TestCase
  include FixtureSetup
  include XmlColumnTestMethods

  def xml_sql_type;ArJdbc::AR42 ? 'XML(2147483647)':'xml';end

  # @override
  def test_use_xml_column
    omit("[derby] XML values are not allowed in top-level result sets;")
    # we'll need to somehow magically add XMLSERIALIZE for all XML columns !
    super
  end

end
