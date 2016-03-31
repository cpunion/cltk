# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains unit tests for the CLTK::Parser class.

############
# Requires #
############
require "spec"

# Standard Library
require "tempfile"

# Ruby Language Toolkit
require "../../src/cltk/lexer"
require "../../src/cltk/parser"
require "../../src/cltk/lexers/calculator"
require "../../src/cltk/parsers/prefix_calc"
require "../../src/cltk/parsers/infix_calc"
require "../../src/cltk/parsers/postfix_calc"

#######################
# Classes and Modules #
#######################

class ABLexer < CLTK::Lexer
  rule(/a/) { {:A, 1} }
  rule(/b/) { {:B, 2} }

  rule(/\s/)
end

class AlphaLexer < CLTK::Lexer
  rule(/[A-Za-z]/) { |t| {t.upcase, t} as BlockReturn}

  rule(/,/) { :COMMA }

  rule(/\s/)
end

class UnderscoreLexer < CLTK::Lexer
  rule(/\w/) { |t| {:A_TOKEN, t} as BlockReturn}
end

class APlusBParser < CLTK::Parser
  production(:a, "A+ B") do |a, b|
    if a[0].is_a? Array
      (a[0] as Array(CLTK::Type)).size
    end
  end

  finalize
end

class AQuestionBParser < CLTK::Parser
  production(:a, "A? B") { |a| a[0] }

  finalize
end

class AStarBParser < CLTK::Parser
  production(:a, "A* B") do |a|
    (a[0] as Array).size
  end

  finalize
end

class AmbiguousParser < CLTK::Parser
  production(:e) do
    clause("NUM") {|n| n[0] as Int32}

    clause("e PLS e") { |e| e = e as Array; (e[0] as Int32) + (e[2] as Int32)}
    clause("e SUB e") { |e| e = e as Array; (e[0] as Int32) - (e[2] as Int32)}
    clause("e MUL e") { |e| e = e as Array; (e[0] as Int32) * (e[2] as Int32)}
    clause("e DIV e") { |e| e = e as Array; (e[0] as Int32) / (e[2] as Int32)}
    nil

  end

  finalize
end

class ArrayCalc < CLTK::Parser
  default_arg_type :array

  production(:e) do
    clause("NUM") { |v| v[0] as Int32 }

    clause("PLS e e") { |v| v = v as Array;(v[1] as Int32) + ( v[2] as Int32) }
    clause("SUB e e") { |v| v = v as Array;(v[1] as Int32) - ( v[2] as Int32) }
    clause("MUL e e") { |v| v = v as Array;(v[1] as Int32) * ( v[2] as Int32) }
    clause("DIV e e") { |v| v = v as Array;(v[1] as Int32) / ( v[2] as Int32) }
    nil
  end

  finalize
end

# This grammar is purposefully ambiguous.  This should not be equivalent
# to the grammar produced with `e -> A B? B?`, due to greedy Kleene
# operators.
class AmbiguousParseStackParser < CLTK::Parser
  production(:s, "e*") { |e| e }

  production(:e, "A b_question b_question") { |a| a = a as Array; [a[0], a[1], a[2]] }

  production(:b_question) do
    clause("")	{ nil }
    clause("B")	{ |b| b }
    nil
  end

  finalize
end

class EBNFSelectorParser < CLTK::Parser
  default_arg_type :array

  production(:s) do
    clause(".A .B* .A") { |a| a }
    clause(".B C* .B")  { |a| a }
    nil
  end

  finalize
end

class EmptyListParser0 < CLTK::Parser
  build_list_production("list", :A, :COMMA)

  finalize
end

class EmptyListParser1 < CLTK::Parser
  default_arg_type :array

  build_list_production("list", ["A", "B", "C D"], :COMMA)

  finalize
end

class GreedTestParser0 < CLTK::Parser
  production(:e, "A? A") do |a|
    a = a as Array;
    [a[0], a[1]]
  end

  finalize
end

class GreedTestParser1 < CLTK::Parser
  production(:e, "A? A?") do |a, b|
    a0, a1 = a[0..1]
    [a0, a1]
  end

  finalize
end

class GreedTestParser2 < CLTK::Parser
  production(:e, "A* A") { |a| a = a as Array;[a[0], a[1]] }

  finalize
end

class GreedTestParser3 < CLTK::Parser
  production(:e, "A+ A") { |a| a = a as Array; [a[0], a[1]] }

  finalize
end

class NonEmptyListParser10 < CLTK::Parser
  build_nonempty_list_production("list", :A, :COMMA)

  finalize
end

class NonEmptyListParser1 < CLTK::Parser
  build_nonempty_list_production("list", [:A, :B], :COMMA)

  finalize({explain: "nelp1.tbl"})
end

class NonEmptyListParser2 < CLTK::Parser
  build_nonempty_list_production("list", ["A", "B", "C D"], :COMMA)

  finalize
end

class NonEmptyListParser3 < CLTK::Parser
  build_nonempty_list_production("list", "A+", :COMMA)

  finalize
end

class NonEmptyListParser4 < CLTK::Parser
  build_nonempty_list_production("list", :A)

  finalize
end

class NonEmptyListParser5 < CLTK::Parser
  build_nonempty_list_production("list", :A, "B C?")

  finalize
end

class DummyError1 < Exception; end
class DummyError2 < Exception; end

class ErrorCalc < CLTK::Parser
  left :ERROR
  right :PLS, :SUB, :MUL, :DIV, :NUM

  production(:e) do
    clause("NUM") {|n| n}

    clause("e PLS e") { |e| e = e as Array; (e[0] as Int32) + (e[2] as Int32) }
    clause("e SUB e") { |e| e = e as Array; (e[0] as Int32) - (e[2] as Int32) }
    clause("e MUL e") { |e| e = e as Array; (e[0] as Int32) * (e[2] as Int32) }
    clause("e DIV e") { |e| e = e as Array; (e[0] as Int32) / (e[2] as Int32) }
    clause("e PLS ERROR e") do |e, env|
      env.error(e[2]);
      e0= (e[0] as Array)[0] as Int32
      e1= (e[3] as Array)[0] as Int32
      e0 + e1
    end

    nil

  end

  finalize
end

class ELLexer < CLTK::Lexer
  rule(/\n/) { :NEWLINE }
  rule(/;/)  { :SEMI    }

  rule(/\s/)

  rule(/[A-Za-z]+/) { |t| {:WORD, t} as BlockReturn}
end

class ErrorLine < CLTK::Parser

  production(:s, "line*") { |l| l[0] }

  production(:line) do
    clause("NEWLINE") { nil }

    clause("WORD+ SEMI NEWLINE")	{ |w| w[0] }
    clause("WORD+ ERROR")		{ |w, e| e.error(e.pos(1).not_nil!.line_number); w[0] }
    nil
  end

  finalize
end

class UnderscoreParser < CLTK::Parser
  production(:s, "A_TOKEN+") { |o| o[0] }

  finalize
end

#class RotatingCalc < CLTK::Parser
#  class MyEnvironment < Environment
#    def initialize
#      @map = { :+ => 0, :- => 1, :* => 2, :/ => 3 }
#      @ops = [ :+, :-, :*, :/ ]
#      super()
#    end
#
#    def get_op(orig_op)
#      new_op = @ops[@map[orig_op]]
#
#      @ops = @ops[1..-1] << @ops[0]
#
#      new_op
#    end
#  end
#
#  setenv MyEnvironment
#
#  production(:e) do
#    clause("NUM") {|n| n}
#
#    clause("PLS e e") { | e, env| e[0].send((env as MyEnvironment).get_op(:+), e[1]) as Int32}
#    clause("SUB e e") { | e, env| e[0].send((env as MyEnvironment).get_op(:-), e[1]) as Int32}
#    clause("MUL e e") { | e, env| e[0].send((env as MyEnvironment).get_op(:*), e[1]) as Int32}
#    clause("DIV e e") { | e, env| e[0].send((env as MyEnvironment).get_op(:/), e[1]) as Int32}
#    nil
#  end
#
#
#  finalize
#end
class SelectionParser < CLTK::Parser
  production(:s, "A+ .B+") do |bs|
    (bs[0] as Array).reduce(0) do |sum, add|
      sum + (add as Int32)
    end
  end

  finalize
end

class UselessParser < CLTK::Parser
  production(:s, "A+") { |a| a[0] }
end

# class TokenHookParser < CLTK::Parser
#   default_arg_type :array
#
#   production(:s) do
#     clause("A A A A") { nil }
#     clause("B B B B") { nil }
#     nil
#   end
#
#   class CounterEnvironment < Environment
#     property :counter
#
#     def initialize
#       @counter = 0
#     end
#   end
#   setenv CounterEnvironment
#   token_hook(:A) { |env| (env as Environment).counter += 1; nil }
#   token_hook(:B) { |env| (env as Environment).counter += 2; nil }
#
#   finalize
# end

describe "CLTK::Parser" do

  it "test_ambiguous_grammar" do
    actual = AmbiguousParser.parse(CLTK::Lexers::Calculator.lex("1 + 2 * 3"), {:accept => :all})
    actual.should eq [9,7]
  end

  # This test is to ensure that objects placed on the output stack are
  # cloned when we split the parse stack.  This was posted as Issue #17 on
  # Github.
  it "test_ambiguous_parse_stack" do
    (AmbiguousParseStackParser.parse(ABLexer.lex("ab")) as Array).size.should eq 1
  end
#
  it "test_array_args" do
    actual = ArrayCalc.parse(CLTK::Lexers::Calculator.lex("+ 1 2"))
    (actual).should eq 3
    actual = ArrayCalc.parse(CLTK::Lexers::Calculator.lex("+ 1 * 2 3"))
    (actual).should eq 7
    actual = ArrayCalc.parse(CLTK::Lexers::Calculator.lex("* + 1 2 3"))
    (actual).should eq 9
  end
#
#  it "test_construction_error" do
#    expect_raises(CLTK::ParserConstructionException) do
#      class MyClass < CLTK::Parser
#	finalize
#      end
#    end
 # end

  it "test_ebnf_parsing" do
    ################
    # APlusBParser #
    ################

    expect_raises(CLTK::NotInLanguage) { APlusBParser.parse(ABLexer.lex("b")) }

    (APlusBParser.parse(ABLexer.lex("ab"))).should eq 1
    (APlusBParser.parse(ABLexer.lex("aab"))).should eq 2
    (APlusBParser.parse(ABLexer.lex("aaab"))).should eq 3
    (APlusBParser.parse(ABLexer.lex("aaaab"))).should eq 4

    ####################
    # AQuestionBParser #
    ####################

    expect_raises(CLTK::NotInLanguage) { AQuestionBParser.parse(ABLexer.lex("aab")) }
    AQuestionBParser.parse(ABLexer.lex("b")).should be_nil
    AQuestionBParser.parse(ABLexer.lex("ab")).should_not be_nil

    ################
    # AStarBParser #
    ################

    (AStarBParser.parse(ABLexer.lex("b")) as Int32).should eq 0
    (AStarBParser.parse(ABLexer.lex("ab")) as Int32).should eq 1
    (AStarBParser.parse(ABLexer.lex("aab")) as Int32).should eq 2
    (AStarBParser.parse(ABLexer.lex("aaab")) as Int32).should eq 3
    (AStarBParser.parse(ABLexer.lex("aaaab")) as Int32).should eq 4
  end

  it "test_empty_list" do
    ####################
    # EmptyListParser0 #
    ####################

    expected = [] of CLTK::Type
    actual   = EmptyListParser0.parse(AlphaLexer.lex(""))
    actual.should eq(expected)

    ####################
    # EmptyListParser1 #
    ####################

    expected = ["a", "b", ["c", "d"]]
    actual   = EmptyListParser1.parse(AlphaLexer.lex("a, b, c d"))
    actual.should eq(expected)
  end

	it "test_greed" do

		####################
		# GreedTestParser0 #
		####################

		expected = [nil, "a"]
		actual   = GreedTestParser0.parse(AlphaLexer.lex("a"))
                actual.should eq expected

		expected = ["a", "a"]
		actual   = GreedTestParser0.parse(AlphaLexer.lex("a a"))
                actual.should eq expected

		####################
		# GreedTestParser1 #
		####################
		expected = [nil, nil]
		actual   = GreedTestParser1.parse(AlphaLexer.lex(""))
                actual.should eq expected

		expected = ["a", nil]
		expected = [nil, "a"]
		actual   = GreedTestParser1.parse(AlphaLexer.lex("a"))
                actual.should eq expected



		expected = ["a", "a"]
		actual   = GreedTestParser1.parse(AlphaLexer.lex("a a"))
                actual.should eq expected


		####################
		# GreedTestParser2 #
		####################

		expected = [[] of CLTK::Type, "a"]
		actual   = GreedTestParser2.parse(AlphaLexer.lex("a"))
                actual.should eq expected


		expected = [["a"], "a"]
		actual   = GreedTestParser2.parse(AlphaLexer.lex("a a"))
                actual.should eq expected



		expected = [["a", "a"], "a"]
		actual   = GreedTestParser2.parse(AlphaLexer.lex("a a a"))
                actual.should eq expected


		####################
		# GreedTestParser3 #
		####################

		expected = [["a"], "a"]
		actual   = GreedTestParser3.parse(AlphaLexer.lex("a a"))
                actual.should eq expected

		expected = [["a", "a"], "a"]
		actual   = GreedTestParser3.parse(AlphaLexer.lex("a a a"))
                actual.should eq expected

	end

	it "test_ebnf_selector_interplay" do
		expected = ["a", ["b", "b", "b"], "a"]
		actual   = EBNFSelectorParser.parse(AlphaLexer.lex("abbba"))
                actual.should eq expected

		expected = ["a", [] of CLTK::Type, "a"]
		actual   = EBNFSelectorParser.parse(AlphaLexer.lex("aa"))
                actual.should eq expected

		expected = ["b", "b"]
		actual   = EBNFSelectorParser.parse(AlphaLexer.lex("bb"))
                actual.should eq expected

		expected = ["b", "b"]
		actual   = EBNFSelectorParser.parse(AlphaLexer.lex("bcccccb"))
                actual.should eq expected

	end

	pending "test_environment" do
		actual = RotatingCalc.parse(CLTK::Lexers::Calculator.lex("+ 1 2"))
		actual.should eq 3

		actual = RotatingCalc.parse(CLTK::Lexers::Calculator.lex("/ 1 * 2 3"))
		actual.should eq 7

		actual = RotatingCalc.parse(CLTK::Lexers::Calculator.lex("- + 1 2 3"))
		actual.should eq 9

		parser = RotatingCalc.new

		actual = parser.parse(CLTK::Lexers::Calculator.lex("+ 1 2"))
		actual.should eq 3

		actual = parser.parse(CLTK::Lexers::Calculator.lex("/ 1 2"))
		actual.should eq 3
	end

	it "test_error_productions" do

		# Test to see if error reporting is working correctly.

		test_string  = "first line;\n"
		test_string += "second line\n"
		test_string += "third line;\n"
		test_string += "fourth line\n"

		expect_raises(CLTK::HandledError) { ErrorLine.parse(ELLexer.lex(test_string)) }

		# Test to see if we can continue parsing after errors are encounterd.
		begin
			ErrorLine.parse(ELLexer.lex(test_string))
		rescue e: CLTK::HandledError
                  e.errors.should eq [2,4]
		end


		begin
		  ErrorCalc.parse(CLTK::Lexers::Calculator.lex("1 + + 1"))
		rescue e: CLTK::HandledError
                  (e.errors.first as Array).size.should eq 1
                  e.result.should eq 2
		end

		# Test to see if we pop tokens correctly after an error is
		# encountered.
		begin
		  ErrorCalc.parse(CLTK::Lexers::Calculator.lex("1 + + + + + + 1"))
		rescue e: CLTK::HandledError
                  (e.errors.first as Array).size.should eq 5
                  e.result.should eq 2
		end
	end

	it "test_infix_calc" do
		actual = CLTK::Parsers::InfixCalc.parse(CLTK::Lexers::Calculator.lex("1 + 2"))
                actual.should eq 3

		actual = CLTK::Parsers::InfixCalc.parse(CLTK::Lexers::Calculator.lex("1 + 2 * 3"))
                actual.should eq 7

		actual = CLTK::Parsers::InfixCalc.parse(CLTK::Lexers::Calculator.lex("(1 + 2) * 3"))
                actual.should eq 9

		expect_raises(CLTK::NotInLanguage) { CLTK::Parsers::InfixCalc.parse(CLTK::Lexers::Calculator.lex("1 2 + 3 *")) }
	end

	it "test_input" do
	  expect_raises(CLTK::BadToken) { CLTK::Parsers::InfixCalc.parse(CLTK::Lexers::EBNF.lex("A B C")) }
	end

	it "test_nonempty_list" do
		#######################
		# NonEmptyListParser10 #
		#######################

		expected = ["a"]
		actual   = NonEmptyListParser10.parse(AlphaLexer.lex("a"))
                actual.should eq expected

		expected = ["a", "a"]
		actual   = NonEmptyListParser10.parse(AlphaLexer.lex("a, a"))
		actual.should eq expected

		expect_raises(CLTK::NotInLanguage) { NonEmptyListParser10.parse(AlphaLexer.lex(""))   }
		expect_raises(CLTK::NotInLanguage) { NonEmptyListParser10.parse(AlphaLexer.lex(","))  }

                expect_raises(CLTK::NotInLanguage) { NonEmptyListParser10.parse(AlphaLexer.lex("aa")) }
		expect_raises(CLTK::NotInLanguage) { NonEmptyListParser10.parse(AlphaLexer.lex("a,")) }
		expect_raises(CLTK::NotInLanguage) { NonEmptyListParser10.parse(AlphaLexer.lex(",a")) }

		#######################
		# NonEmptyListParser1 #
		#######################
		expected = ["a"]
		actual   = NonEmptyListParser1.parse(AlphaLexer.lex("a"))
		actual.should eq expected
		expected = ["b"]
		actual   = NonEmptyListParser1.parse(AlphaLexer.lex("b"))
		actual.should eq expected

		expected = ["a", "b", "a", "b"]
		actual   = NonEmptyListParser1.parse(AlphaLexer.lex("a, b, a, b"))
                actual.should eq expected

		expect_raises(CLTK::NotInLanguage) { NonEmptyListParser1.parse(AlphaLexer.lex("a b")) }
		expect_raises(CLTK::NotInLanguage) { NonEmptyListParser1.parse(AlphaLexer.lex("a, ")) }

		#######################
		# NonEmptyListParser2 #
		#######################

		expected = ["a"]
		actual   = NonEmptyListParser2.parse(AlphaLexer.lex("a"))
		actual.should eq expected

		expected = ["b"]
		actual   = NonEmptyListParser2.parse(AlphaLexer.lex("b"))
		actual.should eq expected

		expected = [["c", "d"]]
		actual   = NonEmptyListParser2.parse(AlphaLexer.lex("c d"))
		actual.should eq expected

		expected = [["c", "d"], ["c", "d"]]
		actual   = NonEmptyListParser2.parse(AlphaLexer.lex("c d, c d"))
		actual.should eq expected

		expected = ["a", "b", ["c", "d"]]
		actual   = NonEmptyListParser2.parse(AlphaLexer.lex("a, b, c d"))
		actual.should eq expected

		expect_raises(CLTK::NotInLanguage) { NonEmptyListParser2.parse(AlphaLexer.lex("c")) }
		expect_raises(CLTK::NotInLanguage) { NonEmptyListParser2.parse(AlphaLexer.lex("d")) }

		#######################
		# NonEmptyListParser3 #
		#######################

		expected = [["a"], ["a", "a"], ["a", "a", "a"]]
		actual   = NonEmptyListParser3.parse(AlphaLexer.lex("a, aa, aaa"))
		actual.should eq expected

		#######################
		# NonEmptyListParser4 #
		#######################

		expected = ["a", "a", "a"]
		actual   = NonEmptyListParser4.parse(AlphaLexer.lex("a a a"))
		actual.should eq expected

		#######################
		# NonEmptyListParser5 #
		#######################

		expected = ["a", "a", "a"]
		actual   = NonEmptyListParser5.parse(AlphaLexer.lex("a b a b c a"))
		actual.should eq expected

		expect_raises(CLTK::NotInLanguage) { NonEmptyListParser5.parse(AlphaLexer.lex("a b b a")) }
	end

	it "test_postfix_calc" do
		actual = CLTK::Parsers::PostfixCalc.parse(CLTK::Lexers::Calculator.lex("1 2 +"))
		actual.should eq 3

		actual = CLTK::Parsers::PostfixCalc.parse(CLTK::Lexers::Calculator.lex("1 2 3 * +"))
		actual.should eq 7

		actual = CLTK::Parsers::PostfixCalc.parse(CLTK::Lexers::Calculator.lex("1 2 + 3 *"))
		actual.should eq 9

		expect_raises(CLTK::NotInLanguage) { CLTK::Parsers::InfixCalc.parse(CLTK::Lexers::Calculator.lex("* + 1 2 3")) }
	end

	it "test_prefix_calc" do
		actual = CLTK::Parsers::PrefixCalc.parse(CLTK::Lexers::Calculator.lex("+ 1 2"))
		actual.should eq 3

		actual = CLTK::Parsers::PrefixCalc.parse(CLTK::Lexers::Calculator.lex("+ 1 * 2 3"))
		actual.should eq 7

		actual = CLTK::Parsers::PrefixCalc.parse(CLTK::Lexers::Calculator.lex("* + 1 2 3"))
		actual.should eq 9

		expect_raises(CLTK::NotInLanguage) { CLTK::Parsers::PrefixCalc.parse(CLTK::Lexers::Calculator.lex("1 + 2 * 3")) }
	end

	it "test_selection_parser" do
		actual   = SelectionParser.parse(ABLexer.lex("aaabbb"))
		expected = 6

		actual.should eq expected
	end

	pending "test_token_hooks" do
		parser = TokenHookParser.new

		parser.parse(AlphaLexer.lex("a a a a"))
                parser.env.counter.should eq 4

		parser.parse(AlphaLexer.lex("b b b b"))
                parser.env.counter.should eq 1
	end

	it "test_underscore_tokens" do
		actual   = (UnderscoreParser.parse(UnderscoreLexer.lex("abc")) as Array).join
		expected = "abc"

		actual.should eq expected
	end

	pending "test_use" do
		tmpfile = File.join(Dir.tmpdir, "usetest")

		FileUtils.rm(tmpfile) if File.exist?(tmpfile)

		parser0 = Class.new(CLTK::Parser) do
			production(:a, "A+") { |a| a.size }

			finalize use: tmpfile
		end

		result0 = parser0.parse(ABLexer.lex("a"))

		assert(File.exist?(tmpfile), "Serialized parser file not found.")

		parser1 = Class.new(CLTK::Parser) do
			production(:a, "A+") { |a| a.size }

			finalize use: tmpfile
		end

		result1 = parser1.parse(ABLexer.lex("a"))

		assert_equal(result0, result1)

		File.unlink(tmpfile)
	end

	pending "test_uesless_parser_exception" do
		expect_raises(CLTK::UselessParserException) { UselessParser.new }
	end
end