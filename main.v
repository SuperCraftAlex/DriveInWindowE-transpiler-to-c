module main

import os
import strconv

struct FOOD {
mut:
	name string
	price int
}

struct ERRW {
	name string
	desc string
}

struct CTX {
mut:
	r_name string
	r_currency string
	r_food []FOOD

	priority int
	persons []int
	code []string

	personereq []int
	foodreq []string

	errors []ERRW
	warnings []ERRW

	ind string = "   "
}

fn get_c_name(a string) string {
	v := a.trim_space()
			.replace(" ", "_")
			.to_lower()
	if v.starts_with("the_") {
		return v[4..]
	}
	return v
}

fn check_price(price int, mut ctx &CTX) {
	if price <= 0 {
		ctx.errors << ERRW {
			name: "Food price cant be 0 or negative!"
		}
	}
	if price > 255 {
		ctx.errors << ERRW {
			name: "Food price cant be more than 255!"
		}
	}
}

fn get_price(a string, mut ctx &CTX) int {
	if a.starts_with("$") {
		if ctx.r_currency == "euro" {
			ctx.errors << ERRW {
				name: "Inconsistent currency!"
			}
		}
		s := a[1..].trim_space()
		v := strconv.common_parse_int(s, 0, 32, true, true) or {
			ctx.errors << ERRW {
				name: "Invalid number"
				desc: s
			}
			0
		}
		ctx.r_currency = "dollar"
		check_price(int(v), mut ctx)
		return int(v)
	}
	if a.ends_with("€") {
		if ctx.r_currency == "dollar" {
			ctx.errors << ERRW {
				name: "Inconsistent currency!"
			}
		}
		s := a[..a.len-3].trim_space()
		v := strconv.common_parse_int(s, 0, 32, true, true) or {
			ctx.errors << ERRW {
				name: "Invalid number"
				desc: s
			}
			0
		}
		ctx.r_currency = "euro"
		check_price(int(v), mut ctx)
		return int(v)
	}
	ctx.errors << ERRW {
		name: "Invalid / no currency"
		desc: a
	}
	return 0
}

fn process(txt []string) &CTX {
	mut ctx := &CTX {
		priority: 1
	}

	mut is_rwelcome := false
	mut is_dishes := false
	mut is_sides := false
	for linel in txt {
		mut l := linel.trim_space()

		if l.len == 0 || l.starts_with("#") {
			continue
		}

		if l.starts_with("Hi, welcome to ") && l.ends_with(".") {
			is_rwelcome = true
			ctx.r_name = l.after("Hi, welcome to ").before(".")
			continue
		}

		if is_rwelcome {
			if l == "Here is the menu:" || l == "Here is menu:" {
				is_rwelcome = false
				is_dishes = true
			}
			else if l == "Here are the sides:" || l == "Here are sides:" {
				is_rwelcome = false
				is_sides = true
			}
			else if l == "May I take your order?" {
				is_rwelcome = false
			}
			continue
		}

		if is_dishes {
			if l == "Here are the sides:" || l == "Here are sides:" {
				is_sides = true
				is_dishes = false
			}
			else if l.contains(":") {
				name := get_c_name(l.split(":").first())
				for food in ctx.r_food {
					if food.name == name {
						ctx.errors << ERRW {
							name: "Food already defined"
							desc: name
						}
					}
				}
				price := get_price(l.split(":").last().trim_space(), mut ctx)
				if price % 10 != 0 {
					ctx.errors << ERRW {
						name: "Main dish price has to be multiple of 10"
						desc: "${name} is ${price}"
					}
				}
				ctx.r_food << FOOD {
					name: name
					price: price
				}
			}
			else if l == "May I take your order?" {
				is_dishes = false
			}
			continue
		}

		if is_sides {
			if l.contains(":") {
				name := get_c_name(l.split(":").first())
				for food in ctx.r_food {
					if food.name == name {
						ctx.errors << ERRW {
							name: "Food already defined"
							desc: name
						}
					}
				}
				price := get_price(l.split(":").last().trim_space(), mut ctx)
				ctx.r_food << FOOD {
					name: name
					price: price
				}
			}
			else if l == "May I take your order?" {
				is_sides = false
			}
			continue
		}

		startswith_person := l.starts_with("Person ")

		if l.starts_with("Hello! We are ") && l.ends_with(" people!") {
			persons := l.after("Hello! We are ").before(" people!").int()
			if ctx.persons.len > 0 {
				ctx.errors << ERRW {
					name: "Cannot use \"we are x people\" if people already exist!"
				}
			}
			for i in 1 .. persons+1 {
				ctx.persons << i
			}
			continue
		}

		if l == "Just wait while we decide..." {
			ctx.code << "${ctx.ind}getchar();"
			continue
		}

		if l.starts_with("Lets just do this until Person ") {
			o := l.after("Lets just do this until Person ").before(" has no more money:").int()
			ctx.personereq << o
			ctx.code << "${ctx.ind}while (person_${o} > 0) {"
			ctx.ind += "   "
			continue
		}

		if l.starts_with("If Person ") {
			o := l.after("If Person ").before(" has money:").int()
			ctx.personereq << o
			ctx.code << "${ctx.ind}if (person_${o} > 0) {"
			ctx.ind += "   "
			continue
		}
		if l == "Otherwise:" {
			ctx.code << "${ctx.ind}else {"
			continue
		}

		if l == "Until here!" {
			ol := ctx.ind.len
			ctx.ind = ""
			for _ in 0 .. ol-3 {
				ctx.ind += " "
			}
			ctx.code << "${ctx.ind}}"
			continue
		}

		if l.starts_with("Okay, what should Person ") {
			o := l.after("Okay, what should Person ").before(" get?").int()
			ctx.personereq << o
			ctx.code << "${ctx.ind}person_${o} = getchar();"
			continue
		}

		if l.starts_with("Okay, how much money should Person ") {
			o := l.after("Okay, how much money should Person ").before(" have?").int()
			ctx.personereq << o
			ctx.code << "${ctx.ind}scanf(\"%hhu\", &person_${o});"
			continue
		}

		if l.starts_with("Okay, that will be ") {
			c := get_price(l.after("Okay, that will be ").before("."), mut ctx)
			ctx.code << "${ctx.ind}return ${c};"
			continue
		}

		if startswith_person {
			person := l.all_after_first("Person ").before(" ").int()
			ctx.personereq << person

			t := l.all_after_first("Person ").all_after_first(" ")

			if t == "joined us!" {
				if ctx.persons.len == 0 {
					ctx.errors << ERRW {
						name : "Cannot use join command if no persons exist!"
					}
				}
				ctx.persons << person
			}
			else if t.starts_with("will pay for ") && t.ends_with(" order.") {
				ctx.code << "${ctx.ind}putchar(person_${person});"
				ctx.code << "${ctx.ind}person_${person} = 0;"
				ctx.personereq << person
			}
			else if t.starts_with("would like ") {
				if t.contains("with") {
					n := get_c_name(t.after("would like ").before(" with"))
					n2 := get_c_name(t.after("with ").before("."))
					ctx.foodreq << n
					ctx.foodreq << n2
					ctx.code << "${ctx.ind}person_${person} = food_${n} + food_${n2};"
				}
				else if t.contains(", hold the ") {
					n := get_c_name(t.after("would like ").before(" with"))
					n2 := get_c_name(t.after(", hold the ").before("."))
					ctx.foodreq << n
					ctx.foodreq << n2
					ctx.code << "${ctx.ind}person_${person} = food_${n} - food_${n2};"
				}
				else if t.contains("what Person") {
					o := t.after("would like what Person ").before(" has.").int()
					ctx.personereq << o
					ctx.code << "${ctx.ind}person_${person} = person_${o};"
				}
				else {
					n := get_c_name(t.after("would like ").before("."))
					ctx.foodreq << n
					ctx.code << "${ctx.ind}person_${person} = food_${n};"
				}
			}
			else if t.starts_with("would also like ") {
				n := get_c_name(t.after("would also like ").before("."))
				ctx.foodreq << n
				ctx.code << "${ctx.ind}person_${person} += food_${n};"
			}
			else if t.starts_with("would not like ") {
				n := get_c_name(t.after("would not like ").before("."))
				ctx.foodreq << n
				ctx.code << "${ctx.ind}person_${person} -= food_${n};"
			}
			else if t.ends_with("has no more money.") {
				ctx.code << "${ctx.ind}person_${person} = 0;"
			}
			else if t.starts_with("needs ") {
				n := get_price(t.after("needs ").before(" "), mut ctx)
				o := t.after("needs ").all_after_first(" ")
				if o.starts_with("more") {
					ctx.code << "${ctx.ind}person_${person} += ${n};"
				}
				else {
					ctx.code << "${ctx.ind}person_${person} -= ${n};"
				}
			}
			else if t.starts_with("borrows ") {
				n := get_price(t.after("borrows ").before(" "), mut ctx)
				o := t.after("borrows ").after(" from Person ").before(".").int()
				ctx.personereq << o
				ctx.code << "${ctx.ind}if (person_${o} >= ${n}) {"
				ctx.code << "${ctx.ind}   person_${person} += ${n};"
				ctx.code << "${ctx.ind}   person_${o} -= ${n};"
				ctx.code << "${ctx.ind}}"
				ctx.code << "${ctx.ind}else {"
				ctx.code << "${ctx.ind}   person_${person} += person_${o};"
				ctx.code << "${ctx.ind}   person_${o} = 0;"
				ctx.code << "${ctx.ind}}"
			}
			else {
				ctx.errors << ERRW {
					name: "Instruction not found!"
					desc: "\"${l}\""
				}
			}
			continue
		}

		ctx.errors << ERRW {
			name: "Instruction not found!"
			desc: "\"${l}\""
		}
	}

	if is_dishes || is_sides || is_rwelcome {
		ctx.errors << ERRW {
			name: "Unfinished restaurant definition!"
		}
	}

	return ctx
}

fn extend_ctx(mut ctx &CTX, by &CTX) {
	for person in by.persons {
		if person !in ctx.persons {
			ctx.persons << person
		}
	}
	if by.priority > ctx.priority {
		t := ctx.code
		ctx.code = []
		ctx.code << by.code
		ctx.code << t
		ctx.r_name = by.r_name
		ctx.r_currency = by.r_currency
		ctx.ind = by.ind
	}
	else {
		ctx.code << by.code
	}

	ctx.personereq << by.personereq
	ctx.foodreq << by.foodreq

	ctx.r_food << by.r_food

	ctx.errors << by.errors
}

fn main() {
	if "help" in os.args || "-h" in os.args || "--h" in os.args {
		println("(Drive-In Window extended) transpiler to c")
		println("Documentation: https://esolangs.org/wiki/Drive-In_Window_extended")
		println("Usage: [file1]... -o [outputfile]")
		return
	}

	if os.args.len == 1 {
		println("Invalid arguments! Usage: [file1]... -o [outputfile]")
		return
	}
	infilestemp := os.args_before("-o")
	if infilestemp.len == 1 {
		println("No input file(s) specified!")
		return
	}
	otemp := os.args_after("-o")
	if otemp.len != 2 {
		println("No / too many output file(s) specified!")
		return
	}
	ofile := otemp[1]
	infiles := infilestemp[1..]

	if infiles.len > 1 {
		println("Warning: More than one input file found! (Not implemented)")
	}

	mut ctx := &CTX {}

	for filep in infiles {
		if filep.split(".").last() != "diw" {
			println("Unknown file extension \"${filep.split('.').last()}\"! Useable file extensions: \".diw\"")
			return
		}
		if !os.is_file(filep) {
			println("File \"${filep}\" not found!")
			return
		}
		extend_ctx(mut ctx, process(os.read_file(filep)!.split("\n")))
	}

	if ctx.r_name.len == 0 {
		ctx.errors << ERRW {
			name: "Restaurant not defined!"
		}
	}

	for req in ctx.personereq {
		if req !in ctx.persons {
			ctx.errors << ERRW {
				name: "Person not initialized!"
				desc: "Person ${req} not initialized!"
			}
		}
	}

	for req in ctx.foodreq {
		mut found := false
		for food in ctx.r_food {
			if food.name == req {
				found = true
				break
			}
		}
		if !found {
			ctx.errors << ERRW {
				name: "Food not initialized!"
				desc: "Food ${req} not initialized!"
			}
		}
	}

	if ctx.ind != "   " {
		ctx.errors << ERRW { name: "Unclosed if / while block(s)!" }
	}

	if ctx.errors.len > 0 {
		println("Errors:")
		for err in ctx.errors {
			if err.desc.len > 0 {
				println("- ${err.name}: ${err.desc}")
			}
			else {
				println("- ${err.name}")
			}
		}
		return
	}

	if ctx.r_food.len == 0 {
		ctx.warnings << ERRW { name: "No food defined!" }
	}

	// TODO: warning: unused person
	for person in ctx.persons {
		if person !in ctx.personereq {
			ctx.warnings << ERRW {
				name: "Person not used"
				desc: "Person ${person}"
			}
		}
	}

	if ctx.warnings.len > 0 {
		println("Warnings:")
		for war in ctx.warnings {
			if war.desc.len > 0 {
				println("- ${war.name}: ${war.desc}")
			}
			else {
				println("- ${war.name}")
			}
		}
		print("\n")
	}

	// final step
	if !os.is_file(ofile) {
		os.create(ofile) or {  }
	}

	mut out := ["#include <stdio.h>", "#include <stdint.h>", ""]
	out << "// restaurant: ${ctx.r_name}:"
	out << ""

	if ctx.r_food.len > 0 {
		out << "// food:"
		for food in ctx.r_food {
			out << "const uint8_t food_${food.name} = ${food.price};"
		}
	}

	out << ""
	out << "int main() {"

	out << "   // persons:"
	for person in ctx.persons {
		out << "   uint8_t person_${person} = 0;"
	}
	out << ""
	out << "   // code:"
	out << ctx.code
	out << "}"

	os.write_file(ofile, out.join("\n")) or {
		println("Error writing to file!")
		return
	}

	println("Done!")
}
