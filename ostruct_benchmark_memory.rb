#!/usr/bin/ruby

require 'benchmark/memory'
require 'ostruct'

if defined?(OpenStruct.optimized?)
	puts "Ruby #{RUBY_VERSION}, ostruct #{OpenStruct::VERSION}, with optimized OpenStruct"
else
	puts "Ruby #{RUBY_VERSION}, ostruct #{OpenStruct::VERSION}"
end

#Benchmark.ips(20) do |x|
Benchmark.memory do |x|
## These parameters can also be configured this way
#x.time = 5
#x.warmup = 2
	
	x.report("creation,   0 fields") do
		i = 0
		while i < 1_000
			OpenStruct.new()
			i += 1
		end
	end
	x.report("creation,   1 field ") do
		i = 0
		while i < 1_000
			OpenStruct.new(k0: 0)
			i += 1
		end
	end
	x.report("creation,   2 fields") do
		i = 0
		while i < 1_000
			OpenStruct.new(k0: 0, k1: 1)
			i += 1
		end
	end
	x.report("creation,   3 fields") do
		i = 0
		while i < 1_000
			OpenStruct.new(k0: 0, k1: 1, k2: 2)
			i += 1
		end
	end
	x.report("creation, 100 fields") do
		large_hash = (0..100).to_h { |i| [:"key_#{i}", i] }
	
		i = 0
		while i < 1_000
			OpenStruct.new(**large_hash)
			i += 1
		end
	end

	o = OpenStruct.new(k: 123)
	
	x.report("attribute access") do
		i = 0
		while i < 1_000
			o.k
			i += 1
		end
	end
	x.report("key lookup by string") do
		i = 0
		while i < 1_000
			o["k"]
			i += 1
		end
		
	end
	x.report("key lookup by symbol") do
		i = 0
		while i < 1_000
			o[:k]
			i += 1
		end
	end
	
	x.compare!
end