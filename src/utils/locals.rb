module Fizzy::Locals

  include Fizzy::IO

  # Entry point for using the DSL defined by `Proxy` class.
  # The DSL is directly accessible inside the provided block.
  #
  def define_locals(&block)
    error("No requirements specification provided.") unless block_given?
    @locals_proxy = Fizzy::Locals::Proxy.new(self)
    @locals_proxy.instance_eval(&block)
  end

  # ┌──────────────────────────────────────────────────────────────────────────┐
  # ├→ Forward DSL calls to the `Proxy` ───────────────────────────────────────┤

  def local(name)
    @locals_proxy.local(name)
  end

  def local!(name)
    @locals_proxy.local!(name)
  end

  def local?(*names, &block)
    @locals_proxy.local?(*names, &block)
  end

  # └──────────────────────────────────────────────────────────────────────────┘

  # DSL used for defining locals.
  #
  class Proxy

    include Fizzy::IO

    attr_reader :locals

    def initialize(receiver)
      @receiver = receiver
      @locals   = {}
      @prefix   = nil
    end

    # ┌────────────────────────────────────────────────────────────────────────┐
    # ├→ DSL definition ───────────────────────────────────────────────────────┤

    # Create a new `local` fetching the value from the corresponding `variable`.
    #
    def variable(name, *args, **opts)
      name = name.to_s.to_sym

      var = _get_var(name, **opts.slice(:type, :strict))

      _set_local(opts.fetch(:as, name),
                 var.nil? ? opts.fetch(:default, nil) : var)
    end

    # Create a new computed `local`, based upon other locals.
    #
    def computed(name, &block)
      name = name.to_s.to_sym
      error("Invalid local name `#{name}`: it's blank.") if name.empty?
      error("Cannot compute local `#{name}`.") unless block_given?

      _set_local(name, @receiver.instance_exec(&block))
    end

    # Access the value of a local.
    #
    def local(name)
      @locals[name.to_s.to_sym]
    end

    # Access the value of a local or raise an error if it's not defined.
    #
    def local!(name)
      value = local(name)
      error("Undefined local `#{name}`.") if value.nil?
      value
    end

    # If all locals identified by `names` are available, evaluate the block
    # passing the locals' values.
    #
    def local?(*names, &block)
      names.collect{|name| local(name)}.compact.length == names.length
    end

    def prefixed(var, as: nil, optional: false)
      error("A block is required") unless block_given?
      unless @receiver.get_var(var.gsub(/\.$/, ""))
        return if optional
        error("Invalid variable prefix: `#{var}`.")
      end
      @prefix = {var: var, local: as}
      yield
      @prefix = nil
    end

    # └────────────────────────────────────────────────────────────────────────┘

    def _get_var(name, **opts)
      name = @prefix && @prefix[:var] ? "#{@prefix[:var]}#{name}" : name
      @receiver.get_var(name.to_s.to_sym, **opts)
    end

    def _set_local(name, value)
      name = @prefix && @prefix[:local] ? "#{@prefix[:local]}#{name}" : name
      @locals[name.to_s.to_sym] = value
    end

  end

end
