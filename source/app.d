
import std.stdio;

struct Descriptor
{

}

alias Position = size_t;
immutable EndOfFile = Position.max;

alias Item = immutable(dchar);

extern(C++)
class Span
{
	Item[] content;
	Span prev, next;

	extern(D)
	this(Item[] content)
	{
		this.content = content;
	}

	Item opIndex(size_t i) const
	{
		return content[i];
	}

	Item[] opSlice(size_t i1, size_t i2) const
	{
		return content[i1..i2];
	}

	size_t opDollar() const
	{
		return length;
	}

	size_t length() const
	{
		return content.length;
	}
}

auto span(Item[] content)
{
	return new Span(content);
}

extern(C++)
class Sequence
{
	import std.typecons : Rebindable;

	Span origin;

	extern(D)
	this(Item[] content)
	{
		origin = span(content);
	}

	~this()
	{
		if (origin is null)
			return;
		destroy(origin);
		origin = null;
	}

	size_t walkLength() const
	{
		Rebindable!(const(Span)) s = origin;
		size_t len;
		while(s)
		{
			len += s.length;
			assert(s != s.next);
			s = s.next;
		}
		return len;
	}

	auto dump() const
	{
		Rebindable!(const Span) s = origin;
		while(s)
		{
			writeln(cast(void*) s, " ", s.length, " '", s.content, "'");
			assert(s != s.next);
			s = s.next;
		}
	}

	struct Range
	{
		this(const Span span)
		{
			_span = span;
		}

		bool empty() const
		{
			return _span is null;
		}

		Item front() const
		{
			assert(!empty);
			return _span[_pos];
		}

		void popFront()
		{
			assert(!empty);
			_pos++;
			if (_pos == _span.length)
			{
				_pos = 0;
				_span = _span.next;
			}
		}

		private:
			@disable this();
			Rebindable!(const Span) _span;
			Position _pos;
	}

	Range opSlice() { return Range(origin); }
}

auto sequence(Item[] content)
{
	return new Sequence(content);
}

Sequence empty()
{
	return sequence("");
}

Span spanByPos(Sequence seq, Position posInSeq, ref Position posInSpan)
{
	auto current = seq.origin;
	Position pos;
	posInSpan = 0;
	while(true)
	{
		if ((pos <= posInSeq) && (posInSeq < pos + current.length))
		{
			posInSpan = posInSeq - pos;
			return current;
		}
		pos += current.length;
		if (current.next is null)
			break;
		assert(current != current.next);
		current = current.next;
	}
	// position is right after the last span
	if (posInSeq == pos)
	{
		posInSpan = current.length;
		return current;
	}
	return null;
}

Span insert(Span firstSpan, Position posInSpan, Span interSpan)
{
	if (posInSpan > firstSpan.length)
		return firstSpan;

	if (posInSpan == 0)
	{
		interSpan.prev = firstSpan.prev;
		interSpan.next = firstSpan;

		firstSpan.prev = interSpan;
		return interSpan;
	}

	if (posInSpan == firstSpan.length)
	{
		interSpan.prev = firstSpan;
		interSpan.next = firstSpan.next;

		firstSpan.next = interSpan;
		return firstSpan;
	}

	auto lastSpan = span(firstSpan[posInSpan..$]);
	firstSpan.content = firstSpan.content[0..posInSpan];

	interSpan.prev = firstSpan;
	interSpan.next = lastSpan;
	lastSpan.prev = interSpan;
	lastSpan.next = firstSpan.next;
	firstSpan.next = interSpan;

	return firstSpan;
}

Sequence insert(Sequence seq, Position posInSeq, Span insertSpan)
{
	Position posInSpan;
	auto sp = seq.spanByPos(posInSeq, posInSpan);
	if (sp is null)
		return seq;
	sp = sp.insert(posInSpan, insertSpan);
	// if the position is the first position of the whole
	// sequence fix the first span
	if (posInSeq == 0)
	{
		seq.origin = sp;
		return seq;
	}

	// if the position is the first one of a span
	// then fix its previous span (if any)
	if (posInSpan == 0 && sp.prev)
		sp.prev.next = sp;

	return seq;
}

Span remove(Span s, Position p)
{
	assert(0);
}

Item itemAt(Sequence s, Position p)
{
	Position pos;
	auto span = s.origin;
	while(span)
	{
		if (pos <= p && p < pos + span.length)
			return span[p - pos];
		pos += span.length;
		assert(span != span.next);
		span = span.next;
	}
	return Item(0);
}

// // axiom 1
// // deleting from an empty Sequence is a no-op
// unittest
// {
//  auto s = empty;
//  assert(s.remove(Position(0)) == empty);
// }

// // axiom 2
// // allows the reduction of a Sequence of Inserts and Removes to a Sequence containing only Inserts
// unittest
// {
//  Sequence s;
//  Position p1 = 0, p2 = 10;
//  auto item = Item('Б');
//  assert(s.insert(Position(p1), item).remove(Position(p2)) == s.remove(p2-1).insert(p1, item));
//  assert(s.insert(Position(p2), item).remove(Position(p2)) == s);
//  assert(s.insert(Position(p2), item).remove(Position(p1)) == s.remove(p2).insert(p1-1, item));
// }

// // axiom 3
// // implies that reading outside the Sequence returns a special EndOfFile item.
// unittest
// {
//  auto s = empty;
//  assert(s.itemAt(Position(0)) == EndOfFile);
// }

// // axiom 4
// // defines the semantics of a Sequence by defining what is at each position of a canonical Sequence
// unittest
// {
//  Sequence s;
//  Position p1 = 0, p2 = 10;
//  auto item = Item('Б');
//  assert(s.insert(Position(p1), item).itemAt(Position(p2)) == s.itemAt(p2-1));
//  assert(s.insert(Position(p2), item).itemAt(Position(p2)) == item);
//  assert(s.insert(Position(p2), item).itemAt(Position(p1)) == s.itemAt(p2));
// }

// unittest
// {
//  // insert/deletion at the beginning, in the middle and at the end
// }

unittest
{
	auto s = sequence("two");
	assert(s.walkLength == 3);
	assert(s.itemAt(0) == 't');
	assert(s.itemAt(1) == 'w');
	assert(s.itemAt(2) == 'o');
	assert(s.itemAt(3) == 0);

	import std.algorithm : equal;
	assert(s[].equal("two"));

	// insert in the end
	{
		s.insert(s.walkLength, span(" four"));

		assert(s.walkLength == 8);
		assert(s[].equal("two four"));
		assert(s.itemAt(8) == 0);
	}

	// insert in the beginning
	{
		s.insert(0, span("one "));

		assert(s.walkLength == 12);
		assert(s[].equal("one two four"));
		assert(s.itemAt(12) == 0);
	}

	// insert in the middle
	{
		s.insert(7, span(" three"));

		assert(s.walkLength == 18);
		assert(s[].equal("one two three four"));
		assert(s.itemAt(18) == 0);
	}
}
