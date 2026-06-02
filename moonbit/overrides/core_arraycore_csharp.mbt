extern "csharp" fn[T] Array::make_uninit(len : Int) -> Array[T] =
  #| return MoonBitArray<T>.MakeUninit(len);

pub fn[T] Array::make(len : Int, elem : T) -> Array[T] {
  let arr = Array::make_uninit(len)
  for i in 0..<len {
    arr.unsafe_set(i, elem)
  }
  arr
}

pub fn[T] Array::makei(len : Int, f : (Int) -> T) -> Array[T] {
  if len <= 0 {
    []
  } else {
    let arr = Array::make_uninit(len)
    for i in 0..<len {
      arr.unsafe_set(i, f(i))
    }
    arr
  }
}

extern "csharp" fn[T] Array::new(capacity? : Int = 0) -> Array[T] =
  #| return new MoonBitArray<T>(capacity);

extern "csharp" fn[T] Array::length(self : Array[T]) -> Int =
  #| return self.Length;

extern "csharp" fn[T] Array::is_empty(self : Array[T]) -> Bool =
  #| return self.Length == 0;

pub fn[T] Array::get(self : Array[T], index : Int) -> T? {
  let len = self.length()
  guard index >= 0 && index < len else { None }
  Some(self.unsafe_get(index))
}

pub fn[T] Array::last(self : Array[T]) -> T? {
  let len = self.length()
  guard len > 0 else { None }
  Some(self.unsafe_get(len - 1))
}

extern "csharp" fn[T] Array::unsafe_get(self : Array[T], idx : Int) -> T =
  #| return MoonBitArray.UnsafeGet(self, idx);

extern "csharp" fn[T] Array::unsafe_set(
  self : Array[T],
  idx : Int,
  value : T,
) -> Unit =
  #| return MoonBitArray.UnsafeSet(self, idx, value);

extern "csharp" fn[T] Array::buffer(self : Array[T]) -> UninitializedArray[T] =
  #| return self.Buffer;

extern "csharp" fn[T] Array::unsafe_truncate_to_length(
  self : Array[T],
  new_len : Int,
) -> Unit =
  #| return MoonBitArray.UnsafeTruncateToLength(self, new_len);

extern "csharp" fn[T] Array::reserve_capacity(
  self : Array[T],
  capacity : Int,
) -> Unit =
  #| return MoonBitArray.ReserveCapacity(self, capacity);

extern "csharp" fn[T] Array::shrink_to_fit(self : Array[T]) -> Unit =
  #| return MoonBitArray.ShrinkToFit(self);

extern "csharp" fn[T] Array::push(self : Array[T], value : T) -> Unit =
  #| return MoonBitArray.Push(self, value);

extern "csharp" fn[T] Array::pop(self : Array[T]) -> T? =
  #| return MoonBitArray.Pop(self);

extern "csharp" fn[T] Array::unsafe_pop(self : Array[T]) -> T =
  #| var index = self.Length - 1;
  #| var value = self.Buffer[index];
  #| self.Buffer[index] = default!;
  #| self.Length = index;
  #| return value;

extern "csharp" fn[T] Array::copy(self : Array[T]) -> Array[T] =
  #| return MoonBitArray.Copy(self);

extern "csharp" fn[T] Array::sort_by(
  self : Array[T],
  cmp : (T, T) -> Int,
) -> Unit =
  #| System.Array.Sort(self.Buffer, 0, self.Length, System.Collections.Generic.Comparer<T>.Create((left, right) => cmp(left, right)));
  #| return MoonBitUnit.Value;

extern "csharp" fn[T] FixedArray::unsafe_blit(
  dst : FixedArray[T],
  dst_offset : Int,
  src : FixedArray[T],
  src_offset : Int,
  len : Int,
) -> Unit =
  #| System.Array.Copy(src, src_offset, dst, dst_offset, len);
  #| return MoonBitUnit.Value;

extern "csharp" fn[T] FixedArray::fill(
  self : FixedArray[T],
  value : T,
  start? : Int = 0,
  end? : Int,
) -> Unit =
  #| var actualEnd = end.IsSome ? end.Value : self.Length;
  #| if (start < 0 || start > actualEnd || actualEnd > self.Length) throw new MoonBitPanic("panic");
  #| System.Array.Fill(self, value, start, actualEnd - start);
  #| return MoonBitUnit.Value;

extern "csharp" fn[T] UninitializedArray::unsafe_blit_fixed(
  dst : UninitializedArray[T],
  dst_offset : Int,
  src : FixedArray[T],
  src_offset : Int,
  len : Int,
) -> Unit =
  #| System.Array.Copy(src, src_offset, dst, dst_offset, len);
  #| return MoonBitUnit.Value;

extern "csharp" fn[T] UninitializedArray::unsafe_blit(
  dst : UninitializedArray[T],
  dst_offset : Int,
  src : UninitializedArray[T],
  src_offset : Int,
  len : Int,
) -> Unit =
  #| System.Array.Copy(src, src_offset, dst, dst_offset, len);
  #| return MoonBitUnit.Value;
