package "moonbitlang/core/builtin"

///|
pub extern "csharp" fn[T] Array::new(
  capacity? : Int = 0,
) -> Array[T] =
  #|return new MoonBitArray<T>(capacity);

///|
pub extern "csharp" fn[T] Array::length(self : Array[T]) -> Int =
  #|return self.Length;

///|
pub extern "csharp" fn[T] Array::push(
  self : Array[T],
  value : T,
) -> Unit =
  #|return MoonBitArray.Push(self, value);

///|
pub extern "csharp" fn[T] Array::append(
  self : Array[T],
  other : ArrayView[T],
) -> Unit =
  #|var required = self.Length + other.Length;
  #|if (self.Buffer.Length < required)
  #|{
  #|    var capacity = self.Buffer.Length == 0 ? 4 : self.Buffer.Length * 2;
  #|    while (capacity < required)
  #|    {
  #|        capacity *= 2;
  #|    }
  #|    System.Array.Resize(ref self.Buffer, capacity);
  #|}
  #|other.AsSpan().CopyTo(self.Buffer.AsSpan(self.Length));
  #|self.Length += other.Length;
  #|return MoonBitUnit.Value;

///|
pub extern "csharp" fn[T, U] Array::map(
  self : Array[T],
  f : (T) -> U raise?,
) -> Array[U] raise? =
  #|var result = new MoonBitArray<U>(self.Length);
  #|for (var i = 0; i < self.Length; i++)
  #|{
  #|    MoonBitArray.Push(result, f(self.Buffer[i]));
  #|}
  #|return result;

///|
pub extern "csharp" fn[T] Array::concat(
  self : Array[T],
  other : Array[T],
) -> Array[T] =
  #|return MoonBitArray.Concat(self, other);

///|
pub impl[T] Add for Array[T] with add(self, other) {
  Array::concat(self, other)
}

///|
pub fn[T] Array::iter(self : Array[T]) -> Iter[T] = "%array_iter"

///|
pub fn[T] Array::is_empty(self : Array[T]) -> Bool = "%array_is_empty"

///|
pub fn[T] Array::copy(self : Array[T]) -> Array[T] = "%array_copy"

///|
pub fn[T] Array::make(len : Int, elem : T) -> Array[T] = "%array_make"

///|
pub fn[T] Array::remove(self : Array[T], index : Int) -> T = "%array_remove"

///|
pub fn[T] Array::pop(self : Array[T]) -> T? = "%array_pop"

///|
pub fn[A] Array::last(self : Array[A]) -> A? = "%array_last"

///|
pub fn[T] Array::filter(
  self : Array[T],
  f : (T) -> Bool raise?,
) -> Array[T] raise? = "%array_filter"

///|
pub extern "csharp" fn[T] Array::all(
  self : Array[T],
  f : (T) -> Bool raise?,
) -> Bool raise? =
  #|for (var i = 0; i < self.Length; i++)
  #|{
  #|    if (!f(self.Buffer[i]))
  #|    {
  #|        return false;
  #|    }
  #|}
  #|return true;

///|
pub extern "csharp" fn[A] Array::join(
  self : Array[A],
  separator : StringView,
) -> String =
  #|var sep = separator.ToString();
  #|var items = new string[self.Length];
  #|for (var i = 0; i < self.Length; i++)
  #|{
  #|    items[i] = self.Buffer[i]?.ToString() ?? "";
  #|}
  #|return string.Join(sep, items);

///|
pub fn[T] Array::sort_by(self : Array[T], cmp : (T, T) -> Int) -> Unit = "%array_sort_by"
