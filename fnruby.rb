require 'sdg_utils/lambda/sourcerer'

class Object
  def matches(val)
    if self == val then [] else false end
  end
end

class ADTInstance
  attr_reader :type, :label, :args

  def initialize(type, label, *args)
    @type = type
    @label = label
    @args = args
  end

  def matches(val)
    def match_args(args, vals)
      if args == [] then 
        []  # if we reach the end of the list, we've succeeded
      else
        args_head, *args_tail = args
        vals_head, *vals_tail = vals

        r = args_head.matches(vals_head)
        rest = match_args(args_tail, vals_tail)

        # if the heads match and the tails match
        # then combine the results
        if r and rest then
          r + rest
        else
          false
        end
      end
    end

    if val.is_a? ADTInstance and val.type == @type and val.label == @label and val.args.length == @args.length then
      match_args(@args, val.args)
    else
      false
    end
  end
  
  def to_s
    @label.to_s + "(" + @args.map{|x| x.to_s}.join(", ") + ")"
  end
end

class PatternVar
  def initialize(name)
    @name = name
  end

  def matches(val)
    # ignore the name, return the value
    [val]
  end

  def to_s
    "PatternVar(" + @name.to_s + ")"
  end
end

def process_ast(ast)
  if ast.is_a? Parser::AST::Node then
    ast.type.to_s + "(" + ast.children.map{|x| process_ast(x)}.join(", ") + ")"
  else ast.to_s
  end
end

def process_data(ast)
  if ast.is_a? Parser::AST::Node and ast.type == :send and ast.children[1] == :| then
    process_data(ast.children[0]) + process_data(ast.children[2])
  else
    [ast]
  end
end

def process_data_type(p, t)
  case t.type
  when :const
    name = t.children[1]
    "#{name} = ADTInstance.new(:#{p}, :#{name})"
  when :send
    name = t.children[1]
    #arg_names = t.children.drop(2).map{|x| x[1].to_s}

    # ignoring the arg names here:
    "def #{name}(*args) ADTInstance.new(:#{p}, :#{name}, *args) end"
  end
end

def process_pattern(p)
  names = []
  new_p = SDGUtils::Lambda::Sourcerer.reprint(p) do |node, parent, anno|
    if node.type == :send and node.children[0] == nil and node.children.length == 2 then
      name = node.children[1]
      names.unshift(name)
      "PatternVar.new(:#{name})"
    else nil
    end
  end
  [names, new_p]
end

def process_rule(p, anno)
  names, left = process_pattern(p.children[0])
  right = "lambda {|" + names.map{|x| x.to_s}.join(",") + "| "  + SDGUtils::Lambda::Sourcerer.compute_src(p.children[1], anno) + "}"
  [left, right]
end


def instr_src(src)
  ast = SDGUtils::Lambda::Sourcerer.parse_string(src).children[2]
  return "" unless ast
  orig_src = SDGUtils::Lambda::Sourcerer.read_src(ast)
  #  puts "ast is " + ast.to_sexp
  
  instr_src = SDGUtils::Lambda::Sourcerer.reprint(ast) do |node, parent, anno|
    new_src =
      case node.type
      when :send
        if node.children[1] == :data then
          type_name_node = node.children[2]
          type_name = type_name_node.children[1]
          data_types = type_name_node.children[2]
          ts = process_data(data_types)

          results = ts.map{|x| process_data_type(type_name, x)}
          final = results.map{|x| x.to_s}.join("; ")
          final
        elsif node.children[1] == :match then
          val = SDGUtils::Lambda::Sourcerer.compute_src(node.children[2], anno)
          hash = node.children[3].children
          rules = "[" + hash.map{|x| left, right = process_rule(x, anno); "[#{left}, #{right}]"}.join(", ") + "]"
          "pattern_match(#{val}, #{rules})"
        else
          nil
        end
      else
        nil
      end
  end
  instr_src
end

def pattern_match(val, rules)
  #  puts "val is #{val} and rules are #{rules}"
  if rules == [] then
    false
  else
    head, *tail = rules
    vals = head[0].matches(val)
    if vals then 
      head[1].call(*vals)
    else
      pattern_match(val, tail)
    end
  end
end

def fnruby(&b)
  s = instr_src(b.source).to_s
  #  puts s
  eval(s)
end

