require 'test_helper'

require "test_xml/mini_test"
require "roxml"


require "roar/representer/roxml"



class RoxmlRepresenterUnitTest < MiniTest::Spec
  describe "XmlRepresenter" do
    describe "#link" do
      class Rapper < Roar::Representer::Roxml
        link :self
        link :next
      end
      
      it "creates a LinksDefinition" do
        assert_equal 1, Rapper.roxml_attrs.size
        assert_equal [{:rel=>:self, :block=>nil}, {:rel=>:next, :block=>nil}], Rapper.roxml_attrs.first.rel2block
      end
    end
    
    
    
  end
  
end

class LinksDefinitionTest < MiniTest::Spec
  describe "LinksDefinition" do
    before do
      @d = Roar::Representer::LinksDefinition.new(:links)
    end
    
    it "accepts options in constructor" do
      assert_equal [], @d.rel2block
    end
    
    it "accepts configuration" do
      @d.rel2block << {:rel => :self}
      assert_equal [{:rel=>:self}], @d.rel2block
    end
  end
end

class RoxmlDefinitionTest < MiniTest::Spec
  class Rapper
    attr_accessor :name
  end
  
  describe "ROXML::Definition" do
    it "responds to #populate" do
      @r = Rapper.new
      ROXML::Definition.new(:name).populate(@r, "name" => "Eugen")
      assert_equal "Eugen", @r.name
    end
  end
end

class RoxmlRepresenterFunctionalTest < MiniTest::Spec
  class ItemApplicationXml < Roar::Representer::Roxml
    xml_name :item
    xml_accessor :value
  end
  
  class Item
    include Roar::Model
    accessors :value
    
    def self.model_name
      "item"
    end
  end
  
  class Order
    include Roar::Model
    accessors :id, :item
    
    def self.model_name
      :order
    end
  end
  
  class GreedyOrder
    include Roar::Model
    accessors :id, :items
    
    def self.model_name
      :order
    end
  end
  
  
  describe "with ModelWrapper" do
    class OrderXmlRepresenter < Roar::Representer::Roxml
      xml_accessor :id
      xml_accessor :item, :as => ItemApplicationXml
    end
    
    before do
      @c = Class.new(OrderXmlRepresenter)
    end
    
    
    it "#for_model copies represented model attributes, nothing more" do
      @o = Order.new("id" => 1, "item" => Item.new("value" => "Beer"))
      
      @r = @c.for_model(@o)
      assert_kind_of OrderXmlRepresenter, @r
      assert_equal 1, @r.id
      
      @i = @r.item
      assert_kind_of ItemApplicationXml, @i
      assert_equal "Beer", @i.value
    end
    
    it "Model::ActiveRecordMethods#to_nested_attributes" do
      @o = Order.new("id" => 1, "item" => Item.new("value" => "Beer"))
      @r = @c.for_model(@o)
      
      @c.class_eval do
        include Roar::Representer::ActiveRecordMethods
      end
      assert_equal({"id" => 1, "item_attributes" => {"value" => "Beer"}}, @r.to_nested_attributes) # DISCUSS: overwrite #to_attributes.
    end
    
    describe "#compute_attributes_for in #for_model" do
      it "respects :model_reader" do
        class Representery < Roar::Representer::Roxml
          xml_accessor :id, :model_reader => :value
        end
        
        assert_equal "Beer", Representery.for_model(Item.new("value" => "Beer")).id
      end
      
      
    end
    
    
  end
  
  
  
  
  
  class TestXmlRepresenter < Roar::Representer::Roxml
    xml_name :order  # FIXME: get from represented?
    xml_accessor :id
  end
  
  
  describe "RoxmlRepresenter" do
    before do
      @m = {"id" => "1"}
      @o = Order.new(@m)
      @r = TestXmlRepresenter.new
      @i = ItemApplicationXml.new
      @i.value = "Beer"
    end
    
    describe "#from_attributes" do
      it "copies represented attributes, only" do
        @r = OrderXmlRepresenter.from_attributes("id" => 1, "item" => @i, "unknown" => 1)
        assert_kind_of OrderXmlRepresenter, @r
        assert_equal 1, @r.id
        
        assert_kind_of ItemApplicationXml, @r.item
        assert_equal @r.item.value, "Beer"
      end
    end
    
    
    describe "#to_attributes" do
      it "returns a nested attributes hash" do
        @r = OrderXmlRepresenter.from_attributes("id" => 1, "item" => @i)
        assert_equal({"id" => 1, "item" => {"value" => "Beer"}}, @r.to_attributes)
      end
    end
    
    
    describe "#to_xml" do
      it "serializes the current model" do
        assert_xml_equal "<order/>", @r.to_xml.serialize
        
        @r.id = 2
        assert_xml_equal "<rap><id>2</id></rap>", @r.to_xml(:name => :rap).serialize
      end
    end
    
    
    describe "without options" do
      it "#serialize_model returns the serialized model" do
        assert_xml_equal "<order><id>1</id></order>", @r.class.serialize_model(@o)
      end
      
      
      it ".from_xml returns the deserialized model" do
        @m = TestXmlRepresenter.deserialize("<order><id>1</id></order>")
        assert_equal "1", @m.id
      end
      
      it ".from_xml still works with nil" do
        assert TestXmlRepresenter.deserialize(nil)
      end
      
    end
    
    
    describe "with a typed attribute" do
      before do
        @c = Class.new(Roar::Representer::Roxml) do
          xml_name :order
          xml_accessor :id
          xml_accessor :item, :as => ItemApplicationXml
        end
      end
      
      it "#serialize_model skips empty :item" do
        assert_xml_equal "<order><id>1</id></order>", @c.serialize_model(@o)
      end
      
      it "#to_xml delegates to ItemXmlRepresenter#to_xml" do
        @o.item = Item.new("value" => "Bier")
        assert_xml_equal "<order><id>1</id><item><value>Bier</value></item>\n</order>", 
          @c.serialize_model(@o)
      end
      
      it ".from_xml typecasts :item" do
        @m = @c.deserialize("<order><id>1</id><item><value>beer</value></item>\n</order>")
        
        assert_equal "1",     @m.id
        assert_equal "beer",  @m.item.value
      end
    end
    
    
    describe "with a typed list" do
      before do
        @c = Class.new(Roar::Representer::Roxml) do
          xml_name :order
          xml_accessor :id
          xml_accessor :items, :as => [ItemApplicationXml], :tag => :item
        end
        
        @o = GreedyOrder.new("id" => 1)
      end
      
      it "#serialize_model skips empty :item" do
        assert_xml_equal "<order><id>1</id></order>", @c.serialize_model(@o)
      end
      
      it "#serialize delegates to ItemXmlRepresenter#to_xml in list" do
        @o.items = [Item.new("value" => "Bier")]
        
        assert_xml_equal "<order><id>1</id><item><value>Bier</value></item></order>", 
          @c.serialize_model(@o)
      end
      
      it ".from_xml typecasts list" do
        @m = @c.deserialize("<order><id>1</id><item><value>beer</value></item>\n</order>")
        
        assert_equal "1",     @m.id
        assert_equal 1,       @m.items.size
        assert_equal "beer",  @m.items.first.value
      end
    end
    
  end
end

class HypermediaAPIFunctionalTest
  describe "Hypermedia API" do
    before do
      @c = Class.new(Roar::Representer::Roxml) do
        xml_name :wuff
        xml_accessor :id
        link :self do "http://self" end
        link :next do "http://next/#{id}" end
      end
      @r = @c.new
    end
    
    it "responds to #links" do
      assert_equal nil, @r.links
    end
    
    it "computes links in #from_attributes" do
      @r = @c.from_attributes({"id" => 1})
      assert_equal 2, @r.links.size
      assert_equal({"rel"=>:self, "href"=>"http://self"}, @r.links.first.to_attributes)
      assert_equal({"rel"=>:next, "href"=>"http://next/1"}, @r.links.last.to_attributes) 
    end
    
    it "extracts links from XML" do
      @r = @c.deserialize(%{
      <order>
        <link rel="self" href="http://self">
      </order>
      })
      assert_equal 1, @r.links.size
      assert_equal({"rel"=>"self", "href"=>"http://self"}, @r.links.first.to_attributes) 
    end
    
    it "renders <link> correctly in XML" do
      assert_xml_equal %{<wuff>
  <id>1</id>
  <link rel="self" href="http://self"/>
  <link rel="next" href="http://next/1"/>
</wuff><expected />}, @c.from_attributes({"id" => 1}).serialize
    end
    
  end
end

class HyperlinkRepresenterUnitTest
  describe "API" do
    before do
      @l = Roar::Representer::Roxml::Hyperlink.from_xml(%{<link rel="self" href="http://roar.apotomo.de"/>})
    end
    
    it "responds to #rel" do
      assert_equal "self", @l.rel
    end
    
    it "responds to #href" do
      assert_equal "http://roar.apotomo.de", @l.href
    end
  end
end


require 'roar/model/hypermedia'

class HypermediaTest
  describe "Hypermedia" do
    class Bookmarks
      include Roar::Model::Hypermedia
    end
    
    before do
      #@l = Roar::Representer::Roxml::Hyperlink.from_xml(%{<link rel="self" href="http://roar.apotomo.de"/>})
      @b = Bookmarks.new
      @b.links = [{"rel" => "self", "href" => "http://self"}, {"rel" => "next", "href" => "http://next"}]
    end
    
    it "responds to #links" do
      assert_kind_of Roar::Model::Hypermedia::LinkCollection, @b.links
      assert_equal 2, @b.links.size
    end
    
    
    it "responds to links #[]" do
      assert_equal "http://self", @b.links["self"]
      assert_equal "http://self", @b.links[:self]
      assert_equal "http://next", @b.links[:next]
      assert_equal nil, @b.links[:prev]
    end
  end
end
