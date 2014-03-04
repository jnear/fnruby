require_relative 'fnruby'
require "test/unit"


data { List = Nil | Cons(a, b) }

class TestSimpleNumber < Test::Unit::TestCase
  
  def test_simple
    x = Cons(1,2)
    r = match { with x,
      Nil => "wrong answer",
      Cons(a, b) => "right answer! #{a} #{b}" }
    assert_equal(r, "right answer! 1 2")


    # nested structures, ignoring bound vars
    x = Cons(1, Cons(2, 3))
    r = match { with x,
      Nil => "wrong answer",
      Cons(a, Cons(b, c)) => "only used one #{b}" }
    assert_equal(r, "only used one 2")


    # nested structures and constants, ignoring bound vars
    x = Cons(1, Cons(2, 3))
    r = match { with x,
      Nil => "wrong answer",
      Cons(1, Cons(b, c)) => "only used one #{b}" }
    assert_equal(r, "only used one 2")


    # nested structures and WRONG constant
    x = Cons(1, Cons(2, 3))
    r = match { with x,
      Nil => "wrong answer",
      Cons(2, Cons(b, c)) => "only used one #{b}" }
    assert_equal(r, false)


    # wrong structure
    x = Cons(1, Nil)
    r = match { with x,
      Nil => "wrong answer",
      Cons(a, Cons(b, c)) => "only used one #{b}" }
    assert_equal(r, false)


    # non-adt structures
    r =  match { with 1.is_a?(String),
      true => "wrong answer",
      false => "right answer" }
    assert_equal(r, "right answer")
  end

  def test_lists
    ls = [1,2,3]
    r = match { with ls,
      [] => "wrong answer",
      x::xs => "right answer #{x} and #{xs}" }
    assert_equal("right answer 1 and [2, 3]", r)
  end
end

