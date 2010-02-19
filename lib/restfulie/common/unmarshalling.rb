module Hashi
  class CustomHash
    def initialize(hash = {})
      @internal_hash = hash
      link = hash['link'] if hash.kind_of? Hash
      add_transitions([link]) if link.kind_of? Hash
      add_transitions(link) if link.kind_of? Array
    end
  end
end

# module Jeokkarak
#   module Base
#     alias_method :old_from_hash_parse, :from_hash_parse
#     def from_hash_parse(result,h,key,value)
#       return old_from_hash_parse(result, h, key, value) if key!='link'
#       link = h[key]
#       result.add_transitions([link]) if link.kind_of? Hash
#       result.add_transitions(link) if link.kind_of? Array
#     end
#   end
# end

module Restfulie
  module Unmarshalling
    # basic code from Matt Pulver
    # found at http://www.xcombinator.com/2008/08/11/activerecord-from_xml-and-from_json-part-2/
    # addapted to support links
    
    def from_hash( hash )
      h = hash ? hash.dup : {}
      links = nil
      h.each do |key, value|
        if key == "link"
          links = value.instance_of?(Array) ? h[key] : [h[key]]
        elsif [Array, Hash].include? value.class
          klazz = get_the_class(key)
          if value.instance_of?(Array)
            h[key].map! { |e| (klazz || Hashi::CustomHash).send(:from_hash, e) }
          elsif value.instance_of?(Hash)
            h[key] = klazz.array_from_hash(value)
          else
            h[key] = klazz.from_hash value
          end
        end
         h.delete key if ["xmlns", "link"].include?(key)
       end
       
       result = make_new_object h
       result.add_transitions(links) if !(links.nil?) && self.include?(Restfulie::Client::InstanceMethods)
       result
     end
     
     # creates an array of this type based on a hash created using rails Hash.from_xml method
     # because Hash.from_xml returns some no-cute hash structure when dealing with aligned elements
     # we had to support it in a variety of ways.
     # usage example:
     #
       # hash = {"player" => {"name" => "guilherme silveira"}}
       # player = Player.array_from_hash(hash)
       # puts player[0].name
       # 
       # hash = {"player" => [{"name" => "guilherme silveira"}, {"name" => "andre de santi"}]}
       # player = Player.array_from_hash(hash)
       # puts player[0].name
       # puts player[1].name
     def array_from_hash(hash)
       
       return self.from_hash(hash) unless (hash.size == 1 && hash.keys.first == self.to_s.underscore)
       
       children = hash.values.first
       
       return [self.from_hash(children)] unless children.instance_of?(Array)

       children.map { |child| self.from_hash(child) }
       
     end
     
    def from_json(json)
      from_hash(safe_json_decode(json).values.first)
    end

    # The xml has a surrounding class tag (e.g. ship-to),
    # but the hash has no counterpart (e.g. 'ship_to' => {} )
    def from_xml(xml)
      hash = Hash.from_xml xml
      head = hash[self.to_s.underscore]
      result = self.from_hash head
      return nil if result.nil?
      result._came_from = :xml if self.include?(Restfulie::Client::InstanceMethods)
      result
    end
    
    private
    def make_new_object(hash = {})
      obj = self.new
      hash.keys.each { |key| obj.send("#{key}=", hash[key]) }
      obj
    end
    
    def get_the_class(name)
      respond_to?(:reflect_on_association) ? reflect_on_association(name.to_sym).klass.to_s.constantize : nil
    end
  end
end  

private
def safe_json_decode(json)
  return {} if !json
  begin
    ActiveSupport::JSON.decode json
  rescue ; {} end
end
# end of code based on Matt Pulver's