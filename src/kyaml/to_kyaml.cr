require "./any"
require "./emitter"

module KYAML
  # Emits an arbitrary basic typed *object* as KYAML to *io*.
  #
  # Accepts scalar and collection types and normalizes them into the `KYAML::Any::Type` union, delegating to the `KYAML::Emitter`.
  #
  # Structs are out of scope here, use the (pending) `KYAML::Serializable` instead.
  def self.emit(object, io : IO) : Nil
    Emitter.new(io).emit(normalize(object))
  end

  # :ditto:
  def self.emit(object) : String
    String.build { |io| emit(object, io) }
  end

  # Emits each element of *objects* as its own KYAML doc to *io*.
  #
  # An empty collection generates no output.
  def self.emit_all(objects : Enumerable, io : IO) : Nil
    objects.each do |object|
      io << "---\n"
      emit(object, io)
      io << '\n'
    end
  end

  # :ditto:
  def self.emit_all(objects : Enumerable) : String
    String.build { |io| emit_all(objects, io) }
  end

  # Normalizes a basic typed value into the `KYAML::Any::Type` union so the emitter can render it. Recurses through Arrays and Hashes.
  def self.normalize(value : Nil) : KYAML::Any::Type
    nil
  end

  # :nodoc:
  def self.normalize(value : Bool) : KYAML::Any::Type
    value
  end

  # :nodoc:
  def self.normalize(value : Int) : KYAML::Any::Type
    value.to_i64
  end

  # :nodoc:
  def self.normalize(value : Float) : KYAML::Any::Type
    value.to_f64
  end

  # :nodoc:
  def self.normalize(value : String | Symbol | Char) : KYAML::Any::Type
    value.to_s
  end

  # :nodoc:
  def self.normalize(value : KYAML::Any) : KYAML::Any::Type
    value.raw
  end

  # :nodoc:
  def self.normalize(value : Array) : KYAML::Any::Type
    value.map { |elem| KYAML::Any.new(normalize(elem)) }
  end

  # :nodoc:
  def self.normalize(value : Hash) : KYAML::Any::Type
    normalized = {} of String => KYAML::Any
    value.each do |k, v|
      normalized[k.to_s] = KYAML::Any.new(normalize(v))
    end
    normalized
  end
end

# TODO: Probably remove when Serializable is implemented?
class Object
  # Emits `self` as KYAML to *io*.
  def to_kyaml(io : IO) : Nil
    KYAML.emit(self, io)
  end

  # Emits `self` as KYAML and returns it as a `String`.
  def to_kyaml : String
    KYAML.emit(self)
  end
end
