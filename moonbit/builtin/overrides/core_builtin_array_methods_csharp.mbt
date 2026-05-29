extern "csharp" fn[T] Array::filter(
  self : Array[T],
  f : (T) -> Bool,
) -> Array[T] =
  #| var result = new MoonBitArray<T>();
  #| for (var i = 0; i < self.Length; i++)
  #| {
  #|     var item = self.Buffer[i];
  #|     if (f(item))
  #|     {
  #|         MoonBitArray.Push(result, item);
  #|     }
  #| }
  #| return result;

extern "csharp" fn[T] Array::remove(self : Array[T], index : Int) -> T =
  #| if ((uint)index >= (uint)self.Length)
  #| {
  #|     throw new MoonBitPanic($"index out of bounds: the len is from 0 to {self.Length} but the index is {index}");
  #| }
  #| var item = self.Buffer[index];
  #| var remaining = self.Length - index - 1;
  #| if (remaining > 0)
  #| {
  #|     System.Array.Copy(self.Buffer, index + 1, self.Buffer, index, remaining);
  #| }
  #| self.Buffer[self.Length - 1] = default!;
  #| self.Length -= 1;
  #| return item;

extern "csharp" fn[T] Array::append(
  self : Array[T],
  other : ArrayView[T],
) -> Unit =
  #| var required = self.Length + other.Length;
  #| if (self.Buffer.Length < required)
  #| {
  #|     var capacity = self.Buffer.Length == 0 ? 4 : self.Buffer.Length * 2;
  #|     while (capacity < required)
  #|     {
  #|         capacity *= 2;
  #|     }
  #|     System.Array.Resize(ref self.Buffer, capacity);
  #| }
  #| other.AsSpan().CopyTo(self.Buffer.AsSpan(self.Length));
  #| self.Length += other.Length;
  #| return MoonBitUnit.Value;

extern "csharp" fn[T] Array::all(
  self : Array[T],
  f : (T) -> Bool,
) -> Bool =
  #| for (var i = 0; i < self.Length; i++)
  #| {
  #|     if (!f(self.Buffer[i]))
  #|     {
  #|         return false;
  #|     }
  #| }
  #| return true;

extern "csharp" fn[T, U] Array::map(
  self : Array[T],
  f : (T) -> U,
) -> Array[U] =
  #| var result = new MoonBitArray<U>(new U[self.Length], self.Length);
  #| for (var i = 0; i < self.Length; i++)
  #| {
  #|     result.Buffer[i] = f(self.Buffer[i]);
  #| }
  #| return result;
