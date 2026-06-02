priv struct Entry[K, V] {
  mut prev : Int
  mut next : Entry[K, V]?
  mut psl : Int
  hash : Int
  key : K
  mut value : V
}

struct Map[K, V] {
  mut entries : FixedArray[Entry[K, V]?]
  mut size : Int
  mut capacity : Int
  mut capacity_mask : Int
  mut grow_at : Int
  mut head : Entry[K, V]?
  mut tail : Int
}

let default_init_capacity = 8

fn[K, V] new_map(capacity : Int) -> Map[K, V] {
  let capacity = capacity.next_power_of_two()
  {
    entries: FixedArray::make(capacity, None),
    size: 0,
    capacity,
    capacity_mask: capacity - 1,
    grow_at: calc_grow_threshold(capacity),
    head: None,
    tail: -1,
  }
}

fn capacity_for_length(length : Int) -> Int {
  let mut capacity = length.next_power_of_two()
  if length > calc_grow_threshold(capacity) {
    capacity *= 2
  }
  capacity
}

pub fn[K : Hash + Eq, V] Map::Map(
  arr : ArrayView[(K, V)],
  capacity? : Int,
) -> Map[K, V] {
  let length = arr.length()
  let capacity = match capacity {
    Some(capacity) => Int::max(capacity, capacity_for_length(length))
    None =>
      if length == 0 {
        default_init_capacity
      } else {
        capacity_for_length(length)
      }
  }
  let m = new_map(capacity)
  for item in arr {
    m.set(item.0, item.1)
  }
  m
}

#alias("_[_]")
pub fn[K : Hash + Eq, V] Map::get(self : Map[K, V], key : K) -> V? {
  let hash = key.hash()
  for i = 0, idx = hash & self.capacity_mask {
    match self.entries[idx] {
      Some(entry) => {
        if entry.hash == hash && entry.key == key {
          break Some(entry.value)
        }
        if i > entry.psl {
          break None
        }
        continue i + 1, (idx + 1) & self.capacity_mask
      }
      None => break None
    }
  }
}

pub fn[K : Hash + Eq, V] Map::contains(self : Map[K, V], key : K) -> Bool {
  self.get(key) is Some(_)
}

#alias("_[_]=_")
pub fn[K : Hash + Eq, V] Map::set(
  self : Map[K, V],
  key : K,
  value : V,
) -> Unit {
  self.set_with_hash(key, value, key.hash())
}

fn[K : Eq, V] Map::set_with_hash(
  self : Map[K, V],
  key : K,
  value : V,
  hash : Int,
) -> Unit {
  let (idx, psl, push_away) = for psl = 0, idx = hash & self.capacity_mask {
    match self.entries[idx] {
      Some(entry) => {
        if entry.hash == hash && entry.key == key {
          entry.value = value
          return
        }
        if psl > entry.psl {
          break (idx, psl, Some(entry))
        }
        continue psl + 1, (idx + 1) & self.capacity_mask
      }
      None => break (idx, psl, None)
    }
  }
  if self.size >= self.grow_at {
    self.grow()
    self.set_with_hash(key, value, hash)
  } else {
    if push_away is Some(entry) {
      self.push_away(idx, entry)
    }
    let entry = { prev: self.tail, next: None, psl, hash, key, value }
    self.add_entry_to_tail(idx, entry)
  }
}

fn[K, V] Map::push_away(
  self : Map[K, V],
  idx : Int,
  entry : Entry[K, V],
) -> Unit {
  for idx = idx, entry = entry {
    let next_idx = (idx + 1) & self.capacity_mask
    match self.entries[next_idx] {
      Some(next_entry) => {
        entry.psl += 1
        if entry.psl > next_entry.psl {
          self.set_entry(entry, next_idx)
          continue next_idx, next_entry
        }
        continue next_idx, entry
      }
      None => {
        entry.psl += 1
        self.set_entry(entry, next_idx)
        break
      }
    }
  }
}

fn[K, V] Map::set_entry(
  self : Map[K, V],
  entry : Entry[K, V],
  idx : Int,
) -> Unit {
  match entry.prev {
    -1 => self.head = Some(entry)
    prev => self.entries[prev].unwrap().next = Some(entry)
  }
  match entry.next {
    Some(next) => next.prev = idx
    None => self.tail = idx
  }
  self.entries[idx] = Some(entry)
}

fn[K, V] Map::add_entry_to_tail(
  self : Map[K, V],
  idx : Int,
  entry : Entry[K, V],
) -> Unit {
  match self.tail {
    -1 => self.head = Some(entry)
    tail => self.entries[tail].unwrap().next = Some(entry)
  }
  self.tail = idx
  self.entries[idx] = Some(entry)
  self.size += 1
}

fn[K : Eq, V] Map::grow(self : Map[K, V]) -> Unit {
  let old_head = self.head
  let new_capacity = self.capacity << 1
  self.entries = FixedArray::make(new_capacity, None)
  self.capacity = new_capacity
  self.capacity_mask = new_capacity - 1
  self.grow_at = calc_grow_threshold(self.capacity)
  self.size = 0
  self.head = None
  self.tail = -1
  for x = old_head {
    match x {
      Some(entry) => {
        self.set_with_hash(entry.key, entry.value, entry.hash)
        continue entry.next
      }
      None => break
    }
  }
}

fn calc_grow_threshold(capacity : Int) -> Int {
  capacity * 13 / 16
}

pub impl[K : Show, V : Show] Show for Map[K, V] with output(self, logger) {
  logger.write_string("{")
  for x = 0, y = self.head {
    match (x, y) {
      (_, None) => break logger.write_string("}")
      (i, Some(entry)) => {
        if i > 0 {
          logger.write_string(", ")
        }
        logger.write_object(entry.key)
        logger.write_string(": ")
        logger.write_object(entry.value)
        continue i + 1, entry.next
      }
    }
  }
}

pub fn[K, V] Map::length(self : Map[K, V]) -> Int {
  self.size
}

pub fn[K, V] Map::is_empty(self : Map[K, V]) -> Bool {
  self.size == 0
}

pub fn[K, V] Map::iter(self : Map[K, V]) -> Iter[(K, V)] {
  let mut curr_entry = self.head
  let len = self.size
  let mut remaining = len
  Iter::new(
    fn() {
      guard remaining > 0 && curr_entry is Some(entry) else { None }
      curr_entry = entry.next
      remaining -= 1
      Some((entry.key, entry.value))
    },
    size_hint=len,
  )
}

pub fn[K, V] Map::iter2(self : Map[K, V]) -> Iter2[K, V] {
  let iter = self.iter()
  Iter2::new(
    fn() {
      iter.next()
    },
    size_hint=self.length(),
  )
}
